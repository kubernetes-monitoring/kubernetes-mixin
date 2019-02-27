local g = import 'grafana-builder/grafana.libsonnet';

{
  grafanaDashboards+:: {
    'k8s-resources-cluster.json':
      local tableStyles = {
        namespace: {
          alias: 'Namespace',
          link: '%(prefix)s/d/%(uid)s/k8s-resources-namespace?var-datasource=$datasource&var-cluster=$cluster&var-namespace=$__cell' % { prefix: $._config.grafanaK8s.linkPrefix, uid: std.md5('k8s-resources-namespace.json') },
        },
      };

      g.dashboard(
        '%(dashboardNamePrefix)sCompute Resources / Cluster' % $._config.grafanaK8s,
        uid=($._config.grafanaDashboardIDs['k8s-resources-cluster.json']),
      ).addTemplate('cluster', 'node_cpu_seconds_total', $._config.clusterLabel, hide=if $._config.showMultiCluster then 0 else 2)
      .addRow(
        (g.row('Headlines') +
         {
           height: '100px',
           showTitle: false,
         })
        .addPanel(
          g.panel('CPU Utilisation') +
          g.statPanel('1 - avg(rate(node_cpu_seconds_total{mode="idle", %(clusterLabel)s="$cluster"}[1m]))' % $._config)
        )
        .addPanel(
          g.panel('CPU Requests Commitment') +
          g.statPanel('sum(kube_pod_container_resource_requests_cpu_cores{%(clusterLabel)s="$cluster"}) / sum(node:node_num_cpu:sum{%(clusterLabel)s="$cluster"})' % $._config)
        )
        .addPanel(
          g.panel('CPU Limits Commitment') +
          g.statPanel('sum(kube_pod_container_resource_limits_cpu_cores{%(clusterLabel)s="$cluster"}) / sum(node:node_num_cpu:sum{%(clusterLabel)s="$cluster"})' % $._config)
        )
        .addPanel(
          g.panel('Memory Utilisation') +
          g.statPanel('1 - sum(:node_memory_MemFreeCachedBuffers_bytes:sum{%(clusterLabel)s="$cluster"}) / sum(:node_memory_MemTotal_bytes:sum{%(clusterLabel)s="$cluster"})' % $._config)
        )
        .addPanel(
          g.panel('Memory Requests Commitment') +
          g.statPanel('sum(kube_pod_container_resource_requests_memory_bytes{%(clusterLabel)s="$cluster"}) / sum(:node_memory_MemTotal_bytes:sum{%(clusterLabel)s="$cluster"})' % $._config)
        )
        .addPanel(
          g.panel('Memory Limits Commitment') +
          g.statPanel('sum(kube_pod_container_resource_limits_memory_bytes{%(clusterLabel)s="$cluster"}) / sum(:node_memory_MemTotal_bytes:sum{%(clusterLabel)s="$cluster"})' % $._config)
        )
      )
      .addRow(
        g.row('CPU')
        .addPanel(
          g.panel('CPU Usage') +
          g.queryPanel('sum(namespace_pod_name_container_name:container_cpu_usage_seconds_total:sum_rate{%(clusterLabel)s="$cluster"}) by (namespace)' % $._config, '{{namespace}}') +
          g.stack
        )
      )
      .addRow(
        g.row('CPU Quota')
        .addPanel(
          g.panel('CPU Quota') +
          g.tablePanel([
            'sum(namespace_pod_name_container_name:container_cpu_usage_seconds_total:sum_rate{%(clusterLabel)s="$cluster"}) by (namespace)' % $._config,
            'sum(kube_pod_container_resource_requests_cpu_cores{%(clusterLabel)s="$cluster"}) by (namespace)' % $._config,
            'sum(namespace_pod_name_container_name:container_cpu_usage_seconds_total:sum_rate{%(clusterLabel)s="$cluster"}) by (namespace) / sum(kube_pod_container_resource_requests_cpu_cores{%(clusterLabel)s="$cluster"}) by (namespace)' % $._config,
            'sum(kube_pod_container_resource_limits_cpu_cores{%(clusterLabel)s="$cluster"}) by (namespace)' % $._config,
            'sum(namespace_pod_name_container_name:container_cpu_usage_seconds_total:sum_rate{%(clusterLabel)s="$cluster"}) by (namespace) / sum(kube_pod_container_resource_limits_cpu_cores{%(clusterLabel)s="$cluster"}) by (namespace)' % $._config,
          ], tableStyles {
            'Value #A': { alias: 'CPU Usage' },
            'Value #B': { alias: 'CPU Requests' },
            'Value #C': { alias: 'CPU Requests %', unit: 'percentunit' },
            'Value #D': { alias: 'CPU Limits' },
            'Value #E': { alias: 'CPU Limits %', unit: 'percentunit' },
          })
        )
      )
      .addRow(
        g.row('Memory')
        .addPanel(
          g.panel('Memory Usage (w/o cache)') +
          // Not using container_memory_usage_bytes here because that includes page cache
          g.queryPanel('sum(container_memory_rss{%(clusterLabel)s="$cluster", container_name!=""}) by (namespace)' % $._config, '{{namespace}}') +
          g.stack +
          { yaxes: g.yaxes('bytes') },
        )
      )
      .addRow(
        g.row('Memory Requests')
        .addPanel(
          g.panel('Requests by Namespace') +
          g.tablePanel([
            // Not using container_memory_usage_bytes here because that includes page cache
            'sum(container_memory_rss{%(clusterLabel)s="$cluster", container_name!=""}) by (namespace)' % $._config,
            'sum(kube_pod_container_resource_requests_memory_bytes{%(clusterLabel)s="$cluster"}) by (namespace)' % $._config,
            'sum(container_memory_rss{%(clusterLabel)s="$cluster", container_name!=""}) by (namespace) / sum(kube_pod_container_resource_requests_memory_bytes{%(clusterLabel)s="$cluster"}) by (namespace)' % $._config,
            'sum(kube_pod_container_resource_limits_memory_bytes{%(clusterLabel)s="$cluster"}) by (namespace)' % $._config,
            'sum(container_memory_rss{%(clusterLabel)s="$cluster", container_name!=""}) by (namespace) / sum(kube_pod_container_resource_limits_memory_bytes{%(clusterLabel)s="$cluster"}) by (namespace)' % $._config,
          ], tableStyles {
            'Value #A': { alias: 'Memory Usage', unit: 'bytes' },
            'Value #B': { alias: 'Memory Requests', unit: 'bytes' },
            'Value #C': { alias: 'Memory Requests %', unit: 'percentunit' },
            'Value #D': { alias: 'Memory Limits', unit: 'bytes' },
            'Value #E': { alias: 'Memory Limits %', unit: 'percentunit' },
          })
        )
      ) + { tags: $._config.grafanaK8s.dashboardTags },

    'k8s-resources-namespace.json':
      local tableStyles = {
        pod: {
          alias: 'Pod',
          link: '%(prefix)s/d/%(uid)s/k8s-resources-pod?var-datasource=$datasource&var-cluster=$cluster&var-namespace=$namespace&var-pod=$__cell' % { prefix: $._config.grafanaK8s.linkPrefix, uid: std.md5('k8s-resources-pod.json') },
        },
      };

      g.dashboard(
        '%(dashboardNamePrefix)sCompute Resources / Namespace' % $._config.grafanaK8s,
        uid=($._config.grafanaDashboardIDs['k8s-resources-namespace.json']),
      ).addTemplate('cluster', 'kube_pod_info', $._config.clusterLabel, hide=if $._config.showMultiCluster then 0 else 2)
      .addTemplate('namespace', 'kube_pod_info{%(clusterLabel)s="$cluster"}' % $._config, 'namespace')
      .addRow(
        g.row('CPU Usage')
        .addPanel(
          g.panel('CPU Usage') +
          g.queryPanel('sum(namespace_pod_name_container_name:container_cpu_usage_seconds_total:sum_rate{%(clusterLabel)s="$cluster", namespace="$namespace"}) by (pod_name)' % $._config, '{{pod_name}}') +
          g.stack,
        )
      )
      .addRow(
        g.row('CPU Quota')
        .addPanel(
          g.panel('CPU Quota') +
          g.tablePanel([
            'sum(label_replace(namespace_pod_name_container_name:container_cpu_usage_seconds_total:sum_rate{%(clusterLabel)s="$cluster", namespace="$namespace"}, "pod", "$1", "pod_name", "(.*)")) by (pod)' % $._config,
            'sum(kube_pod_container_resource_requests_cpu_cores{%(clusterLabel)s="$cluster", namespace="$namespace"}) by (pod)' % $._config,
            'sum(label_replace(namespace_pod_name_container_name:container_cpu_usage_seconds_total:sum_rate{%(clusterLabel)s="$cluster", namespace="$namespace"}, "pod", "$1", "pod_name", "(.*)")) by (pod) / sum(kube_pod_container_resource_requests_cpu_cores{%(clusterLabel)s="$cluster", namespace="$namespace"}) by (pod)' % $._config,
            'sum(kube_pod_container_resource_limits_cpu_cores{%(clusterLabel)s="$cluster", namespace="$namespace"}) by (pod)' % $._config,
            'sum(label_replace(namespace_pod_name_container_name:container_cpu_usage_seconds_total:sum_rate{%(clusterLabel)s="$cluster", namespace="$namespace"}, "pod", "$1", "pod_name", "(.*)")) by (pod) / sum(kube_pod_container_resource_limits_cpu_cores{%(clusterLabel)s="$cluster", namespace="$namespace"}) by (pod)' % $._config,
          ], tableStyles {
            'Value #A': { alias: 'CPU Usage' },
            'Value #B': { alias: 'CPU Requests' },
            'Value #C': { alias: 'CPU Requests %', unit: 'percentunit' },
            'Value #D': { alias: 'CPU Limits' },
            'Value #E': { alias: 'CPU Limits %', unit: 'percentunit' },
          })
        )
      )
      .addRow(
        g.row('Memory Usage')
        .addPanel(
          g.panel('Memory Usage (w/o cache)') +
          // Like abov, without page cache
          g.queryPanel('sum(container_memory_usage_bytes{%(clusterLabel)s="$cluster", namespace="$namespace", container_name!=""}) by (pod_name)' % $._config, '{{pod_name}}') +
          g.stack +
          { yaxes: g.yaxes('bytes') },
        )
      )
      .addRow(
        g.row('Memory Quota')
        .addPanel(
          g.panel('Memory Quota') +
          g.tablePanel([
            'sum(label_replace(container_memory_usage_bytes{%(clusterLabel)s="$cluster", namespace="$namespace",container_name!=""}, "pod", "$1", "pod_name", "(.*)")) by (pod)' % $._config,
            'sum(kube_pod_container_resource_requests_memory_bytes{%(clusterLabel)s="$cluster", namespace="$namespace"}) by (pod)' % $._config,
            'sum(label_replace(container_memory_usage_bytes{%(clusterLabel)s="$cluster", namespace="$namespace",container_name!=""}, "pod", "$1", "pod_name", "(.*)")) by (pod) / sum(kube_pod_container_resource_requests_memory_bytes{namespace="$namespace"}) by (pod)' % $._config,
            'sum(kube_pod_container_resource_limits_memory_bytes{%(clusterLabel)s="$cluster", namespace="$namespace"}) by (pod)' % $._config,
            'sum(label_replace(container_memory_usage_bytes{%(clusterLabel)s="$cluster", namespace="$namespace",container_name!=""}, "pod", "$1", "pod_name", "(.*)")) by (pod) / sum(kube_pod_container_resource_limits_memory_bytes{namespace="$namespace"}) by (pod)' % $._config,
            'sum(label_replace(container_memory_rss{%(clusterLabel)s="$cluster", namespace="$namespace",container_name!=""}, "pod", "$1", "pod_name", "(.*)")) by (pod)' % $._config,
            'sum(label_replace(container_memory_cache{%(clusterLabel)s="$cluster", namespace="$namespace",container_name!=""}, "pod", "$1", "pod_name", "(.*)")) by (pod)' % $._config,
            'sum(label_replace(container_memory_swap{%(clusterLabel)s="$cluster", namespace="$namespace",container_name!=""}, "pod", "$1", "pod_name", "(.*)")) by (pod)' % $._config,
          ], tableStyles {
            'Value #A': { alias: 'Memory Usage', unit: 'bytes' },
            'Value #B': { alias: 'Memory Requests', unit: 'bytes' },
            'Value #C': { alias: 'Memory Requests %', unit: 'percentunit' },
            'Value #D': { alias: 'Memory Limits', unit: 'bytes' },
            'Value #E': { alias: 'Memory Limits %', unit: 'percentunit' },
            'Value #F': { alias: 'Memory Usage (RSS)', unit: 'bytes' },
            'Value #G': { alias: 'Memory Usage (Cache)', unit: 'bytes' },
            'Value #H': { alias: 'Memory Usage (Swap', unit: 'bytes' },
          })
        )
      ) + { tags: $._config.grafanaK8s.dashboardTags },

    'k8s-resources-pod.json':
      local tableStyles = {
        container: {
          alias: 'Container',
        },
      };

      g.dashboard(
        '%(dashboardNamePrefix)sCompute Resources / Pod' % $._config.grafanaK8s,
        uid=($._config.grafanaDashboardIDs['k8s-resources-pod.json']),
      ).addTemplate('cluster', 'kube_pod_info', $._config.clusterLabel, hide=if $._config.showMultiCluster then 0 else 2)
      .addTemplate('namespace', 'kube_pod_info{%(clusterLabel)s="$cluster"}' % $._config, 'namespace')
      .addTemplate('pod', 'kube_pod_info{%(clusterLabel)s="$cluster", namespace="$namespace"}' % $._config, 'pod')
      .addRow(
        g.row('CPU Usage')
        .addPanel(
          g.panel('CPU Usage') +
          g.queryPanel('sum(namespace_pod_name_container_name:container_cpu_usage_seconds_total:sum_rate{namespace="$namespace", pod_name="$pod", container_name!="POD", %(clusterLabel)s="$cluster"}) by (container_name)' % $._config, '{{container_name}}') +
          g.stack,
        )
      )
      .addRow(
        g.row('CPU Quota')
        .addPanel(
          g.panel('CPU Quota') +
          g.tablePanel([
            'sum(label_replace(namespace_pod_name_container_name:container_cpu_usage_seconds_total:sum_rate{%(clusterLabel)s="$cluster", namespace="$namespace", pod_name="$pod", container_name!="POD"}, "container", "$1", "container_name", "(.*)")) by (container)' % $._config,
            'sum(kube_pod_container_resource_requests_cpu_cores{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}) by (container)' % $._config,
            'sum(label_replace(namespace_pod_name_container_name:container_cpu_usage_seconds_total:sum_rate{%(clusterLabel)s="$cluster", namespace="$namespace", pod_name="$pod"}, "container", "$1", "container_name", "(.*)")) by (container) / sum(kube_pod_container_resource_requests_cpu_cores{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}) by (container)' % $._config,
            'sum(kube_pod_container_resource_limits_cpu_cores{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}) by (container)' % $._config,
            'sum(label_replace(namespace_pod_name_container_name:container_cpu_usage_seconds_total:sum_rate{%(clusterLabel)s="$cluster", namespace="$namespace", pod_name="$pod"}, "container", "$1", "container_name", "(.*)")) by (container) / sum(kube_pod_container_resource_limits_cpu_cores{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}) by (container)' % $._config,
          ], tableStyles {
            'Value #A': { alias: 'CPU Usage' },
            'Value #B': { alias: 'CPU Requests' },
            'Value #C': { alias: 'CPU Requests %', unit: 'percentunit' },
            'Value #D': { alias: 'CPU Limits' },
            'Value #E': { alias: 'CPU Limits %', unit: 'percentunit' },
          })
        )
      )
      .addRow(
        g.row('Memory Usage')
        .addPanel(
          g.panel('Memory Usage') +
          g.queryPanel([
            'sum(container_memory_rss{%(clusterLabel)s="$cluster", namespace="$namespace", pod_name="$pod", container_name!="POD", container_name!=""}) by (container_name)' % $._config,
            'sum(container_memory_cache{%(clusterLabel)s="$cluster", namespace="$namespace", pod_name="$pod", container_name!="POD", container_name!=""}) by (container_name)' % $._config,
            'sum(container_memory_swap{%(clusterLabel)s="$cluster", namespace="$namespace", pod_name="$pod", container_name!="POD", container_name!=""}) by (container_name)' % $._config,
          ], [
            '{{container_name}} (RSS)',
            '{{container_name}} (Cache)',
            '{{container_name}} (Swap)',
          ]) +
          g.stack +
          { yaxes: g.yaxes('bytes') },
        )
      )
      .addRow(
        g.row('Memory Quota')
        .addPanel(
          g.panel('Memory Quota') +
          g.tablePanel([
            'sum(label_replace(container_memory_usage_bytes{%(clusterLabel)s="$cluster", namespace="$namespace", pod_name="$pod", container_name!="POD", container_name!=""}, "container", "$1", "container_name", "(.*)")) by (container)' % $._config,
            'sum(kube_pod_container_resource_requests_memory_bytes{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}) by (container)' % $._config,
            'sum(label_replace(container_memory_usage_bytes{%(clusterLabel)s="$cluster", namespace="$namespace", pod_name="$pod"}, "container", "$1", "container_name", "(.*)")) by (container) / sum(kube_pod_container_resource_requests_memory_bytes{namespace="$namespace", pod="$pod"}) by (container)' % $._config,
            'sum(kube_pod_container_resource_limits_memory_bytes{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", container!=""}) by (container)' % $._config,
            'sum(label_replace(container_memory_usage_bytes{%(clusterLabel)s="$cluster", namespace="$namespace", pod_name="$pod", container_name!=""}, "container", "$1", "container_name", "(.*)")) by (container) / sum(kube_pod_container_resource_limits_memory_bytes{namespace="$namespace", pod="$pod"}) by (container)' % $._config,
            'sum(label_replace(container_memory_rss{%(clusterLabel)s="$cluster", namespace="$namespace", pod_name="$pod", container_name != "", container_name != "POD"}, "container", "$1", "container_name", "(.*)")) by (container)' % $._config,
            'sum(label_replace(container_memory_cache{%(clusterLabel)s="$cluster", namespace="$namespace", pod_name="$pod", container_name != "", container_name != "POD"}, "container", "$1", "container_name", "(.*)")) by (container)' % $._config,
            'sum(label_replace(container_memory_swap{%(clusterLabel)s="$cluster", namespace="$namespace", pod_name="$pod", container_name != "", container_name != "POD"}, "container", "$1", "container_name", "(.*)")) by (container)' % $._config,
          ], tableStyles {
            'Value #A': { alias: 'Memory Usage', unit: 'bytes' },
            'Value #B': { alias: 'Memory Requests', unit: 'bytes' },
            'Value #C': { alias: 'Memory Requests %', unit: 'percentunit' },
            'Value #D': { alias: 'Memory Limits', unit: 'bytes' },
            'Value #E': { alias: 'Memory Limits %', unit: 'percentunit' },
            'Value #F': { alias: 'Memory Usage (RSS)', unit: 'bytes' },
            'Value #G': { alias: 'Memory Usage (Cache)', unit: 'bytes' },
            'Value #H': { alias: 'Memory Usage (Swap', unit: 'bytes' },
          })
        )
      ) + { tags: $._config.grafanaK8s.dashboardTags },
  },
} + {
  grafanaDashboards+:: if $._config.showMultiCluster then {
    'k8s-resources-multicluster.json':
      local tableStyles = {
        [$._config.clusterLabel]: {
          alias: 'Cluster',
          link: '%(prefix)s/d/%(uid)s/k8s-resources-cluster?var-datasource=$datasource&var-cluster=$__cell' % { prefix: $._config.grafanaK8s.linkPrefix, uid: std.md5('k8s-resources-cluster.json') },
        },
      };

      g.dashboard(
        '%(dashboardNamePrefix)sCompute Resources /  Multi-Cluster' % $._config.grafanaK8s,
        uid=($._config.grafanaDashboardIDs['k8s-resources-multicluster.json']),
      ).addRow(
        (g.row('Headlines') +
         {
           height: '100px',
           showTitle: false,
         })
        .addPanel(
          g.panel('CPU Utilisation') +
          g.statPanel('1 - avg(rate(node_cpu_seconds_total{mode="idle"}[1m]))' % $._config)
        )
        .addPanel(
          g.panel('CPU Requests Commitment') +
          g.statPanel('sum(kube_pod_container_resource_requests_cpu_cores) / sum(node:node_num_cpu:sum)' % $._config)
        )
        .addPanel(
          g.panel('CPU Limits Commitment') +
          g.statPanel('sum(kube_pod_container_resource_limits_cpu_cores) / sum(node:node_num_cpu:sum)' % $._config)
        )
        .addPanel(
          g.panel('Memory Utilisation') +
          g.statPanel('1 - sum(:node_memory_MemFreeCachedBuffers_bytes:sum) / sum(:node_memory_MemTotal_bytes:sum)' % $._config)
        )
        .addPanel(
          g.panel('Memory Requests Commitment') +
          g.statPanel('sum(kube_pod_container_resource_requests_memory_bytes) / sum(:node_memory_MemTotal_bytes:sum)' % $._config)
        )
        .addPanel(
          g.panel('Memory Limits Commitment') +
          g.statPanel('sum(kube_pod_container_resource_limits_memory_bytes) / sum(:node_memory_MemTotal_bytes:sum)' % $._config)
        )
      )
      .addRow(
        g.row('CPU')
        .addPanel(
          g.panel('CPU Usage') +
          g.queryPanel('sum(namespace_pod_name_container_name:container_cpu_usage_seconds_total:sum_rate) by (%(clusterLabel)s)' % $._config, '{{%(clusterLabel)s}}' % $._config)
          + { fill: 0, linewidth: 2 },
        )
      )
      .addRow(
        g.row('CPU Quota')
        .addPanel(
          g.panel('CPU Quota') +
          g.tablePanel([
            'sum(namespace_pod_name_container_name:container_cpu_usage_seconds_total:sum_rate) by (%(clusterLabel)s)' % $._config,
            'sum(kube_pod_container_resource_requests_cpu_cores) by (%(clusterLabel)s)' % $._config,
            'sum(namespace_pod_name_container_name:container_cpu_usage_seconds_total:sum_rate) by (%(clusterLabel)s) / sum(kube_pod_container_resource_requests_cpu_cores) by (%(clusterLabel)s)' % $._config,
            'sum(kube_pod_container_resource_limits_cpu_cores) by (%(clusterLabel)s)' % $._config,
            'sum(namespace_pod_name_container_name:container_cpu_usage_seconds_total:sum_rate) by (%(clusterLabel)s) / sum(kube_pod_container_resource_limits_cpu_cores) by (%(clusterLabel)s)' % $._config,
          ], tableStyles {
            'Value #A': { alias: 'CPU Usage' },
            'Value #B': { alias: 'CPU Requests' },
            'Value #C': { alias: 'CPU Requests %', unit: 'percentunit' },
            'Value #D': { alias: 'CPU Limits' },
            'Value #E': { alias: 'CPU Limits %', unit: 'percentunit' },
          })
        )
      )
      .addRow(
        g.row('Memory')
        .addPanel(
          g.panel('Memory Usage (w/o cache)') +
          // Not using container_memory_usage_bytes here because that includes page cache
          g.queryPanel('sum(container_memory_rss{container_name!=""}) by (%(clusterLabel)s)' % $._config, '{{%(clusterLabel)s}}' % $._config) +
          { fill: 0, linewidth: 2, yaxes: g.yaxes('decbytes') },
        )
      )
      .addRow(
        g.row('Memory Requests')
        .addPanel(
          g.panel('Requests by Namespace') +
          g.tablePanel([
            // Not using container_memory_usage_bytes here because that includes page cache
            'sum(container_memory_rss{container_name!=""}) by (%(clusterLabel)s)' % $._config,
            'sum(kube_pod_container_resource_requests_memory_bytes) by (%(clusterLabel)s)' % $._config,
            'sum(container_memory_rss{container_name!=""}) by (%(clusterLabel)s) / sum(kube_pod_container_resource_requests_memory_bytes) by (%(clusterLabel)s)' % $._config,
            'sum(kube_pod_container_resource_limits_memory_bytes) by (%(clusterLabel)s)' % $._config,
            'sum(container_memory_rss{container_name!=""}) by (%(clusterLabel)s) / sum(kube_pod_container_resource_limits_memory_bytes) by (%(clusterLabel)s)' % $._config,
          ], tableStyles {
            'Value #A': { alias: 'Memory Usage', unit: 'bytes' },
            'Value #B': { alias: 'Memory Requests', unit: 'bytes' },
            'Value #C': { alias: 'Memory Requests %', unit: 'percentunit' },
            'Value #D': { alias: 'Memory Limits', unit: 'bytes' },
            'Value #E': { alias: 'Memory Limits %', unit: 'percentunit' },
          })
        )
      ) + { tags: $._config.grafanaK8s.dashboardTags },
  } else {},
}
