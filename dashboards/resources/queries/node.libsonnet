{
  cpuUsageCapacity(config)::
    'sum(kube_node_status_capacity{%(clusterLabel)s="$cluster", %(kubeStateMetricsSelector)s, node=~"$node", resource="cpu"})' % config,

  cpuUsageAllocatable(config)::
    'sum(kube_node_status_allocatable{%(clusterLabel)s="$cluster", %(kubeStateMetricsSelector)s, node=~"$node", resource="cpu"})' % config,

  cpuUsageByPod(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m{%(clusterLabel)s="$cluster", node=~"$node"})) by (pod)' % config,

  cpuRequestsByPod(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(cluster:namespace:pod_cpu:active:kube_pod_container_resource_requests{%(clusterLabel)s="$cluster", node=~"$node"})) by (pod)' % config,

  cpuUsageVsRequests(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m{%(clusterLabel)s="$cluster", node=~"$node"})) by (pod) / sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(cluster:namespace:pod_cpu:active:kube_pod_container_resource_requests{%(clusterLabel)s="$cluster", node=~"$node"})) by (pod)' % config,

  cpuLimitsByPod(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(cluster:namespace:pod_cpu:active:kube_pod_container_resource_limits{%(clusterLabel)s="$cluster", node=~"$node"})) by (pod)' % config,

  cpuUsageVsLimits(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m{%(clusterLabel)s="$cluster", node=~"$node"})) by (pod) / sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(cluster:namespace:pod_cpu:active:kube_pod_container_resource_limits{%(clusterLabel)s="$cluster", node=~"$node"})) by (pod)' % config,

  memoryCapacity(config)::
    'sum(kube_node_status_capacity{%(clusterLabel)s="$cluster", %(kubeStateMetricsSelector)s, node=~"$node", resource="memory"})' % config,

  memoryAllocatable(config)::
    'sum(kube_node_status_allocatable{%(clusterLabel)s="$cluster", %(kubeStateMetricsSelector)s, node=~"$node", resource="memory"})' % config,

  memoryUsageWithCache(config)::
    'sum(node_memory_MemTotal_bytes{%(nodeExporterSelector)s, %(clusterLabel)s="$cluster", instance=~"$node"}) - sum(node_memory_MemAvailable_bytes{%(nodeExporterSelector)s, %(clusterLabel)s="$cluster", instance=~"$node"})' % config,

  memoryWorkingSet(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(container_memory_working_set_bytes{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", node=~"$node",container!="", image!=""})) by (pod)' % config,

  memoryRequestsByPod(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(cluster:namespace:pod_memory:active:kube_pod_container_resource_requests{%(clusterLabel)s="$cluster", node=~"$node"})) by (pod)' % config,

  memoryUsageVsRequests(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(node_namespace_pod_container:container_memory_working_set_bytes{%(clusterLabel)s="$cluster", node=~"$node",container!=""})) by (pod) / sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(cluster:namespace:pod_memory:active:kube_pod_container_resource_requests{%(clusterLabel)s="$cluster", node=~"$node"})) by (pod)' % config,

  memoryLimitsByPod(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(cluster:namespace:pod_memory:active:kube_pod_container_resource_limits{%(clusterLabel)s="$cluster", node=~"$node"})) by (pod)' % config,

  memoryUsageVsLimits(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(node_namespace_pod_container:container_memory_working_set_bytes{%(clusterLabel)s="$cluster", node=~"$node",container!=""})) by (pod) / sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(cluster:namespace:pod_memory:active:kube_pod_container_resource_limits{%(clusterLabel)s="$cluster", node=~"$node"})) by (pod)' % config,

  memoryCached(config)::
    'sum(node_memory_Cached_bytes{%(nodeExporterSelector)s, %(clusterLabel)s="$cluster", instance=~"$node"})' % config,

  memoryBuffers(config)::
    'sum(node_memory_Buffers_bytes{%(nodeExporterSelector)s, %(clusterLabel)s="$cluster", instance=~"$node"})' % config,

  memorySwapUsage(config)::
    'sum(node_memory_SwapTotal_bytes{%(nodeExporterSelector)s, %(clusterLabel)s="$cluster", instance=~"$node"} - node_memory_SwapFree_bytes{%(nodeExporterSelector)s, %(clusterLabel)s="$cluster", instance=~"$node"})' % config,

  memoryWorkingSetQuota(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(container_memory_working_set_bytes{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", node=~"$node",container!="", image!=""})) by (pod)' % config,

  memoryUsageRssQuota(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(container_memory_rss{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", node=~"$node",container!=""})) by (pod)' % config,

  memoryUsageCacheQuota(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(container_memory_cache{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", node=~"$node",container!=""})) by (pod)' % config,

  memoryUsageSwapQuota(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(container_memory_swap{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", node=~"$node",container!=""})) by (pod)' % config,

  diskSpaceCapacity(config)::
    'sum(node_filesystem_size_bytes{%(nodeExporterSelector)s, %(clusterLabel)s="$cluster", instance=~"$node", mountpoint="/", fstype!~"tmpfs|aufs|overlay"})' % config,

  diskSpaceUsed(config)::
    'sum(node_filesystem_size_bytes{%(nodeExporterSelector)s, %(clusterLabel)s="$cluster", instance=~"$node", mountpoint="/", fstype!~"tmpfs|aufs|overlay"}) - sum(node_filesystem_free_bytes{%(nodeExporterSelector)s, %(clusterLabel)s="$cluster", instance=~"$node", mountpoint="/", fstype!~"tmpfs|aufs|overlay"})' % config,

  inodeUsage(config)::
    'sum(node_filesystem_files{%(nodeExporterSelector)s, %(clusterLabel)s="$cluster", instance=~"$node", mountpoint="/", fstype!~"tmpfs|aufs|overlay"}) - sum(node_filesystem_files_free{%(nodeExporterSelector)s, %(clusterLabel)s="$cluster", instance=~"$node", mountpoint="/", fstype!~"tmpfs|aufs|overlay"})' % config,

  inodeCapacity(config)::
    'sum(node_filesystem_files{%(nodeExporterSelector)s, %(clusterLabel)s="$cluster", instance=~"$node", mountpoint="/", fstype!~"tmpfs|aufs|overlay"})' % config,

  networkReceiveBandwidth(config)::
    'sum(rate(node_network_receive_bytes_total{%(nodeExporterSelector)s, %(clusterLabel)s="$cluster", instance=~"$node", device!~"^veth.*"}[%(grafanaIntervalVar)s])) by (instance)' % config,

  networkTransmitBandwidth(config)::
    'sum(rate(node_network_transmit_bytes_total{%(nodeExporterSelector)s, %(clusterLabel)s="$cluster", instance=~"$node", device!~"^veth.*"}[%(grafanaIntervalVar)s])) by (instance)' % config,

  networkReceivePackets(config)::
    'sum(rate(node_network_receive_packets_total{%(nodeExporterSelector)s, %(clusterLabel)s="$cluster", instance=~"$node", device!~"^veth.*"}[%(grafanaIntervalVar)s])) by (instance)' % config,

  networkTransmitPackets(config)::
    'sum(rate(node_network_transmit_packets_total{%(nodeExporterSelector)s, %(clusterLabel)s="$cluster", instance=~"$node", device!~"^veth.*"}[%(grafanaIntervalVar)s])) by (instance)' % config,

  networkReceivePacketsDropped(config)::
    'sum(rate(node_network_receive_packets_dropped_total{%(nodeExporterSelector)s, %(clusterLabel)s="$cluster", instance=~"$node", device!~"^veth.*"}[%(grafanaIntervalVar)s])) by (instance)' % config,

  networkTransmitPacketsDropped(config)::
    'sum(rate(node_network_transmit_packets_dropped_total{%(nodeExporterSelector)s, %(clusterLabel)s="$cluster", instance=~"$node", device!~"^veth.*"}[%(grafanaIntervalVar)s])) by (instance)' % config,

  diskIoReadBytes(config)::
    'sum(rate(node_disk_read_bytes_total{%(nodeExporterSelector)s, %(clusterLabel)s="$cluster", instance=~"$node"}[%(grafanaIntervalVar)s])) by (instance)' % config,

  diskIoWriteBytes(config)::
    'sum(rate(node_disk_written_bytes_total{%(nodeExporterSelector)s, %(clusterLabel)s="$cluster", instance=~"$node"}[%(grafanaIntervalVar)s])) by (instance)' % config,

  diskIoReadOps(config)::
    'sum(rate(node_disk_reads_completed_total{%(nodeExporterSelector)s, %(clusterLabel)s="$cluster", instance=~"$node"}[%(grafanaIntervalVar)s])) by (instance)' % config,

  diskIoWriteOps(config)::
    'sum(rate(node_disk_writes_completed_total{%(nodeExporterSelector)s, %(clusterLabel)s="$cluster", instance=~"$node"}[%(grafanaIntervalVar)s])) by (instance)' % config,
}
