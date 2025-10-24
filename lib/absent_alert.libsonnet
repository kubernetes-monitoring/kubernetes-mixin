{
  local absentAlert = self,
  componentName:: error 'must provide component name',
  selector:: error 'must provide selector for component',

  alert: '%sDown' % absentAlert.componentName,
  expr: |||
    absent_over_time(up{%s}[5m])
  ||| % absentAlert.selector,
  'for': '15m',
  labels: {
    severity: 'critical',
  },
  annotations: {
    description: '%s has disappeared from Prometheus target discovery.' % absentAlert.componentName,
    summary: 'Target disappeared from Prometheus target discovery.',
  },
}
