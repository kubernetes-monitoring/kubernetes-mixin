{
  prometheusRules+:: {
    groups+: [
      {
        name: 'k8s.rules',
        rules: [
          {
            record: 'namespace:container_cpu_usage_seconds_total:sum_rate',
            expr: |||
              sum(rate(container_cpu_usage_seconds_total{%(cadvisorSelector)s, image!="", container!="POD"}[5m])) by (namespace)
            ||| % $._config,
          },
          {
            // Reduces cardinality of this timeseries by #cores, which makes it
            // more useable in dashboards.  Also, allows us to do things like
            // quantile_over_time(...) which would otherwise not be possible.
            record: 'namespace_pod_container:container_cpu_usage_seconds_total:sum_rate',
            expr: |||
              sum by (namespace, pod, container) (
                rate(container_cpu_usage_seconds_total{%(cadvisorSelector)s, image!="", container!="POD"}[5m])
              )
            ||| % $._config,
          },
          {
            record: 'namespace:container_memory_usage_bytes:sum',
            expr: |||
              sum(container_memory_usage_bytes{%(cadvisorSelector)s, image!="", container!="POD"}) by (namespace)
            ||| % $._config,
          },
          {
            record: 'namespace:kube_pod_container_resource_requests_memory_bytes:sum',
            expr: |||
              sum by (namespace, label_name) (
                  sum(kube_pod_container_resource_requests_memory_bytes{%(kubeStateMetricsSelector)s} * on (endpoint, instance, job, namespace, pod, service) group_left(phase) (kube_pod_status_phase{phase=~"^(Pending|Running)$"} == 1)) by (namespace, pod)
                * on (namespace, pod)
                  group_left(label_name) kube_pod_labels{%(kubeStateMetricsSelector)s}
              )
            ||| % $._config,
          },
          {
            record: 'namespace:kube_pod_container_resource_requests_cpu_cores:sum',
            expr: |||
              sum by (namespace, label_name) (
                  sum(kube_pod_container_resource_requests_cpu_cores{%(kubeStateMetricsSelector)s} * on (endpoint, instance, job, namespace, pod, service) group_left(phase) (kube_pod_status_phase{phase=~"^(Pending|Running)$"} == 1)) by (namespace, pod)
                * on (namespace, pod)
                  group_left(label_name) kube_pod_labels{%(kubeStateMetricsSelector)s}
              )
            ||| % $._config,
          },
          // workload aggregation for deployments
          {
            record: 'mixin_pod_workload',
            expr: |||
              sum(
                label_replace(
                  label_replace(
                    kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="ReplicaSet"},
                    "replicaset", "$1", "owner_name", "(.*)"
                  ) * on(replicaset, namespace) group_left(owner_name) kube_replicaset_owner{%(kubeStateMetricsSelector)s},
                  "workload", "$1", "owner_name", "(.*)"
                )
              ) by (namespace, workload, pod)
            ||| % $._config,
            labels: {
              workload_type: 'deployment',
            },
          },
          {
            record: 'mixin_pod_workload',
            expr: |||
              sum(
                label_replace(
                  kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="DaemonSet"},
                  "workload", "$1", "owner_name", "(.*)"
                )
              ) by (namespace, workload, pod)
            ||| % $._config,
            labels: {
              workload_type: 'daemonset',
            },
          },
          {
            record: 'mixin_pod_workload',
            expr: |||
              sum(
                label_replace(
                  kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="StatefulSet"},
                  "workload", "$1", "owner_name", "(.*)"
                )
              ) by (namespace, workload, pod)
            ||| % $._config,
            labels: {
              workload_type: 'statefulset',
            },
          },
        ],
      },
      {
        name: 'kube-scheduler.rules',
        rules: [
          {
            record: 'cluster_quantile:%s:histogram_quantile' % metric,
            expr: |||
              histogram_quantile(%(quantile)s, sum(rate(%(metric)s_bucket{%(kubeSchedulerSelector)s}[5m])) without(instance, %(podLabel)s))
            ||| % ({ quantile: quantile, metric: metric } + $._config),
            labels: {
              quantile: quantile,
            },
          }
          for quantile in ['0.99', '0.9', '0.5']
          for metric in [
            'scheduler_e2e_scheduling_duration_seconds',
            'scheduler_scheduling_algorithm_duration_seconds',
            'scheduler_binding_duration_seconds',
          ]
        ],
      },
      {
        name: 'kube-apiserver.rules',
        rules: [
          {
            record: 'cluster_quantile:apiserver_request_duration_seconds:histogram_quantile',
            expr: |||
              histogram_quantile(%(quantile)s, sum(rate(apiserver_request_duration_seconds_bucket{%(kubeApiserverSelector)s}[5m])) without(instance, %(podLabel)s))
            ||| % ({ quantile: quantile } + $._config),
            labels: {
              quantile: quantile,
            },
          }
          for quantile in ['0.99', '0.9', '0.5']
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
          // Add separate rules for Free, so we can aggregate across clusters in dashboards.
          // TODO: adjust recording rule name to match best practices
          {
            record: ':node_memory_MemFreeCachedBuffers_bytes:sum',
            expr: |||
              sum(node_memory_MemFree_bytes{%(nodeExporterSelector)s} + node_memory_Cached_bytes{%(nodeExporterSelector)s} + node_memory_Buffers_bytes{%(nodeExporterSelector)s})
            ||| % $._config,
          },
        ],
      },
    ],
  },
}
