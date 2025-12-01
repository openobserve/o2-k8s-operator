#!/bin/bash

# OpenObserve Operator Deployment Script
# This script deploys the OpenObserve operator to a Kubernetes cluster

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="o2operator"
OPERATOR_NAME="openobserve-operator"
WEBHOOK_SECRET_NAME="openobserve-webhook-server-cert"
IMAGE_REPO=""
IMAGE_TAG="latest"
DRY_RUN=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --image)
            IMAGE_REPO="$2"
            shift 2
            ;;
        --tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --skip-certs)
            SKIP_CERTS="true"
            shift
            ;;
        --uninstall)
            UNINSTALL="true"
            shift
            ;;
        --dry-run)
            DRY_RUN="--dry-run=client"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --image         Docker image repository (optional, uses manifest default)"
            echo "  --tag           Docker image tag (default: latest)"
            echo "  --namespace     Namespace to deploy to (default: o2operator)"
            echo "  --skip-certs    Skip certificate generation (use existing)"
            echo "  --dry-run       Preview changes without applying them"
            echo "  --uninstall     Uninstall the operator"
            echo "  -h, --help      Show this help message"
            echo ""
            echo "Examples:"
            echo "  Deploy using default image from manifest:"
            echo "    $0"
            echo ""
            echo "  Deploy from public ECR:"
            echo "    $0 --image public.ecr.aws/zinclabs/o2operator"
            echo ""
            echo "  Deploy from private ECR:"
            echo "    $0 --image 058694856476.dkr.ecr.us-east-1.amazonaws.com/o2operator"
            echo ""
            echo "  Dry run (preview changes):"
            echo "    $0 --dry-run"
            echo ""
            echo "  Uninstall:"
            echo "    $0 --uninstall"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}Error: kubectl is not installed or not in PATH${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ kubectl is available${NC}"
}

# Function to check cluster connection
check_cluster() {
    if ! kubectl cluster-info &> /dev/null; then
        echo -e "${RED}Error: Cannot connect to Kubernetes cluster${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Connected to Kubernetes cluster${NC}"
    kubectl cluster-info | head -1
}

# Function to generate webhook certificates
generate_webhook_certs() {
    echo -e "${YELLOW}Generating webhook certificates...${NC}"

    # Create temporary directory for certificates
    CERT_DIR=$(mktemp -d)
    trap "rm -rf $CERT_DIR" EXIT

    # Generate CA private key
    openssl genrsa -out ${CERT_DIR}/ca.key 2048

    # Generate CA certificate
    openssl req -new -x509 -key ${CERT_DIR}/ca.key -out ${CERT_DIR}/ca.crt -days 3650 \
        -subj "/CN=openobserve-webhook-ca"

    # Generate server private key
    openssl genrsa -out ${CERT_DIR}/tls.key 2048

    # Generate certificate signing request
    cat <<EOF > ${CERT_DIR}/csr.conf
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
[req_distinguished_name]
[v3_req]
subjectAltName = @alt_names
[alt_names]
DNS.1 = openobserve-webhook-service
DNS.2 = openobserve-webhook-service.${NAMESPACE}
DNS.3 = openobserve-webhook-service.${NAMESPACE}.svc
DNS.4 = openobserve-webhook-service.${NAMESPACE}.svc.cluster.local
EOF

    openssl req -new -key ${CERT_DIR}/tls.key -out ${CERT_DIR}/server.csr \
        -subj "/CN=openobserve-webhook-service.${NAMESPACE}.svc" \
        -config ${CERT_DIR}/csr.conf

    # Sign the server certificate
    openssl x509 -req -in ${CERT_DIR}/server.csr -CA ${CERT_DIR}/ca.crt -CAkey ${CERT_DIR}/ca.key \
        -CAcreateserial -out ${CERT_DIR}/tls.crt -days 3650 \
        -extensions v3_req -extfile ${CERT_DIR}/csr.conf

    # Create the secret
    kubectl create secret tls ${WEBHOOK_SECRET_NAME} \
        --cert=${CERT_DIR}/tls.crt \
        --key=${CERT_DIR}/tls.key \
        --namespace=${NAMESPACE} \
        --dry-run=client -o yaml | kubectl apply -f -

    # Get CA bundle for webhook configuration
    CA_BUNDLE=$(cat ${CERT_DIR}/ca.crt | base64 | tr -d '\n')

    # Update webhook configuration with CA bundle
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/caBundle: .*/caBundle: ${CA_BUNDLE}/" manifests/04-webhook.yaml
    else
        # Linux
        sed -i "s/caBundle: .*/caBundle: ${CA_BUNDLE}/" manifests/04-webhook.yaml
    fi

    echo -e "${GREEN}✓ Webhook certificates generated and secret created${NC}"
}

