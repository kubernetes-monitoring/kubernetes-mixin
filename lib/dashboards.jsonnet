local dashboards = (import 'mixin.libsonnet').grafana_dashboards;

{
  [name]: dashboards[name]
  for name in std.objectFields(dashboards)
}
