{
  _config+:: {
    kubeApiserverSelector: 'job="kube-apiserver"',
    podLabel: 'pod',
  },

  prometheusRules+:: {
    groups+: [
      {
        name: 'kube-apiserver.rules',
        rules: [
          {
            record: 'cluster_quantile:apiserver_request_duration_seconds:histogram_quantile',
            expr: |||
              histogram_quantile(%(quantile)s, sum(rate(apiserver_request_duration_seconds_bucket{%(kubeApiserverSelector)s}[5m])) without(instance, %(podLabel)s))
            ||| % ({ quantile: quantile } + $._config),
            labels: {
              quantile: quantile,
            },
          }
          for quantile in ['0.99', '0.9', '0.5']
        ],
      },
    ],
  },
}
