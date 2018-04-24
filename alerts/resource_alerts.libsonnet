{
  prometheus_alerts+:: {
    groups+: [
      {
        name: 'kubernetes-resources',
        rules: [
          {
            alert: 'KubeCPUOvercommit',
            expr: |||
              sum(namespace_name:kube_pod_container_resource_requests_cpu_cores:sum)
                /
              sum(node:node_num_cpu:sum)
                >
              (count(node:node_num_cpu:sum)-1) / count(node:node_num_cpu:sum)
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              message: 'Overcommited CPU resource requests on Pods, cannot tolerate node failure.',
            },
            'for': '5m',
          },
          {
            alert: 'KubeMemOvercommit',
            expr: |||
              sum(namespace_name:kube_pod_container_resource_requests_memory_bytes:sum)
                /
              sum(node_memory_MemTotal)
                >
              (count(node:node_num_cpu:sum)-1)
                /
              count(node:node_num_cpu:sum)
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              message: 'Overcommited Memory resource requests on Pods, cannot tolerate node failure.',
            },
            'for': '5m',
          },
          {
            alert: 'KubeCPUOvercommit',
            expr: |||
              sum(kube_resourcequota{%(kube_state_metrics_selector)s, type="hard", resource="requests.cpu"})
                /
              sum(node:node_num_cpu:sum)
                > %(namespace_overcommit_factor)s
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              message: 'Overcommited CPU resource request quota on Namespaces.',
            },
            'for': '5m',
          },
          {
            alert: 'KubeMemOvercommit',
            expr: |||
              sum(kube_resourcequota{%(kube_state_metrics_selector)s, type="hard", resource="requests.memory"})
                /
              sum(node_memory_MemTotal{%(node_exporter_selector)s})
                > %(namespace_overcommit_factor)s
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              message: 'Overcommited Memory resource request quota on Namespaces.',
            },
            'for': '5m',
          },
          {
            alert: 'KubeQuotaExceeded',
            expr: |||
              100 * kube_resourcequota{%(kube_state_metrics_selector)s, type="used"}
                / ignoring(instance, job, type)
              kube_resourcequota{%(kube_state_metrics_selector)s, type="hard"}
                > 90
            ||| % $._config,
            'for': '15m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              message: '{{ printf "%0.0f" $value }}% usage of {{ $labels.resource }} in namespace {{ $labels.namespace }}.',
            },
          },
        ],
      },
    ],
  },
}
