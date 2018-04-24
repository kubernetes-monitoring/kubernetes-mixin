{
  prometheus_rules+:: {
    groups+: [
      {
        name: 'k8s.rules',
        rules: [
          {
            record: 'namespace:container_cpu_usage_seconds_total:sum_rate',
            expr: |||
              sum(rate(container_cpu_usage_seconds_total{%(cadvisor_selector)s, image!=""}[5m])) by (namespace)
            ||| % $._config,
          },
          {
            record: 'namespace:container_memory_usage_bytes:sum',
            expr: |||
              sum(container_memory_usage_bytes{%(cadvisor_selector)s, image!=""}) by (namespace)
            ||| % $._config,
          },
          {
            record: 'namespace_name:container_cpu_usage_seconds_total:sum_rate',
            expr: |||
              sum by (namespace, label_name) (
                 sum(rate(container_cpu_usage_seconds_total{%(cadvisor_selector)s, image!=""}[5m])) by (namespace, pod_name)
               * on (namespace, pod_name) group_left(label_name)
                 label_replace(kube_pod_labels{%(kube_state_metrics_selector)s}, "pod_name", "$1", "pod", "(.*)")
              )
            ||| % $._config,
          },
          {
            record: 'namespace_name:container_memory_usage_bytes:sum',
            expr: |||
              sum by (namespace, label_name) (
                sum(container_memory_usage_bytes{%(cadvisor_selector)s,image!=""}) by (pod_name, namespace)
              * on (namespace, pod_name) group_left(label_name)
                label_replace(kube_pod_labels{%(kube_state_metrics_selector)s}, "pod_name", "$1", "pod", "(.*)")
              )
            ||| % $._config,
          },
          {
            record: 'namespace_name:kube_pod_container_resource_requests_memory_bytes:sum',
            expr: |||
              sum by (namespace, label_name) (
                sum(kube_pod_container_resource_requests_memory_bytes{%(kube_state_metrics_selector)s}) by (namespace, pod)
              * on (namespace, pod) group_left(label_name)
                label_replace(kube_pod_labels{%(kube_state_metrics_selector)s}, "pod_name", "$1", "pod", "(.*)")
              )
            ||| % $._config,
          },
          {
            record: 'namespace_name:kube_pod_container_resource_requests_cpu_cores:sum',
            expr: |||
              sum by (namespace, label_name) (
                sum(kube_pod_container_resource_requests_cpu_cores{%(kube_state_metrics_selector)s}) by (namespace, pod)
              * on (namespace, pod) group_left(label_name)
                label_replace(kube_pod_labels{%(kube_state_metrics_selector)s}, "pod_name", "$1", "pod", "(.*)")
              )
            ||| % $._config,
          },
        ],
      },
      {
        name: 'node.rules',
        rules: [
          {
            // Number of nodes in the cluster
            // SINCE 2018-02-08
            record: ':kube_pod_info_node_count:',
            expr: 'sum(min(kube_pod_info) by (node))',
          },
          {
            // This rule results in the tuples (node, namespace, instance) => 1;
            // it is used to calculate per-node metrics, given namespace & instance.
            record: 'node_namespace_instance:kube_pod_info:',
            expr: |||
              max(label_replace(kube_pod_info{%(kube_state_metrics_selector)s}, "instance", "$1", "pod", "(.*)")) by (node, namespace, instance)
            ||| % $._config,
          },
          {
            // This rule gives the number of CPUs per node.
            record: 'node:node_num_cpu:sum',
            expr: |||
              count by (node) (sum by (node, cpu) (
                node_cpu{%(node_exporter_selector)s}
              * on (namespace, instance) group_left(node)
                node_namespace_instance:kube_pod_info:
              ))
            ||| % $._config,
          },
          {
            // CPU utilisation is % CPU is not idle.
            record: ':node_cpu_utilisation:avg1m',
            expr: |||
              1 - avg(rate(node_cpu{%(node_exporter_selector)s,mode="idle"}[1m]))
            ||| % $._config,
          },
          {
            // CPU utilisation is % CPU is not idle.
            record: 'node:node_cpu_utilisation:avg1m',
            expr: |||
              1 - avg by (node) (
                rate(node_cpu{%(node_exporter_selector)s,mode="idle"}[1m])
              * on (namespace, instance) group_left(node)
                node_namespace_instance:kube_pod_info:)
            ||| % $._config,
          },
          {
            // CPU saturation is 1min avg run queue length / number of CPUs.
            // Can go over 100%.  >100% is bad.
            record: ':node_cpu_saturation_load1:',
            expr: |||
              sum(node_load1{%(node_exporter_selector)s})
              /
              sum(node:node_num_cpu:sum)
            ||| % $._config,
          },
          {
            // CPU saturation is 1min avg run queue length / number of CPUs.
            // Can go over 100%.  >100% is bad.
            record: 'node:node_cpu_saturation_load1:',
            expr: |||
              sum by (node) (
                node_load1{%(node_exporter_selector)s}
              * on (namespace, instance) group_left(node)
                node_namespace_instance:kube_pod_info:
              )
              /
              node:node_num_cpu:sum
            ||| % $._config,
          },
          {
            record: ':node_memory_utilisation:',
            expr: |||
              1 -
              sum(node_memory_MemFree{%(node_exporter_selector)s} + node_memory_Cached{%(node_exporter_selector)s} + node_memory_Buffers{%(node_exporter_selector)s})
              /
              sum(node_memory_MemTotal{%(node_exporter_selector)s})
            ||| % $._config,
          },
          {
            // Available memory per node
            // SINCE 2018-02-08
            record: 'node:node_memory_bytes_available:sum',
            expr: |||
              sum by (node) (
                (node_memory_MemFree{%(node_exporter_selector)s} + node_memory_Cached{%(node_exporter_selector)s} + node_memory_Buffers{%(node_exporter_selector)s})
                * on (namespace, instance) group_left(node)
                  node_namespace_instance:kube_pod_info:
              )
            ||| % $._config,
          },
          {
            // Total memory per node
            // SINCE 2018-02-08
            record: 'node:node_memory_bytes_total:sum',
            expr: |||
              sum by (node) (
                node_memory_MemTotal{%(node_exporter_selector)s}
                * on (namespace, instance) group_left(node)
                  node_namespace_instance:kube_pod_info:
              )
            ||| % $._config,
          },
          {
            // Memory utilisation per node, normalized by per-node memory
            // NEW 2018-02-08
            record: 'node:node_memory_utilisation:ratio',
            expr: |||
              (node:node_memory_bytes_total:sum - node:node_memory_bytes_available:sum)
              /
              scalar(sum(node:node_memory_bytes_total:sum))
            |||,
          },
          {
            record: ':node_memory_swap_io_bytes:sum_rate',
            expr: |||
              1e3 * sum(
                (rate(node_vmstat_pgpgin{%(node_exporter_selector)s}[1m])
               + rate(node_vmstat_pgpgout{%(node_exporter_selector)s}[1m]))
              )
            ||| % $._config,
          },
          {
            // DEPRECATED
            record: 'node:node_memory_utilisation:',
            expr: |||
              1 -
              sum by (node) (
                (node_memory_MemFree{%(node_exporter_selector)s} + node_memory_Cached{%(node_exporter_selector)s} + node_memory_Buffers{%(node_exporter_selector)s})
              * on (namespace, instance) group_left(node)
                node_namespace_instance:kube_pod_info:
              )
              /
              sum by (node) (
                node_memory_MemTotal{%(node_exporter_selector)s}
              * on (namespace, instance) group_left(node)
                node_namespace_instance:kube_pod_info:
              )
            ||| % $._config,
          },
          {
            // DEPENDS 2018-02-08
            // REPLACE node:node_memory_utilisation:
            record: 'node:node_memory_utilisation_2:',
            expr: |||
              1 - (node:node_memory_bytes_available:sum / node:node_memory_bytes_total:sum)
            ||| % $._config,
          },
          {
            record: 'node:node_memory_swap_io_bytes:sum_rate',
            expr: |||
              1e3 * sum by (node) (
                (rate(node_vmstat_pgpgin{%(node_exporter_selector)s}[1m])
               + rate(node_vmstat_pgpgout{%(node_exporter_selector)s}[1m]))
               * on (namespace, instance) group_left(node)
                 node_namespace_instance:kube_pod_info:
              )
            ||| % $._config,
          },
          {
            // Disk utilisation (ms spent, by rate() it's bound by 1 second)
            record: ':node_disk_utilisation:avg_irate',
            expr: |||
              avg(irate(node_disk_io_time_ms{%(node_exporter_selector)s,device=~"(sd|xvd).+"}[1m]) / 1e3)
            ||| % $._config,
          },
          {
            // Disk utilisation (ms spent, by rate() it's bound by 1 second)
            record: 'node:node_disk_utilisation:avg_irate',
            expr: |||
              avg by (node) (
                irate(node_disk_io_time_ms{%(node_exporter_selector)s,device=~"(sd|xvd).+"}[1m]) / 1e3
              * on (namespace, instance) group_left(node)
                node_namespace_instance:kube_pod_info:
              )
            ||| % $._config,
          },
          {
            // Disk saturation (ms spent, by rate() it's bound by 1 second)
            record: ':node_disk_saturation:avg_irate',
            expr: |||
              avg(irate(node_disk_io_time_weighted{%(node_exporter_selector)s,device=~"(sd|xvd).+"}[1m]) / 1e3)
            ||| % $._config,
          },
          {
            // Disk saturation (ms spent, by rate() it's bound by 1 second)
            record: 'node:node_disk_saturation:avg_irate',
            expr: |||
              avg by (node) (
                irate(node_disk_io_time_weighted{%(node_exporter_selector)s,device=~"(sd|xvd).+"}[1m]) / 1e3
              * on (namespace, instance) group_left(node)
                node_namespace_instance:kube_pod_info:
              )
            ||| % $._config,
          },
          {
            record: ':node_net_utilisation:sum_irate',
            expr: |||
              sum(irate(node_network_receive_bytes{%(node_exporter_selector)s,device="eth0"}[1m])) +
              sum(irate(node_network_transmit_bytes{%(node_exporter_selector)s,device="eth0"}[1m]))
            ||| % $._config,
          },
          {
            record: 'node:node_net_utilisation:sum_irate',
            expr: |||
              sum by (node) (
                (irate(node_network_receive_bytes{%(node_exporter_selector)s,device="eth0"}[1m]) +
                irate(node_network_transmit_bytes{%(node_exporter_selector)s,device="eth0"}[1m]))
              * on (namespace, instance) group_left(node)
                node_namespace_instance:kube_pod_info:
              )
            ||| % $._config,
          },
          {
            record: ':node_net_saturation:sum_irate',
            expr: |||
              sum(irate(node_network_receive_drop{%(node_exporter_selector)s,device="eth0"}[1m])) +
              sum(irate(node_network_transmit_drop{%(node_exporter_selector)s,device="eth0"}[1m]))
            ||| % $._config,
          },
          {
            record: 'node:node_net_saturation:sum_irate',
            expr: |||
              sum by (node) (
                (irate(node_network_receive_drop{%(node_exporter_selector)s,device="eth0"}[1m]) +
                irate(node_network_transmit_drop{%(node_exporter_selector)s,device="eth0"}[1m]))
              * on (namespace, instance) group_left(node)
                node_namespace_instance:kube_pod_info:
              )
            ||| % $._config,
          },
        ],
      },
    ],
  },
}
