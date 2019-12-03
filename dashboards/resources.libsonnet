local g = import 'grafana-builder/grafana.libsonnet';
local grafana = import 'grafonnet/grafana.libsonnet';
local template = grafana.template;

{
  grafanaDashboards+:: {

    local intervalTemplate =
      template.new(
        name='interval',
        datasource='$datasource',
        query='4h',
        current='5m',
        hide=2,
        refresh=2,
        includeAll=false,
        sort=1
      ) + {
        auto: false,
        auto_count: 30,
        auto_min: '10s',
        skipUrlSync: false,
        type: 'interval',
        options: [
          {
            selected: true,
            text: '4h',
            value: '4h',
          },
        ],
      },

    local typeTemplate =
      template.new(
        name='type',
        datasource='$datasource',
        query='label_values(mixin_pod_workload{namespace=~"$namespace", workload=~".+"}, workload_type)',
        current='deployment',
        hide='',
        refresh=1,
        includeAll=false,
        sort=0
      ) + {
        auto: false,
        auto_count: 30,
        auto_min: '10s',
        definition: 'label_values(mixin_pod_workload{namespace=~"$namespace", workload=~".+"}, workload_type)',
        skipUrlSync: false,
      },

    'k8s-resources-cluster.json':
      local tableStyles = {
        namespace: {
          alias: 'Namespace',
          link: '%(prefix)s/d/%(uid)s/k8s-resources-namespace?var-datasource=$datasource&var-cluster=$cluster&var-namespace=$__cell' % { prefix: $._config.grafanaK8s.linkPrefix, uid: std.md5('k8s-resources-namespace.json') },
          linkTooltip: 'Drill down to pods',
        },
        'Value #A': {
          alias: 'Pods',
          linkTooltip: 'Drill down to pods',
          link: '%(prefix)s/d/%(uid)s/k8s-resources-namespace?var-datasource=$datasource&var-cluster=$cluster&var-namespace=$__cell_1' % { prefix: $._config.grafanaK8s.linkPrefix, uid: std.md5('k8s-resources-namespace.json') },
          decimals: 0,
        },
        'Value #B': {
          alias: 'Workloads',
          linkTooltip: 'Drill down to workloads',
          link: '%(prefix)s/d/%(uid)s/k8s-resources-workloads-namespace?var-datasource=$datasource&var-cluster=$cluster&var-namespace=$__cell_1' % { prefix: $._config.grafanaK8s.linkPrefix, uid: std.md5('k8s-resources-workloads-namespace.json') },
          decimals: 0,
        },
      };

      local podWorkloadColumns = [
        'count(mixin_pod_workload{%(clusterLabel)s="$cluster"}) by (namespace)' % $._config,
        'count(avg(mixin_pod_workload{%(clusterLabel)s="$cluster"}) by (workload, namespace)) by (namespace)' % $._config,
      ];

      local networkColumns = [
        'sum(irate(container_network_receive_bytes_total{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[$interval])) by (namespace)' % $._config,
        'sum(irate(container_network_transmit_bytes_total{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[$interval])) by (namespace)' % $._config,
        'sum(irate(container_network_receive_packets_total{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[$interval])) by (namespace)' % $._config,
        'sum(irate(container_network_transmit_packets_total{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[$interval])) by (namespace)' % $._config,
        'sum(irate(container_network_receive_packets_dropped_total{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[$interval])) by (namespace)' % $._config,
        'sum(irate(container_network_transmit_packets_dropped_total{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[$interval])) by (namespace)' % $._config,
      ];

      local networkTableStyles = {
        namespace: {
          alias: 'Namespace',
          link: '%(prefix)s/d/%(uid)s/k8s-resources-namespace?var-datasource=$datasource&var-cluster=$cluster&var-namespace=$__cell' % { prefix: $._config.grafanaK8s.linkPrefix, uid: std.md5('k8s-resources-namespace.json') },
          linkTooltip: 'Drill down to pods',
        },
        'Value #A': {
          alias: 'Current Receive Bandwidth',
          unit: 'Bps',
        },
        'Value #B': {
          alias: 'Current Transmit Bandwidth',
          unit: 'Bps',
        },
        'Value #C': {
          alias: 'Rate of Received Packets',
          unit: 'pps',
        },
        'Value #D': {
          alias: 'Rate of Transmitted Packets',
          unit: 'pps',
        },
        'Value #E': {
          alias: 'Rate of Received Packets Dropped',
          unit: 'pps',
        },
        'Value #F': {
          alias: 'Rate of Transmitted Packets Dropped',
          unit: 'pps',
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
          g.statPanel('sum(kube_pod_container_resource_requests_cpu_cores{%(clusterLabel)s="$cluster"}) / sum(kube_node_status_allocatable_cpu_cores{%(clusterLabel)s="$cluster"})' % $._config)
        )
        .addPanel(
          g.panel('CPU Limits Commitment') +
          g.statPanel('sum(kube_pod_container_resource_limits_cpu_cores{%(clusterLabel)s="$cluster"}) / sum(kube_node_status_allocatable_cpu_cores{%(clusterLabel)s="$cluster"})' % $._config)
        )
        .addPanel(
          g.panel('Memory Utilisation') +
          g.statPanel('1 - sum(:node_memory_MemAvailable_bytes:sum{%(clusterLabel)s="$cluster"}) / sum(kube_node_status_allocatable_memory_bytes{%(clusterLabel)s="$cluster"})' % $._config)
        )
        .addPanel(
          g.panel('Memory Requests Commitment') +
          g.statPanel('sum(kube_pod_container_resource_requests_memory_bytes{%(clusterLabel)s="$cluster"}) / sum(kube_node_status_allocatable_memory_bytes{%(clusterLabel)s="$cluster"})' % $._config)
        )
        .addPanel(
          g.panel('Memory Limits Commitment') +
          g.statPanel('sum(kube_pod_container_resource_limits_memory_bytes{%(clusterLabel)s="$cluster"}) / sum(kube_node_status_allocatable_memory_bytes{%(clusterLabel)s="$cluster"})' % $._config)
        )
      )
      .addRow(
        g.row('CPU')
        .addPanel(
          g.panel('CPU Usage') +
          g.queryPanel('sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate{%(clusterLabel)s="$cluster"}) by (namespace)' % $._config, '{{namespace}}') +
          g.stack
        )
      )
      .addRow(
        g.row('CPU Quota')
        .addPanel(
          g.panel('CPU Quota') +
          g.tablePanel(podWorkloadColumns + [
            'sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate{%(clusterLabel)s="$cluster"}) by (namespace)' % $._config,
            'sum(kube_pod_container_resource_requests_cpu_cores{%(clusterLabel)s="$cluster"}) by (namespace)' % $._config,
            'sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate{%(clusterLabel)s="$cluster"}) by (namespace) / sum(kube_pod_container_resource_requests_cpu_cores{%(clusterLabel)s="$cluster"}) by (namespace)' % $._config,
            'sum(kube_pod_container_resource_limits_cpu_cores{%(clusterLabel)s="$cluster"}) by (namespace)' % $._config,
            'sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate{%(clusterLabel)s="$cluster"}) by (namespace) / sum(kube_pod_container_resource_limits_cpu_cores{%(clusterLabel)s="$cluster"}) by (namespace)' % $._config,
          ], tableStyles {
            'Value #C': { alias: 'CPU Usage' },
            'Value #D': { alias: 'CPU Requests' },
            'Value #E': { alias: 'CPU Requests %', unit: 'percentunit' },
            'Value #F': { alias: 'CPU Limits' },
            'Value #G': { alias: 'CPU Limits %', unit: 'percentunit' },
          })
        )
      )
      .addRow(
        g.row('Memory')
        .addPanel(
          g.panel('Memory Usage (w/o cache)') +
          // Not using container_memory_usage_bytes here because that includes page cache
          g.queryPanel('sum(container_memory_rss{%(clusterLabel)s="$cluster", container!=""}) by (namespace)' % $._config, '{{namespace}}') +
          g.stack +
          { yaxes: g.yaxes('bytes') },
        )
      )
      .addRow(
        g.row('Memory Requests')
        .addPanel(
          g.panel('Requests by Namespace') +
          g.tablePanel(podWorkloadColumns + [
            // Not using container_memory_usage_bytes here because that includes page cache
            'sum(container_memory_rss{%(clusterLabel)s="$cluster", container!=""}) by (namespace)' % $._config,
            'sum(kube_pod_container_resource_requests_memory_bytes{%(clusterLabel)s="$cluster"}) by (namespace)' % $._config,
            'sum(container_memory_rss{%(clusterLabel)s="$cluster", container!=""}) by (namespace) / sum(kube_pod_container_resource_requests_memory_bytes{%(clusterLabel)s="$cluster"}) by (namespace)' % $._config,
            'sum(kube_pod_container_resource_limits_memory_bytes{%(clusterLabel)s="$cluster"}) by (namespace)' % $._config,
            'sum(container_memory_rss{%(clusterLabel)s="$cluster", container!=""}) by (namespace) / sum(kube_pod_container_resource_limits_memory_bytes{%(clusterLabel)s="$cluster"}) by (namespace)' % $._config,
          ], tableStyles {
            'Value #C': { alias: 'Memory Usage', unit: 'bytes' },
            'Value #D': { alias: 'Memory Requests', unit: 'bytes' },
            'Value #E': { alias: 'Memory Requests %', unit: 'percentunit' },
            'Value #F': { alias: 'Memory Limits', unit: 'bytes' },
            'Value #G': { alias: 'Memory Limits %', unit: 'percentunit' },
          })
        )
      )
      .addRow(
        g.row('Network')
        .addPanel(
          g.panel('Current Network Usage') +
          g.tablePanel(
            networkColumns,
            networkTableStyles
          ),
        )
      )
      .addRow(
        g.row('Network')
        .addPanel(
          g.panel('Receive Bandwidth') +
          g.queryPanel('sum(irate(container_network_receive_bytes_total{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[$interval])) by (namespace)' % $._config, '{{namespace}}') +
          g.stack +
          { yaxes: g.yaxes('Bps') },
        )
      )
      .addRow(
        g.row('Network')
        .addPanel(
          g.panel('Transmit Bandwidth') +
          g.queryPanel('sum(irate(container_network_transmit_bytes_total{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[$interval])) by (namespace)' % $._config, '{{namespace}}') +
          g.stack +
          { yaxes: g.yaxes('Bps') },
        )
      )
      .addRow(
        g.row('Network')
        .addPanel(
          g.panel('Average Container Bandwidth by Namespace: Received') +
          g.queryPanel('avg(irate(container_network_receive_bytes_total{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[$interval])) by (namespace)' % $._config, '{{namespace}}') +
          g.stack +
          { yaxes: g.yaxes('Bps') },
        )
      )
      .addRow(
        g.row('Network')
        .addPanel(
          g.panel('Average Container Bandwidth by Namespace: Transmitted') +
          g.queryPanel('avg(irate(container_network_transmit_bytes_total{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[$interval])) by (namespace)' % $._config, '{{namespace}}') +
          g.stack +
          { yaxes: g.yaxes('Bps') },
        )
      )
      .addRow(
        g.row('Network')
        .addPanel(
          g.panel('Rate of Received Packets') +
          g.queryPanel('sum(irate(container_network_receive_packets_total{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[$interval])) by (namespace)' % $._config, '{{namespace}}') +
          g.stack +
          { yaxes: g.yaxes('Bps') },
        )
      )
      .addRow(
        g.row('Network')
        .addPanel(
          g.panel('Rate of Transmitted Packets') +
          g.queryPanel('sum(irate(container_network_receive_packets_total{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[$interval])) by (namespace)' % $._config, '{{namespace}}') +
          g.stack +
          { yaxes: g.yaxes('Bps') },
        )
      )
      .addRow(
        g.row('Network')
        .addPanel(
          g.panel('Rate of Received Packets Dropped') +
          g.queryPanel('sum(irate(container_network_receive_packets_dropped_total{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[$interval])) by (namespace)' % $._config, '{{namespace}}') +
          g.stack +
          { yaxes: g.yaxes('Bps') },
        )
      )
      .addRow(
        g.row('Network')
        .addPanel(
          g.panel('Rate of Transmitted Packets Dropped') +
          g.queryPanel('sum(irate(container_network_transmit_packets_dropped_total{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[$interval])) by (namespace)' % $._config, '{{namespace}}') +
          g.stack +
          { yaxes: g.yaxes('Bps') },
        )
      ) + { tags: $._config.grafanaK8s.dashboardTags, templating+: { list+: [intervalTemplate] } },

    'k8s-resources-namespace.json':
      local tableStyles = {
        pod: {
          alias: 'Pod',
          link: '%(prefix)s/d/%(uid)s/k8s-resources-pod?var-datasource=$datasource&var-cluster=$cluster&var-namespace=$namespace&var-pod=$__cell' % { prefix: $._config.grafanaK8s.linkPrefix, uid: std.md5('k8s-resources-pod.json') },
        },
      };

      local networkColumns = [
        'sum(irate(container_network_receive_bytes_total{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace"}[$interval])) by (pod)' % $._config,
        'sum(irate(container_network_transmit_bytes_total{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace"}[$interval])) by (pod)' % $._config,
        'sum(irate(container_network_receive_packets_total{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace"}[$interval])) by (pod)' % $._config,
        'sum(irate(container_network_transmit_packets_total{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace"}[$interval])) by (pod)' % $._config,
        'sum(irate(container_network_receive_packets_dropped_total{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace"}[$interval])) by (pod)' % $._config,
        'sum(irate(container_network_transmit_packets_dropped_total{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace"}[$interval])) by (pod)' % $._config,
      ];

      local networkTableStyles = {
        pod: {
          alias: 'Pod',
          link: '%(prefix)s/d/%(uid)s/k8s-resources-pod?var-datasource=$datasource&var-cluster=$cluster&var-namespace=$namespace&var-pod=$__cell' % { prefix: $._config.grafanaK8s.linkPrefix, uid: std.md5('k8s-resources-pod.json') },
          linkTooltip: 'Drill down to pods',
        },
        'Value #A': {
          alias: 'Current Receive Bandwidth',
          unit: 'Bps',
        },
        'Value #B': {
          alias: 'Current Transmit Bandwidth',
          unit: 'Bps',
        },
        'Value #C': {
          alias: 'Rate of Received Packets',
          unit: 'pps',
        },
        'Value #D': {
          alias: 'Rate of Transmitted Packets',
          unit: 'pps',
        },
        'Value #E': {
          alias: 'Rate of Received Packets Dropped',
          unit: 'pps',
        },
        'Value #F': {
          alias: 'Rate of Transmitted Packets Dropped',
          unit: 'pps',
        },
      };

      g.dashboard(
        '%(dashboardNamePrefix)sCompute Resources / Namespace (Pods)' % $._config.grafanaK8s,
        uid=($._config.grafanaDashboardIDs['k8s-resources-namespace.json']),
      ).addTemplate('cluster', 'kube_pod_info', $._config.clusterLabel, hide=if $._config.showMultiCluster then 0 else 2)
      .addTemplate('namespace', 'kube_pod_info{%(clusterLabel)s="$cluster"}' % $._config, 'namespace')
      .addRow(
        g.row('CPU Usage')
        .addPanel(
          g.panel('CPU Usage') +
          g.queryPanel('sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate{%(clusterLabel)s="$cluster", namespace="$namespace"}) by (pod)' % $._config, '{{pod}}') +
          g.stack,
        )
      )
      .addRow(
        g.row('CPU Quota')
        .addPanel(
          g.panel('CPU Quota') +
          g.tablePanel([
            'sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate{%(clusterLabel)s="$cluster", namespace="$namespace"}) by (pod)' % $._config,
            'sum(kube_pod_container_resource_requests_cpu_cores{%(clusterLabel)s="$cluster", namespace="$namespace"}) by (pod)' % $._config,
            'sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate{%(clusterLabel)s="$cluster", namespace="$namespace"}) by (pod) / sum(kube_pod_container_resource_requests_cpu_cores{%(clusterLabel)s="$cluster", namespace="$namespace"}) by (pod)' % $._config,
            'sum(kube_pod_container_resource_limits_cpu_cores{%(clusterLabel)s="$cluster", namespace="$namespace"}) by (pod)' % $._config,
            'sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate{%(clusterLabel)s="$cluster", namespace="$namespace"}) by (pod) / sum(kube_pod_container_resource_limits_cpu_cores{%(clusterLabel)s="$cluster", namespace="$namespace"}) by (pod)' % $._config,
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
          // Like above, without page cache
          g.queryPanel('sum(container_memory_working_set_bytes{%(clusterLabel)s="$cluster", namespace="$namespace", container!=""}) by (pod)' % $._config, '{{pod}}') +
          g.stack +
          { yaxes: g.yaxes('bytes') },
        )
      )
      .addRow(
        g.row('Memory Quota')
        .addPanel(
          g.panel('Memory Quota') +
          g.tablePanel([
            'sum(container_memory_working_set_bytes{%(clusterLabel)s="$cluster", namespace="$namespace",container!=""}) by (pod)' % $._config,
            'sum(kube_pod_container_resource_requests_memory_bytes{%(clusterLabel)s="$cluster", namespace="$namespace"}) by (pod)' % $._config,
            'sum(container_memory_working_set_bytes{%(clusterLabel)s="$cluster", namespace="$namespace",container!=""}) by (pod) / sum(kube_pod_container_resource_requests_memory_bytes{namespace="$namespace"}) by (pod)' % $._config,
            'sum(kube_pod_container_resource_limits_memory_bytes{%(clusterLabel)s="$cluster", namespace="$namespace"}) by (pod)' % $._config,
            'sum(container_memory_working_set_bytes{%(clusterLabel)s="$cluster", namespace="$namespace",container!=""}) by (pod) / sum(kube_pod_container_resource_limits_memory_bytes{namespace="$namespace"}) by (pod)' % $._config,
            'sum(container_memory_rss{%(clusterLabel)s="$cluster", namespace="$namespace",container!=""}) by (pod)' % $._config,
            'sum(container_memory_cache{%(clusterLabel)s="$cluster", namespace="$namespace",container!=""}) by (pod)' % $._config,
            'sum(container_memory_swap{%(clusterLabel)s="$cluster", namespace="$namespace",container!=""}) by (pod)' % $._config,
          ], tableStyles {
            'Value #A': { alias: 'Memory Usage', unit: 'bytes' },
            'Value #B': { alias: 'Memory Requests', unit: 'bytes' },
            'Value #C': { alias: 'Memory Requests %', unit: 'percentunit' },
            'Value #D': { alias: 'Memory Limits', unit: 'bytes' },
            'Value #E': { alias: 'Memory Limits %', unit: 'percentunit' },
            'Value #F': { alias: 'Memory Usage (RSS)', unit: 'bytes' },
            'Value #G': { alias: 'Memory Usage (Cache)', unit: 'bytes' },
            'Value #H': { alias: 'Memory Usage (Swap)', unit: 'bytes' },
          })
        )
      )
      .addRow(
        g.row('Network')
        .addPanel(
          g.panel('Current Network Usage') +
          g.tablePanel(
            networkColumns,
            networkTableStyles
          ),
        )
      )
      .addRow(
        g.row('Network')
        .addPanel(
          g.panel('Receive Bandwidth') +
          g.queryPanel('sum(irate(container_network_receive_bytes_total{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace"}[$interval])) by (pod)' % $._config, '{{pod}}') +
          g.stack +
          { yaxes: g.yaxes('Bps') },
        )
      )
      .addRow(
        g.row('Network')
        .addPanel(
          g.panel('Transmit Bandwidth') +
          g.queryPanel('sum(irate(container_network_transmit_bytes_total{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace"}[$interval])) by (pod)' % $._config, '{{pod}}') +
          g.stack +
          { yaxes: g.yaxes('Bps') },
        )
      )
      .addRow(
        g.row('Network')
        .addPanel(
          g.panel('Rate of Received Packets') +
          g.queryPanel('sum(irate(container_network_receive_packets_total{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace"}[$interval])) by (pod)' % $._config, '{{pod}}') +
          g.stack +
          { yaxes: g.yaxes('Bps') },
        )
      )
      .addRow(
        g.row('Network')
        .addPanel(
          g.panel('Rate of Transmitted Packets') +
          g.queryPanel('sum(irate(container_network_receive_packets_total{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace"}[$interval])) by (pod)' % $._config, '{{pod}}') +
          g.stack +
          { yaxes: g.yaxes('Bps') },
        )
      )
      .addRow(
        g.row('Network')
        .addPanel(
          g.panel('Rate of Received Packets Dropped') +
          g.queryPanel('sum(irate(container_network_receive_packets_dropped_total{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace"}[$interval])) by (pod)' % $._config, '{{pod}}') +
          g.stack +
          { yaxes: g.yaxes('Bps') },
        )
      )
      .addRow(
        g.row('Network')
        .addPanel(
          g.panel('Rate of Transmitted Packets Dropped') +
          g.queryPanel('sum(irate(container_network_transmit_packets_dropped_total{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace"}[$interval])) by (pod)' % $._config, '{{pod}}') +
          g.stack +
          { yaxes: g.yaxes('Bps') },
        )
      ) + { tags: $._config.grafanaK8s.dashboardTags, templating+: { list+: [intervalTemplate] } },

    'k8s-resources-node.json':
      local tableStyles = {
        pod: {
          alias: 'Pod',
        },
      };

      g.dashboard(
        '%(dashboardNamePrefix)sCompute Resources / Node (Pods)' % $._config.grafanaK8s,
        uid=($._config.grafanaDashboardIDs['k8s-resources-node.json']),
      ).addTemplate('cluster', 'kube_pod_info', $._config.clusterLabel, hide=if $._config.showMultiCluster then 0 else 2)
      .addTemplate('node', 'kube_pod_info{%(clusterLabel)s="$cluster"}' % $._config, 'node')
      .addRow(
        g.row('CPU Usage')
        .addPanel(
          g.panel('CPU Usage') +
          g.queryPanel('sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate{%(clusterLabel)s="$cluster", node="$node"}) by (pod)' % $._config, '{{pod}}') +
          g.stack,
        )
      )
      .addRow(
        g.row('CPU Quota')
        .addPanel(
          g.panel('CPU Quota') +
          g.tablePanel([
            'sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate{%(clusterLabel)s="$cluster", node="$node"}) by (pod)' % $._config,
            'sum(kube_pod_container_resource_requests_cpu_cores{%(clusterLabel)s="$cluster", node="$node"}) by (pod)' % $._config,
            'sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate{%(clusterLabel)s="$cluster", node="$node"}) by (pod) / sum(kube_pod_container_resource_requests_cpu_cores{%(clusterLabel)s="$cluster", node="$node"}) by (pod)' % $._config,
            'sum(kube_pod_container_resource_limits_cpu_cores{%(clusterLabel)s="$cluster", node="$node"}) by (pod)' % $._config,
            'sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate{%(clusterLabel)s="$cluster", node="$node"}) by (pod) / sum(kube_pod_container_resource_limits_cpu_cores{%(clusterLabel)s="$cluster", node="$node"}) by (pod)' % $._config,
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
          // Like above, without page cache
          g.queryPanel('sum(node_namespace_pod_container:container_memory_working_set_bytes{%(clusterLabel)s="$cluster", node="$node", container!=""}) by (pod)' % $._config, '{{pod}}') +
          g.stack +
          { yaxes: g.yaxes('bytes') },
        )
      )
      .addRow(
        g.row('Memory Quota')
        .addPanel(
          g.panel('Memory Quota') +
          g.tablePanel([
            'sum(node_namespace_pod_container:container_memory_working_set_bytes{%(clusterLabel)s="$cluster", node="$node",container!=""}) by (pod)' % $._config,
            'sum(kube_pod_container_resource_requests_memory_bytes{%(clusterLabel)s="$cluster", node="$node"}) by (pod)' % $._config,
            'sum(node_namespace_pod_container:container_memory_working_set_bytes{%(clusterLabel)s="$cluster", node="$node",container!=""}) by (pod) / sum(kube_pod_container_resource_requests_memory_bytes{node="$node"}) by (pod)' % $._config,
            'sum(kube_pod_container_resource_limits_memory_bytes{%(clusterLabel)s="$cluster", node="$node"}) by (pod)' % $._config,
            'sum(node_namespace_pod_container:container_memory_working_set_bytes{%(clusterLabel)s="$cluster", node="$node",container!=""}) by (pod) / sum(kube_pod_container_resource_limits_memory_bytes{node="$node"}) by (pod)' % $._config,
            'sum(node_namespace_pod_container:container_memory_rss{%(clusterLabel)s="$cluster", node="$node",container!=""}) by (pod)' % $._config,
            'sum(node_namespace_pod_container:container_memory_cache{%(clusterLabel)s="$cluster", node="$node",container!=""}) by (pod)' % $._config,
            'sum(node_namespace_pod_container:container_memory_swap{%(clusterLabel)s="$cluster", node="$node",container!=""}) by (pod)' % $._config,
          ], tableStyles {
            'Value #A': { alias: 'Memory Usage', unit: 'bytes' },
            'Value #B': { alias: 'Memory Requests', unit: 'bytes' },
            'Value #C': { alias: 'Memory Requests %', unit: 'percentunit' },
            'Value #D': { alias: 'Memory Limits', unit: 'bytes' },
            'Value #E': { alias: 'Memory Limits %', unit: 'percentunit' },
            'Value #F': { alias: 'Memory Usage (RSS)', unit: 'bytes' },
            'Value #G': { alias: 'Memory Usage (Cache)', unit: 'bytes' },
            'Value #H': { alias: 'Memory Usage (Swap)', unit: 'bytes' },
          })
        )
      ) + { tags: $._config.grafanaK8s.dashboardTags },

    'k8s-resources-workloads-namespace.json':
      local tableStyles = {
        workload: {
          alias: 'Workload',
          link: '%(prefix)s/d/%(uid)s/k8s-resources-workload?var-datasource=$datasource&var-cluster=$cluster&var-namespace=$namespace&var-workload=$__cell&var-type=$__cell_2' % { prefix: $._config.grafanaK8s.linkPrefix, uid: std.md5('k8s-resources-workload.json') },
        },
        workload_type: {
          alias: 'Workload Type',
        },
      };

      local networkColumns = [
        |||
          (sum(irate(container_network_receive_bytes_total{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace"}[$interval])
          * on (namespace,pod)
          group_left(workload,workload_type) mixin_pod_workload{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace", workload_type="$type"}) by (workload))
        ||| % $._config,
        |||
          (sum(irate(container_network_transmit_bytes_total{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace"}[$interval])
          * on (namespace,pod)
          group_left(workload,workload_type) mixin_pod_workload{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace", workload_type="$type"}) by (workload))
        ||| % $._config,
        |||
          (sum(irate(container_network_receive_packets_total{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace"}[$interval])
          * on (namespace,pod)
          group_left(workload,workload_type) mixin_pod_workload{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace", workload_type="$type"}) by (workload))
        ||| % $._config,
        |||
          (sum(irate(container_network_transmit_packets_total{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace"}[$interval])
          * on (namespace,pod)
          group_left(workload,workload_type) mixin_pod_workload{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace", workload_type="$type"}) by (workload))
        ||| % $._config,
        |||
          (sum(irate(container_network_receive_packets_dropped_total{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace"}[$interval])
          * on (namespace,pod)
          group_left(workload,workload_type) mixin_pod_workload{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace", workload_type="$type"}) by (workload))
        ||| % $._config,
        |||
          (sum(irate(container_network_transmit_packets_dropped_total{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace"}[$interval])
          * on (namespace,pod)
          group_left(workload,workload_type) mixin_pod_workload{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace", workload_type="$type"}) by (workload))
        ||| % $._config,
      ];

      local networkTableStyles = {
        workload: {
          alias: 'Workload',
          link: '%(prefix)s/d/%(uid)s/k8s-resources-workload?var-datasource=$datasource&var-cluster=$cluster&var-namespace=$namespace&var-workload=$__cell&var-type=$type' % { prefix: $._config.grafanaK8s.linkPrefix, uid: std.md5('k8s-resources-workload.json') },
          linkTooltip: 'Drill down to pods',
        },
        workload_type: {
          alias: 'Workload Type',
        },
        'Value #A': {
          alias: 'Current Receive Bandwidth',
          unit: 'Bps',
        },
        'Value #B': {
          alias: 'Current Transmit Bandwidth',
          unit: 'Bps',
        },
        'Value #C': {
          alias: 'Rate of Received Packets',
          unit: 'pps',
        },
        'Value #D': {
          alias: 'Rate of Transmitted Packets',
          unit: 'pps',
        },
        'Value #E': {
          alias: 'Rate of Received Packets Dropped',
          unit: 'pps',
        },
        'Value #F': {
          alias: 'Rate of Transmitted Packets Dropped',
          unit: 'pps',
        },
      };

      local cpuUsageQuery = |||
        sum(
          node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate{%(clusterLabel)s="$cluster", namespace="$namespace"}
        * on(namespace,pod)
          group_left(workload, workload_type) mixin_pod_workload{%(clusterLabel)s="$cluster", namespace="$namespace", workload_type="$type"}
        ) by (workload, workload_type)
      ||| % $._config;

      local cpuRequestsQuery = |||
        sum(
          kube_pod_container_resource_requests_cpu_cores{%(clusterLabel)s="$cluster", namespace="$namespace"}
        * on(namespace,pod)
          group_left(workload, workload_type) mixin_pod_workload{%(clusterLabel)s="$cluster", namespace="$namespace", workload_type="$type"}
        ) by (workload, workload_type)
      ||| % $._config;

      local podCountQuery = 'count(mixin_pod_workload{%(clusterLabel)s="$cluster", namespace="$namespace", workload_type="$type"}) by (workload, workload_type)' % $._config;
      local cpuLimitsQuery = std.strReplace(cpuRequestsQuery, 'requests', 'limits');

      local memUsageQuery = |||
        sum(
            container_memory_working_set_bytes{%(clusterLabel)s="$cluster", namespace="$namespace", container!=""}
          * on(namespace,pod)
            group_left(workload, workload_type) mixin_pod_workload{%(clusterLabel)s="$cluster", namespace="$namespace", workload_type="$type"}
        ) by (workload, workload_type)
      ||| % $._config;
      local memRequestsQuery = std.strReplace(cpuRequestsQuery, 'cpu_cores', 'memory_bytes');
      local memLimitsQuery = std.strReplace(cpuLimitsQuery, 'cpu_cores', 'memory_bytes');

      g.dashboard(
        '%(dashboardNamePrefix)sCompute Resources / Namespace (Workloads)' % $._config.grafanaK8s,
        uid=($._config.grafanaDashboardIDs['k8s-resources-workloads-namespace.json']),
      ).addTemplate('cluster', 'kube_pod_info', $._config.clusterLabel, hide=if $._config.showMultiCluster then 0 else 2)
      .addTemplate('namespace', 'kube_pod_info{%(clusterLabel)s="$cluster"}' % $._config, 'namespace')
      .addRow(
        g.row('CPU Usage')
        .addPanel(
          g.panel('CPU Usage') +
          g.queryPanel(cpuUsageQuery, '{{workload}} - {{workload_type}}') +
          g.stack,
        )
      )
      .addRow(
        g.row('CPU Quota')
        .addPanel(
          g.panel('CPU Quota') +
          g.tablePanel([
            podCountQuery,
            cpuUsageQuery,
            cpuRequestsQuery,
            cpuUsageQuery + '/' + cpuRequestsQuery,
            cpuLimitsQuery,
            cpuUsageQuery + '/' + cpuLimitsQuery,
          ], tableStyles {
            'Value #A': { alias: 'Running Pods', decimals: 0 },
            'Value #B': { alias: 'CPU Usage' },
            'Value #C': { alias: 'CPU Requests' },
            'Value #D': { alias: 'CPU Requests %', unit: 'percentunit' },
            'Value #E': { alias: 'CPU Limits' },
            'Value #F': { alias: 'CPU Limits %', unit: 'percentunit' },
          })
        )
      )
      .addRow(
        g.row('Memory Usage')
        .addPanel(
          g.panel('Memory Usage') +
          g.queryPanel(memUsageQuery, '{{workload}} - {{workload_type}}') +
          g.stack +
          { yaxes: g.yaxes('bytes') },
        )
      )
      .addRow(
        g.row('Memory Quota')
        .addPanel(
          g.panel('Memory Quota') +
          g.tablePanel([
            podCountQuery,
            memUsageQuery,
            memRequestsQuery,
            memUsageQuery + '/' + memRequestsQuery,
            memLimitsQuery,
            memUsageQuery + '/' + memLimitsQuery,
          ], tableStyles {
            'Value #A': { alias: 'Running Pods', decimals: 0 },
            'Value #B': { alias: 'Memory Usage', unit: 'bytes' },
            'Value #C': { alias: 'Memory Requests', unit: 'bytes' },
            'Value #D': { alias: 'Memory Requests %', unit: 'percentunit' },
            'Value #E': { alias: 'Memory Limits', unit: 'bytes' },
            'Value #F': { alias: 'Memory Limits %', unit: 'percentunit' },
          })
        )
      )
      .addRow(
        g.row('Network')
        .addPanel(
          g.panel('Current Network Usage') +
          g.tablePanel(
            networkColumns,
            networkTableStyles
          ),
        )
      )
      .addRow(
        g.row('Network')
        .addPanel(
          g.panel('Receive Bandwidth') +
          g.queryPanel(|||
            (sum(irate(container_network_receive_bytes_total{%(clusterLabel)s="$cluster", namespace=~"$namespace"}[$interval])
            * on (namespace,pod)
            group_left(workload,workload_type) mixin_pod_workload{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace", workload=~".+", workload_type="$type"}) by (workload))
          ||| % $._config, '{{workload}}') +
          g.stack +
          { yaxes: g.yaxes('Bps') },
        )
      )
      .addRow(
        g.row('Network')
        .addPanel(
          g.panel('Transmit Bandwidth') +
          g.queryPanel(|||
            (sum(irate(container_network_transmit_bytes_total{%(clusterLabel)s="$cluster", namespace=~"$namespace"}[$interval])
            * on (namespace,pod)
            group_left(workload,workload_type) mixin_pod_workload{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace", workload=~".+", workload_type="$type"}) by (workload))
          ||| % $._config, '{{workload}}') +
          g.stack +
          { yaxes: g.yaxes('Bps') },
        )
      )
      .addRow(
        g.row('Network')
        .addPanel(
          g.panel('Average Container Bandwidth by Workload: Received') +
          g.queryPanel(|||
            (avg(irate(container_network_receive_bytes_total{%(clusterLabel)s="$cluster", namespace=~"$namespace"}[$interval])
            * on (namespace,pod)
            group_left(workload,workload_type) mixin_pod_workload{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace", workload=~".+", workload_type="$type"}) by (workload))
          ||| % $._config, '{{workload}}') +
          g.stack +
          { yaxes: g.yaxes('Bps') },
        )
      )
      .addRow(
        g.row('Network')
        .addPanel(
          g.panel('Average Container Bandwidth by Workload: Transmitted') +
          g.queryPanel(|||
            (avg(irate(container_network_transmit_bytes_total{%(clusterLabel)s="$cluster", namespace=~"$namespace"}[$interval])
            * on (namespace,pod)
            group_left(workload,workload_type) mixin_pod_workload{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace", workload=~".+", workload_type="$type"}) by (workload))
          ||| % $._config, '{{workload}}') +
          g.stack +
          { yaxes: g.yaxes('Bps') },
        )
      )
      .addRow(
        g.row('Network')
        .addPanel(
          g.panel('Rate of Received Packets') +
          g.queryPanel(|||
            (sum(irate(container_network_receive_packets_total{%(clusterLabel)s="$cluster", namespace=~"$namespace"}[$interval])
            * on (namespace,pod)
            group_left(workload,workload_type) mixin_pod_workload{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace", workload=~".+", workload_type="$type"}) by (workload))
          ||| % $._config, '{{workload}}') +
          g.stack +
          { yaxes: g.yaxes('Bps') },
        )
      )
      .addRow(
        g.row('Network')
        .addPanel(
          g.panel('Rate of Transmitted Packets') +
          g.queryPanel(|||
            (sum(irate(container_network_transmit_packets_total{%(clusterLabel)s="$cluster", namespace=~"$namespace"}[$interval])
            * on (namespace,pod)
            group_left(workload,workload_type) mixin_pod_workload{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace", workload=~".+", workload_type="$type"}) by (workload))
          ||| % $._config, '{{workload}}') +
          g.stack +
          { yaxes: g.yaxes('Bps') },
        )
      )
      .addRow(
        g.row('Network')
        .addPanel(
          g.panel('Rate of Received Packets Dropped') +
          g.queryPanel(|||
            (sum(irate(container_network_receive_packets_dropped_total{%(clusterLabel)s="$cluster", namespace=~"$namespace"}[$interval])
            * on (namespace,pod)
            group_left(workload,workload_type) mixin_pod_workload{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace", workload=~".+", workload_type="$type"}) by (workload))
          ||| % $._config, '{{workload}}') +
          g.stack +
          { yaxes: g.yaxes('Bps') },
        )
      )
      .addRow(
        g.row('Network')
        .addPanel(
          g.panel('Rate of Transmitted Packets Dropped') +
          g.queryPanel(|||
            (sum(irate(container_network_transmit_packets_dropped_total{%(clusterLabel)s="$cluster", namespace=~"$namespace"}[$interval])
            * on (namespace,pod) 
            group_left(workload,workload_type) mixin_pod_workload{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace", workload=~".+", workload_type="$type"}) by (workload))
          ||| % $._config, '{{workload}}') +
          g.stack +
          { yaxes: g.yaxes('Bps') },
        )
      ) + { tags: $._config.grafanaK8s.dashboardTags, templating+: { list+: [intervalTemplate, typeTemplate] } },

    'k8s-resources-workload.json':
      local tableStyles = {
        pod: {
          alias: 'Pod',
          link: '%(prefix)s/d/%(uid)s/k8s-resources-pod?var-datasource=$datasource&var-cluster=$cluster&var-namespace=$namespace&var-pod=$__cell' % { prefix: $._config.grafanaK8s.linkPrefix, uid: std.md5('k8s-resources-pod.json') },
        },
      };

      local networkColumns = [
        |||
          (sum(irate(container_network_receive_bytes_total{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace"}[$interval])
          * on (namespace,pod)
          group_left(workload,workload_type) mixin_pod_workload{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace", workload=~"$workload", workload_type="$type"}) by (pod))
        ||| % $._config,
        |||
          (sum(irate(container_network_transmit_bytes_total{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace"}[$interval])
          * on (namespace,pod)
          group_left(workload,workload_type) mixin_pod_workload{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace", workload=~"$workload", workload_type="$type"}) by (pod))
        ||| % $._config,
        |||
          (sum(irate(container_network_receive_packets_total{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace"}[$interval])
          * on (namespace,pod)
          group_left(workload,workload_type) mixin_pod_workload{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace", workload=~"$workload", workload_type="$type"}) by (pod))
        ||| % $._config,
        |||
          (sum(irate(container_network_transmit_packets_total{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace"}[$interval])
          * on (namespace,pod)
          group_left(workload,workload_type) mixin_pod_workload{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace", workload=~"$workload", workload_type="$type"}) by (pod))
        ||| % $._config,
        |||
          (sum(irate(container_network_receive_packets_dropped_total{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace"}[$interval])
          * on (namespace,pod)
          group_left(workload,workload_type) mixin_pod_workload{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace", workload=~"$workload", workload_type="$type"}) by (pod))
        ||| % $._config,
        |||
          (sum(irate(container_network_transmit_packets_dropped_total{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace"}[$interval])
          * on (namespace,pod)
          group_left(workload,workload_type) mixin_pod_workload{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace", workload=~"$workload", workload_type="$type"}) by (pod))
        ||| % $._config,
      ];

      local networkTableStyles = {
        pod: {
          alias: 'Pod',
          link: '%(prefix)s/d/%(uid)s/k8s-resources-pod?var-datasource=$datasource&var-cluster=$cluster&var-namespace=$namespace&var-pod=$__cell' % { prefix: $._config.grafanaK8s.linkPrefix, uid: std.md5('k8s-resources-pod.json') },
        },
        'Value #A': {
          alias: 'Current Receive Bandwidth',
          unit: 'Bps',
        },
        'Value #B': {
          alias: 'Current Transmit Bandwidth',
          unit: 'Bps',
        },
        'Value #C': {
          alias: 'Rate of Received Packets',
          unit: 'pps',
        },
        'Value #D': {
          alias: 'Rate of Transmitted Packets',
          unit: 'pps',
        },
        'Value #E': {
          alias: 'Rate of Received Packets Dropped',
          unit: 'pps',
        },
        'Value #F': {
          alias: 'Rate of Transmitted Packets Dropped',
          unit: 'pps',
        },
      };


      local cpuUsageQuery = |||
        sum(
            node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate{%(clusterLabel)s="$cluster", namespace="$namespace"}
          * on(namespace,pod)
            group_left(workload, workload_type) mixin_pod_workload{%(clusterLabel)s="$cluster", namespace="$namespace", workload="$workload", workload_type="$type"}
        ) by (pod)
      ||| % $._config;

      local cpuRequestsQuery = |||
        sum(
            kube_pod_container_resource_requests_cpu_cores{%(clusterLabel)s="$cluster", namespace="$namespace"}
          * on(namespace,pod)
            group_left(workload, workload_type) mixin_pod_workload{%(clusterLabel)s="$cluster", namespace="$namespace", workload="$workload", workload_type="$type"}
        ) by (pod)
      ||| % $._config;

      local cpuLimitsQuery = std.strReplace(cpuRequestsQuery, 'requests', 'limits');

      local memUsageQuery = |||
        sum(
            container_memory_working_set_bytes{%(clusterLabel)s="$cluster", namespace="$namespace", container!=""}
          * on(namespace,pod)
            group_left(workload, workload_type) mixin_pod_workload{%(clusterLabel)s="$cluster", namespace="$namespace", workload="$workload", workload_type="$type"}
        ) by (pod)
      ||| % $._config;
      local memRequestsQuery = std.strReplace(cpuRequestsQuery, 'cpu_cores', 'memory_bytes');
      local memLimitsQuery = std.strReplace(cpuLimitsQuery, 'cpu_cores', 'memory_bytes');

      g.dashboard(
        '%(dashboardNamePrefix)sCompute Resources / Workload' % $._config.grafanaK8s,
        uid=($._config.grafanaDashboardIDs['k8s-resources-workload.json']),
      ).addTemplate('cluster', 'kube_pod_info', $._config.clusterLabel, hide=if $._config.showMultiCluster then 0 else 2)
      .addTemplate('namespace', 'kube_pod_info{%(clusterLabel)s="$cluster"}' % $._config, 'namespace')
      .addTemplate('workload', 'mixin_pod_workload{%(clusterLabel)s="$cluster", namespace="$namespace"}' % $._config, 'workload')
      .addTemplate('type', 'mixin_pod_workload{%(clusterLabel)s="$cluster", namespace="$namespace", workload="$workload"}' % $._config, 'workload_type')
      .addRow(
        g.row('CPU Usage')
        .addPanel(
          g.panel('CPU Usage') +
          g.queryPanel(cpuUsageQuery, '{{pod}}') +
          g.stack,
        )
      )
      .addRow(
        g.row('CPU Quota')
        .addPanel(
          g.panel('CPU Quota') +
          g.tablePanel([
            cpuUsageQuery,
            cpuRequestsQuery,
            cpuUsageQuery + '/' + cpuRequestsQuery,
            cpuLimitsQuery,
            cpuUsageQuery + '/' + cpuLimitsQuery,
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
          g.queryPanel(memUsageQuery, '{{pod}}') +
          g.stack +
          { yaxes: g.yaxes('bytes') },
        )
      )
      .addRow(
        g.row('Memory Quota')
        .addPanel(
          g.panel('Memory Quota') +
          g.tablePanel([
            memUsageQuery,
            memRequestsQuery,
            memUsageQuery + '/' + memRequestsQuery,
            memLimitsQuery,
            memUsageQuery + '/' + memLimitsQuery,
          ], tableStyles {
            'Value #A': { alias: 'Memory Usage', unit: 'bytes' },
            'Value #B': { alias: 'Memory Requests', unit: 'bytes' },
            'Value #C': { alias: 'Memory Requests %', unit: 'percentunit' },
            'Value #D': { alias: 'Memory Limits', unit: 'bytes' },
            'Value #E': { alias: 'Memory Limits %', unit: 'percentunit' },
          })
        )
      )
      .addRow(
        g.row('Network')
        .addPanel(
          g.panel('Current Network Usage') +
          g.tablePanel(
            networkColumns,
            networkTableStyles
          ),
        )
      )
      .addRow(
        g.row('Network')
        .addPanel(
          g.panel('Receive Bandwidth') +
          g.queryPanel(|||
            (sum(irate(container_network_receive_bytes_total{%(clusterLabel)s="$cluster", namespace=~"$namespace"}[$interval])
            * on (namespace,pod)
            group_left(workload,workload_type) mixin_pod_workload{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace", workload=~"$workload", workload_type="$type"}) by (pod))
          ||| % $._config, '{{pod}}') +
          g.stack +
          { yaxes: g.yaxes('Bps') },
        )
      )
      .addRow(
        g.row('Network')
        .addPanel(
          g.panel('Transmit Bandwidth') +
          g.queryPanel(|||
            (sum(irate(container_network_transmit_bytes_total{%(clusterLabel)s="$cluster", namespace=~"$namespace"}[$interval])
            * on (namespace,pod)
            group_left(workload,workload_type) mixin_pod_workload{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace", workload=~"$workload", workload_type="$type"}) by (pod))
          ||| % $._config, '{{pod}}') +
          g.stack +
          { yaxes: g.yaxes('Bps') },
        )
      )
      .addRow(
        g.row('Network')
        .addPanel(
          g.panel('Average Container Bandwidth by Pod: Received') +
          g.queryPanel(|||
            (avg(irate(container_network_receive_bytes_total{%(clusterLabel)s="$cluster", namespace=~"$namespace"}[$interval])
            * on (namespace,pod)
            group_left(workload,workload_type) mixin_pod_workload{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace", workload=~"$workload", workload_type="$type"}) by (pod))
          ||| % $._config, '{{pod}}') +
          g.stack +
          { yaxes: g.yaxes('Bps') },
        )
      )
      .addRow(
        g.row('Network')
        .addPanel(
          g.panel('Average Container Bandwidth by Pod: Transmitted') +
          g.queryPanel(|||
            (avg(irate(container_network_transmit_bytes_total{%(clusterLabel)s="$cluster", namespace=~"$namespace"}[$interval])
            * on (namespace,pod)
            group_left(workload,workload_type) mixin_pod_workload{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace", workload=~"$workload", workload_type="$type"}) by (pod))
          ||| % $._config, '{{pod}}') +
          g.stack +
          { yaxes: g.yaxes('Bps') },
        )
      )
      .addRow(
        g.row('Network')
        .addPanel(
          g.panel('Rate of Received Packets') +
          g.queryPanel(|||
            (sum(irate(container_network_receive_packets_total{%(clusterLabel)s="$cluster", namespace=~"$namespace"}[$interval])
            * on (namespace,pod)
            group_left(workload,workload_type) mixin_pod_workload{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace", workload=~"$workload", workload_type="$type"}) by (pod))
          ||| % $._config, '{{pod}}') +
          g.stack +
          { yaxes: g.yaxes('Bps') },
        )
      )
      .addRow(
        g.row('Network')
        .addPanel(
          g.panel('Rate of Transmitted Packets') +
          g.queryPanel(|||
            (sum(irate(container_network_transmit_packets_total{%(clusterLabel)s="$cluster", namespace=~"$namespace"}[$interval])
            * on (namespace,pod)
            group_left(workload,workload_type) mixin_pod_workload{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace", workload=~"$workload", workload_type="$type"}) by (pod))
          ||| % $._config, '{{pod}}') +
          g.stack +
          { yaxes: g.yaxes('Bps') },
        )
      )
      .addRow(
        g.row('Network')
        .addPanel(
          g.panel('Rate of Received Packets Dropped') +
          g.queryPanel(|||
            (sum(irate(container_network_receive_packets_dropped_total{%(clusterLabel)s="$cluster", namespace=~"$namespace"}[$interval])
            * on (namespace,pod)
            group_left(workload,workload_type) mixin_pod_workload{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace", workload=~"$workload", workload_type="$type"}) by (pod))
          ||| % $._config, '{{pod}}') +
          g.stack +
          { yaxes: g.yaxes('Bps') },
        )
      )
      .addRow(
        g.row('Network')
        .addPanel(
          g.panel('Rate of Transmitted Packets Dropped') +
          g.queryPanel(|||
            (sum(irate(container_network_transmit_packets_dropped_total{%(clusterLabel)s="$cluster", namespace=~"$namespace"}[$interval])
            * on (namespace,pod) 
            group_left(workload,workload_type) mixin_pod_workload{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace", workload=~"$workload", workload_type="$type"}) by (pod))
          ||| % $._config, '{{pod}}') +
          g.stack +
          { yaxes: g.yaxes('Bps') },
        )
      ) + { tags: $._config.grafanaK8s.dashboardTags, templating+: { list+: [intervalTemplate] } },

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
          g.queryPanel('sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate{namespace="$namespace", pod="$pod", container!="POD", %(clusterLabel)s="$cluster"}) by (container)' % $._config, '{{container}}') +
          g.stack,
        )
      )
      .addRow(
        g.row('CPU Quota')
        .addPanel(
          g.panel('CPU Quota') +
          g.tablePanel([
            'sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", container!="POD"}) by (container)' % $._config,
            'sum(kube_pod_container_resource_requests_cpu_cores{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}) by (container)' % $._config,
            'sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}) by (container) / sum(kube_pod_container_resource_requests_cpu_cores{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}) by (container)' % $._config,
            'sum(kube_pod_container_resource_limits_cpu_cores{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}) by (container)' % $._config,
            'sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}) by (container) / sum(kube_pod_container_resource_limits_cpu_cores{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}) by (container)' % $._config,
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
            'sum(container_memory_rss{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", container!="POD", container!=""}) by (container)' % $._config,
            'sum(container_memory_cache{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", container!="POD", container!=""}) by (container)' % $._config,
            'sum(container_memory_swap{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", container!="POD", container!=""}) by (container)' % $._config,
          ], [
            '{{container}} (RSS)',
            '{{container}} (Cache)',
            '{{container}} (Swap)',
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
            'sum(container_memory_working_set_bytes{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", container!="POD", container!=""}) by (container)' % $._config,
            'sum(kube_pod_container_resource_requests_memory_bytes{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}) by (container)' % $._config,
            'sum(container_memory_working_set_bytes{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}) by (container) / sum(kube_pod_container_resource_requests_memory_bytes{namespace="$namespace", pod="$pod"}) by (container)' % $._config,
            'sum(kube_pod_container_resource_limits_memory_bytes{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", container!=""}) by (container)' % $._config,
            'sum(container_memory_working_set_bytes{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", container!=""}) by (container) / sum(kube_pod_container_resource_limits_memory_bytes{namespace="$namespace", pod="$pod"}) by (container)' % $._config,
            'sum(container_memory_rss{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", container != "", container != "POD"}) by (container)' % $._config,
            'sum(container_memory_cache{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", container != "", container != "POD"}) by (container)' % $._config,
            'sum(container_memory_swap{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", container != "", container != "POD"}) by (container)' % $._config,
          ], tableStyles {
            'Value #A': { alias: 'Memory Usage', unit: 'bytes' },
            'Value #B': { alias: 'Memory Requests', unit: 'bytes' },
            'Value #C': { alias: 'Memory Requests %', unit: 'percentunit' },
            'Value #D': { alias: 'Memory Limits', unit: 'bytes' },
            'Value #E': { alias: 'Memory Limits %', unit: 'percentunit' },
            'Value #F': { alias: 'Memory Usage (RSS)', unit: 'bytes' },
            'Value #G': { alias: 'Memory Usage (Cache)', unit: 'bytes' },
            'Value #H': { alias: 'Memory Usage (Swap)', unit: 'bytes' },
          })
        )
      )
      .addRow(
        g.row('Network')
        .addPanel(
          g.panel('Receive Bandwidth') +
          g.queryPanel('sum(irate(container_network_receive_bytes_total{namespace=~"$namespace", pod=~"$pod"}[$interval])) by (pod)', '{{pod}}') +
          g.stack +
          { yaxes: g.yaxes('Bps') },
        )
      )
      .addRow(
        g.row('Network')
        .addPanel(
          g.panel('Transmit Bandwidth') +
          g.queryPanel('sum(irate(container_network_transmit_bytes_total{namespace=~"$namespace", pod=~"$pod"}[$interval])) by (pod)', '{{pod}}') +
          g.stack +
          { yaxes: g.yaxes('Bps') },
        )
      )
      .addRow(
        g.row('Network')
        .addPanel(
          g.panel('Rate of Received Packets') +
          g.queryPanel('sum(irate(container_network_receive_packets_total{namespace=~"$namespace", pod=~"$pod"}[$interval])) by (pod)', '{{pod}}') +
          g.stack +
          { yaxes: g.yaxes('Bps') },
        )
      )
      .addRow(
        g.row('Network')
        .addPanel(
          g.panel('Rate of Transmitted Packets') +
          g.queryPanel('sum(irate(container_network_transmit_packets_total{namespace=~"$namespace", pod=~"$pod"}[$interval])) by (pod)', '{{pod}}') +
          g.stack +
          { yaxes: g.yaxes('Bps') },
        )
      )
      .addRow(
        g.row('Network')
        .addPanel(
          g.panel('Rate of Received Packets Dropped') +
          g.queryPanel('sum(irate(container_network_receive_packets_dropped_total{namespace=~"$namespace", pod=~"$pod"}[$interval])) by (pod)', '{{pod}}') +
          g.stack +
          { yaxes: g.yaxes('Bps') },
        )
      )
      .addRow(
        g.row('Network')
        .addPanel(
          g.panel('Rate of Transmitted Packets Dropped') +
          g.queryPanel('sum(irate(container_network_transmit_packets_dropped_total{namespace=~"$namespace", pod=~"$pod"}[$interval])) by (pod)', '{{pod}}') +
          g.stack +
          { yaxes: g.yaxes('Bps') },
        )
      ) + { tags: $._config.grafanaK8s.dashboardTags, templating+: { list+: [intervalTemplate] } },
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
          g.statPanel('sum(kube_pod_container_resource_requests_cpu_cores) / sum(kube_node_status_allocatable_cpu_cores)' % $._config)
        )
        .addPanel(
          g.panel('CPU Limits Commitment') +
          g.statPanel('sum(kube_pod_container_resource_limits_cpu_cores) / sum(kube_node_status_allocatable_cpu_cores)' % $._config)
        )
        .addPanel(
          g.panel('Memory Utilisation') +
          g.statPanel('1 - sum(:node_memory_MemAvailable_bytes:sum) / sum(kube_node_status_allocatable_memory_bytes)' % $._config)
        )
        .addPanel(
          g.panel('Memory Requests Commitment') +
          g.statPanel('sum(kube_pod_container_resource_requests_memory_bytes) / sum(kube_node_status_allocatable_memory_bytes)' % $._config)
        )
        .addPanel(
          g.panel('Memory Limits Commitment') +
          g.statPanel('sum(kube_pod_container_resource_limits_memory_bytes) / sum(kube_node_status_allocatable_memory_bytes)' % $._config)
        )
      )
      .addRow(
        g.row('CPU')
        .addPanel(
          g.panel('CPU Usage') +
          g.queryPanel('sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate) by (%(clusterLabel)s)' % $._config, '{{%(clusterLabel)s}}' % $._config)
          + { fill: 0, linewidth: 2 },
        )
      )
      .addRow(
        g.row('CPU Quota')
        .addPanel(
          g.panel('CPU Quota') +
          g.tablePanel([
            'sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate) by (%(clusterLabel)s)' % $._config,
            'sum(kube_pod_container_resource_requests_cpu_cores) by (%(clusterLabel)s)' % $._config,
            'sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate) by (%(clusterLabel)s) / sum(kube_pod_container_resource_requests_cpu_cores) by (%(clusterLabel)s)' % $._config,
            'sum(kube_pod_container_resource_limits_cpu_cores) by (%(clusterLabel)s)' % $._config,
            'sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate) by (%(clusterLabel)s) / sum(kube_pod_container_resource_limits_cpu_cores) by (%(clusterLabel)s)' % $._config,
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
          g.queryPanel('sum(container_memory_rss{container!=""}) by (%(clusterLabel)s)' % $._config, '{{%(clusterLabel)s}}' % $._config) +
          { fill: 0, linewidth: 2, yaxes: g.yaxes('bytes') },
        )
      )
      .addRow(
        g.row('Memory Requests')
        .addPanel(
          g.panel('Requests by Namespace') +
          g.tablePanel([
            // Not using container_memory_usage_bytes here because that includes page cache
            'sum(container_memory_rss{container!=""}) by (%(clusterLabel)s)' % $._config,
            'sum(kube_pod_container_resource_requests_memory_bytes) by (%(clusterLabel)s)' % $._config,
            'sum(container_memory_rss{container!=""}) by (%(clusterLabel)s) / sum(kube_pod_container_resource_requests_memory_bytes) by (%(clusterLabel)s)' % $._config,
            'sum(kube_pod_container_resource_limits_memory_bytes) by (%(clusterLabel)s)' % $._config,
            'sum(container_memory_rss{container!=""}) by (%(clusterLabel)s) / sum(kube_pod_container_resource_limits_memory_bytes) by (%(clusterLabel)s)' % $._config,
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
