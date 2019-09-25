{
  _config+:: {
    kubeStateMetricsSelector: error 'must provide selector for kube-state-metrics',
    kubeletSelector: error 'must provide selector for kubelet',

    // The upper bound for the `kubelet_pleg_relist_duration_seconds` histogram
    // buckets is set to `10` seconds. Therefore the max value returned from
    // the  `histogram_quantile` function of the PLEG duration alert is capped at 10.
    kubeletPlegDurationWarningSeconds: 10,
  },

  prometheusAlerts+:: {
    groups+: [
      {
        name: 'kubernetes-system-kubelet',
        rules: [
          {
            expr: |||
              kube_node_status_condition{%(kubeStateMetricsSelector)s,condition="Ready",status="true"} == 0
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              message: '{{ $labels.node }} has been unready for more than 15 minutes.',
            },
            'for': '15m',
            alert: 'KubeNodeNotReady',
          },
          {
            expr: |||
              kube_node_spec_taint{%(kubeStateMetricsSelector)s,key="node.kubernetes.io/unreachable",effect="NoSchedule"} == 1
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              message: '{{ $labels.node }} is unreachable and some workloads may be rescheduled.',
            },
            alert: 'KubeNodeUnreachable',
          },
          {
            alert: 'KubeletTooManyPods',
            expr: |||
              max(max(kubelet_running_pod_count{%(kubeletSelector)s}) by(instance) * on(instance) group_left(node) kubelet_node_name{%(kubeletSelector)s}) by(node) / max(kube_node_status_capacity_pods{%(kubeStateMetricsSelector)s}) by(node) > 0.95
            ||| % $._config,
            'for': '15m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              message: "Kubelet '{{ $labels.node }}' is running at {{ $value | humanizePercentage }} of its Pod capacity.",
            },
          },
          {
            alert: 'KubeNodeReadinessFlapping',
            expr: |||
              sum(changes(kube_node_status_condition{status='true',condition='Ready'}[15m])) by (node) > 2
            ||| % $._config,
            'for': '1m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              message: 'The readiness status of node {{ $labels.node }} has changed {{ $value }} times in the last 15 minutes.',
            },
          },
          {
            alert: 'KubeletPlegDurationHigh',
            expr: |||
              histogram_quantile(0.99, sum(rate(kubelet_pleg_relist_duration_seconds_bucket[5m])) by (node, le)) >= %(kubeletPlegDurationWarningSeconds)s
            ||| % $._config,
            'for': '5m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              message: 'The Kubelet Pod Liecycle Event Generator has a 99th percentile duration of {{ $value }} seconds on node {{ $labels.node }}.',
            },
          },
          (import '../lib/absent_alert.libsonnet') {
            componentName:: 'Kubelet',
            selector:: $._config.kubeletSelector,
          },
        ],
      },
    ],
  },
}
