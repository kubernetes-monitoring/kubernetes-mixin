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
    }
}