{
  _config+:: {
    kubeApiserverSelector: 'job="kube-apiserver"',
    podLabel: 'pod',
    kubeApiserverReadSelector: 'verb=~"LIST|GET"',
    kubeApiserverWriteSelector: 'verb=~"POST|PUT|PATCH|DELETE"',
  },

  prometheusRules+:: {
    groups+: [
      {
        local SLODays = $._config.SLOs.apiserver.days + 'd',
        local SLOTarget = $._config.SLOs.apiserver.target,
        local verbs = [
          { type: 'read', selector: $._config.kubeApiserverReadSelector },
          { type: 'write', selector: $._config.kubeApiserverWriteSelector },
        ],

        name: 'kube-apiserver.rules',
        rules: [
          {
            record: 'apiserver_request:burnrate%(window)s' % w,
            expr: |||
              (
                (
                  # too slow
                  sum(rate(apiserver_request_duration_seconds_count{%(kubeApiserverSelector)s,%(kubeApiserverReadSelector)s}[%(window)s]))
                  -
                  (
                    sum(rate(apiserver_request_duration_seconds_bucket{%(kubeApiserverSelector)s,%(kubeApiserverReadSelector)s,scope="resource",le="0.1"}[%(window)s])) +
                    sum(rate(apiserver_request_duration_seconds_bucket{%(kubeApiserverSelector)s,%(kubeApiserverReadSelector)s,scope="namespace",le="0.5"}[%(window)s])) +
                    sum(rate(apiserver_request_duration_seconds_bucket{%(kubeApiserverSelector)s,%(kubeApiserverReadSelector)s,scope="cluster",le="5"}[%(window)s]))
                  )
                )
                +
                # errors
                sum(rate(apiserver_request_total{%(kubeApiserverSelector)s,%(kubeApiserverReadSelector)s,code=~"5.."}[%(window)s]))
              )
              /
              sum(rate(apiserver_request_total{%(kubeApiserverSelector)s,%(kubeApiserverReadSelector)s}[%(window)s]))
            ||| % {
              window: w,
              kubeApiserverSelector: $._config.kubeApiserverSelector,
              kubeApiserverReadSelector: $._config.kubeApiserverReadSelector,
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
                  sum(rate(apiserver_request_duration_seconds_count{%(kubeApiserverSelector)s,%(kubeApiserverWriteSelector)s}[%(window)s]))
                  -
                  sum(rate(apiserver_request_duration_seconds_bucket{%(kubeApiserverSelector)s,%(kubeApiserverWriteSelector)s,le="1"}[%(window)s]))
                )
                +
                sum(rate(apiserver_request_total{%(kubeApiserverSelector)s,%(kubeApiserverWriteSelector)s,code=~"5.."}[%(window)s]))
              )
              /
              sum(rate(apiserver_request_total{%(kubeApiserverSelector)s,%(kubeApiserverWriteSelector)s}[%(window)s]))
            ||| % {
              window: w,
              kubeApiserverSelector: $._config.kubeApiserverSelector,
              kubeApiserverWriteSelector: $._config.kubeApiserverWriteSelector,
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
        ] + [
          {
            record: 'apiserver_request:availability%s' % SLODays,
            expr: |||
              1 - (
                (
                  # write too slow
                  sum(increase(apiserver_request_duration_seconds_count{%(kubeApiserverWriteSelector)s}[%(SLODays)s]))
                  -
                  sum(increase(apiserver_request_duration_seconds_bucket{%(kubeApiserverWriteSelector)s,le="1"}[%(SLODays)s]))
                ) +
                (
                  # read too slow
                  sum(increase(apiserver_request_duration_seconds_count{%(kubeApiserverReadSelector)s}[%(SLODays)s]))
                  -
                  (
                    sum(increase(apiserver_request_duration_seconds_bucket{%(kubeApiserverReadSelector)s,scope="resource",le="0.1"}[%(SLODays)s])) +
                    sum(increase(apiserver_request_duration_seconds_bucket{%(kubeApiserverReadSelector)s,scope="namespace",le="0.5"}[%(SLODays)s])) +
                    sum(increase(apiserver_request_duration_seconds_bucket{%(kubeApiserverReadSelector)s,scope="cluster",le="5"}[%(SLODays)s]))
                  )
                ) +
                # errors
                sum(code:apiserver_request_total:increase%(SLODays)s{code=~"5.."})
              )
              /
              sum(code:apiserver_request_total:increase%(SLODays)s)
            ||| % ($._config { SLODays: SLODays }),
            labels: {
              verb: 'all',
            },
          },
          {
            record: 'apiserver_request:availability%s' % SLODays,
            expr: |||
              1 - (
                sum(increase(apiserver_request_duration_seconds_count{%(kubeApiserverSelector)s,%(kubeApiserverReadSelector)s}[%(SLODays)s]))
                -
                (
                  # too slow
                  sum(increase(apiserver_request_duration_seconds_bucket{%(kubeApiserverSelector)s,%(kubeApiserverReadSelector)s,scope="resource",le="0.1"}[%(SLODays)s])) +
                  sum(increase(apiserver_request_duration_seconds_bucket{%(kubeApiserverSelector)s,%(kubeApiserverReadSelector)s,scope="namespace",le="0.5"}[%(SLODays)s])) +
                  sum(increase(apiserver_request_duration_seconds_bucket{%(kubeApiserverSelector)s,%(kubeApiserverReadSelector)s,scope="cluster",le="5"}[%(SLODays)s]))
                )
                +
                # errors
                sum(code:apiserver_request_total:increase%(SLODays)s{verb="read",code=~"5.."})
              )
              /
              sum(code:apiserver_request_total:increase%(SLODays)s{verb="read"})
            ||| % ($._config { SLODays: SLODays }),
            labels: {
              verb: 'read',
            },
          },
          {
            record: 'apiserver_request:availability%s' % SLODays,
            expr: |||
              1 - (
                (
                  # too slow
                  sum(increase(apiserver_request_duration_seconds_count{%(kubeApiserverWriteSelector)s}[%(SLODays)s]))
                  -
                  sum(increase(apiserver_request_duration_seconds_bucket{%(kubeApiserverWriteSelector)s,le="1"}[%(SLODays)s]))
                )
                +
                # errors
                sum(code:apiserver_request_total:increase%(SLODays)s{verb="write",code=~"5.."})
              )
              /
              sum(code:apiserver_request_total:increase%(SLODays)s{verb="write"})
            ||| % ($._config { SLODays: SLODays }),
            labels: {
              verb: 'write',
            },
          },
        ] + [
          {
            record: 'code:apiserver_request_total:increase%s' % SLODays,
            expr: |||
              sum by (code) (increase(apiserver_request_total{%s}[%s]))
            ||| % [std.join(',', [$._config.kubeApiserverSelector, verb.selector]), SLODays],
            labels: {
              verb: verb.type,
            },
          }
          for verb in verbs
        ] + [
          {
            record: 'code_resource:apiserver_request_total:rate5m',
            expr: |||
              sum by (code,resource) (rate(apiserver_request_total{%s}[5m]))
            ||| % std.join(',', [$._config.kubeApiserverSelector, verb.selector]),
            labels: {
              verb: verb.type,
            },
          }
          for verb in verbs
        ] + [
          {
            record: 'cluster_quantile:apiserver_request_duration_seconds:histogram_quantile',
            expr: |||
              histogram_quantile(0.99, sum by (le, resource) (rate(apiserver_request_duration_seconds_bucket{%s}[5m]))) > 0
            ||| % std.join(',', [$._config.kubeApiserverSelector, verb.selector]),
            labels: {
              verb: verb.type,
              quantile: '0.99',
            },
          }
          for verb in verbs
        ] + [
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
