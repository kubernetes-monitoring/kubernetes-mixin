{
  _config+:: {
    kubeStateMetricsSelector: 'job="kube-state-metrics"',
    nodeExporterSelector: 'job="node-exporter"',
    podLabel: 'pod',
  },

  prometheusRules+:: {
    groups+: [
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
            record: 'node_namespace_pod:kube_pod_info:',
            expr: |||
              max(label_replace(kube_pod_info{%(kubeStateMetricsSelector)s}, "%(podLabel)s", "$1", "pod", "(.*)")) by (node, namespace, %(podLabel)s)
            ||| % $._config,
          },
          {
            // This rule gives the number of CPUs per node.
            record: 'node:node_num_cpu:sum',
            expr: |||
              count by (node) (sum by (node, cpu) (
                node_cpu_seconds_total{%(nodeExporterSelector)s}
              * on (namespace, %(podLabel)s) group_left(node)
                node_namespace_pod:kube_pod_info:
              ))
            ||| % $._config,
          },
          // Add separate rules for Available memory, so we can aggregate across clusters in dashboards.
          {
            record: ':node_memory_MemAvailable_bytes:sum',
            expr: |||
              sum(
                node_memory_MemAvailable_bytes{%(nodeExporterSelector)s} or
                (
                  node_memory_Buffers_bytes{%(nodeExporterSelector)s} +
                  node_memory_Cached_bytes{%(nodeExporterSelector)s} +
                  node_memory_MemFree_bytes{%(nodeExporterSelector)s} +
                  node_memory_Slab_bytes{%(nodeExporterSelector)s}
                )
              )
            ||| % $._config,
          },
        ],
      },
    ],
  },
}
