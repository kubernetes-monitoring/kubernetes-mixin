{
  prometheusAlerts+:: {
    groups+: [
      {
        name: 'kubernetes-apps',
        rules: [
          {
            expr: |||
              rate(kube_pod_container_status_restarts_total{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}[15m]) > 0
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
              sum by (namespace, pod) (kube_pod_status_phase{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s, phase=~"Pending|Unknown"}) > 0
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
              kube_deployment_status_observed_generation{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}
                !=
              kube_deployment_metadata_generation{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}
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
              kube_deployment_spec_replicas{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}
                !=
              kube_deployment_status_replicas_available{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}
            ||| % $._config,
            labels: {
              severity: 'critical',
            },
            annotations: {
              message: 'Deployment {{ $labels.namespace }}/{{ $labels.deployment }} replica mismatch',
            },
            'for': '1h',
            alert: 'KubeDeploymentReplicasMismatch',
          },
          {
            expr: |||
              kube_statefulset_status_replicas_ready{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}
                !=
              kube_statefulset_status_replicas{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}
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
              kube_statefulset_status_observed_generation{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}
                !=
              kube_statefulset_metadata_generation{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}
            ||| % $._config,
            labels: {
              severity: 'critical',
            },
            annotations: {
              message: 'StatefulSet {{ $labels.namespace }}/{{ $labels.statefulset }} generation mismatch',
            },
            'for': '15m',
            alert: 'KubeStatefulSetGenerationMismatch',
          },
          {
            alert: 'KubeDaemonSetRolloutStuck',
            expr: |||
              kube_daemonset_status_number_ready{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}
                /
              kube_daemonset_status_desired_number_scheduled{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s} * 100 < 100
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
              kube_daemonset_status_desired_number_scheduled{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}
                -
              kube_daemonset_status_current_number_scheduled{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s} > 0
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
              kube_daemonset_status_number_misscheduled{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s} > 0
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              message: 'A number of pods of daemonset {{$labels.namespace}}/{{$labels.daemonset}} are running where they are not supposed to run.',
            },
            'for': '10m',
          },
          {
            alert: 'KubeCronJobRunning',
            expr: |||
              time() - kube_cronjob_next_schedule_time{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s} > 3600
            ||| % $._config,
            'for': '1h',
            labels: {
              severity: 'warning',
            },
            annotations: {
              message: 'CronJob {{ $labels.namespaces }}/{{ $labels.cronjob }} is taking more than 1h to complete.',
            },
          },
          {
            alert: 'KubeJobCompletion',
            expr: |||
              kube_job_spec_completions{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s} - kube_job_status_succeeded{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}  > 0
            ||| % $._config,
            'for': '1h',
            labels: {
              severity: 'warning',
            },
            annotations: {
              message: 'Job {{ $labels.namespaces }}/{{ $labels.job }} is taking more than 1h to complete.',
            },
          },
          {
            alert: 'KubeJobFailed',
            expr: |||
              kube_job_status_failed{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s}  > 0
            ||| % $._config,
            'for': '1h',
            labels: {
              severity: 'warning',
            },
            annotations: {
              message: 'Job {{ $labels.namespaces }}/{{ $labels.job }} failed to complete.',
            },
          },
        ],
      },
    ],
  },
}
