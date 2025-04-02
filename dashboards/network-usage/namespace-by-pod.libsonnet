local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local gauge = g.panel.gauge;
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
    'namespace-by-pod.json':
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

        namespace:
          var.query.new('namespace')
          + var.query.selectionOptions.withIncludeAll(true, '.+')
          + var.query.withDatasourceFromVariable(self.datasource)
          + var.query.queryTypes.withLabelValues(
            'namespace',
            'container_network_receive_packets_total{%(clusterLabel)s="$cluster"}' % $._config,
          )
          + var.query.generalOptions.withCurrent('kube-system')
          + var.query.generalOptions.withLabel('namespace')
          + var.query.refresh.onTime()
          + var.query.generalOptions.showOnDashboard.withLabelAndValue()
          + var.query.withSort(type='alphabetical'),

      };

      local links = {
        pod: {
          title: 'Drill down',
          url: '%(prefix)s/d/%(uid)s/kubernetes-networking-pod?${datasource:queryparam}&var-cluster=${cluster}&var-namespace=${namespace}&var-pod=${__data.fields.Pod}' % {
            uid: $._config.grafanaDashboardIDs['pod-total.json'],
            prefix: $._config.grafanaK8s.linkPrefix,
          },
        },
      };

      local panels = [
        gauge.new('Current Rate of Bytes Received')
        + gauge.standardOptions.withDisplayName('$namespace')
        + gauge.standardOptions.withUnit('Bps')
        + gauge.standardOptions.withMin(0)
        + gauge.standardOptions.withMax(10000000000)  // 10GBs
        + gauge.standardOptions.thresholds.withSteps([
          {
            color: 'dark-green',
            index: 0,
            value: null,  // 0GBs
          },
          {
            color: 'dark-yellow',
            index: 1,
            value: 5000000000,  // 5GBs
          },
          {
            color: 'dark-red',
            index: 2,
            value: 7000000000,  // 7GBs
          },
        ])
        + gauge.queryOptions.withInterval($._config.grafanaK8s.minimumTimeInterval)
        + gauge.queryOptions.withTargets([
          prometheus.new(
            '${datasource}', |||
              sum (
                  rate(container_network_receive_bytes_total{%(clusterLabel)s="$cluster",namespace=~"$namespace"}[%(grafanaIntervalVar)s])
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

        gauge.new('Current Rate of Bytes Transmitted')
        + gauge.standardOptions.withDisplayName('$namespace')
        + gauge.standardOptions.withUnit('Bps')
        + gauge.standardOptions.withMin(0)
        + gauge.standardOptions.withMax(10000000000)  // 10GBs
        + gauge.queryOptions.withInterval($._config.grafanaK8s.minimumTimeInterval)
        + gauge.standardOptions.thresholds.withSteps([
          {
            color: 'dark-green',
            index: 0,
            value: null,  // 0GBs
          },
          {
            color: 'dark-yellow',
            index: 1,
            value: 5000000000,  // 5GBs
          },
          {
            color: 'dark-red',
            index: 2,
            value: 7000000000,  // 7GBs
          },
        ])
        + gauge.queryOptions.withTargets([
          prometheus.new(
            '${datasource}', |||
              sum (
                  rate(container_network_transmit_bytes_total{%(clusterLabel)s="$cluster",namespace=~"$namespace"}[%(grafanaIntervalVar)s])
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

        table.new('Current Network Usage')
        + table.gridPos.withW(24)
        + table.queryOptions.withTargets([
          prometheus.new(
            '${datasource}', |||
              sum by (pod) (
                  rate(container_network_receive_bytes_total{%(clusterLabel)s="$cluster",namespace=~"$namespace"}[%(grafanaIntervalVar)s])
                * on (%(clusterLabel)s,namespace,pod) group_left ()
                  topk by (%(clusterLabel)s,namespace,pod) (
                    1,
                    max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false"})
                  )
              )
            ||| % $._config
          )
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new(
            '${datasource}', |||
              sum by (pod) (
                  rate(container_network_transmit_bytes_total{%(clusterLabel)s="$cluster",namespace=~"$namespace"}[%(grafanaIntervalVar)s])
                * on (%(clusterLabel)s,namespace,pod) group_left ()
                  topk by (%(clusterLabel)s,namespace,pod) (
                    1,
                    max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false"})
                  )
              )
            ||| % $._config
          )
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new(
            '${datasource}', |||
              sum by (pod) (
                  rate(container_network_receive_packets_total{%(clusterLabel)s="$cluster",namespace=~"$namespace"}[%(grafanaIntervalVar)s])
                * on (%(clusterLabel)s,namespace,pod) group_left ()
                  topk by (%(clusterLabel)s,namespace,pod) (
                    1,
                    max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false"})
                  )
              )
            ||| % $._config
          )
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new(
            '${datasource}', |||
              sum by (pod) (
                  rate(container_network_transmit_packets_total{%(clusterLabel)s="$cluster",namespace=~"$namespace"}[%(grafanaIntervalVar)s])
                * on (%(clusterLabel)s,namespace,pod) group_left ()
                  topk by (%(clusterLabel)s,namespace,pod) (
                    1,
                    max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false"})
                  )
              )
            ||| % $._config
          )
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new(
            '${datasource}', |||
              sum by (pod) (
                  rate(container_network_receive_packets_dropped_total{%(clusterLabel)s="$cluster",namespace=~"$namespace"}[%(grafanaIntervalVar)s])
                * on (%(clusterLabel)s,namespace,pod) group_left ()
                  topk by (%(clusterLabel)s,namespace,pod) (
                    1,
                    max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false"})
                  )
              )
            ||| % $._config
          )
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new(
            '${datasource}', |||
              sum by (pod) (
                  rate(container_network_transmit_packets_dropped_total{%(clusterLabel)s="$cluster",namespace=~"$namespace"}[%(grafanaIntervalVar)s])
                * on (%(clusterLabel)s,namespace,pod) group_left ()
                  topk by (%(clusterLabel)s,namespace,pod) (
                    1,
                    max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false"})
                  )
              )
            ||| % $._config
          )
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
        ])

        + table.queryOptions.withTransformations([
          table.queryOptions.transformation.withId('joinByField')
          + table.queryOptions.transformation.withOptions({
            byField: 'pod',
            mode: 'outer',
          }),

          table.queryOptions.transformation.withId('organize')
          + table.queryOptions.transformation.withOptions({
            excludeByName: {
              Time: true,
              'Time 1': true,
              'Time 2': true,
              'Time 3': true,
              'Time 4': true,
              'Time 5': true,
              'Time 6': true,
            },
            indexByName: {
              'Time 1': 0,
              'Time 2': 1,
              'Time 3': 2,
              'Time 4': 3,
              'Time 5': 4,
              'Time 6': 5,
              pod: 6,
              'Value #A': 7,
              'Value #B': 8,
              'Value #C': 9,
              'Value #D': 10,
              'Value #E': 11,
              'Value #F': 12,
            },
            renameByName: {
              pod: 'Pod',
              'Value #A': 'Current Receive Bandwidth',
              'Value #B': 'Current Transmit Bandwidth',
              'Value #C': 'Rate of Received Packets',
              'Value #D': 'Rate of Transmitted Packets',
              'Value #E': 'Rate of Received Packets Dropped',
              'Value #F': 'Rate of Transmitted Packets Dropped',
            },
          }),
        ])

        + table.standardOptions.withOverrides([
          {
            matcher: {
              id: 'byRegexp',
              options: '/Bandwidth/',
            },
            properties: [
              {
                id: 'unit',
                value: 'Bps',
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
              options: 'Pod',
            },
            properties: [
              {
                id: 'links',
                value: [links.pod],
              },
            ],
          },
        ]),

        tsPanel.new('Receive Bandwidth')
        + tsPanel.standardOptions.withUnit('binBps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}', |||
              sum by (pod) (
                  rate(container_network_receive_bytes_total{%(clusterLabel)s="$cluster",namespace=~"$namespace"}[%(grafanaIntervalVar)s])
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
              sum by (pod) (
                  rate(container_network_transmit_bytes_total{%(clusterLabel)s="$cluster",namespace=~"$namespace"}[%(grafanaIntervalVar)s])
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
          prometheus.new(
            '${datasource}', |||
              sum by (pod) (
                  rate(container_network_receive_packets_total{%(clusterLabel)s="$cluster",namespace=~"$namespace"}[%(grafanaIntervalVar)s])
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

        tsPanel.new('Rate of Transmitted Packets')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}', |||
              sum by (pod) (
                  rate(container_network_transmit_packets_total{%(clusterLabel)s="$cluster",namespace=~"$namespace"}[%(grafanaIntervalVar)s])
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

        tsPanel.new('Rate of Received Packets Dropped')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}', |||
              sum by (pod) (
                  rate(container_network_receive_packets_dropped_total{%(clusterLabel)s="$cluster",namespace!=""}[%(grafanaIntervalVar)s])
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

        tsPanel.new('Rate of Transmitted Packets Dropped')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}', |||
              sum by (pod) (
                  rate(container_network_transmit_packets_dropped_total{%(clusterLabel)s="$cluster",namespace=~"$namespace"}[%(grafanaIntervalVar)s])
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

      g.dashboard.new('%(dashboardNamePrefix)sNetworking / Namespace (Pods)' % $._config.grafanaK8s)
      + g.dashboard.withUid($._config.grafanaDashboardIDs['namespace-by-pod.json'])
      + g.dashboard.withTags($._config.grafanaK8s.dashboardTags)
      + g.dashboard.withEditable(false)
      + g.dashboard.time.withFrom('now-1h')
      + g.dashboard.time.withTo('now')
      + g.dashboard.withRefresh($._config.grafanaK8s.refresh)
      + g.dashboard.withVariables([variables.datasource, variables.cluster, variables.namespace])
      + g.dashboard.withPanels(g.util.grid.wrapPanels(panels, panelWidth=12, panelHeight=9)),
  },
}
