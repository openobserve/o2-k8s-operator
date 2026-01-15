# OpenObserve Function Samples

This directory contains example VRL (Vector Remap Language) function configurations for the OpenObserve Kubernetes Operator. Functions enable powerful data transformation, enrichment, and processing capabilities within OpenObserve pipelines.

## Overview

The OpenObserve Function CRD (`OpenObserveFunction`) allows you to create reusable VRL transformation functions that can be applied to your data streams. VRL is a domain-specific language designed for observability data transformation, offering a safe, performant way to manipulate logs, metrics, and traces.

## What is VRL?

VRL (Vector Remap Language) is a expression-oriented language designed specifically for transforming observability data. It provides:

- **Type Safety**: Compile-time type checking prevents runtime errors
- **Performance**: Optimized for high-throughput data processing
- **Safety**: No infinite loops, controlled resource usage
- **Rich Functions**: Extensive built-in function library for data manipulation

## Why Use Functions?

- **Data Enrichment**: Add contextual information to events
- **Field Extraction**: Parse and extract structured data from unstructured logs
- **Data Normalization**: Standardize data formats across different sources
- **Filtering**: Remove unnecessary fields or sensitive information
- **Routing**: Add routing metadata based on content
- **Aggregation**: Perform calculations and aggregations
- **Format Conversion**: Transform between different data formats

## Prerequisites

Before using these samples:

1. **Deploy the OpenObserve Operator**
   ```bash
   ./deploy.sh
   ```

2. **Configure OpenObserve Connection**
   Create an OpenObserveConfig resource:
   ```bash
   kubectl apply -f configs/dev/o2dev-config.yaml
   ```

## Sample Files

| File | Description | Complexity | Key Features |
|------|-------------|------------|--------------|
| `basic-function.yaml` | Simple function adding timestamp and environment | Basic | Minimal configuration, field addition |
| `function-with-test.yaml` | Function with test cases for validation | Intermediate | Test configuration, conditional logic |
| `function-test-failure-example.yaml` | Example showing test failure scenarios | Intermediate | Error handling, test validation |
| `function-with-json-events.yaml` | JSON parsing and complex transformations | Advanced | JSON handling, nested data |
| `advanced-k8s-function.yaml` | Kubernetes log processing with enrichment | Advanced | K8s metadata, pattern matching, cleanup |

## Function Structure

### Basic Configuration

```yaml
apiVersion: openobserve.ai/v1alpha1
kind: OpenObserveFunction
metadata:
  name: <function-name>
  namespace: o2operator
spec:
  configRef:
    name: openobserve-main     # Reference to OpenObserveConfig
    namespace: o2operator

  name: <function-identifier>  # Function name in OpenObserve
  org: <organization>          # Optional: Organization name

  function: |
    # VRL code here
    .new_field = "value"
    .

  test:
    enabled: <true|false>      # Enable/disable testing
    events: []                 # Test events (if enabled)
```

## VRL Language Features

### 1. Field Operations

```vrl
# Add new fields
.new_field = "value"
.timestamp = now()

# Modify existing fields
.level = upcase(.level)

# Delete fields
del(.unwanted_field)

# Rename fields
.new_name = del(.old_name)
```

### 2. Conditional Logic

```vrl
# If statements
if .status_code >= 500 {
    .severity = "critical"
} else if .status_code >= 400 {
    .severity = "warning"
} else {
    .severity = "info"
}

# Conditional assignment
.environment = if .namespace == "prod" { "production" } else { "development" }
```

### 3. String Operations

```vrl
# String manipulation
.uppercased = upcase(.message)
.lowercased = downcase(.message)
.trimmed = trim(.message)

# Pattern matching
.contains_error = contains(.message, "error")
.matches_pattern = match(.message, r'^ERROR:.*')

# String splitting
.parts = split(.path, "/")
.service = split(.deployment, "-")[0] ?? "unknown"
```

### 4. JSON Parsing

