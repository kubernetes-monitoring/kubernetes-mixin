{
  _config+:: {
    cadvisorSelector: 'job="cadvisor"',
    kubeStateMetricsSelector: 'job="kube-state-metrics"',
  },

  prometheusRules+:: {
    groups+: [
      {
        name: 'k8s.rules.container_cpu_usage_seconds_total',
        rules: [
          {
            // Reduces cardinality of this timeseries by #cores, which makes it
            // more useable in dashboards.  Also, allows us to do things like
            // quantile_over_time(...) which would otherwise not be possible.
            record: 'node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m',
            expr: |||
              sum by (%(clusterLabel)s, namespace, pod, container) (
                rate(container_cpu_usage_seconds_total{%(cadvisorSelector)s, image!=""}[5m])
              ) * on (%(clusterLabel)s, namespace, pod) group_left(node) topk by (%(clusterLabel)s, namespace, pod) (
                1, max by(%(clusterLabel)s, namespace, pod, node) (kube_pod_info{node!=""})
              )
            ||| % $._config,
          },
          {
            record: 'node_namespace_pod_container:container_cpu_usage_seconds_total:sum_irate',
            expr: |||
              sum by (%(clusterLabel)s, namespace, pod, container) (
                irate(container_cpu_usage_seconds_total{%(cadvisorSelector)s, image!=""}[5m])
              ) * on (%(clusterLabel)s, namespace, pod) group_left(node) topk by (%(clusterLabel)s, namespace, pod) (
                1, max by(%(clusterLabel)s, namespace, pod, node) (kube_pod_info{node!=""})
              )
            ||| % $._config,
          },
        ],
      },
      {
        name: 'k8s.rules.container_memory_working_set_bytes',
        rules: [
          {
            record: 'node_namespace_pod_container:container_memory_working_set_bytes',
            expr: |||
              container_memory_working_set_bytes{%(cadvisorSelector)s, image!=""}
              * on (%(clusterLabel)s, namespace, pod) group_left(node) topk by(%(clusterLabel)s, namespace, pod) (1,
                max by(%(clusterLabel)s, namespace, pod, node) (kube_pod_info{node!=""})
              )
            ||| % $._config,
          },
        ],
      },
      {
        name: 'k8s.rules.container_memory_rss',
        rules: [
          {
            record: 'node_namespace_pod_container:container_memory_rss',
            expr: |||
              container_memory_rss{%(cadvisorSelector)s, image!=""}
              * on (%(clusterLabel)s, namespace, pod) group_left(node) topk by(%(clusterLabel)s, namespace, pod) (1,
                max by(%(clusterLabel)s, namespace, pod, node) (kube_pod_info{node!=""})
              )
            ||| % $._config,
          },
        ],
      },
      {
        name: 'k8s.rules.container_memory_cache',
        rules: [
          {
            record: 'node_namespace_pod_container:container_memory_cache',
            expr: |||
              container_memory_cache{%(cadvisorSelector)s, image!=""}
              * on (%(clusterLabel)s, namespace, pod) group_left(node) topk by(%(clusterLabel)s, namespace, pod) (1,
                max by(%(clusterLabel)s, namespace, pod, node) (kube_pod_info{node!=""})
              )
            ||| % $._config,
          },
        ],
      },
      {
        name: 'k8s.rules.container_memory_swap',
        rules: [
          {
            record: 'node_namespace_pod_container:container_memory_swap',
            expr: |||
              container_memory_swap{%(cadvisorSelector)s, image!=""}
              * on (%(clusterLabel)s, namespace, pod) group_left(node) topk by(%(clusterLabel)s, namespace, pod) (1,
                max by(%(clusterLabel)s, namespace, pod, node) (kube_pod_info{node!=""})
              )
            ||| % $._config,
          },
        ],
      },
      {
        name: 'k8s.rules.container_memory_requests',
        rules: [
          {
            record: 'cluster:namespace:pod_memory:active:kube_pod_container_resource_requests',
            expr: |||
              kube_pod_container_resource_requests{resource="memory",%(kubeStateMetricsSelector)s}  * on (namespace, pod, %(clusterLabel)s)
              group_left() max by (namespace, pod, %(clusterLabel)s) (
                (kube_pod_status_phase{phase=~"Pending|Running"} == 1)
              )
            ||| % $._config,
          },
          {
            record: 'namespace_memory:kube_pod_container_resource_requests:sum',
            expr: |||
              sum by (namespace, %(clusterLabel)s) (
                  sum by (namespace, pod, %(clusterLabel)s) (
                      max by (namespace, pod, container, %(clusterLabel)s) (
                        kube_pod_container_resource_requests{resource="memory",%(kubeStateMetricsSelector)s}
                      ) * on(namespace, pod, %(clusterLabel)s) group_left() max by (namespace, pod, %(clusterLabel)s) (
                        kube_pod_status_phase{phase=~"Pending|Running"} == 1
                      )
                  )
              )
            ||| % $._config,
          },
        ],
      },
      {
        name: 'k8s.rules.container_cpu_requests',
        rules: [
          {
            record: 'cluster:namespace:pod_cpu:active:kube_pod_container_resource_requests',
            expr: |||
              kube_pod_container_resource_requests{resource="cpu",%(kubeStateMetricsSelector)s}  * on (namespace, pod, %(clusterLabel)s)
              group_left() max by (namespace, pod, %(clusterLabel)s) (
                (kube_pod_status_phase{phase=~"Pending|Running"} == 1)
              )
            ||| % $._config,
          },
          {
            record: 'namespace_cpu:kube_pod_container_resource_requests:sum',
            expr: |||
              sum by (namespace, %(clusterLabel)s) (
                  sum by (namespace, pod, %(clusterLabel)s) (
                      max by (namespace, pod, container, %(clusterLabel)s) (
                        kube_pod_container_resource_requests{resource="cpu",%(kubeStateMetricsSelector)s}
                      ) * on(namespace, pod, %(clusterLabel)s) group_left() max by (namespace, pod, %(clusterLabel)s) (
                        kube_pod_status_phase{phase=~"Pending|Running"} == 1
                      )
                  )
              )
            ||| % $._config,
          },
        ],
      },
      {
        name: 'k8s.rules.container_memory_limits',
        rules: [
          {
            record: 'cluster:namespace:pod_memory:active:kube_pod_container_resource_limits',
            expr: |||
              kube_pod_container_resource_limits{resource="memory",%(kubeStateMetricsSelector)s}  * on (namespace, pod, %(clusterLabel)s)
              group_left() max by (namespace, pod, %(clusterLabel)s) (
                (kube_pod_status_phase{phase=~"Pending|Running"} == 1)
              )
            ||| % $._config,
          },
          {
            record: 'namespace_memory:kube_pod_container_resource_limits:sum',
            expr: |||
              sum by (namespace, %(clusterLabel)s) (
                  sum by (namespace, pod, %(clusterLabel)s) (
                      max by (namespace, pod, container, %(clusterLabel)s) (
                        kube_pod_container_resource_limits{resource="memory",%(kubeStateMetricsSelector)s}
                      ) * on(namespace, pod, %(clusterLabel)s) group_left() max by (namespace, pod, %(clusterLabel)s) (
                        kube_pod_status_phase{phase=~"Pending|Running"} == 1
                      )
                  )
              )
            ||| % $._config,
          },
        ],
      },
      {
        name: 'k8s.rules.container_cpu_limits',
        rules: [
          {
            record: 'cluster:namespace:pod_cpu:active:kube_pod_container_resource_limits',
            expr: |||
              kube_pod_container_resource_limits{resource="cpu",%(kubeStateMetricsSelector)s}  * on (namespace, pod, %(clusterLabel)s)
              group_left() max by (namespace, pod, %(clusterLabel)s) (
                (kube_pod_status_phase{phase=~"Pending|Running"} == 1)
              )
            ||| % $._config,
          },
          {
            record: 'namespace_cpu:kube_pod_container_resource_limits:sum',
            expr: |||
              sum by (namespace, %(clusterLabel)s) (
                  sum by (namespace, pod, %(clusterLabel)s) (
                      max by (namespace, pod, container, %(clusterLabel)s) (
                        kube_pod_container_resource_limits{resource="cpu",%(kubeStateMetricsSelector)s}
                      ) * on(namespace, pod, %(clusterLabel)s) group_left() max by (namespace, pod, %(clusterLabel)s) (
                        kube_pod_status_phase{phase=~"Pending|Running"} == 1
                      )
                  )
              )
            ||| % $._config,
          },
        ],
      },
      {
        name: 'k8s.rules.pod_owner',
        rules: [
          // workload aggregation for replicasets
          {
            record: 'namespace_workload_pod:kube_pod_owner:relabel',
            expr: |||
              max by (%(clusterLabel)s, namespace, workload, pod) (
                label_replace(
                  label_replace(
                    kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="ReplicaSet"},
                    "replicaset", "$1", "owner_name", "(.*)"
                  ) * on (%(clusterLabel)s, replicaset, namespace) group_left(owner_name) topk by(%(clusterLabel)s, replicaset, namespace) (
                    1, max by (%(clusterLabel)s, replicaset, namespace, owner_name) (
                      kube_replicaset_owner{%(kubeStateMetricsSelector)s, owner_kind=""}
                    )
                  ),
                  "workload", "$1", "replicaset", "(.*)"
                )
              )
            ||| % $._config,
            labels: {
              workload_type: if $._config.usePascalCaseForWorkloadTypeLabelValues then 'ReplicaSet' else 'replicaset',
            },
          },
          // workload aggregation for deployments
          {
            record: 'namespace_workload_pod:kube_pod_owner:relabel',
            expr: |||
              max by (%(clusterLabel)s, namespace, workload, pod) (
                label_replace(
                  label_replace(
                    kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="ReplicaSet"},
                    "replicaset", "$1", "owner_name", "(.*)"
                  ) * on(replicaset, namespace, %(clusterLabel)s) group_left(owner_name) topk by(%(clusterLabel)s, replicaset, namespace) (
                    1, max by (%(clusterLabel)s, replicaset, namespace, owner_name) (
                      kube_replicaset_owner{%(kubeStateMetricsSelector)s, owner_kind="Deployment"}
                    )
                  ),
                  "workload", "$1", "owner_name", "(.*)"
                )
              )
            ||| % $._config,
            labels: {
              workload_type: if $._config.usePascalCaseForWorkloadTypeLabelValues then 'Deployment' else 'deployment',
            },
          },
          // workload aggregation for daemonsets
          {
            record: 'namespace_workload_pod:kube_pod_owner:relabel',
            expr: |||
              max by (%(clusterLabel)s, namespace, workload, pod) (
                label_replace(
                  kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="DaemonSet"},
                  "workload", "$1", "owner_name", "(.*)"
                )
              )
            ||| % $._config,
            labels: {
              workload_type: if $._config.usePascalCaseForWorkloadTypeLabelValues then 'DaemonSet' else 'daemonset',
            },
          },
          // workload aggregation for statefulsets
          {
            record: 'namespace_workload_pod:kube_pod_owner:relabel',
            expr: |||
              max by (%(clusterLabel)s, namespace, workload, pod) (
                label_replace(
                  kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="StatefulSet"},
                "workload", "$1", "owner_name", "(.*)")
              )
            ||| % $._config,
            labels: {
              workload_type: if $._config.usePascalCaseForWorkloadTypeLabelValues then 'StatefulSet' else 'statefulset',
            },
          },
          // backwards compatibility for jobs
          {
            record: 'namespace_workload_pod:kube_pod_owner:relabel',
            expr: |||
              group by (%(clusterLabel)s, namespace, workload, pod) (
                label_join(
                  group by (%(clusterLabel)s, namespace, job_name, pod, owner_name) (
                    label_join(
                      kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="Job"}
                    , "job_name", "", "owner_name")
                  )
                  * on (%(clusterLabel)s, namespace, job_name) group_left()
                  group by (%(clusterLabel)s, namespace, job_name) (
                    kube_job_owner{%(kubeStateMetricsSelector)s, owner_kind=~"Pod|"}
                  )
                , "workload", "", "owner_name")
              )
            ||| % $._config,
            labels: {
              workload_type: if $._config.usePascalCaseForWorkloadTypeLabelValues then 'Job' else 'job',
            },
          },
          // workload aggregation for barepods
          {
            record: 'namespace_workload_pod:kube_pod_owner:relabel',
            expr: |||
              max by (%(clusterLabel)s, namespace, workload, pod) (
                label_replace(
                  kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="", owner_name=""},
                "workload", "$1", "pod", "(.+)")
              )
            ||| % $._config,
            labels: {
              workload_type: if $._config.usePascalCaseForWorkloadTypeLabelValues then 'BarePod' else 'barepod',
            },
          },
          // workload aggregation for staticpods
          {
            record: 'namespace_workload_pod:kube_pod_owner:relabel',
            expr: |||
              max by (%(clusterLabel)s, namespace, workload, pod) (
                label_replace(
                  kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="Node"},
                "workload", "$1", "pod", "(.+)")
              )
            ||| % $._config,
            labels: {
              workload_type: if $._config.usePascalCaseForWorkloadTypeLabelValues then 'StaticPod' else 'staticpod',
            },
          },
          // workload aggregation for non-standard types (jobs, replicasets)
          {
            record: 'namespace_workload_pod:kube_pod_owner:relabel',
            expr: |||
              group by (%(clusterLabel)s, namespace, workload, workload_type, pod) (
                label_join(
                  label_join(
                    group by (%(clusterLabel)s, namespace, job_name, pod) (
                      label_join(
                        kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="Job"}
                      , "job_name", "", "owner_name")
                    )
                    * on (%(clusterLabel)s, namespace, job_name) group_left(owner_kind, owner_name)
                    group by (%(clusterLabel)s, namespace, job_name, owner_kind, owner_name) (
                      kube_job_owner{%(kubeStateMetricsSelector)s, owner_kind!="Pod", owner_kind!=""}
                    )
                  , "workload", "", "owner_name")
                , "workload_type", "", "owner_kind")

                OR

                label_replace(
                  label_replace(
                    label_replace(
                      kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="ReplicaSet"}
                      , "replicaset", "$1", "owner_name", "(.+)"
                    )
                    * on(%(clusterLabel)s, namespace, replicaset) group_left(owner_kind, owner_name)
                    group by (%(clusterLabel)s, namespace, replicaset, owner_kind, owner_name) (
                      kube_replicaset_owner{%(kubeStateMetricsSelector)s, owner_kind!="Deployment", owner_kind!=""}
                    )
                  , "workload", "$1", "owner_name", "(.+)")
                  OR
                  label_replace(
                    group by (%(clusterLabel)s, namespace, pod, owner_name, owner_kind) (
                      kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind!="ReplicaSet", owner_kind!="DaemonSet", owner_kind!="StatefulSet", owner_kind!="Job", owner_kind!="Node", owner_kind!=""}
                    )
                    , "workload", "$1", "owner_name", "(.+)"
                  )
                , "workload_type", "$1", "owner_kind", "(.+)")
              )
            ||| % $._config,
          },
        ],
      },
    ],
  },
}
