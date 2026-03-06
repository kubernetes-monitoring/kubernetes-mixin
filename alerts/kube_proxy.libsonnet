{
  _config+:: {
    kubeProxySelector: error 'must provide selector for kube-proxy',
  },

  prometheusAlerts+:: {
    groups+: [
      {
        name: 'kubernetes-system-kube-proxy',
        rules: [
          (import '../lib/absent_alert.libsonnet') {
            componentName:: 'KubeProxy',
            selector:: $._config.kubeProxySelector,
          },
          {
            alert: 'KubeProxyInstanceUnreachable',
            expr: 'up{%s} == 0' % $._config.kubeProxySelector,
            'for': '15m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: 'A KubeProxy instance has been unreachable for more than 15 minutes.',
              summary: 'KubeProxy instance is unreachable.',
            },
          },
        ],
      },
    ],
  },
}
