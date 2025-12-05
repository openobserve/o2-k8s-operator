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

# Function to check if resource is stuck in deletion
check_stuck_resource() {
    local resource_type=$1
    local name=$2
    local namespace=$3

    # Check if resource has deletionTimestamp set
    deletion_timestamp=$(kubectl get $resource_type $name -n $namespace -o jsonpath='{.metadata.deletionTimestamp}' 2>/dev/null)

    if [ -n "$deletion_timestamp" ]; then
        return 0  # Resource is stuck
    else
        return 1  # Resource is not stuck
    fi
}

# Function to remove finalizers from stuck resources
remove_finalizers_if_stuck() {
    local resource_type=$1
    local resource_plural=$2
    local resource_short=$3

    echo -e "${YELLOW}Checking for stuck ${resource_type} resources...${NC}"

    local found_stuck=false

    # Get all resources with namespace and name
    while IFS= read -r line; do
        if [ -z "$line" ]; then
            continue
        fi

        namespace=$(echo $line | awk '{print $1}')
        name=$(echo $line | awk '{print $2}')

        if [ -z "$namespace" ] || [ -z "$name" ]; then
            continue
        fi

        # Check if resource is stuck (has deletionTimestamp)
        if check_stuck_resource $resource_short $name $namespace; then
            echo -e "${YELLOW}  Found stuck resource: $name in namespace $namespace${NC}"
            found_stuck=true

            # Remove finalizers
            echo -e "${YELLOW}  Removing finalizers from $name...${NC}"
            kubectl patch $resource_short $name -n $namespace \
                -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || \
            kubectl patch $resource_short $name -n $namespace \
                --type json -p='[{"op": "remove", "path": "/metadata/finalizers"}]' 2>/dev/null || true

            # Wait a moment for the resource to be deleted
            sleep 1

            # Check if resource still exists
            if kubectl get $resource_short $name -n $namespace &>/dev/null; then
                echo -e "${RED}  Warning: $name still exists after removing finalizers${NC}"
            else
                echo -e "${GREEN}  ✓ $name deleted successfully${NC}"
            fi
        fi
    done < <(kubectl get $resource_plural --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name --no-headers 2>/dev/null)

    if [ "$found_stuck" = false ]; then
        echo -e "${GREEN}  No stuck ${resource_type} resources found${NC}"
    fi
}

