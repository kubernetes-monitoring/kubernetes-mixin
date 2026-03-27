{
  local instanceUnreachableAlert = self,
  componentName:: error 'must provide component name',
  selector:: error 'must provide selector for component',

  alert: '%sInstanceUnreachable' % instanceUnreachableAlert.componentName,
  expr: |||
    up{%s} == 0
  ||| % instanceUnreachableAlert.selector,
  'for': '15m',
  labels: {
    severity: 'warning',
  },
  annotations: {
    description: 'A %s instance has been unreachable for more than 15 minutes.' % instanceUnreachableAlert.componentName,
    summary: '%s instance is unreachable.' % instanceUnreachableAlert.componentName,
  },
}
