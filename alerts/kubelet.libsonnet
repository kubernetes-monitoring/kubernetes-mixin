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
          (import '../lib/absent_alert.libsonnet') {
            componentName:: 'Kubelet',
            selector:: $._config.kubeletSelector,
          },
        ],
      },
    ],
  },
}
