{
  _config+:: {
    kubeSchedulerSelector: 'job="kube-scheduler"',
  },

  prometheusAlerts+:: {
    groups+: [
      {
        name: 'kubernetes-system-scheduler',
        source_tenants: $._config['sourceTenants'],
        rules: [
          (import '../lib/absent_alert.libsonnet') {
            componentName:: 'KubeScheduler',
            selector:: $._config.kubeSchedulerSelector,
          },
        ],
      },
    ],
  },
}
