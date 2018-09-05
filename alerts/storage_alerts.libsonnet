{
  prometheusAlerts+:: {
    groups+: [
      {
        name: 'kubernetes-storage',
        rules: [
          {
            alert: 'KubePersistentVolumeUsageCritical',
            expr: |||
              100 * kubelet_volume_stats_available_bytes{%(prefixedNamespaceSelector)s%(kubeletSelector)s}
                /
              kubelet_volume_stats_capacity_bytes{%(prefixedNamespaceSelector)s%(kubeletSelector)s}
                < 3
            ||| % $._config,
            'for': '1m',
            labels: {
              severity: 'critical',
            },
            annotations: {
              message: 'The persistent volume claimed by {{ $labels.persistentvolumeclaim }} in namespace {{ $labels.namespace }} has {{ printf "%0.0f" $value }}% free.',
            },
          },
          {
            alert: 'KubePersistentVolumeFullInFourDays',
            expr: |||
              kubelet_volume_stats_available_bytes{%(prefixedNamespaceSelector)s%(kubeletSelector)s} and predict_linear(kubelet_volume_stats_available_bytes{%(prefixedNamespaceSelector)s%(kubeletSelector)s}[%(volumeFullPredictionSampleTime)s], 4 * 24 * 3600) < 0
            ||| % $._config,
            'for': '5m',
            labels: {
              severity: 'critical',
            },
            annotations: {
              message: 'Based on recent sampling, the persistent volume claimed by {{ $labels.persistentvolumeclaim }} in namespace {{ $labels.namespace }} is expected to fill up within four days. Currently {{ $value }} bytes are available.',
            },
          },
        ],
      },
    ],
  },
}
