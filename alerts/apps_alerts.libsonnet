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
            alert: 'KubeStatefulSetGenerationMismatch',
          },
          {
            alert: 'KubeDaemonSetRolloutStuck',
            expr: |||
              kube_daemonset_status_number_ready{%(kubeStateMetricsSelector)s}
                /
              kube_daemonset_status_desired_number_scheduled{%(kubeStateMetricsSelector)s} * 100 < 100
            ||| % $._config,
            labels: {
              severity: 'critical',
            },
            annotations: {
              message: 'Only {{$value}}% of desired pods scheduled and ready for daemon set {{$labels.namespace}}/{{$labels.daemonset}}',
            },
            'for': '15m',
          },
          {
            alert: 'KubeDaemonSetNotScheduled',
            expr: |||
              kube_daemonset_status_desired_number_scheduled{%(kubeStateMetricsSelector)s}
                -
              kube_daemonset_status_current_number_scheduled{%(kubeStateMetricsSelector)s} > 0
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              message: 'A number of pods of daemonset {{$labels.namespace}}/{{$labels.daemonset}} are not scheduled.',
            },
            'for': '10m',
          },
          {
            alert: 'KubeDaemonSetMisScheduled',
            expr: |||
              kube_daemonset_status_number_misscheduled{%(kubeStateMetricsSelector)s} > 0
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              message: 'A number of pods of daemonset {{$labels.namespace}}/{{$labels.daemonset}} are running where they are not supposed to run.',
            },
            'for': '10m',
          },
        ],
      },
    ],
  },
}
