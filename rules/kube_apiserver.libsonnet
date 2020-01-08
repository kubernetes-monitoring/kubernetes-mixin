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
            record: 'cluster:apiserver_request_duration_seconds:mean5m',
            expr: |||
              sum(rate(apiserver_request_duration_seconds_sum{subresource!="log",verb!~"LIST|WATCH|WATCHLIST|PROXY|CONNECT"}[5m])) without(instance, %(podLabel)s)
              /
              sum(rate(apiserver_request_duration_seconds_count{subresource!="log",verb!~"LIST|WATCH|WATCHLIST|PROXY|CONNECT"}[5m])) without(instance, %(podLabel)s)
            ||| % ($._config),
          },
        ] + [
          {
            record: 'cluster_quantile:apiserver_request_duration_seconds:histogram_quantile',
            expr: |||
              histogram_quantile(%(quantile)s, sum(rate(apiserver_request_duration_seconds_bucket{%(kubeApiserverSelector)s,subresource!="log",verb!~"LIST|WATCH|WATCHLIST|PROXY|CONNECT"}[5m])) without(instance, %(podLabel)s))
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
