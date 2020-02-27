{
  _config+:: {
    cadvisorSelector: 'job="cadvisor"',
    kubeStateMetricsSelector: 'job="kube-state-metrics"',
  },

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
            record: 'node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate',
            expr: |||
              sum by (%(clusterLabel)s, namespace, pod, container) (
                rate(container_cpu_usage_seconds_total{%(cadvisorSelector)s, image!="", container!="POD"}[5m])
              ) * on (%(clusterLabel)s, namespace, pod) group_left(node) topk by (%(clusterLabel)s, namespace, pod) (
                1, max by(%(clusterLabel)s, namespace, pod, node) (kube_pod_info)
              )
            ||| % $._config,
          },
          {
            record: 'node_namespace_pod_container:container_memory_working_set_bytes',
            expr: |||
              container_memory_working_set_bytes{%(cadvisorSelector)s, image!=""}
              * on (namespace, pod) group_left(node) topk by(namespace, pod) (1,
                max by(namespace, pod, node) (kube_pod_info)
              )
            ||| % $._config,
          },
          {
            record: 'node_namespace_pod_container:container_memory_rss',
            expr: |||
              container_memory_rss{%(cadvisorSelector)s, image!=""}
              * on (namespace, pod) group_left(node) topk by(namespace, pod) (1,
                max by(namespace, pod, node) (kube_pod_info)
              )
            ||| % $._config,
          },
          {
            record: 'node_namespace_pod_container:container_memory_cache',
            expr: |||
              container_memory_cache{%(cadvisorSelector)s, image!=""}
              * on (namespace, pod) group_left(node) topk by(namespace, pod) (1,
                max by(namespace, pod, node) (kube_pod_info)
              )
            ||| % $._config,
          },
          {
            record: 'node_namespace_pod_container:container_memory_swap',
            expr: |||
              container_memory_swap{%(cadvisorSelector)s, image!=""}
              * on (namespace, pod) group_left(node) topk by(namespace, pod) (1,
                max by(namespace, pod, node) (kube_pod_info)
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
              sum by (namespace) (
                  sum by (namespace, pod) (
                      max by (namespace, pod, container) (
                          kube_pod_container_resource_requests_memory_bytes{%(kubeStateMetricsSelector)s}
                      ) * on(namespace, pod) group_left() max by (namespace, pod) (
                          kube_pod_status_phase{phase=~"Pending|Running"} == 1
                      )
                  )
              )
            ||| % $._config,
          },
          {
            record: 'namespace:kube_pod_container_resource_requests_cpu_cores:sum',
            expr: |||
              sum by (namespace) (
                  sum by (namespace, pod) (
                      max by (namespace, pod, container) (
                          kube_pod_container_resource_requests_cpu_cores{%(kubeStateMetricsSelector)s}
                      ) * on(namespace, pod) group_left() max by (namespace, pod) (
                        kube_pod_status_phase{phase=~"Pending|Running"} == 1
                      )
                  )
              )
            ||| % $._config,
          },
          // workload aggregation for deployments
          {
            record: 'mixin_pod_workload',
            expr: |||
              max by (%(clusterLabel)s, namespace, workload, pod) (
                label_replace(
                  label_replace(
                    kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="ReplicaSet"},
                    "replicaset", "$1", "owner_name", "(.*)"
                  ) * on(replicaset, namespace) group_left(owner_name) topk by(replicaset, namespace) (
                    1, max by (replicaset, namespace, owner_name) (
                      kube_replicaset_owner{%(kubeStateMetricsSelector)s}
                    )
                  ),
                  "workload", "$1", "owner_name", "(.*)"
                )
              )
            ||| % $._config,
            labels: {
              workload_type: 'deployment',
            },
          },
          {
            record: 'mixin_pod_workload',
            expr: |||
              max by (%(clusterLabel)s, namespace, workload, pod) (
                label_replace(
                  kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="DaemonSet"},
                  "workload", "$1", "owner_name", "(.*)"
                )
              )
            ||| % $._config,
            labels: {
              workload_type: 'daemonset',
            },
          },
          {
            record: 'mixin_pod_workload',
            expr: |||
              max by (%(clusterLabel)s, namespace, workload, pod) (
                label_replace(
                  kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="StatefulSet"},
                  "workload", "$1", "owner_name", "(.*)"
                )
              )
            ||| % $._config,
            labels: {
              workload_type: 'statefulset',
            },
          },
        ],
      },
    ],
  },
}
