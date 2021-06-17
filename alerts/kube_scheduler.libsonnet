{
  local kubernetesMixin = self,

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
            selector:: kubernetesMixin._config.kubeSchedulerSelector,
          },
        ],
      },
    ],
  },
}
