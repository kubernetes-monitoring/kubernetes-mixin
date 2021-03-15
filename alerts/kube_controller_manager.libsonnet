{
  _config+:: {
    kubeControllerManagerSelector: error 'must provide selector for kube-controller-manager',
  },

  prometheusAlerts+:: if !$._config.managedCluster then {
    groups+: [
      {
        name: 'kubernetes-system-controller-manager',
        rules: [
          (import '../lib/absent_alert.libsonnet') {
            componentName:: 'KubeControllerManager',
            selector:: $._config.kubeControllerManagerSelector,
          },
        ],
      },
    ],
  } else {},
}
