{
  _config+:: {
    kubeStateMetricsSelector: error 'must provide selector for kube-state-metrics',
    nodeExporterSelector: error 'must provide selector for node-exporter',
    namespaceSelector: null,
    prefixedNamespaceSelector: if self.namespaceSelector != null then self.namespaceSelector + ',' else '',

    // We alert when the aggregate (CPU, Memory) quota for all namespaces is
    // greater than the amount of the resources in the cluster.  We do however
    // allow you to overcommit if you wish.
    namespaceOvercommitFactor: 1.5,
    cpuThrottlingPercent: 25,
    cpuThrottlingSelector: '',
    placeholdersNamespaceSelector: '',
  },

  prometheusAlerts+:: {
    groups+: [
      {
        name: 'kubernetes-resources',
        rules: [
          {
            alert: 'KubeCPUOvercommit',
            expr: |||
              sum(namespace:kube_pod_container_resource_requests_cpu_cores:sum{%(placeholdersNamespaceSelector)s})
                /
              sum(kube_node_status_allocatable_cpu_cores)
                >
              (count(kube_node_status_allocatable_cpu_cores)-1) / count(kube_node_status_allocatable_cpu_cores)
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
              sum(namespace:kube_pod_container_resource_requests_memory_bytes:sum{%(placeholdersNamespaceSelector)s})
                /
              sum(kube_node_status_allocatable_memory_bytes)
                >
              (count(kube_node_status_allocatable_memory_bytes)-1)
                /
              count(kube_node_status_allocatable_memory_bytes)
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
              sum(kube_resourcequota{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s, type="hard", resource="cpu"})
                /
              sum(kube_node_status_allocatable_cpu_cores)
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
              sum(kube_resourcequota{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s, type="hard", resource="memory"})
                /
              sum(kube_node_status_allocatable_memory_bytes{%(nodeExporterSelector)s})
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
              kube_resourcequota{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s, type="used"}
                / ignoring(instance, job, type)
              (kube_resourcequota{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s, type="hard"} > 0)
                > 0.90
            ||| % $._config,
            'for': '15m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              message: 'Namespace {{ $labels.namespace }} is using {{ $value | humanizePercentage }} of its {{ $labels.resource }} quota.',
            },
          },
          {
            alert: 'CPUThrottlingHigh',
            expr: |||
              sum(increase(container_cpu_cfs_throttled_periods_total{container!="", %(cpuThrottlingSelector)s}[5m])) by (container, pod, namespace)
                /
              sum(increase(container_cpu_cfs_periods_total{%(cpuThrottlingSelector)s}[5m])) by (container, pod, namespace)
                > ( %(cpuThrottlingPercent)s / 100 )
            ||| % $._config,
            'for': '15m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              message: '{{ $value | humanizePercentage }} throttling of CPU in namespace {{ $labels.namespace }} for container {{ $labels.container }} in pod {{ $labels.pod }}.',
            },
          },
        ],
      },
    ],
  },
}