```vrl
# Parse JSON
parsed, err = parse_json(.body)
if err == null {
    .parsed_body = parsed
}

# Access nested JSON
if exists(.parsed_body.user.id) {
    .user_id = .parsed_body.user.id
}
```

### 5. Data Type Conversion

```vrl
# Type conversions
.int_value = to_int(.string_value) ?? 0
.float_value = to_float(.string_value) ?? 0.0
.string_value = to_string(.numeric_value)
.bool_value = to_bool(.string_value) ?? false
```

### 6. Error Handling

```vrl
# Safe parsing with error handling
result, err = parse_json(.json_string)
if err != null {
    .parse_error = err
    .valid_json = false
} else {
    .data = result
    .valid_json = true
}
```

## Common Use Cases

### 1. Log Level Normalization

```vrl
# Normalize different log level formats
.normalized_level = if contains(downcase(.level ?? ""), "err") {
    "ERROR"
} else if contains(downcase(.level ?? ""), "warn") {
    "WARNING"
} else if contains(downcase(.level ?? ""), "info") {
    "INFO"
} else if contains(downcase(.level ?? ""), "debug") {
    "DEBUG"
} else {
    "UNKNOWN"
}
```

### 2. Kubernetes Metadata Enrichment

```vrl
# Extract service from deployment name
if exists(.k8s_deployment_name) {
    .service = split(.k8s_deployment_name, "-")[0] ?? "unknown"

    # Derive environment from namespace
    .environment = if .k8s_namespace_name == "production" {
        "prod"
    } else if .k8s_namespace_name == "staging" {
        "staging"
    } else {
        "dev"
    }
}
```

### 3. Sensitive Data Masking

```vrl
# Mask email addresses
if exists(.email) {
    parts = split(.email, "@")
    if length(parts) == 2 {
        .email = slice(parts[0], 0, 3) + "***@" + parts[1]
    }
}

# Remove sensitive fields
del(.password)
del(.api_key)
del(.ssn)
```

### 4. Metric Calculation

```vrl
# Calculate request duration
if exists(.start_time) && exists(.end_time) {
    .duration_ms = to_int(.end_time) - to_int(.start_time)

    # Add performance category
    .performance = if .duration_ms < 100 {
        "fast"
    } else if .duration_ms < 1000 {
        "normal"
    } else {
        "slow"
    }
}
```

### 5. Error Detection

```vrl
# Flag errors based on multiple indicators
.is_error = false

# Check status code
if exists(.status_code) && to_int(.status_code) ?? 0 >= 400 {
    .is_error = true
}

# Check log level
if exists(.level) && downcase(.level) == "error" {
    .is_error = true
}

# Check message content
if exists(.message) {
    search_text = downcase(.message)
    if contains(search_text, "error") ||
       contains(search_text, "exception") ||
       contains(search_text, "failed") {
        .is_error = true
    }
}
```

## Testing Functions

### Why Test Functions?

- **Validation**: Ensure functions work as expected before deployment
- **Regression Prevention**: Catch breaking changes
- **Documentation**: Test cases serve as usage examples
- **Confidence**: Deploy with certainty that transformations work

### Test Configuration

```yaml
test:
  enabled: true
  events:
    - _timestamp: 1735128523652186
      level: "info"
      message: "Test message"
      # Input event fields

  # Optional: Expected output (if not provided, just checks for errors)
  expected:
    - _timestamp: 1735128523652186
      level: "INFO"          # Transformed to uppercase
      message: "Test message"
      processed_at: "2024-..."  # Added by function
```

### Running Tests

Tests are automatically executed when:
1. Creating a new function
2. Updating an existing function
3. The function will only be created/updated if tests pass

## Deployment

### Deploy a Single Function

```bash
# Deploy basic function
kubectl apply -f samples/functions/basic-function.yaml

# Check function status
kubectl get openobservefunctions -n o2operator
```

### Deploy All Functions

```bash
kubectl apply -f samples/functions/*.yaml
```

### Verify Function Creation

