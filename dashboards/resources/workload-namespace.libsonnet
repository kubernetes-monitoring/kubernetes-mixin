local g = import 'grafana-builder/grafana.libsonnet';
local grafana = import 'grafonnet/grafana.libsonnet';
local template = grafana.template;

{
  grafanaDashboards+:: {
    local intervalTemplate =
      template.new(
        name='interval',
        datasource='$datasource',
        query='$__interval',
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
            text: '$__interval',
            value: '$__interval',
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

      local cpuQuotaRequestsQuery = 'scalar(kube_resourcequota{%(clusterLabel)s="$cluster", namespace="$namespace", type="hard",resource="requests.cpu"})' % $._config;
      local cpuQuotaLimitsQuery = std.strReplace(cpuQuotaRequestsQuery, 'requests.cpu', 'limits.cpu');
      local memoryQuotaRequestsQuery = std.strReplace(cpuQuotaRequestsQuery, 'requests.cpu', 'requests.memory');
      local memoryQuotaLimitsQuery = std.strReplace(cpuQuotaRequestsQuery, 'requests.cpu', 'limits.memory');

      g.dashboard(
        '%(dashboardNamePrefix)sCompute Resources / Namespace (Workloads)' % $._config.grafanaK8s,
        uid=($._config.grafanaDashboardIDs['k8s-resources-workloads-namespace.json']),
      )
      .addRow(
        g.row('CPU Usage')
        .addPanel(
          g.panel('CPU Usage') +
          g.queryPanel([cpuUsageQuery, cpuQuotaRequestsQuery, cpuQuotaLimitsQuery], ['{{workload}} - {{workload_type}}', 'quota - requests', 'quota - limits']) +
          g.stack + {
            seriesOverrides: [
              {
                alias: 'quota - requests',
                color: '#F2495C',
                dashes: true,
                fill: 0,
                hideTooltip: true,
                legend: false,
                linewidth: 2,
                stack: false,
              },
              {
                alias: 'quota - limits',
                color: '#FF9830',
                dashes: true,
                fill: 0,
                hideTooltip: true,
                legend: false,
                linewidth: 2,
                stack: false,
              },
            ],
          },
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
          g.queryPanel([memUsageQuery, memoryQuotaRequestsQuery, memoryQuotaLimitsQuery], ['{{workload}} - {{workload_type}}', 'quota - requests', 'quota - limits']) +
          g.stack +
          {
            yaxes: g.yaxes('bytes'),
            seriesOverrides: [
              {
                alias: 'quota - requests',
                color: '#F2495C',
                dashes: true,
                fill: 0,
                hideTooltip: true,
                legend: false,
                linewidth: 2,
                stack: false,
              },
              {
                alias: 'quota - limits',
                color: '#FF9830',
                dashes: true,
                fill: 0,
                hideTooltip: true,
                legend: false,
                linewidth: 2,
                stack: false,
              },
            ],
          },
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
      ) + { tags: $._config.grafanaK8s.dashboardTags, templating+: { list+: [intervalTemplate, typeTemplate, clusterTemplate, namespaceTemplate] }, refresh: $._config.grafanaK8s.refresh },

  },
}