# Function to uninstall the operator
uninstall_operator() {
    echo -e "${YELLOW}Uninstalling OpenObserve Operator...${NC}"

    # Delete webhook configuration
    kubectl delete validatingwebhookconfiguration openobserve-validating-webhook --ignore-not-found=true

    # First, remove finalizers from all custom resources to prevent them from getting stuck
    echo -e "${YELLOW}Removing finalizers from custom resources...${NC}"

    # Remove finalizers from OpenObserveAlerts
    for resource in $(kubectl get openobservealerts --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name --no-headers 2>/dev/null); do
        namespace=$(echo $resource | awk '{print $1}')
        name=$(echo $resource | awk '{print $2}')
        kubectl patch openobservealert $name -n $namespace --type json -p='[{"op": "remove", "path": "/metadata/finalizers"}]' 2>/dev/null || true
    done

    # Remove finalizers from OpenObservePipelines
    for resource in $(kubectl get openobservepipelines --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name --no-headers 2>/dev/null); do
        namespace=$(echo $resource | awk '{print $1}')
        name=$(echo $resource | awk '{print $2}')
        kubectl patch openobservepipeline $name -n $namespace --type json -p='[{"op": "remove", "path": "/metadata/finalizers"}]' 2>/dev/null || true
    done

    # Remove finalizers from OpenObserveConfigs
    for resource in $(kubectl get openobserveconfigs --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name --no-headers 2>/dev/null); do
        namespace=$(echo $resource | awk '{print $1}')
        name=$(echo $resource | awk '{print $2}')
        kubectl patch openobserveconfig $name -n $namespace --type json -p='[{"op": "remove", "path": "/metadata/finalizers"}]' 2>/dev/null || true
    done


    # Delete all resources in reverse order
    kubectl delete -f manifests/04-webhook.yaml --ignore-not-found=true
    kubectl delete -f manifests/03-deployment.yaml --ignore-not-found=true
    kubectl delete -f manifests/02-rbac.yaml --ignore-not-found=true

    # Delete all custom resources before CRDs (with timeout to prevent hanging)
    kubectl delete openobservealerts --all --all-namespaces --ignore-not-found=true --timeout=10s
    kubectl delete openobservepipelines --all --all-namespaces --ignore-not-found=true --timeout=10s
    kubectl delete openobserveconfigs --all --all-namespaces --ignore-not-found=true --timeout=10s

    # Delete CRDs
    kubectl delete -f manifests/01-o2configs.crd.yaml --ignore-not-found=true
    kubectl delete -f manifests/01-o2alerts.crd.yaml --ignore-not-found=true
    kubectl delete -f manifests/01-o2pipelines.crd.yaml --ignore-not-found=true

    # Delete namespace (this will delete everything in it)
    kubectl delete namespace ${NAMESPACE} --ignore-not-found=true

    echo -e "${GREEN}✓ OpenObserve Operator uninstalled successfully${NC}"
    exit 0
}

