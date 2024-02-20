{
  prometheusRules+:: {
    local verbs = [
      { type: 'read', selector: $._config.kubeApiserverReadSelector },
      { type: 'write', selector: $._config.kubeApiserverWriteSelector },
    ],

    groups+: [
      {
        name: 'kube-apiserver-histogram.rules',
        rules:
          [
            {
              record: 'cluster_quantile:apiserver_request_sli_duration_seconds:histogram_quantile',
              expr: |||
                histogram_quantile(0.99, sum by (%s, le, resource) (rate(apiserver_request_sli_duration_seconds_bucket{%s}[5m]))) > 0
              ||| % [$._config.clusterLabel, std.join(',', [$._config.kubeApiserverSelector, verb.selector, $._config.kubeApiserverNonStreamingSelector])],
              labels: {
                verb: verb.type,
                quantile: '0.99',
              },
            }
            for verb in verbs
          ],
      },
    ],
  },
}
