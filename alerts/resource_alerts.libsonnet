{
  prometheusAlerts+:: {
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
              sum(kube_resourcequota{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s, type="hard", resource="requests.cpu"})
                /
              sum(node:node_num_cpu:sum)
                > %(namespaceOvercommitFactor)s
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
              sum(kube_resourcequota{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s, type="hard", resource="requests.memory"})
                /
              sum(node_memory_MemTotal{%(nodeExporterSelector)s})
                > %(namespaceOvercommitFactor)s
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
            alert: 'NodeCPUUsage',
            annotations: {
              message: 'Node {{ $labels.node }} has CPU usage {{ $value }} percent (which is above the configured threshold of %s percent).' % ($._config.maxNodeCpuUsagePercent),
            },
            expr: |||
              (node:node_cpu_utilisation:avg1m * 100) > %(maxNodeCpuUsagePercent)s
            ||| % $._config,
            'for': $._config.nodeCpuUsageTimeBeforeAlert,
            labels: {
              severity: 'critical',
            },
          },
          {
            alert: 'NodeMemoryUsage',
            annotations: {
              message: 'Node {{ $labels.node }} has memory usage {{ $value }} percent (which is above the configured threshold of %s percent).' % ($._config.maxNodeMemoryUsagePercent),
            },
            expr: |||
              (node:node_memory_utilisation: * 100) > %(maxNodeMemoryUsagePercent)s
            ||| % $._config,
            'for': $._config.nodeMemoryUsageTimeBeforeAlert,
            labels: {
              severity: 'critical',
            },
          },
          {
            alert: 'KubeQuotaExceeded',
            expr: |||
              100 * kube_resourcequota{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s, type="used"}
                / ignoring(instance, job, type)
              kube_resourcequota{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s, type="hard"}
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
