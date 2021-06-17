local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local g = import 'github.com/grafana/jsonnet-libs/grafana-builder/grafana.libsonnet';
local template = grafana.template;

{
  local kubernetesMixin = self,

  grafanaDashboards+:: {
    local clusterTemplate =
      template.new(
        name='cluster',
        datasource='$datasource',
        query='label_values(kube_pod_info, %s)' % kubernetesMixin._config.clusterLabel,
        current='',
        hide=if kubernetesMixin._config.showMultiCluster then '' else '2',
        refresh=2,
        includeAll=false,
        sort=1
      ),

    local namespaceTemplate =
      template.new(
        name='namespace',
        datasource='$datasource',
        query='label_values(kube_pod_info{%(clusterLabel)s="$cluster"}, namespace)' % kubernetesMixin._config.clusterLabel,
        current='',
        hide='',
        refresh=2,
        includeAll=false,
        sort=1
      ),

    local podTemplate =
      template.new(
        name='pod',
        datasource='$datasource',
        query='label_values(kube_pod_info{%(clusterLabel)s="$cluster", namespace="$namespace"}, pod)' % kubernetesMixin._config.clusterLabel,
        current='',
        hide='',
        refresh=2,
        includeAll=false,
        sort=1
      ),

    'k8s-resources-pod.json':
      local tableStyles = {
        container: {
          alias: 'Container',
        },
      };

      local cpuRequestsQuery = |||
        sum(
            kube_pod_container_resource_requests{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", resource="cpu"}
        )
      ||| % kubernetesMixin._config;

      local cpuLimitsQuery = std.strReplace(cpuRequestsQuery, 'requests', 'limits');
      local memRequestsQuery = std.strReplace(cpuRequestsQuery, 'cpu', 'memory');
      local memLimitsQuery = std.strReplace(cpuLimitsQuery, 'cpu', 'memory');

      local storageIOColumns = [
        'sum by(container) (rate(container_fs_reads_total{container!="", %(clusterLabel)s="$cluster",namespace=~"$namespace", pod="$pod"}[5m]))' % kubernetesMixin._config,
        'sum by(container) (rate(container_fs_writes_total{container!="", %(clusterLabel)s="$cluster",namespace=~"$namespace", pod="$pod"}[5m]))' % kubernetesMixin._config,
        'sum by(container) (rate(container_fs_reads_total{container!="", %(clusterLabel)s="$cluster",namespace=~"$namespace", pod="$pod"}[5m]) + rate(container_fs_writes_total{container!="", %(clusterLabel)s="$cluster",namespace=~"$namespace", pod="$pod"}[5m]))' % kubernetesMixin._config,
        'sum by(container) (rate(container_fs_reads_bytes_total{container!="", %(clusterLabel)s="$cluster",namespace=~"$namespace", pod="$pod"}[5m]))' % kubernetesMixin._config,
        'sum by(container) (rate(container_fs_writes_bytes_total{container!="", %(clusterLabel)s="$cluster",namespace=~"$namespace", pod="$pod"}[5m]))' % kubernetesMixin._config,
        'sum by(container) (rate(container_fs_reads_bytes_total{container!="", %(clusterLabel)s="$cluster",namespace=~"$namespace", pod="$pod"}[5m]) + rate(container_fs_writes_bytes_total{container!="", %(clusterLabel)s="$cluster",namespace=~"$namespace", pod="$pod"}[5m]))' % kubernetesMixin._config,
      ];

      local storageIOTableStyles = {
        container: {
          alias: 'Container',
        },
        'Value #A': {
          alias: 'IOPS(Reads)',
          unit: 'short',
          decimals: -1,
        },
        'Value #B': {
          alias: 'IOPS(Writes)',
          unit: 'short',
          decimals: -1,
        },
        'Value #C': {
          alias: 'IOPS(Reads + Writes)',
          unit: 'short',
          decimals: -1,
        },
        'Value #D': {
          alias: 'Throughput(Read)',
          unit: 'Bps',
        },
        'Value #E': {
          alias: 'Throughput(Write)',
          unit: 'Bps',
        },
        'Value #F': {
          alias: 'Throughput(Read + Write)',
          unit: 'Bps',
        },
      };

      g.dashboard(
        '%(dashboardNamePrefix)sCompute Resources / Pod' % kubernetesMixin._config.grafanaK8s,
        uid=(kubernetesMixin._config.grafanaDashboardIDs['k8s-resources-pod.json']),
      )
      .addRow(
        g.row('CPU Usage')
        .addPanel(
          g.panel('CPU Usage') +
          g.queryPanel(
            [
              'sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_irate{namespace="$namespace", pod="$pod", %(clusterLabel)s="$cluster"}) by (container)' % kubernetesMixin._config,
              cpuRequestsQuery,
              cpuLimitsQuery,
            ], [
              '{{container}}',
              'requests',
              'limits',
            ],
          ) +
          g.stack + {
            seriesOverrides: [
              {
                alias: 'requests',
                color: '#F2495C',
                fill: 0,
                hideTooltip: true,
                legend: true,
                linewidth: 2,
                stack: false,
              },
              {
                alias: 'limits',
                color: '#FF9830',
                fill: 0,
                hideTooltip: true,
                legend: true,
                linewidth: 2,
                stack: false,
              },
            ],
          },
        )
      )
      .addRow(
        g.row('CPU Throttling')
        .addPanel(
          g.panel('CPU Throttling') +
          g.queryPanel('sum(increase(container_cpu_cfs_throttled_periods_total{namespace="$namespace", pod="$pod", container!="", %(clusterLabel)s="$cluster"}[5m])) by (container) /sum(increase(container_cpu_cfs_periods_total{namespace="$namespace", pod="$pod", container!="", %(clusterLabel)s="$cluster"}[5m])) by (container)' % kubernetesMixin._config, '{{container}}') +
          g.stack
          + {
            yaxes: g.yaxes({ format: 'percentunit', max: 1 }),
            legend+: {
              current: true,
              max: true,
            },
            thresholds: [
              {
                value: kubernetesMixin._config.cpuThrottlingPercent / 100,
                colorMode: 'critical',
                op: 'gt',
                fill: true,
                line: true,
                yaxis: 'left',
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
            'sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_irate{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}) by (container)' % kubernetesMixin._config,
            'sum(kube_pod_container_resource_requests{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", resource="cpu"}) by (container)' % kubernetesMixin._config,
            'sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_irate{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}) by (container) / sum(kube_pod_container_resource_requests{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", resource="cpu"}) by (container)' % kubernetesMixin._config,
            'sum(kube_pod_container_resource_limits{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", resource="cpu"}) by (container)' % kubernetesMixin._config,
            'sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_irate{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}) by (container) / sum(kube_pod_container_resource_limits{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", resource="cpu"}) by (container)' % kubernetesMixin._config,
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
          g.panel('Memory Usage (WSS)') +
          g.queryPanel([
            'sum(container_memory_working_set_bytes{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", container!="", image!=""}) by (container)' % kubernetesMixin._config,
            memRequestsQuery,
            memLimitsQuery,
          ], [
            '{{container}}',
            'requests',
            'limits',
          ]) +
          g.stack +
          {
            yaxes: g.yaxes('bytes'),
            seriesOverrides: [
              {
                alias: 'requests',
                color: '#F2495C',
                dashes: true,
                fill: 0,
                hideTooltip: true,
                legend: true,
                linewidth: 2,
                stack: false,
              },
              {
                alias: 'limits',
                color: '#FF9830',
                dashes: true,
                fill: 0,
                hideTooltip: true,
                legend: true,
                linewidth: 2,
                stack: false,
              },
            ],
          }
        )
      )
      .addRow(
        g.row('Memory Quota')
        .addPanel(
          g.panel('Memory Quota') +
          g.tablePanel([
            'sum(container_memory_working_set_bytes{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", container!="", image!=""}) by (container)' % kubernetesMixin._config,
            'sum(kube_pod_container_resource_requests{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", resource="memory"}) by (container)' % kubernetesMixin._config,
            'sum(container_memory_working_set_bytes{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", image!=""}) by (container) / sum(kube_pod_container_resource_requests{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", resource="memory"}) by (container)' % kubernetesMixin._config,
            'sum(kube_pod_container_resource_limits{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", resource="memory"}) by (container)' % kubernetesMixin._config,
            'sum(container_memory_working_set_bytes{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", container!="", image!=""}) by (container) / sum(kube_pod_container_resource_limits{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", resource="memory"}) by (container)' % kubernetesMixin._config,
            'sum(container_memory_rss{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", container != "", container != "POD"}) by (container)' % kubernetesMixin._config,
            'sum(container_memory_cache{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", container != "", container != "POD"}) by (container)' % kubernetesMixin._config,
            'sum(container_memory_swap{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", container != "", container != "POD"}) by (container)' % kubernetesMixin._config,
          ], tableStyles {
            'Value #A': { alias: 'Memory Usage (WSS)', unit: 'bytes' },
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
        g.row('Bandwidth')
        .addPanel(
          g.panel('Receive Bandwidth') +
          g.queryPanel('sum(irate(container_network_receive_bytes_total{%(clusterLabel)s="$cluster", namespace=~"$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s])) by (pod)' % kubernetesMixin._config, '{{pod}}') +
          g.stack +
          { yaxes: g.yaxes('Bps'), interval: kubernetesMixin._config.grafanaK8s.minimumTimeInterval },
        )
        .addPanel(
          g.panel('Transmit Bandwidth') +
          g.queryPanel('sum(irate(container_network_transmit_bytes_total{%(clusterLabel)s="$cluster", namespace=~"$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s])) by (pod)' % kubernetesMixin._config, '{{pod}}') +
          g.stack +
          { yaxes: g.yaxes('Bps'), interval: kubernetesMixin._config.grafanaK8s.minimumTimeInterval },
        )
      )
      .addRow(
        g.row('Rate of Packets')
        .addPanel(
          g.panel('Rate of Received Packets') +
          g.queryPanel('sum(irate(container_network_receive_packets_total{%(clusterLabel)s="$cluster", namespace=~"$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s])) by (pod)' % kubernetesMixin._config, '{{pod}}') +
          g.stack +
          { yaxes: g.yaxes('Bps'), interval: kubernetesMixin._config.grafanaK8s.minimumTimeInterval },
        )
        .addPanel(
          g.panel('Rate of Transmitted Packets') +
          g.queryPanel('sum(irate(container_network_transmit_packets_total{%(clusterLabel)s="$cluster", namespace=~"$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s])) by (pod)' % kubernetesMixin._config, '{{pod}}') +
          g.stack +
          { yaxes: g.yaxes('Bps'), interval: kubernetesMixin._config.grafanaK8s.minimumTimeInterval },
        )
      )
      .addRow(
        g.row('Rate of Packets Dropped')
        .addPanel(
          g.panel('Rate of Received Packets Dropped') +
          g.queryPanel('sum(irate(container_network_receive_packets_dropped_total{%(clusterLabel)s="$cluster", namespace=~"$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s])) by (pod)' % kubernetesMixin._config, '{{pod}}') +
          g.stack +
          { yaxes: g.yaxes('Bps'), interval: kubernetesMixin._config.grafanaK8s.minimumTimeInterval },
        )
        .addPanel(
          g.panel('Rate of Transmitted Packets Dropped') +
          g.queryPanel('sum(irate(container_network_transmit_packets_dropped_total{%(clusterLabel)s="$cluster", namespace=~"$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s])) by (pod)' % kubernetesMixin._config, '{{pod}}') +
          g.stack +
          { yaxes: g.yaxes('Bps'), interval: kubernetesMixin._config.grafanaK8s.minimumTimeInterval },
        )
      )
      .addRow(
        g.row('Storage IO - Distribution(Pod - Read & Writes)')
        .addPanel(
          g.panel('IOPS') +
          g.queryPanel(['ceil(sum by(pod) (rate(container_fs_reads_total{container!="", %(clusterLabel)s="$cluster",namespace=~"$namespace", pod=~"$pod"}[5m])))' % kubernetesMixin._config, 'ceil(sum by(pod) (rate(container_fs_writes_total{container!="", %(clusterLabel)s="$cluster",namespace=~"$namespace", pod=~"$pod"}[5m])))' % kubernetesMixin._config], ['Reads', 'Writes']) +
          g.stack +
          { yaxes: g.yaxes('short'), decimals: -1 },
        )
        .addPanel(
          g.panel('ThroughPut') +
          g.queryPanel(['sum by(pod) (rate(container_fs_reads_bytes_total{container!="", %(clusterLabel)s="$cluster",namespace=~"$namespace", pod=~"$pod"}[5m]))' % kubernetesMixin._config, 'sum by(pod) (rate(container_fs_writes_bytes_total{container!="", %(clusterLabel)s="$cluster",namespace=~"$namespace", pod=~"$pod"}[5m]))' % kubernetesMixin._config], ['Reads', 'Writes']) +
          g.stack +
          { yaxes: g.yaxes('Bps') },
        )
      )
      .addRow(
        g.row('Storage IO - Distribution(Containers)')
        .addPanel(
          g.panel('IOPS(Reads+Writes)') +
          g.queryPanel('ceil(sum by(container) (rate(container_fs_reads_total{container!="", %(clusterLabel)s="$cluster",namespace=~"$namespace", pod="$pod"}[5m]) + rate(container_fs_writes_total{container!="", %(clusterLabel)s="$cluster",namespace=~"$namespace", pod="$pod"}[5m])))' % kubernetesMixin._config, '{{container}}') +
          g.stack +
          { yaxes: g.yaxes('short'), decimals: -1 },
        )
        .addPanel(
          g.panel('ThroughPut(Read+Write)') +
          g.queryPanel('sum by(container) (rate(container_fs_reads_bytes_total{container!="", %(clusterLabel)s="$cluster",namespace=~"$namespace", pod="$pod"}[5m]) + rate(container_fs_writes_bytes_total{container!="", %(clusterLabel)s="$cluster",namespace=~"$namespace", pod="$pod"}[5m]))' % kubernetesMixin._config, '{{container}}') +
          g.stack +
          { yaxes: g.yaxes('Bps') },
        )
      )
      .addRow(
        g.row('Storage IO - Distribution')
        .addPanel(
          g.panel('Current Storage IO') +
          g.tablePanel(
            storageIOColumns,
            storageIOTableStyles
          ) +
          {
            sort: {
              col: 4,
              desc: true,
            },
          },
        )
      ) + { tags: kubernetesMixin._config.grafanaK8s.dashboardTags, templating+: { list+: [clusterTemplate, namespaceTemplate, podTemplate] }, refresh: kubernetesMixin._config.grafanaK8s.refresh },
  },
}
