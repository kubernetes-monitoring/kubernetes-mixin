{
  prometheusRules+:: {
    groups+: [
      {
        name: 'kube-apiserver-burnrate.rules',
        rules: [
          {
            record: 'apiserver_request:burnrate%(window)s' % w,
            expr: |||
              (
                (
                  # too slow
                  sum by (%(clusterLabel)s) (rate(apiserver_request_sli_duration_seconds_count{%(kubeApiserverSelector)s,%(kubeApiserverReadSelector)s,%(kubeApiserverNonStreamingSelector)s}[%(window)s]))
                  -
                  (
                    (
                      sum by (%(clusterLabel)s) (rate(apiserver_request_sli_duration_seconds_bucket{%(kubeApiserverSelector)s,%(kubeApiserverReadSelector)s,%(kubeApiserverNonStreamingSelector)s,scope=~"resource|",le=~"%(kubeApiserverReadResourceLatency)s"}[%(window)s]))
                      or
                      vector(0)
                    )
                    +
                    sum by (%(clusterLabel)s) (rate(apiserver_request_sli_duration_seconds_bucket{%(kubeApiserverSelector)s,%(kubeApiserverReadSelector)s,%(kubeApiserverNonStreamingSelector)s,scope="namespace",le=~"%(kubeApiserverReadNamespaceLatency)s"}[%(window)s]))
                    +
                    sum by (%(clusterLabel)s) (rate(apiserver_request_sli_duration_seconds_bucket{%(kubeApiserverSelector)s,%(kubeApiserverReadSelector)s,%(kubeApiserverNonStreamingSelector)s,scope="cluster",le=~"%(kubeApiserverReadClusterLatency)s"}[%(window)s]))
                  )
                )
                +
                # errors
                sum by (%(clusterLabel)s) (rate(apiserver_request_total{%(kubeApiserverSelector)s,%(kubeApiserverReadSelector)s,code=~"5.."}[%(window)s]))
              )
              /
              sum by (%(clusterLabel)s) (rate(apiserver_request_total{%(kubeApiserverSelector)s,%(kubeApiserverReadSelector)s}[%(window)s]))
            ||| % {
              clusterLabel: $._config.clusterLabel,
              window: w,
              kubeApiserverSelector: $._config.kubeApiserverSelector,
              kubeApiserverReadSelector: $._config.kubeApiserverReadSelector,
              kubeApiserverNonStreamingSelector: $._config.kubeApiserverNonStreamingSelector,
              kubeApiserverReadResourceLatency: $._config.kubeApiserverReadResourceLatency,
              kubeApiserverReadNamespaceLatency: $._config.kubeApiserverReadNamespaceLatency,
              kubeApiserverReadClusterLatency: $._config.kubeApiserverReadClusterLatency,
            },
            labels: {
              verb: 'read',
            },
          }
          for w in std.set([  // Get the unique array of short and long window rates
            w.short
            for w in $._config.SLOs.apiserver.windows
          ] + [
            w.long
            for w in $._config.SLOs.apiserver.windows
          ])
        ] + [
          {
            record: 'apiserver_request:burnrate%(window)s' % w,
            expr: |||
              (
                (
                  # too slow
                  sum by (%(clusterLabel)s) (rate(apiserver_request_sli_duration_seconds_count{%(kubeApiserverSelector)s,%(kubeApiserverWriteSelector)s,%(kubeApiserverNonStreamingSelector)s}[%(window)s]))
                  -
                  sum by (%(clusterLabel)s) (rate(apiserver_request_sli_duration_seconds_bucket{%(kubeApiserverSelector)s,%(kubeApiserverWriteSelector)s,%(kubeApiserverNonStreamingSelector)s,le=~"%(kubeApiserverWriteLatency)s"}[%(window)s]))
                )
                +
                sum by (%(clusterLabel)s) (rate(apiserver_request_total{%(kubeApiserverSelector)s,%(kubeApiserverWriteSelector)s,code=~"5.."}[%(window)s]))
              )
              /
              sum by (%(clusterLabel)s) (rate(apiserver_request_total{%(kubeApiserverSelector)s,%(kubeApiserverWriteSelector)s}[%(window)s]))
            ||| % {
              clusterLabel: $._config.clusterLabel,
              window: w,
              kubeApiserverSelector: $._config.kubeApiserverSelector,
              kubeApiserverWriteSelector: $._config.kubeApiserverWriteSelector,
              kubeApiserverNonStreamingSelector: $._config.kubeApiserverNonStreamingSelector,
              kubeApiserverWriteLatency: $._config.kubeApiserverWriteLatency,
            },
            labels: {
              verb: 'write',
            },
          }
          for w in std.set([  // Get the unique array of short and long window rates
            w.short
            for w in $._config.SLOs.apiserver.windows
          ] + [
            w.long
            for w in $._config.SLOs.apiserver.windows
          ])
        ],
      },
    ],
  },
}
