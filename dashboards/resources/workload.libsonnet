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

    local clusterTemplate =
      template.new(
        name='cluster',
        datasource='$datasource',
        query='label_values(kube_pod_info, %s)' % $._config.clusterLabel,
        current='',
        hide=if $._config.showMultiCluster then '' else '2',
        refresh=1,
        includeAll=false,
        sort=1
      ),

    local namespaceTemplate =
      template.new(
        name='namespace',
        datasource='$datasource',
        query='label_values(kube_pod_info{%(clusterLabel)s="$cluster"}, namespace)' % $._config.clusterLabel,
        current='',
        hide='',
        refresh=1,
        includeAll=false,
        sort=1
      ),

    local workloadTemplate =
      template.new(
        name='workload',
        datasource='$datasource',
        query='label_values(mixin_pod_workload{%(clusterLabel)s="$cluster", namespace="$namespace"}, workload)' % $._config.clusterLabel,
        current='',
        hide=if $._config.showMultiCluster then '' else '2',
        refresh=1,
        includeAll=false,
        sort=1
      ),

    local workloadTypeTemplate =
      template.new(
        name='type',
        datasource='$datasource',
        query='label_values(mixin_pod_workload{%(clusterLabel)s="$cluster", namespace="$namespace", workload="$workload"}, workload_type)' % $._config.clusterLabel,
        current='',
        hide='',
        refresh=1,
        includeAll=false,
        sort=1
      ),
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
      )
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
      ) + { tags: $._config.grafanaK8s.dashboardTags, templating+: { list+: [intervalTemplate, clusterTemplate, namespaceTemplate, workloadTemplate, workloadTypeTemplate] }, refresh: $._config.grafanaK8s.refresh },
  },
}
