# OpenObserve Dashboard Samples

This directory contains sample dashboard configurations for the OpenObserve Operator.

## Available Samples

### 1. dashboard1.yaml
Dashboard demonstrating tab structure.

**Features:**
- 3 tabs with empty panels
- Minimal configuration for tab layout
- Good starting point for multi-tab dashboards

**Usage:**
```bash
kubectl apply -f dashboard1.yaml
```

### 2. dashboard2.yaml
Dashboard with tabs containing single panels.

**Features:**
- 3 tabs, each with one area chart panel
- Demonstrates basic panel configuration in tabs
- SQL query examples

**Usage:**
```bash
kubectl apply -f dashboard2.yaml
```

### 3. dashboard3.yaml
Dashboard with tabs containing multiple panels.

**Features:**
- 3 tabs, each with 2 panels (area and bar charts)
- Demonstrates panel layout within tabs
- Multiple visualization types

**Usage:**
```bash
kubectl apply -f dashboard3.yaml
```

### 4. dashboard4.yaml
Comprehensive dashboard with all chart types.

**Features:**
- 4 tabs with extensive panel examples
- All supported panel types: area, area-stacked, bar, h-bar, line, scatter, stacked, h-stacked, geomap, maps, pie, donut, heatmap, table, metric, gauge, html, markdown, sankey, custom_chart
- Complex query examples
- Good reference for advanced dashboards

**Usage:**
```bash
kubectl apply -f dashboard4.yaml
```

### 5. dashboardWithVariables.yaml
Dashboard demonstrating variable usage.

**Features:**
- Query values variables
- Constant variables
- Textbox variables
- Custom dropdown variables
- Variable usage in dashboards

**Usage:**
```bash
kubectl apply -f dashboardWithVariables.yaml
```

## Dashboard Structure

A dashboard resource requires:

```yaml
apiVersion: openobserve.ai/v1alpha1
kind: OpenObserveDashboard
metadata:
  name: my-dashboard
  namespace: o2operator
spec:
  configRef:
    name: openobserve-main    # Reference to OpenObserveConfig
  title: "My Dashboard"        # Dashboard title (unique in org/folder)
  description: "Description"   # Optional description
  org: "default"               # Organization (defaults to "default")
  folderName: "default"        # Folder name (defaults to "default")
  dashboard:
    version: 8
    tabs:                      # Array of tabs
      - tabId: "default"
        name: "Main"
        panels:                # Array of panels
          - id: panel_001
            type: area         # Panel type
            title: "Panel Title"
            description: ""
            config: {}         # Panel configuration
            queryType: sql
            queries:           # Array of queries
              - query: "SELECT ..."
                fields: {}     # Query field structure
                config: {}     # Query configuration
                joins: []
            layout: {}         # Panel position/size
            htmlContent: ""
            markdownContent: ""
            customChartContent: ""
    variables: {}              # Dashboard variables (optional)
    defaultDatetimeDuration: {} # Default time range
```

## Required Fields

### Panel Level
Each panel must have:
- `id`, `type`, `title`, `description`
- `config`, `queryType`, `queries`, `layout`
- `htmlContent`, `markdownContent`, `customChartContent`

### Query Level
Each query must have:
- `fields` - Object with stream, stream_type, x, y, z, breakdown, filter
- `config` - Query configuration object
- `joins` - Array of joins (can be empty)

### Fields Object
Must contain:
- `stream` - Stream name
- `stream_type` - logs, metrics, or traces
- `x`, `y`, `z` - Axis definitions (arrays, can be empty)
- `breakdown` - Breakdown fields (array, can be empty)
- `filter` - Filter configuration object

## Panel Types

Supported panel types:
- `area`, `area-stacked` - Area charts
- `line` - Line charts
- `bar`, `h-bar` - Bar charts (vertical and horizontal)
- `stacked`, `h-stacked` - Stacked charts
- `pie`, `donut` - Pie and donut charts
- `metric` - Single value metric
- `gauge` - Gauge visualization
- `table` - Data table
- `heatmap` - Heatmap visualization
- `geomap`, `maps` - Geographic visualizations
- `sankey` - Sankey diagrams
- `scatter` - Scatter plots
- `html`, `markdown` - Text panels
- `custom_chart` - Custom ECharts visualizations

## Variables

Supported variable types:
- `query_values` - Dynamic values from query results (requires stream and field)
- `constant` - Static constant value
- `textbox` - Free text input
- `custom` - Custom dropdown with predefined options

**Note:** `query_values` type requires the stream and fields to exist in your OpenObserve instance.

## Tips

1. **Start simple** - Use minimal-dashboard.yaml as a template
2. **Test queries** - Verify queries work in OpenObserve UI before adding to dashboards
3. **Quote special keys** - YAML requires quotes for keys like "x", "y", "z" to prevent boolean interpretation
4. **Use existing streams** - Ensure streams referenced in variables and queries actually exist
5. **Check logs** - If creation fails, check operator logs for detailed error messages

## Troubleshooting

### Dashboard creation shows "created" but fails
- Check operator logs: `kubectl logs -n o2operator -l app=openobserve-operator`
- Verify OpenObserveConfig is Ready: `kubectl get openobserveconfig -n o2operator`
- Check dashboard status: `kubectl get openobservedashboard -n o2operator`

### Deletion stuck
- Check if OpenObserveConfig connection works
- If stuck, force delete: `kubectl patch openobservedashboard <name> -n o2operator -p '{"metadata":{"finalizers":[]}}' --type=merge`

### Duplicate dashboards created
- Fixed in latest version - now adopts existing dashboards with same title
- Deletion will clean up all duplicates

### Variables fail with 500 error
- Verify the stream exists in OpenObserve
- Verify the field exists in the stream
- Try removing filters first to isolate the issue
- Use simpler variable types (constant, textbox) instead of query_values

## More Information

- See [main README](../../README.md) for operator overview
- See [O2OPERATOR_FEATURES.md](../../docs/O2OPERATOR_FEATURES.md) for detailed features
- See [TROUBLESHOOTING.md](../../docs/TROUBLESHOOTING.md) for common issues
