{
  _config+:: {
    notKubeDnsCoreDnsSelector: 'job!~"kube-dns|coredns"',
  },

  prometheusAlerts+:: {
    groups+: [
      {
        name: 'kubernetes-system',
        rules: [
          {
            alert: 'KubeClientErrors',
            // Many clients use get requests to check the existence of objects,
            // this is normal and an expected error, therefore it should be
            // ignored in this alert.
            expr: |||
              (sum(rate(rest_client_requests_total{code=~"5.."}[5m])) by (instance, job)
                /
              sum(rate(rest_client_requests_total[5m])) by (instance, job))
              > 0.01
            |||,
            'for': '15m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              message: "Kubernetes API server client '{{ $labels.job }}/{{ $labels.instance }}' is experiencing {{ $value | humanizePercentage }} errors.'",
            },
          },
        ],
      },
    ],
  },
}
