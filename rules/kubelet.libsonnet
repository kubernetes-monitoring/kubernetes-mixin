{
  local kubernetesMixin = self,

  _config+:: {
    kubeletSelector: 'job="kubelet"',
  },

  prometheusRules+:: {
    groups+: [
      {
        name: 'kubelet.rules',
        rules: [
          {
            record: 'node_quantile:kubelet_pleg_relist_duration_seconds:histogram_quantile',
            expr: |||
              histogram_quantile(%(quantile)s, sum(rate(kubelet_pleg_relist_duration_seconds_bucket[5m])) by (instance, le) * on(instance) group_left(node) kubelet_node_name{%(kubeletSelector)s})
            ||| % ({ quantile: quantile } + kubernetesMixin._config),
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
