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
              sum by (namespace, pod, container) (
                rate(container_cpu_usage_seconds_total{%(cadvisorSelector)s, image!="", container!="POD"}[5m])
              ) * on (namespace, pod) group_left(node) max by(namespace, pod, node) (kube_pod_info)
            ||| % $._config,
          },
          {
            record: 'node_namespace_pod_container:container_memory_working_set_bytes',
            expr: |||
              container_memory_working_set_bytes{%(cadvisorSelector)s, image!=""}
              * on (namespace, pod) group_left(node) max by(namespace, pod, node) (kube_pod_info)
            ||| % $._config,
          },
          {
            record: 'node_namespace_pod_container:container_memory_rss',
            expr: |||
              container_memory_rss{%(cadvisorSelector)s, image!=""}
              * on (namespace, pod) group_left(node) max by(namespace, pod, node) (kube_pod_info)
            ||| % $._config,
          },
          {
            record: 'node_namespace_pod_container:container_memory_cache',
            expr: |||
              container_memory_cache{%(cadvisorSelector)s, image!=""}
              * on (namespace, pod) group_left(node) max by(namespace, pod, node) (kube_pod_info)
            ||| % $._config,
          },
          {
            record: 'node_namespace_pod_container:container_memory_swap',
            expr: |||
              container_memory_swap{%(cadvisorSelector)s, image!=""}
              * on (namespace, pod) group_left(node) max by(namespace, pod, node) (kube_pod_info)
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
                  sum(kube_pod_container_resource_requests_memory_bytes{%(kubeStateMetricsSelector)s} * on (endpoint, instance, job, namespace, pod, service) group_left(phase) (kube_pod_status_phase{phase=~"Pending|Running"} == 1)) by (namespace, pod)
                * on (namespace, pod)
                  group_left(label_name) kube_pod_labels{%(kubeStateMetricsSelector)s}
              )
            ||| % $._config,
          },
          {
            record: 'namespace:kube_pod_container_resource_requests_cpu_cores:sum',
            expr: |||
              sum by (namespace, label_name) (
                  sum(kube_pod_container_resource_requests_cpu_cores{%(kubeStateMetricsSelector)s} * on (endpoint, instance, job, namespace, pod, service) group_left(phase) (kube_pod_status_phase{phase=~"Pending|Running"} == 1)) by (namespace, pod)
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
    ],
  },
}
