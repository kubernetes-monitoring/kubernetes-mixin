{
  prometheusAlerts+:: {
    groups+: [
      {
        name: 'kubernetes-absent',
        rules: [
          {
            alert: '%sDown' % name,
            expr: |||
              absent(up{%s} == 1)
            ||| % $._config.jobs[name].selector,
            'for': '15m',
            labels: {
              severity: 'critical',
            },
            annotations: {
              message: '%s has disappeared from Prometheus target discovery.' % name,
              [if 'absent_runbook_url' in $._config.jobs[name] then 'runbook_url']: $._config.jobs[name].runbook_url,
            },
          }
          for name in std.objectFields($._config.jobs)
        ],
      },
    ],
  },
}
