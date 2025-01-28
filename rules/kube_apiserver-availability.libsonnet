{
  prometheusRules+:: {
    local SLODays = $._config.SLOs.apiserver.days + 'd',
    local verbs = [
      { type: 'read', selector: $._config.kubeApiserverReadSelector },
      { type: 'write', selector: $._config.kubeApiserverWriteSelector },
    ],

    groups+: [
      {
        name: 'kube-apiserver-availability.rules',
        interval: '3m',
        rules: [
          {
            record: 'code_verb:apiserver_request_total:increase%s' % SLODays,
            expr: |||
              avg_over_time(code_verb:apiserver_request_total:increase1h[%s]) * 24 * %d
            ||| % [SLODays, $._config.SLOs.apiserver.days],
          },
        ] + [
          {
            record: 'code:apiserver_request_total:increase%s' % SLODays,
            expr: |||
              sum by (%s, code) (code_verb:apiserver_request_total:increase%s{%s})
            ||| % [$._config.clusterLabel, SLODays, verb.selector],
            labels: {
              verb: verb.type,
            },
          }
          for verb in verbs
        ] + [
          {
            record: 'cluster_verb_scope_le:apiserver_request_sli_duration_seconds_bucket:increase1h',
            expr: |||
              sum by (%(clusterLabel)s, verb, scope, le) (increase(apiserver_request_sli_duration_seconds_bucket[1h]))
            ||| % $._config,
          },
          {
            record: 'cluster_verb_scope_le:apiserver_request_sli_duration_seconds_bucket:increase%s' % SLODays,
            expr: |||
              sum by (%s, verb, scope, le) (avg_over_time(cluster_verb_scope_le:apiserver_request_sli_duration_seconds_bucket:increase1h[%s]) * 24 * %s)
            ||| % [$._config.clusterLabel, SLODays, $._config.SLOs.apiserver.days],
          },
          {
            record: 'cluster_verb_scope:apiserver_request_sli_duration_seconds_count:increase1h',
            expr: |||
              sum by (%(clusterLabel)s, verb, scope) (cluster_verb_scope_le:apiserver_request_sli_duration_seconds_bucket:increase1h{le="+Inf"})
            ||| % $._config,
          },
          {
            record: 'cluster_verb_scope:apiserver_request_sli_duration_seconds_count:increase%s' % SLODays,
            expr: |||
              sum by (%s, verb, scope) (cluster_verb_scope_le:apiserver_request_sli_duration_seconds_bucket:increase%s{le="+Inf"})
            ||| % [$._config.clusterLabel, SLODays],
          },
          {
            record: 'apiserver_request:availability%s' % SLODays,
            expr: |||
              1 - (
                (
                  # write too slow
                  sum by (%(clusterLabel)s) (cluster_verb_scope:apiserver_request_sli_duration_seconds_count:increase%(SLODays)s{%(kubeApiserverWriteSelector)s})
                  -
                  sum by (%(clusterLabel)s) (cluster_verb_scope_le:apiserver_request_sli_duration_seconds_bucket:increase%(SLODays)s{%(kubeApiserverWriteSelector)s,le=~"%(kubeApiserverWriteLatency)s"})
                ) +
                (
                  # read too slow
                  sum by (%(clusterLabel)s) (cluster_verb_scope:apiserver_request_sli_duration_seconds_count:increase%(SLODays)s{%(kubeApiserverReadSelector)s})
                  -
                  (
                    (
                      sum by (%(clusterLabel)s) (cluster_verb_scope_le:apiserver_request_sli_duration_seconds_bucket:increase%(SLODays)s{%(kubeApiserverReadSelector)s,scope=~"resource|",le=~"%(kubeApiserverReadResourceLatency)s"})
                      or
                      vector(0)
                    )
                    +
                    sum by (%(clusterLabel)s) (cluster_verb_scope_le:apiserver_request_sli_duration_seconds_bucket:increase%(SLODays)s{%(kubeApiserverReadSelector)s,scope="namespace",le=~"%(kubeApiserverReadNamespaceLatency)s"})
                    +
                    sum by (%(clusterLabel)s) (cluster_verb_scope_le:apiserver_request_sli_duration_seconds_bucket:increase%(SLODays)s{%(kubeApiserverReadSelector)s,scope="cluster",le=~"%(kubeApiserverReadClusterLatency)s"})
                  )
                ) +
                # errors
                sum by (%(clusterLabel)s) (code:apiserver_request_total:increase%(SLODays)s{code=~"5.."} or vector(0))
              )
              /
              sum by (%(clusterLabel)s) (code:apiserver_request_total:increase%(SLODays)s)
            ||| % ($._config { SLODays: SLODays }),
            labels: {
              verb: 'all',
            },
          },
          {
            record: 'apiserver_request:availability%s' % SLODays,
            expr: |||
              1 - (
                sum by (%(clusterLabel)s) (cluster_verb_scope:apiserver_request_sli_duration_seconds_count:increase%(SLODays)s{%(kubeApiserverReadSelector)s})
                -
                (
                  # too slow
                  (
                    sum by (%(clusterLabel)s) (cluster_verb_scope_le:apiserver_request_sli_duration_seconds_bucket:increase%(SLODays)s{%(kubeApiserverReadSelector)s,scope=~"resource|",le=~"%(kubeApiserverReadResourceLatency)s"})
                    or
                    vector(0)
                  )
                  +
                  sum by (%(clusterLabel)s) (cluster_verb_scope_le:apiserver_request_sli_duration_seconds_bucket:increase%(SLODays)s{%(kubeApiserverReadSelector)s,scope="namespace",le=~"%(kubeApiserverReadNamespaceLatency)s"})
                  +
                  sum by (%(clusterLabel)s) (cluster_verb_scope_le:apiserver_request_sli_duration_seconds_bucket:increase%(SLODays)s{%(kubeApiserverReadSelector)s,scope="cluster",le=~"%(kubeApiserverReadClusterLatency)s"})
                )
                +
                # errors
                sum by (%(clusterLabel)s) (code:apiserver_request_total:increase%(SLODays)s{verb="read",code=~"5.."} or vector(0))
              )
              /
              sum by (%(clusterLabel)s) (code:apiserver_request_total:increase%(SLODays)s{verb="read"})
            ||| % ($._config { SLODays: SLODays, days: $._config.SLOs.apiserver.days }),
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
                  sum by (%(clusterLabel)s) (cluster_verb_scope:apiserver_request_sli_duration_seconds_count:increase%(SLODays)s{%(kubeApiserverWriteSelector)s})
                  -
                  sum by (%(clusterLabel)s) (cluster_verb_scope_le:apiserver_request_sli_duration_seconds_bucket:increase%(SLODays)s{%(kubeApiserverWriteSelector)s,le=~"%(kubeApiserverWriteLatency)s"})
                )
                +
                # errors
                sum by (%(clusterLabel)s) (code:apiserver_request_total:increase%(SLODays)s{verb="write",code=~"5.."} or vector(0))
              )
              /
              sum by (%(clusterLabel)s) (code:apiserver_request_total:increase%(SLODays)s{verb="write"})
            ||| % ($._config { SLODays: SLODays, days: $._config.SLOs.apiserver.days }),
            labels: {
              verb: 'write',
            },
          },
        ] + [
          {
            record: 'code_resource:apiserver_request_total:rate5m',
            expr: |||
              sum by (%s,code,resource) (rate(apiserver_request_total{%s}[5m]))
            ||| % [$._config.clusterLabel, std.join(',', [$._config.kubeApiserverSelector, verb.selector])],
            labels: {
              verb: verb.type,
            },
          }
          for verb in verbs
        ] + [
          {
            record: 'code_verb:apiserver_request_total:increase1h',
            expr: |||
              sum by (%s, code, verb) (increase(apiserver_request_total{%s,verb=~"LIST|GET|POST|PUT|PATCH|DELETE",code=~"%s"}[1h]))
            ||| % [$._config.clusterLabel, $._config.kubeApiserverSelector, code],
          }
          for code in ['2..', '3..', '4..', '5..']
        ],
      },
    ],
  },
}