```bash
# Get function details
kubectl describe openobservefunction basic-transformation -n o2operator

# Check operator logs for function status
kubectl logs -n o2operator deployment/openobserve-operator | grep function
```

## Using Functions in Pipelines

Functions can be referenced in OpenObserve pipelines:

```yaml
apiVersion: openobserve.ai/v1alpha1
kind: OpenObservePipeline
metadata:
  name: log-processing-pipeline
spec:
  # ... pipeline configuration ...

  nodes:
    - id: "transform"
      type: "function"
      config:
        function_name: "k8s_log_processor"  # Reference your function
```

## Best Practices

### 1. Performance
- **Minimize Operations**: Avoid unnecessary transformations
- **Early Filtering**: Drop unwanted data early in the function
- **Efficient Parsing**: Parse JSON once and reuse the result

### 2. Error Handling
- **Check for Existence**: Always use `exists()` before accessing fields
- **Provide Defaults**: Use `??` operator for fallback values
- **Handle Parse Errors**: Check error returns from parsing functions

### 3. Maintainability
- **Clear Naming**: Use descriptive field and variable names
- **Add Comments**: Document complex logic
- **Modular Functions**: Create separate functions for different purposes

### 4. Testing
- **Comprehensive Cases**: Test edge cases and error conditions
- **Real Data**: Use realistic test data
- **Update Tests**: Keep tests current with function changes

### 5. Security
- **Remove Sensitive Data**: Don't log passwords, tokens, or PII
- **Validate Input**: Check data types and ranges
- **Limit Scope**: Only add necessary fields

## Common Patterns

### Pattern: Safe Field Access
```vrl
# Always check existence before access
if exists(.field.nested.value) {
    .extracted = .field.nested.value
}
```

### Pattern: Default Values
```vrl
# Provide defaults for missing fields
.level = .level ?? "info"
.count = to_int(.count) ?? 0
```

### Pattern: Field Cleanup
```vrl
# Remove temporary or internal fields
del(._internal)
del(.temp_*)
```

### Pattern: Conditional Enrichment
```vrl
# Only add fields when relevant
if .environment == "production" {
    .alert_team = "ops-critical"
    .sla_applicable = true
}
```

## Troubleshooting

### Function Not Working
- Check VRL syntax - use the OpenObserve UI to test
- Verify field names match your data schema
- Review operator logs for detailed error messages

### Test Failures
- Compare expected vs actual output
- Check for type mismatches
- Ensure all required fields are present

### Performance Issues
- Profile function with realistic data volumes
- Reduce complex operations
- Consider splitting into multiple functions

### Field Not Added
- Verify the function is being applied
- Check if field is deleted later in pipeline
- Ensure conditional logic is correct

## VRL Function Reference

Common VRL functions used in samples:

| Function | Description | Example |
|----------|-------------|---------|
| `now()` | Current timestamp | `.timestamp = now()` |
| `exists()` | Check field existence | `if exists(.field)` |
| `del()` | Delete field | `del(.unwanted)` |
| `parse_json()` | Parse JSON string | `data, err = parse_json(.json)` |
| `contains()` | Check string contains | `contains(.msg, "error")` |
| `split()` | Split string | `split(.path, "/")` |
| `upcase()`/`downcase()` | Change case | `upcase(.level)` |
| `to_int()`/`to_string()` | Type conversion | `to_int(.count)` |
| `length()` | Get length | `length(.array)` |
| `encode_json()` | Convert to JSON | `encode_json(.)` |

## Additional Resources

- [VRL Documentation](https://vector.dev/docs/reference/vrl/)
- [OpenObserve Function Documentation](https://openobserve.ai/docs/functions)
- [Pipeline Samples](../pipelines/README.md)
- [Troubleshooting Guide](../../docs/TROUBLESHOOTING.md)

## Contributing

To add new function samples:
1. Create a YAML file with descriptive name
2. Include comprehensive comments
3. Add test cases for validation
4. Document the use case
5. Update this README

For questions or issues, please [open an issue](https://github.com/openobserve/o2-k8s-operator/issues) on GitHub.