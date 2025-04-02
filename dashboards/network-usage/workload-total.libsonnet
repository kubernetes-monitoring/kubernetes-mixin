local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local barGauge = g.panel.barGauge;
local prometheus = g.query.prometheus;
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
    'workload-total.json':
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
            'kube_pod_info{%(kubeStateMetricsSelector)s}' % $._config,
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

        workload:
          var.query.new('workload')
          + var.query.withDatasourceFromVariable(self.datasource)
          + var.query.queryTypes.withLabelValues(
            'workload',
            'namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster", namespace=~"$namespace", workload=~".+"}' % $._config,
          )
          + var.query.generalOptions.withLabel('workload')
          + var.query.refresh.onTime()
          + var.query.generalOptions.showOnDashboard.withLabelAndValue()
          + var.query.withSort(type='alphabetical'),

        workload_type:
          var.query.new('type')
          + var.query.selectionOptions.withIncludeAll(true, '.+')
          + var.query.withDatasourceFromVariable(self.datasource)
          + var.query.queryTypes.withLabelValues(
            'workload_type',
            'namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster", namespace=~"$namespace", workload=~"$workload"}' % $._config,
          )
          + var.query.generalOptions.withLabel('workload_type')
          + var.query.refresh.onTime()
          + var.query.generalOptions.showOnDashboard.withLabelAndValue()
          + var.query.withSort(type='alphabetical'),
      };

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
              sort_desc(sum(rate(container_network_receive_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster",namespace=~"$namespace"}[%(grafanaIntervalVar)s])
              * on (namespace,pod)
              group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster",namespace=~"$namespace", workload=~"$workload", workload_type=~"$type"}) by (pod))
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
              sort_desc(sum(rate(container_network_transmit_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster",namespace=~"$namespace"}[%(grafanaIntervalVar)s])
              * on (namespace,pod)
              group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster",namespace=~"$namespace", workload=~"$workload", workload_type=~"$type"}) by (pod))
            ||| % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        barGauge.new('Average Rate of Bytes Received')
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
              sort_desc(avg(rate(container_network_receive_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster",namespace=~"$namespace"}[%(grafanaIntervalVar)s])
              * on (namespace,pod)
              group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster",namespace=~"$namespace", workload=~"$workload", workload_type=~"$type"}) by (pod))
            ||| % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        barGauge.new('Average Rate of Bytes Transmitted')
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
              sort_desc(avg(rate(container_network_transmit_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster",namespace=~"$namespace"}[%(grafanaIntervalVar)s])
              * on (namespace,pod)
              group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster",namespace=~"$namespace", workload=~"$workload", workload_type=~"$type"}) by (pod))
            ||| % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Receive Bandwidth')
        + tsPanel.standardOptions.withUnit('binBps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            |||
              sort_desc(sum(rate(container_network_receive_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster",namespace=~"$namespace"}[%(grafanaIntervalVar)s])
              * on (namespace,pod)
              group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster",namespace=~"$namespace", workload=~"$workload", workload_type=~"$type"}) by (pod))
            ||| % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Transmit Bandwidth')
        + tsPanel.standardOptions.withUnit('binBps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            |||
              sort_desc(sum(rate(container_network_transmit_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster",namespace=~"$namespace"}[%(grafanaIntervalVar)s])
              * on (namespace,pod)
              group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster",namespace=~"$namespace", workload=~"$workload", workload_type=~"$type"}) by (pod))
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
              sort_desc(sum(rate(container_network_receive_packets_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster",namespace=~"$namespace"}[%(grafanaIntervalVar)s])
              * on (namespace,pod)
              group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster",namespace=~"$namespace", workload=~"$workload", workload_type=~"$type"}) by (pod))
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
              sort_desc(sum(rate(container_network_transmit_packets_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster",namespace=~"$namespace"}[%(grafanaIntervalVar)s])
              * on (namespace,pod)
              group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster",namespace=~"$namespace", workload=~"$workload", workload_type=~"$type"}) by (pod))
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
              sort_desc(sum(rate(container_network_receive_packets_dropped_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster",namespace=~"$namespace"}[%(grafanaIntervalVar)s])
              * on (namespace,pod)
              group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster",namespace=~"$namespace", workload=~"$workload", workload_type=~"$type"}) by (pod))
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
              sort_desc(sum(rate(container_network_transmit_packets_dropped_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster",namespace=~"$namespace"}[%(grafanaIntervalVar)s])
              * on (namespace,pod)
              group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster",namespace=~"$namespace", workload=~"$workload", workload_type=~"$type"}) by (pod))
            ||| % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),
      ];

      g.dashboard.new('%(dashboardNamePrefix)sNetworking / Workload' % $._config.grafanaK8s)
      + g.dashboard.withUid($._config.grafanaDashboardIDs['workload-total.json'])
      + g.dashboard.withTags($._config.grafanaK8s.dashboardTags)
      + g.dashboard.withEditable(false)
      + g.dashboard.time.withFrom('now-1h')
      + g.dashboard.time.withTo('now')
      + g.dashboard.withRefresh($._config.grafanaK8s.refresh)
      + g.dashboard.withVariables([variables.datasource, variables.cluster, variables.namespace, variables.workload, variables.workload_type])
      + g.dashboard.withPanels(g.util.grid.wrapPanels(panels, panelWidth=12, panelHeight=9)),
  },
}
