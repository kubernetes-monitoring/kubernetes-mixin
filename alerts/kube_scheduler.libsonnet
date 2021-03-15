{
  _config+:: {
    kubeSchedulerSelector: 'job="kube-scheduler"',
  },

  prometheusAlerts+:: if !$._config.managedCluster then {
    groups+: [
      {
        name: 'kubernetes-system-scheduler',
        rules: [
          (import '../lib/absent_alert.libsonnet') {
            componentName:: 'KubeScheduler',
            selector:: $._config.kubeSchedulerSelector,
          },
        ],
      },
    ],
  } else {},
}
