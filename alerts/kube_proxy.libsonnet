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
            alert: 'KubeProxyUnreachable',
            expr: 'up{%s} == 0' % $._config.kubeProxySelector,
            'for': '15m',
            labels: {
              severity: 'critical',
            },
            annotations: {
              description: 'Pod {{ $labels.pod }} is not being scraped successfully.',
              summary: 'KubeProxy is unreachable.',
            },
          },
        ],
      },
    ],
  },
}