# Function to uninstall the operator
uninstall_operator() {
    echo -e "${YELLOW}Uninstalling OpenObserve Operator...${NC}"

    # First, delete webhook configuration to prevent validation during cleanup
    echo -e "${YELLOW}Removing webhook configuration...${NC}"
    kubectl delete validatingwebhookconfiguration openobserve-validating-webhook --ignore-not-found=true

    # Stop the operator deployment to prevent it from interfering
    echo -e "${YELLOW}Stopping operator deployment...${NC}"
    kubectl scale deployment/${OPERATOR_NAME} -n ${NAMESPACE} --replicas=0 --timeout=30s 2>/dev/null || true

    # Wait for operator pods to terminate
    kubectl wait --for=delete pod -l app=${OPERATOR_NAME} -n ${NAMESPACE} --timeout=30s 2>/dev/null || true

    # Check for and remove finalizers from stuck resources
    echo -e "${YELLOW}Checking for stuck resources and removing finalizers...${NC}"

    # Process each resource type
    remove_finalizers_if_stuck "OpenObserveAlert" "openobservealerts" "openobservealert"
    remove_finalizers_if_stuck "OpenObservePipeline" "openobservepipelines" "openobservepipeline"
    remove_finalizers_if_stuck "OpenObserveFunction" "openobservefunctions" "openobservefunction"
    remove_finalizers_if_stuck "OpenObserveDestination" "openobservedestinations" "openobservedestination"
    remove_finalizers_if_stuck "OpenObserveAlertTemplate" "openobservealerttemplates" "openobservealerttemplate"
    remove_finalizers_if_stuck "OpenObserveConfig" "openobserveconfigs" "openobserveconfig"


    # Now delete all resources
    echo -e "${YELLOW}Deleting operator resources...${NC}"
    kubectl delete -f manifests/04-webhook.yaml --ignore-not-found=true 2>/dev/null || true
    kubectl delete -f manifests/03-deployment.yaml --ignore-not-found=true 2>/dev/null || true
    kubectl delete -f manifests/02-rbac.yaml --ignore-not-found=true 2>/dev/null || true

    # Try to delete all custom resources (with timeout to prevent hanging)
    echo -e "${YELLOW}Deleting custom resources...${NC}"
    kubectl delete openobservealerts --all --all-namespaces --ignore-not-found=true --timeout=10s 2>/dev/null || true
    kubectl delete openobservepipelines --all --all-namespaces --ignore-not-found=true --timeout=10s 2>/dev/null || true
    kubectl delete openobservefunctions --all --all-namespaces --ignore-not-found=true --timeout=10s 2>/dev/null || true
    kubectl delete openobservedestinations --all --all-namespaces --ignore-not-found=true --timeout=10s 2>/dev/null || true
    kubectl delete openobservealerttemplates --all --all-namespaces --ignore-not-found=true --timeout=10s 2>/dev/null || true
    kubectl delete openobserveconfigs --all --all-namespaces --ignore-not-found=true --timeout=10s 2>/dev/null || true

    # Final check - if any resources still exist with finalizers, force remove them
    echo -e "${YELLOW}Final cleanup check...${NC}"
    for resource_type in openobservealerts openobservepipelines openobservefunctions openobservedestinations openobservealerttemplates openobserveconfigs; do
        remaining=$(kubectl get $resource_type --all-namespaces --no-headers 2>/dev/null | wc -l)
        if [ "$remaining" -gt 0 ]; then
            echo -e "${YELLOW}  Force removing remaining $resource_type resources...${NC}"
            kubectl get $resource_type --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name --no-headers 2>/dev/null | \
            while read namespace name; do
                if [ -n "$namespace" ] && [ -n "$name" ]; then
                    kubectl patch ${resource_type%s} $name -n $namespace \
                        -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
                fi
            done
        fi
    done

    # Delete CRDs
    echo -e "${YELLOW}Deleting Custom Resource Definitions...${NC}"
    kubectl delete -f manifests/01-o2configs.crd.yaml --ignore-not-found=true 2>/dev/null || true
    kubectl delete -f manifests/01-o2alerts.crd.yaml --ignore-not-found=true 2>/dev/null || true
    kubectl delete -f manifests/01-o2pipelines.crd.yaml --ignore-not-found=true 2>/dev/null || true
    kubectl delete -f manifests/01-o2functions.crd.yaml --ignore-not-found=true 2>/dev/null || true
    kubectl delete -f manifests/01-o2alerttemplates.crd.yaml --ignore-not-found=true 2>/dev/null || true
    kubectl delete -f manifests/01-o2destinations.crd.yaml --ignore-not-found=true 2>/dev/null || true

    # Delete namespace (this will delete everything in it)
    echo -e "${YELLOW}Deleting namespace ${NAMESPACE}...${NC}"
    kubectl delete namespace ${NAMESPACE} --ignore-not-found=true --timeout=30s 2>/dev/null || true

    # Check if namespace is stuck
    if kubectl get namespace ${NAMESPACE} &>/dev/null; then
        echo -e "${YELLOW}Namespace ${NAMESPACE} is stuck, removing finalizers...${NC}"
        kubectl patch namespace ${NAMESPACE} -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
        kubectl delete namespace ${NAMESPACE} --ignore-not-found=true --force --grace-period=0 2>/dev/null || true
    fi

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
    kubectl apply ${DRY_RUN} -f manifests/01-o2functions.crd.yaml
    kubectl apply ${DRY_RUN} -f manifests/01-o2alerttemplates.crd.yaml
    kubectl apply ${DRY_RUN} -f manifests/01-o2destinations.crd.yaml
    echo -e "${GREEN}✓ CRDs installed${NC}"

    # Wait for CRDs to be established
    if [ -z "$DRY_RUN" ]; then
        echo -e "${YELLOW}Waiting for CRDs to be established...${NC}"
        kubectl wait --for condition=established --timeout=60s \
            crd/openobserveconfigs.openobserve.ai \
            crd/openobservepipelines.openobserve.ai \
            crd/openobservealerts.openobserve.ai \
            crd/openobservefunctions.openobserve.ai \
            crd/openobservealerttemplates.openobserve.ai \
            crd/openobservedestinations.openobserve.ai
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