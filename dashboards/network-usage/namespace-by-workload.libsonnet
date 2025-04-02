local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local barGauge = g.panel.barGauge;
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
        + timeSeries.options.legend.withCalcs(['lastNotNull'])
        + timeSeries.options.tooltip.withMode('single')
        + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
        + timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
        + timeSeries.fieldConfig.defaults.custom.withSpanNulls(true)
        + timeSeries.queryOptions.withInterval($._config.grafanaK8s.minimumTimeInterval),
    },

  grafanaDashboards+:: {
    'namespace-by-workload.json':

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

        workload_type:
          var.query.new('type')
          + var.query.selectionOptions.withIncludeAll()
          + var.query.withDatasourceFromVariable(self.datasource)
          + var.query.queryTypes.withLabelValues(
            'workload_type',
            'namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster", namespace="$namespace", workload=~".+"}' % $._config,
          )
          + var.query.generalOptions.withLabel('workload_type')
          + var.query.refresh.onTime()
          + var.query.generalOptions.showOnDashboard.withLabelAndValue()
          + var.query.withSort(type='alphabetical'),
      };

      local links = {
        workload: {
          title: 'Drill down',
          url: '%(prefix)s/d/%(uid)s/kubernetes-networking-workload?${datasource:queryparam}&var-cluster=${cluster}&var-namespace=${namespace}&var-type=${__data.fields.Type}&var-workload=${__data.fields.Workload}' % {
            uid: $._config.grafanaDashboardIDs['workload-total.json'],
            prefix: $._config.grafanaK8s.linkPrefix,
          },
        },
      };

      local colQueries = [
        |||
          sort_desc(sum(rate(container_network_receive_bytes_total{%(clusterLabel)s="$cluster",namespace="$namespace"}[%(grafanaIntervalVar)s])
          * on (namespace,pod) kube_pod_info{%(clusterLabel)s="$cluster",namespace="$namespace",host_network="false"}
          * on (namespace,pod)
          group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster",namespace="$namespace", workload=~".+", workload_type=~"$type"}) by (workload, workload_type))
        ||| % $._config,
        |||
          sort_desc(sum(rate(container_network_transmit_bytes_total{%(clusterLabel)s="$cluster",namespace="$namespace"}[%(grafanaIntervalVar)s])
          * on (namespace,pod) kube_pod_info{%(clusterLabel)s="$cluster",namespace="$namespace",host_network="false"}
          * on (namespace,pod)
          group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster",namespace="$namespace", workload=~".+", workload_type=~"$type"}) by (workload, workload_type))
        ||| % $._config,
        |||
          sort_desc(avg(rate(container_network_receive_bytes_total{%(clusterLabel)s="$cluster",namespace="$namespace"}[%(grafanaIntervalVar)s])
          * on (namespace,pod) kube_pod_info{%(clusterLabel)s="$cluster",namespace="$namespace",host_network="false"}
          * on (namespace,pod)
          group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster",namespace="$namespace", workload=~".+", workload_type=~"$type"}) by (workload, workload_type))
        ||| % $._config,
        |||
          sort_desc(avg(rate(container_network_transmit_bytes_total{%(clusterLabel)s="$cluster",namespace="$namespace"}[%(grafanaIntervalVar)s])
          * on (namespace,pod) kube_pod_info{%(clusterLabel)s="$cluster",namespace="$namespace",host_network="false"}
          * on (namespace,pod)
          group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster",namespace="$namespace", workload=~".+", workload_type=~"$type"}) by (workload, workload_type))
        ||| % $._config,
        |||
          sort_desc(sum(rate(container_network_receive_packets_total{%(clusterLabel)s="$cluster",namespace="$namespace"}[%(grafanaIntervalVar)s])
          * on (namespace,pod) kube_pod_info{%(clusterLabel)s="$cluster",namespace="$namespace",host_network="false"}
          * on (namespace,pod)
          group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster",namespace="$namespace", workload=~".+", workload_type=~"$type"}) by (workload, workload_type))
        ||| % $._config,
        |||
          sort_desc(sum(rate(container_network_transmit_packets_total{%(clusterLabel)s="$cluster",namespace="$namespace"}[%(grafanaIntervalVar)s])
          * on (namespace,pod) kube_pod_info{%(clusterLabel)s="$cluster",namespace="$namespace",host_network="false"}
          * on (namespace,pod)
          group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster",namespace="$namespace", workload=~".+", workload_type=~"$type"}) by (workload, workload_type))
        ||| % $._config,
        |||
          sort_desc(sum(rate(container_network_receive_packets_dropped_total{%(clusterLabel)s="$cluster",namespace="$namespace"}[%(grafanaIntervalVar)s])
          * on (namespace,pod) kube_pod_info{%(clusterLabel)s="$cluster",namespace="$namespace",host_network="false"}
          * on (namespace,pod)
          group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster",namespace="$namespace", workload=~".+", workload_type=~"$type"}) by (workload, workload_type))
        ||| % $._config,
        |||
          sort_desc(sum(rate(container_network_transmit_packets_dropped_total{%(clusterLabel)s="$cluster",namespace="$namespace"}[%(grafanaIntervalVar)s])
          * on (namespace,pod) kube_pod_info{%(clusterLabel)s="$cluster",namespace="$namespace",host_network="false"}
          * on (namespace,pod)
          group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster",namespace="$namespace", workload=~".+", workload_type=~"$type"}) by (workload, workload_type))
        ||| % $._config,
      ];

      local panels = [
        barGauge.new('Current Rate of Bytes Received')
        + barGauge.options.withDisplayMode('basic')
        + barGauge.options.withShowUnfilled(false)
        + barGauge.standardOptions.withUnit('Bps')
        + barGauge.standardOptions.color.withMode('fixed')
        + barGauge.standardOptions.color.withFixedColor('green')
        + barGauge.queryOptions.withInterval($._config.grafanaK8s.minimumTimeInterval)
        + barGauge.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            |||
              sort_desc(sum(rate(container_network_receive_bytes_total{%(clusterLabel)s="$cluster",namespace="$namespace"}[%(grafanaIntervalVar)s])
              * on (%(clusterLabel)s,namespace,pod) group_left ()
                  topk by (%(clusterLabel)s,namespace,pod) (
                    1,
                    max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false"})
                  )
              * on (%(clusterLabel)s,namespace,pod)
              group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster",namespace="$namespace", workload=~".+", workload_type=~"$type"}) by (workload))
            ||| % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        barGauge.new('Current Rate of Bytes Transmitted')
        + barGauge.options.withDisplayMode('basic')
        + barGauge.options.withShowUnfilled(false)
        + barGauge.standardOptions.withUnit('Bps')
        + barGauge.standardOptions.color.withMode('fixed')
        + barGauge.standardOptions.color.withFixedColor('green')
        + barGauge.queryOptions.withInterval($._config.grafanaK8s.minimumTimeInterval)
        + barGauge.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            |||
              sort_desc(sum(rate(container_network_transmit_bytes_total{%(clusterLabel)s="$cluster",namespace="$namespace"}[%(grafanaIntervalVar)s])
              * on (%(clusterLabel)s,namespace,pod) group_left ()
                  topk by (%(clusterLabel)s,namespace,pod) (
                    1,
                    max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false"})
                  )
              * on (%(clusterLabel)s,namespace,pod)
              group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster",namespace="$namespace", workload=~".+", workload_type=~"$type"}) by (workload))
            ||| % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        table.new('Current Status')
        + table.gridPos.withW(24)
        + table.queryOptions.withTargets([
          prometheus.new('${datasource}', colQueries[0])
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', colQueries[1])
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', colQueries[2])
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', colQueries[3])
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', colQueries[4])
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', colQueries[5])
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', colQueries[6])
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', colQueries[7])
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
        ])
        + table.queryOptions.withTransformations([
          table.queryOptions.transformation.withId('joinByField')
          + table.queryOptions.transformation.withOptions({
            byField: 'workload',
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
              'workload_type 2': true,
              'workload_type 3': true,
              'workload_type 4': true,
              'workload_type 5': true,
              'workload_type 6': true,
              'workload_type 7': true,
              'workload_type 8': true,
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
              workload: 8,
              'workload_type 1': 9,
              'Value #A': 10,
              'Value #B': 11,
              'Value #C': 12,
              'Value #D': 13,
              'Value #E': 14,
              'Value #F': 15,
              'Value #G': 16,
              'Value #H': 17,
              'workload_type 2': 18,
              'workload_type 3': 19,
              'workload_type 4': 20,
              'workload_type 5': 21,
              'workload_type 6': 22,
              'workload_type 7': 23,
              'workload_type 8': 24,
            },
            renameByName: {
              workload: 'Workload',
              'workload_type 1': 'Type',
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
              options: 'Workload',
            },
            properties: [
              {
                id: 'links',
                value: [links.workload],
              },
            ],
          },
        ]),

        tsPanel.new('Receive Bandwidth')
        + tsPanel.standardOptions.withUnit('Bps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            |||
              sort_desc(sum(rate(container_network_receive_bytes_total{%(clusterLabel)s="$cluster",namespace="$namespace"}[%(grafanaIntervalVar)s])
              * on (%(clusterLabel)s,namespace,pod) group_left ()
                  topk by (%(clusterLabel)s,namespace,pod) (
                    1,
                    max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false"})
                  )
              * on (%(clusterLabel)s,namespace,pod)
              group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster",namespace="$namespace", workload=~".+", workload_type=~"$type"}) by (workload))
            ||| % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Transmit Bandwidth')
        + tsPanel.standardOptions.withUnit('Bps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            |||
              sort_desc(sum(rate(container_network_transmit_bytes_total{%(clusterLabel)s="$cluster",namespace="$namespace"}[%(grafanaIntervalVar)s])
              * on (%(clusterLabel)s,namespace,pod) group_left ()
                  topk by (%(clusterLabel)s,namespace,pod) (
                    1,
                    max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false"})
                  )
              * on (%(clusterLabel)s,namespace,pod)
              group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster",namespace="$namespace", workload=~".+", workload_type=~"$type"}) by (workload))
            ||| % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Average Container Bandwidth by Workload: Received')
        + tsPanel.standardOptions.withUnit('Bps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            |||
              sort_desc(avg(rate(container_network_receive_bytes_total{%(clusterLabel)s="$cluster",namespace="$namespace"}[%(grafanaIntervalVar)s])
              * on (%(clusterLabel)s,namespace,pod) group_left ()
                  topk by (%(clusterLabel)s,namespace,pod) (
                    1,
                    max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false"})
                  )
              * on (%(clusterLabel)s,namespace,pod)
              group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster",namespace="$namespace", workload=~".+", workload_type=~"$type"}) by (workload))
            ||| % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Average Container Bandwidth by Workload: Transmitted')
        + tsPanel.standardOptions.withUnit('Bps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            |||
              sort_desc(avg(rate(container_network_transmit_bytes_total{%(clusterLabel)s="$cluster",namespace="$namespace"}[%(grafanaIntervalVar)s])
              * on (%(clusterLabel)s,namespace,pod) group_left ()
                  topk by (%(clusterLabel)s,namespace,pod) (
                    1,
                    max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false"})
                  )
              * on (%(clusterLabel)s,namespace,pod)
              group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster",namespace="$namespace", workload=~".+", workload_type=~"$type"}) by (workload))
            ||| % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of Received Packets')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            |||
              sort_desc(sum(rate(container_network_receive_packets_total{%(clusterLabel)s="$cluster",namespace="$namespace"}[%(grafanaIntervalVar)s])
              * on (%(clusterLabel)s,namespace,pod) group_left ()
                  topk by (%(clusterLabel)s,namespace,pod) (
                    1,
                    max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false"})
                  )
              * on (%(clusterLabel)s,namespace,pod)
              group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster",namespace="$namespace", workload=~".+", workload_type=~"$type"}) by (workload))
            ||| % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of Transmitted Packets')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            |||
              sort_desc(sum(rate(container_network_transmit_packets_total{%(clusterLabel)s="$cluster",namespace="$namespace"}[%(grafanaIntervalVar)s])
              * on (%(clusterLabel)s,namespace,pod) group_left ()
                  topk by (%(clusterLabel)s,namespace,pod) (
                    1,
                    max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false"})
                  )
              * on (%(clusterLabel)s,namespace,pod)
              group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster",namespace="$namespace", workload=~".+", workload_type=~"$type"}) by (workload))
            ||| % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of Received Packets Dropped')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            |||
              sort_desc(sum(rate(container_network_receive_packets_dropped_total{%(clusterLabel)s="$cluster",namespace="$namespace"}[%(grafanaIntervalVar)s])
              * on (%(clusterLabel)s,namespace,pod) group_left ()
                  topk by (%(clusterLabel)s,namespace,pod) (
                    1,
                    max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false"})
                  )
              * on (%(clusterLabel)s,namespace,pod)
              group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster",namespace="$namespace", workload=~".+", workload_type=~"$type"}) by (workload))
            ||| % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of Transmitted Packets Dropped')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            |||
              sort_desc(sum(rate(container_network_transmit_packets_dropped_total{%(clusterLabel)s="$cluster",namespace="$namespace"}[%(grafanaIntervalVar)s])
              * on (%(clusterLabel)s,namespace,pod) group_left ()
                  topk by (%(clusterLabel)s,namespace,pod) (
                    1,
                    max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false"})
                  )
              * on (%(clusterLabel)s,namespace,pod)
              group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster",namespace="$namespace", workload=~".+", workload_type=~"$type"}) by (workload))
            ||| % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),
      ];

      g.dashboard.new('%(dashboardNamePrefix)sNetworking / Namespace (Workload)' % $._config.grafanaK8s)
      + g.dashboard.withUid($._config.grafanaDashboardIDs['namespace-by-workload.json'])
      + g.dashboard.withTags($._config.grafanaK8s.dashboardTags)
      + g.dashboard.withEditable(false)
      + g.dashboard.time.withFrom('now-1h')
      + g.dashboard.time.withTo('now')
      + g.dashboard.withRefresh($._config.grafanaK8s.refresh)
      + g.dashboard.withVariables([variables.datasource, variables.cluster, variables.namespace, variables.workload_type])
      + g.dashboard.withPanels(g.util.grid.wrapPanels(panels, panelWidth=12, panelHeight=9)),
  },
}
