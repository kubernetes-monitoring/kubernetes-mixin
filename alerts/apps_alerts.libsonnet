{
  prometheusAlerts+:: {
    groups+: [
      {
        name: 'kubernetes-apps',
        rules: [
          {
            expr: |||
              rate(kube_pod_container_status_restarts_total{%(kubeStateMetricsSelector)s}[15m]) > 0
            ||| % $._config,
            labels: {
              severity: 'critical',
            },
            annotations: {
              message: '{{ $labels.namespace }}/{{ $labels.pod }} ({{ $labels.container }}) is restarting {{ printf "%.2f" $value }} / second',
            },
            'for': '1h',
            alert: 'KubePodCrashLooping',
          },
          {
            expr: |||
              sum by (namespace, pod) (kube_pod_status_phase{%(kubeStateMetricsSelector)s, phase!~"Running|Succeeded"}) > 0
            ||| % $._config,
            labels: {
              severity: 'critical',
            },
            annotations: {
              message: '{{ $labels.namespace }}/{{ $labels.pod }} is not ready.',
            },
            'for': '1h',
            alert: 'KubePodNotReady',
          },
          {
            expr: |||
              kube_deployment_status_observed_generation{%(kubeStateMetricsSelector)s}
                !=
              kube_deployment_metadata_generation{%(kubeStateMetricsSelector)s}
            ||| % $._config,
            labels: {
              severity: 'critical',
            },
            annotations: {
              message: 'Deployment {{ $labels.namespace }}/{{ $labels.deployment }} generation mismatch',
            },
            'for': '15m',
            alert: 'KubeDeploymentGenerationMismatch',
          },
          {
            expr: |||
              kube_deployment_spec_replicas{%(kubeStateMetricsSelector)s}
                !=
              kube_deployment_status_replicas_available{%(kubeStateMetricsSelector)s}
            ||| % $._config,
            labels: {
              severity: 'critical',
            },
            annotations: {
              message: 'Deployment {{ $labels.namespace }}/{{ $labels.deployment }} replica mismatch',
            },
            'for': '15m',
            alert: 'KubeDeploymentReplicasMismatch',
          },
          {
            expr: |||
              kube_statefulset_status_replicas_ready{%(kubeStateMetricsSelector)s}
                !=
              kube_statefulset_status_replicas{%(kubeStateMetricsSelector)s}
            ||| % $._config,
            labels: {
              severity: 'critical',
            },
            annotations: {
              message: 'StatefulSet {{ $labels.namespace }}/{{ $labels.statefulset }} replica mismatch',
            },
            'for': '15m',
            alert: 'KubeStatefulSetReplicasMismatch',
          },
          {
            expr: |||
              kube_statefulset_status_observed_generation{%(kubeStateMetricsSelector)s}
                !=
              kube_statefulset_metadata_generation{%(kubeStateMetricsSelector)s}
            ||| % $._config,
            labels: {
              severity: 'critical',
            },
            annotations: {
              message: 'StatefulSet {{ $labels.namespace }}/{{ labels.statefulset }} generation mismatch',
            },
            'for': '15m',
            alert: 'KubeDeploymentGenerationMismatch',
          },
        ],
      },
    ],
  },
}
