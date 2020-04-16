{
  _config+:: {
    kubeStateMetricsSelector: error 'must provide selector for kube-state-metrics',
    kubeletSelector: error 'must provide selector for kubelet',
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
            'for': '2m',
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
            // Some node has a capacity of 1 like AWS's Fargate and only exists while a pod is running on it.
            // We have to ignore this special node in the KubeletTooManyPods alert.
            expr: |||
              max(max(kubelet_running_pod_count{%(kubeletSelector)s}) by(instance) * on(instance) group_left(node) kubelet_node_name{%(kubeletSelector)s}) by(node) / max(kube_node_status_capacity_pods{%(kubeStateMetricsSelector)s} != 1) by(node) > 0.95
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
              sum(changes(kube_node_status_condition{status="true",condition="Ready"}[15m])) by (node) > 2
            ||| % $._config,
            'for': '15m',
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
              node_quantile:kubelet_pleg_relist_duration_seconds:histogram_quantile{quantile="0.99"} >= 10
            ||| % $._config,
            'for': '5m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              message: 'The Kubelet Pod Lifecycle Event Generator has a 99th percentile duration of {{ $value }} seconds on node {{ $labels.node }}.',
            },
          },
          {
            alert: 'KubeletPodStartUpLatencyHigh',
            expr: |||
              histogram_quantile(0.99, sum(rate(kubelet_pod_worker_duration_seconds_bucket{%(kubeletSelector)s}[5m])) by (instance, le)) * on(instance) group_left(node) kubelet_node_name{%(kubeletSelector)s} > 60
            ||| % $._config,
            'for': '15m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              message: 'Kubelet Pod startup 99th percentile latency is {{ $value }} seconds on node {{ $labels.node }}.',
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
