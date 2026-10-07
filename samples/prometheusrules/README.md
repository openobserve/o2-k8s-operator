# PrometheusRule support

A `PrometheusRuleBinding` turns existing prometheus-operator `PrometheusRule`
objects into OpenObserve alerts. You don't edit the rules. The operator only
reads them: it never adds a finalizer, status or annotation, so the same objects
keep working in Prometheus and with `promtool test rules`.

The binding supplies what a stock rule doesn't carry: which OpenObserve to use,
the folder, the destinations, and defaults.

## Quick start

```bash
# Prerequisite: the PrometheusRule CRD (installed by prometheus-operator or kube-prometheus-stack)
kubectl get crd prometheusrules.monitoring.coreos.com

kubectl apply -f samples/prometheusrules/prometheusrule-example.yaml
kubectl apply -f samples/prometheusrules/prometheusrule-binding.yaml
kubectl get prb -n o2operator
```

```text
NAME              RULES   ALERTS   FAILED   READY   AGE
platform-alerts   2       2        0        True    30s
```

## How a rule becomes an alert

The rule's `expr` is sent to OpenObserve **unchanged**. Each series the expression
returns fires its own alert, as in Prometheus. Comparisons, `bool`, `absent()`,
vector-to-vector matching and `vector(1)` all work.

| Prometheus | OpenObserve |
|---|---|
| `alert` | alert name (characters OpenObserve rejects become `_`) |
| `expr` | PromQL query, unchanged, one alert per returned series |
| `for` | pending period |
| `keep_firing_for` | keep-firing period (OpenObserve v1.1.0+, at most 24h) |
| group `interval` | evaluation frequency (whole minutes, at least 1) |
| `labels` | context attributes; `severity` also sets the alert priority |
| `labels.alert_group` | tag `alert_group:<value>` |
| `annotations.summary` | row template |
| `annotations.description` | description |
| `annotations.runbook_url` | runbook link |
| other annotations | context attributes |
| `{{ $labels.x }}`, `{{ $value }}` | `{x}`, `{value}` |
| recording rules | skipped, counted in status |

Template constructs OpenObserve can't express, such as `{{ $value | humanize }}`
or `{{ if … }}`, are reported as `TranslationWarning` events on the
PrometheusRule. The alert is still created.

To see exactly what will be sent, without a cluster:

```bash
o2 promrule render -f prometheusrule-example.yaml --binding prometheusrule-binding.yaml
```

## Binding fields

| Field | Default | Meaning |
|---|---|---|
| `configRef` | required | the `Config` holding the OpenObserve connection |
| `org` | the Config's org | organization to create alerts in |
| `ruleSelector` | required | label selector on PrometheusRule objects |
| `namespaceSelector` | the binding's namespace | `{}` selects every namespace |
| `folder` | `default` | alert folder, created if missing |
| `destinations` | required | existing destination names |
| `template` | each destination's own | template override |
| `tags` | none | extra tags on every alert |
| `defaults.enabled` | `true` | applies to newly created alerts only |
| `defaults.perSeries` | `true` | one alert per series |
| `defaults.period` | `1m` | look-back window |
| `defaults.frequency` | group `interval` | evaluation frequency override |
| `defaults.silence` | `0m` | `4h` matches Alertmanager's default repeat interval |
| `defaults.notifyOnRecovery` | `false` | notify once when an alert recovers |
| `defaults.severityLabel` | `severity` | label mapped to priority |
| `defaults.severityPriority` | critical→1, error/high→2, warning→3, info→4, low/none→5 | merged over the built-in map |
| `defaults.tagLabels` | `[alert_group]` | labels turned into tags |
| `overrides[]` | none | per alert name: `silence`, `period`, `template`, `destinations`, `priority`, `enabled`, `dedupFields` |

## Ownership and deletion

Each managed alert carries the tags `managed-by:o2-operator`,
`o2-binding:<cluster>/<namespace>/<name>`, `o2-rule:<key>`, `o2-hash:<hash>` and
`o2-name:<hash>`. An alert counts as managed only when all of these hold:
- it carries the binding's tags;
- its owner is the user the Config signs in as;
- its `o2-name` tag still matches its name.

As a result:

- Alerts that people created are never modified or deleted. That includes UI
  clones, which copy the tags but get a new name.
- Renaming a managed alert in the UI detaches it; the operator then creates a
  fresh one.
- Extra copies with the same name are reported (`DuplicateIgnored`), never
  deleted.
- Removing a rule, or relabelling its object out of the selector, deletes that
  rule's alert.
- If the selector matches no object at all, nothing is deleted, and a
  `NoRulesSelected` warning is raised. Delete the binding to remove every alert.
- Deleting the binding deletes its alerts.
- A paused alert stays paused across rule updates, unless an override sets
  `enabled`.

Set `CLUSTER_NAME` on the operator Deployment when several clusters bind rules
into the same OpenObserve org. Without it, the `kube-system` namespace UID
identifies the cluster.

## Differences from Prometheus

- Evaluation looks back over `defaults.period` (1 minute by default), not at a
  single instant.
- A series that stops matching recovers after 3 evaluations, not the next one.
- Series whose value is `NaN` or `±Inf` don't fire.
- A rule with no metric of its own, such as `vector(1)`, is attached to an
  existing metrics stream. The notification variable `{stream_name}` shows that
  stream.
- The alert threshold shown in the UI, and in `{alert_threshold}`, is
  `-1.797…e308`. That is how "every returned series fires" is expressed today.

## Operator settings

| Variable | Default | Meaning |
|---|---|---|
| `PROMRULE_RECONCILE_INTERVAL_SECONDS` | `60` | resync interval |
| `PROMRULE_CONTROLLER_CONCURRENCY` | `1` | parallel bindings |
| `CLUSTER_NAME` | `kube-system` UID | cluster identity in ownership tags |

Metrics on the operator's `/metrics` endpoint:

- `o2_operator_promrule_alerts`
- `o2_operator_promrule_rule_failures`
- `o2_operator_promrule_ready`
- `o2_operator_promrule_sync_total`