# Function to deploy the operator
deploy_operator() {
    echo -e "${BLUE}=== Deploying OpenObserve Operator ===${NC}"

    if [ -n "$DRY_RUN" ]; then
        echo -e "${YELLOW}Running in DRY-RUN mode - no changes will be applied${NC}"
    fi

    # Update image in deployment if provided
    if [ -n "$IMAGE_REPO" ]; then
        echo -e "${YELLOW}Using custom image: ${IMAGE_REPO}:${IMAGE_TAG}${NC}"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            sed -i '' "s|image: .*|image: ${IMAGE_REPO}:${IMAGE_TAG}|" manifests/03-deployment.yaml
        else
            # Linux
            sed -i "s|image: .*|image: ${IMAGE_REPO}:${IMAGE_TAG}|" manifests/03-deployment.yaml
        fi
    else
        # Use the image already defined in the deployment manifest
        EXISTING_IMAGE=$(grep "image:" manifests/03-deployment.yaml | grep -v "#" | head -1 | awk '{print $2}')
        echo -e "${YELLOW}Using existing image from manifest: ${EXISTING_IMAGE}${NC}"
    fi

    # Apply namespace
    echo -e "${YELLOW}Creating namespace...${NC}"
    kubectl apply ${DRY_RUN} -f manifests/00-namespace.yaml
    echo -e "${GREEN}✓ Namespace created${NC}"

    # Apply CRDs
    echo -e "${YELLOW}Installing CRDs...${NC}"
    kubectl apply ${DRY_RUN} -f manifests/01-o2configs.crd.yaml
    kubectl apply ${DRY_RUN} -f manifests/01-o2alerts.crd.yaml
    kubectl apply ${DRY_RUN} -f manifests/01-o2pipelines.crd.yaml
    echo -e "${GREEN}✓ CRDs installed${NC}"

    # Wait for CRDs to be established
    if [ -z "$DRY_RUN" ]; then
        echo -e "${YELLOW}Waiting for CRDs to be established...${NC}"
        kubectl wait --for condition=established --timeout=60s \
            crd/openobserveconfigs.openobserve.ai \
            crd/openobservepipelines.openobserve.ai \
            crd/openobservealerts.openobserve.ai
        echo -e "${GREEN}✓ CRDs are ready${NC}"
    else
        echo -e "${YELLOW}Skipping CRD wait (dry-run mode)${NC}"
    fi

    # Apply RBAC
    echo -e "${YELLOW}Setting up RBAC...${NC}"
    kubectl apply ${DRY_RUN} -f manifests/02-rbac.yaml
    echo -e "${GREEN}✓ RBAC configured${NC}"

    # Generate certificates if not skipped
    if [ "$SKIP_CERTS" != "true" ] && [ -z "$DRY_RUN" ]; then
        generate_webhook_certs
    elif [ -n "$DRY_RUN" ]; then
        echo -e "${YELLOW}Skipping certificate generation (dry-run mode)${NC}"
    else
        echo -e "${YELLOW}Skipping certificate generation (using existing)${NC}"
    fi

    # Apply webhook configuration
    echo -e "${YELLOW}Configuring webhooks...${NC}"
    kubectl apply ${DRY_RUN} -f manifests/04-webhook.yaml
    echo -e "${GREEN}✓ Webhooks configured${NC}"

    # Deploy operator
    echo -e "${YELLOW}Deploying operator...${NC}"
    kubectl apply ${DRY_RUN} -f manifests/03-deployment.yaml
    echo -e "${GREEN}✓ Operator deployed${NC}"

    # Wait for deployment to be ready
    if [ -z "$DRY_RUN" ]; then
        echo -e "${YELLOW}Waiting for operator to be ready...${NC}"
        kubectl rollout status deployment/${OPERATOR_NAME} -n ${NAMESPACE} --timeout=120s
        echo -e "${GREEN}✓ Operator is running${NC}"
    else
        echo -e "${YELLOW}Skipping deployment wait (dry-run mode)${NC}"
    fi

    # Show deployment status
    echo ""
    if [ -z "$DRY_RUN" ]; then
        echo -e "${GREEN}=== Deployment Complete ===${NC}"
        echo "Operator Status:"
        kubectl get deployment -n ${NAMESPACE} ${OPERATOR_NAME}
        echo ""
        echo "Pods:"
        kubectl get pods -n ${NAMESPACE} -l app=${OPERATOR_NAME}
        echo ""
        echo "To view operator logs:"
        echo "  kubectl logs -n ${NAMESPACE} -l app=${OPERATOR_NAME} -f"
        echo ""
        echo "To create OpenObserve resources:"
        echo "  kubectl apply -f <your-resource>.yaml"
    else
        echo -e "${GREEN}=== Dry-Run Complete ===${NC}"
        echo "No resources were actually created."
        echo "To apply these resources, run the command again without --dry-run"
    fi
}

# Main script
main() {
    echo -e "${BLUE}=== OpenObserve Operator Deployment Script ===${NC}"

    # Check prerequisites
    check_kubectl
    check_cluster

    # Check if we're in the right directory
    if [ ! -d "manifests" ]; then
        echo -e "${RED}Error: manifests directory not found${NC}"
        echo "Please run this script from the deploy directory"
        exit 1
    fi

    # Handle uninstall
    if [ "$UNINSTALL" == "true" ]; then
        uninstall_operator
    else
        deploy_operator
    fi
}

# Run main function
main "$@"