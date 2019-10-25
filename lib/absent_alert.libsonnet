{
  local absentAlert = self,
  componentName:: error 'must provide component name',
  selector:: error 'must provide selector for component',

  alert: '%sDown' % absentAlert.componentName,
  expr: |||
    absent(up{%s} == 1)
  ||| % absentAlert.selector,
  'for': '15m',
  labels: {
    severity: 'critical',
  },
  annotations: {
    message: '%s has disappeared from Prometheus target discovery.' % absentAlert.componentName,
  },
}
