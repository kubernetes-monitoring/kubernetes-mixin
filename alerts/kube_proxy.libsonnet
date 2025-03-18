{
  _config+:: {
    kubeProxySelector: error 'must provide selector for kube-proxy',
  },

  prometheusAlerts+:: {
    groups+: [
      {
        name: 'kubernetes-system-kube-proxy',
        source_tenants: $._config['sourceTenants'],
        rules: [
          (import '../lib/absent_alert.libsonnet') {
            componentName:: 'KubeProxy',
            selector:: $._config.kubeProxySelector,
          },
        ],
      },
    ],
  },
}
