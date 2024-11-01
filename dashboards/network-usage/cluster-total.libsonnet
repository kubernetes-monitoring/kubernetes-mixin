local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local prometheus = g.query.prometheus;
local table = g.panel.table;
local timeSeries = g.panel.timeSeries;
local var = g.dashboard.variable;

{
  local tsPanel =
    timeSeries {
      new(title):
        timeSeries.new(title)
        + timeSeries.options.legend.withShowLegend()
        + timeSeries.options.legend.withAsTable()
        + timeSeries.options.legend.withDisplayMode('table')
        + timeSeries.options.legend.withPlacement('right')
        + timeSeries.options.tooltip.withMode('single')
        + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
        + timeSeries.queryOptions.withInterval($._config.grafanaK8s.minimumTimeInterval),
    },

  grafanaDashboards+:: {
    'cluster-total.json':
      local variables = {
        datasource:
          var.datasource.new('datasource', 'prometheus')
          + var.datasource.withRegex($._config.datasourceFilterRegex)
          + var.datasource.generalOptions.showOnDashboard.withLabelAndValue()
          + var.datasource.generalOptions.withLabel('Data source')
          + {
            current: {
              selected: true,
              text: $._config.datasourceName,
              value: $._config.datasourceName,
            },
          },

        cluster:
          var.query.new('cluster')
          + var.query.withDatasourceFromVariable(self.datasource)
          + var.query.queryTypes.withLabelValues(
            $._config.clusterLabel,
            'up{%(cadvisorSelector)s}' % $._config,
          )
          + var.query.generalOptions.withLabel('cluster')
          + var.query.refresh.onTime()
          + (
            if $._config.showMultiCluster
            then var.query.generalOptions.showOnDashboard.withLabelAndValue()
            else var.query.generalOptions.showOnDashboard.withNothing()
          )
          + var.query.withSort(type='alphabetical'),
      };

      local links = {
        namespace: {
          title: 'Drill down',
          url: '%(prefix)s/d/%(uid)s/kubernetes-networking-namespace-pods?${datasource:queryparam}&var-cluster=${cluster}&var-namespace=${__data.fields.Namespace}' % {
            uid: $._config.grafanaDashboardIDs['namespace-by-pod.json'],
            prefix: $._config.grafanaK8s.linkPrefix,
          },
        },
      };

      local panels = [
        tsPanel.new('Current Rate of Bytes Received')
        + tsPanel.standardOptions.withUnit('binBps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}', |||
              sum by (namespace) (
                  rate(container_network_receive_bytes_total{%(clusterLabel)s="$cluster",namespace!=""}[%(grafanaIntervalVar)s])
                * on (%(clusterLabel)s,namespace,pod) group_left ()
                  topk by (%(clusterLabel)s,namespace,pod) (
                    1,
                    max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false"})
                  )
              )
            ||| % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Current Rate of Bytes Transmitted')
        + tsPanel.standardOptions.withUnit('binBps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}', |||
              sum by (namespace) (
                  rate(container_network_transmit_bytes_total{%(clusterLabel)s="$cluster",namespace!=""}[%(grafanaIntervalVar)s])
                * on (%(clusterLabel)s,namespace,pod) group_left ()
                  topk by (%(clusterLabel)s,namespace,pod) (
                    1,
                    max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false"})
                  )
              )
            ||| % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        table.new('Current Status')
        + table.gridPos.withW(24)
        + table.queryOptions.withTargets([
          prometheus.new('${datasource}', |||
            sum by (namespace) (
                rate(container_network_receive_bytes_total{%(clusterLabel)s="$cluster",namespace!=""}[%(grafanaIntervalVar)s])
              * on (%(clusterLabel)s,namespace,pod) group_left ()
                topk by (%(clusterLabel)s,namespace,pod) (
                  1,
                  max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false"})
                )
            )
          ||| % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', |||
            sum by (namespace) (
                rate(container_network_transmit_bytes_total{%(clusterLabel)s="$cluster",namespace!=""}[%(grafanaIntervalVar)s])
              * on (%(clusterLabel)s,namespace,pod) group_left ()
                topk by (%(clusterLabel)s,namespace,pod) (
                  1,
                  max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false"})
                )
            )
          ||| % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', |||
            avg by (namespace) (
                rate(container_network_receive_bytes_total{%(clusterLabel)s="$cluster",namespace!=""}[%(grafanaIntervalVar)s])
              * on (%(clusterLabel)s,namespace,pod) group_left ()
                topk by (%(clusterLabel)s,namespace,pod) (
                  1,
                  max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false"})
                )
            )
          ||| % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', |||
            avg by (namespace) (
                rate(container_network_transmit_bytes_total{%(clusterLabel)s="$cluster",namespace!=""}[%(grafanaIntervalVar)s])
              * on (%(clusterLabel)s,namespace,pod) group_left ()
                topk by (%(clusterLabel)s,namespace,pod) (
                  1,
                  max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false"})
                )
            )
          ||| % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', |||
            sum by (namespace) (
                rate(container_network_receive_packets_total{%(clusterLabel)s="$cluster",namespace!=""}[%(grafanaIntervalVar)s])
              * on (%(clusterLabel)s,namespace,pod) group_left ()
                topk by (%(clusterLabel)s,namespace,pod) (
                  1,
                  max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false"})
                )
            )
          ||| % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', |||
            sum by (namespace) (
                rate(container_network_transmit_packets_total{%(clusterLabel)s="$cluster",namespace!=""}[%(grafanaIntervalVar)s])
              * on (%(clusterLabel)s,namespace,pod) group_left ()
                topk by (%(clusterLabel)s,namespace,pod) (
                  1,
                  max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false"})
                )
            )
          ||| % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', |||
            sum by (namespace) (
                rate(container_network_receive_packets_dropped_total{%(clusterLabel)s="$cluster",namespace!=""}[%(grafanaIntervalVar)s])
              * on (%(clusterLabel)s,namespace,pod) group_left ()
                topk by (%(clusterLabel)s,namespace,pod) (
                  1,
                  max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false"})
                )
            )
          ||| % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', |||
            sum by (namespace) (
                rate(container_network_transmit_packets_dropped_total{%(clusterLabel)s="$cluster",namespace!=""}[%(grafanaIntervalVar)s])
              * on (%(clusterLabel)s,namespace,pod) group_left ()
                topk by (%(clusterLabel)s,namespace,pod) (
                  1,
                  max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false"})
                )
            )
          ||| % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
        ])
        + table.queryOptions.withTransformations([
          table.queryOptions.transformation.withId('joinByField')
          + table.queryOptions.transformation.withOptions({
            byField: 'namespace',
            mode: 'outer',
          }),

          g.panel.table.queryOptions.transformation.withId('organize')
          + g.panel.table.queryOptions.transformation.withOptions({
            excludeByName: {
              Time: true,
              'Time 1': true,
              'Time 2': true,
              'Time 3': true,
              'Time 4': true,
              'Time 5': true,
              'Time 6': true,
              'Time 7': true,
              'Time 8': true,
            },
            indexByName: {
              'Time 1': 0,
              'Time 2': 1,
              'Time 3': 2,
              'Time 4': 3,
              'Time 5': 4,
              'Time 6': 5,
              'Time 7': 6,
              'Time 8': 7,
              namespace: 8,
              'Value #A': 9,
              'Value #B': 10,
              'Value #C': 11,
              'Value #D': 12,
              'Value #E': 13,
              'Value #F': 14,
              'Value #G': 15,
              'Value #H': 16,
            },
            renameByName: {
              namespace: 'Namespace',
              'Value #A': 'Rx Bytes',
              'Value #B': 'Tx Bytes',
              'Value #C': 'Rx Bytes (Avg)',
              'Value #D': 'Tx Bytes (Avg)',
              'Value #E': 'Rx Packets',
              'Value #F': 'Tx Packets',
              'Value #G': 'Rx Packets Dropped',
              'Value #H': 'Tx Packets Dropped',
            },
          }),
        ])

        + table.standardOptions.withOverrides([
          {
            matcher: {
              id: 'byRegexp',
              options: '/Bytes/',
            },
            properties: [
              {
                id: 'unit',
                value: 'binBps',
              },
            ],
          },
          {
            matcher: {
              id: 'byRegexp',
              options: '/Packets/',
            },
            properties: [
              {
                id: 'unit',
                value: 'pps',
              },
            ],
          },
          {
            matcher: {
              id: 'byName',
              options: 'Namespace',
            },
            properties: [
              {
                id: 'links',
                value: [links.namespace],
              },
            ],
          },
        ]),

        tsPanel.new('Average Rate of Bytes Received')
        + tsPanel.standardOptions.withUnit('binBps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}', |||
              avg by (namespace) (
                  rate(container_network_receive_bytes_total{%(clusterLabel)s="$cluster",namespace!=""}[%(grafanaIntervalVar)s])
                * on (%(clusterLabel)s,namespace,pod) group_left ()
                  topk by (%(clusterLabel)s,namespace,pod) (
                    1,
                    max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false"})
                  )
              )
            ||| % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Average Rate of Bytes Transmitted')
        + tsPanel.standardOptions.withUnit('binBps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}', |||
              avg by (namespace) (
                  rate(container_network_transmit_bytes_total{%(clusterLabel)s="$cluster",namespace!=""}[%(grafanaIntervalVar)s])
                * on (%(clusterLabel)s,namespace,pod) group_left ()
                  topk by (%(clusterLabel)s,namespace,pod) (
                    1,
                    max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false"})
                  )
              )
            ||| % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Receive Bandwidth')
        + tsPanel.standardOptions.withUnit('binBps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}', |||
              sum by (namespace) (
                  rate(container_network_receive_bytes_total{%(clusterLabel)s="$cluster",namespace!=""}[%(grafanaIntervalVar)s])
                * on (%(clusterLabel)s,namespace,pod) group_left ()
                  topk by (%(clusterLabel)s,namespace,pod) (
                    1,
                    max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false"})
                  )
              )
            ||| % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Transmit Bandwidth')
        + tsPanel.standardOptions.withUnit('binBps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}', |||
              sum by (namespace) (
                  rate(container_network_transmit_bytes_total{%(clusterLabel)s="$cluster",namespace!=""}[%(grafanaIntervalVar)s])
                * on (%(clusterLabel)s,namespace,pod) group_left ()
                  topk by (%(clusterLabel)s,namespace,pod) (
                    1,
                    max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false"})
                  )
              )
            ||| % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of Received Packets')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new('${datasource}', |||
            sum by (namespace) (
                rate(container_network_receive_packets_total{%(clusterLabel)s="$cluster",namespace!=""}[%(grafanaIntervalVar)s])
              * on (%(clusterLabel)s,namespace,pod) group_left ()
                topk by (%(clusterLabel)s,namespace,pod) (
                  1,
                  max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false"})
                )
            )
          ||| % $._config)
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of Transmitted Packets')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new('${datasource}', |||
            sum by (namespace) (
                rate(container_network_transmit_packets_total{%(clusterLabel)s="$cluster",namespace!=""}[%(grafanaIntervalVar)s])
              * on (%(clusterLabel)s,namespace,pod) group_left ()
                topk by (%(clusterLabel)s,namespace,pod) (
                  1,
                  max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false"})
                )
            )
          ||| % $._config)
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of Received Packets Dropped')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new('${datasource}', |||
            sum by (namespace) (
                rate(container_network_receive_packets_dropped_total{%(clusterLabel)s="$cluster",namespace!=""}[%(grafanaIntervalVar)s])
              * on (%(clusterLabel)s,namespace,pod) group_left ()
                topk by (%(clusterLabel)s,namespace,pod) (
                  1,
                  max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false"})
                )
            )
          ||| % $._config)
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of Transmitted Packets Dropped')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new('${datasource}', |||
            sum by (namespace) (
                rate(container_network_transmit_packets_dropped_total{%(clusterLabel)s="$cluster",namespace!=""}[%(grafanaIntervalVar)s])
              * on (%(clusterLabel)s,namespace,pod) group_left ()
                topk by (%(clusterLabel)s,namespace,pod) (
                  1,
                  max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false"})
                )
            )
          ||| % $._config)
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of TCP Retransmits out of all sent segments')
        + tsPanel.standardOptions.withUnit('percentunit')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}', |||
              sum by (instance) (
                  rate(node_netstat_Tcp_RetransSegs{%(clusterLabel)s="$cluster"}[%(grafanaIntervalVar)s]) / rate(node_netstat_Tcp_OutSegs{%(clusterLabel)s="$cluster"}[%(grafanaIntervalVar)s])
                * on (%(clusterLabel)s,namespace,pod) group_left ()
                  topk by (%(clusterLabel)s,namespace,pod) (
                    1,
                    max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false"})
                  )
              )
            ||| % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of TCP SYN Retransmits out of all retransmits')
        + tsPanel.standardOptions.withUnit('percentunit')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}', |||
              sum by (instance) (
                  rate(node_netstat_TcpExt_TCPSynRetrans{%(clusterLabel)s="$cluster"}[%(grafanaIntervalVar)s]) / rate(node_netstat_Tcp_RetransSegs{%(clusterLabel)s="$cluster"}[%(grafanaIntervalVar)s])
                * on (%(clusterLabel)s,namespace,pod) group_left ()
                  topk by (%(clusterLabel)s,namespace,pod) (
                    1,
                    max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false"})
                  )
              )
            ||| % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),
      ];

      g.dashboard.new('%(dashboardNamePrefix)sNetworking / Cluster' % $._config.grafanaK8s)
      + g.dashboard.withUid($._config.grafanaDashboardIDs['cluster-total.json'])
      + g.dashboard.withTags($._config.grafanaK8s.dashboardTags)
      + g.dashboard.withEditable(false)
      + g.dashboard.time.withFrom('now-1h')
      + g.dashboard.time.withTo('now')
      + g.dashboard.withRefresh($._config.grafanaK8s.refresh)
      + g.dashboard.withVariables([variables.datasource, variables.cluster])
      + g.dashboard.withPanels(g.util.grid.wrapPanels(panels, panelWidth=12, panelHeight=9)),
  },
}
