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
              message: 'Cluster has overcommitted CPU resource requests for Pods and cannot tolerate node failure.',
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
              message: 'Cluster has overcommitted memory resource requests for Pods and cannot tolerate node failure.',
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
              message: 'Cluster has overcommitted CPU resource requests for Namespaces.',
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
              message: 'Cluster has overcommitted memory resource requests for Namespaces.',
            },
            'for': '5m',
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
              message: 'Namespace {{ $labels.namespace }} is using {{ printf "%0.0f" $value }}% of its {{ $labels.resource }} quota.',
            },
          },
        ],
      },
    ],
  },
}
