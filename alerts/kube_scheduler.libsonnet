{
  _config+:: {
    kubeSchedulerSelector: 'job="kube-scheduler"',
  },

  prometheusAlerts+:: {
    groups+: [
      {
        name: 'kubernetes-system-scheduler',
        rules: [
          (import '../lib/absent_alert.libsonnet') {
            componentName:: 'KubeScheduler',
            selector:: $._config.kubeSchedulerSelector,
          },
          (import '../lib/instance_unreachable_alert.libsonnet') {
            componentName:: 'KubeScheduler',
            selector:: $._config.kubeSchedulerSelector,
          },
        ],
      },
    ],
  },
}
