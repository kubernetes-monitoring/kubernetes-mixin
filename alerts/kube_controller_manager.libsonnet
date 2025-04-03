{
  _config+:: {
    kubeControllerManagerSelector: error 'must provide selector for kube-controller-manager',
  },

  prometheusAlerts+:: {
    groups+: [
      {
        name: 'kubernetes-system-controller-manager',
        source_tenants: $._config['sourceTenants'],
        rules: [
          (import '../lib/absent_alert.libsonnet') {
            componentName:: 'KubeControllerManager',
            selector:: $._config.kubeControllerManagerSelector,
          },
        ],
      },
    ],
  },
}
