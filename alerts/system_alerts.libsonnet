{
  prometheusAlerts+:: {
    groups+: [
      {
        name: 'kubernetes-system',
        rules: [
          {
            expr: |||
              max(kube_node_status_ready{%(kubeStateMetricsSelector)s, condition="false"} == 1) BY (node)
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              message: '{{ $labels.node }} has been unready for more than an hour',
            },
            'for': '1h',
            alert: 'KubeNodeNotReady',
          },
          {
            alert: 'KubeVersionMismatch',
            expr: |||
              count(count(kubernetes_build_info{%(notKubeDnsSelector)s}) by (gitVersion)) > 1
            ||| % $._config,
            'for': '1h',
            labels: {
              severity: 'warning',
            },
            annotations: {
              message: 'There are {{ $value }} different versions of Kubernetes components running.',
            },
          },
          {
            alert: 'KubeClientErrors',
            expr: |||
              sum(rate(rest_client_requests_total{code!~"2.."}[5m])) by (instance, job) * 100
                /
              sum(rate(rest_client_requests_total[5m])) by (instance, job)
                > 1
            |||,
            'for': '15m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              message: "Kubernetes API server client '{{ $labels.job }}/{{ $labels.instance }}' is experiencing {{ printf \"%0.0f\" $value }}% errors.'",
            },
          },
          {
            alert: 'KubeClientErrors',
            expr: |||
              sum(rate(ksm_scrape_error_total{%(kubeStateMetricsSelector)s}[5m])) by (instance, job) > 0.1
            ||| % $._config,
            'for': '15m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              message: "Kubernetes API server client '{{ $labels.job }}/{{ $labels.instance }}' is experiencing {{ printf \"%0.0f\" $value }} errors / sec.'",
            },
          },
        ],
      },
    ],
  },
}
