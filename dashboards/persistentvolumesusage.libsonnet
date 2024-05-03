local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local prometheus = g.query.prometheus;
local gauge = g.panel.gauge;
local timeSeries = g.panel.timeSeries;
local var = g.dashboard.variable;

{
  local gaugePanel(title, unit, query) =
    gauge.new(title)
    + gauge.standardOptions.withUnit(unit)
    + gauge.queryOptions.withInterval($._config.grafanaK8s.minimumTimeInterval)
    + gauge.queryOptions.withTargets([
      prometheus.new('${datasource}', query)
      + prometheus.withInstant(true),
    ]),

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
    'persistentvolumesusage.json':
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
            'kubelet_volume_stats_capacity_bytes{%(kubeletSelector)s}' % $._config,
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
            'kubelet_volume_stats_capacity_bytes{%(clusterLabel)s="$cluster", %(kubeletSelector)s}' % $._config,
          )
          + var.query.generalOptions.withLabel('Namespace')
          + var.query.refresh.onTime()
          + var.query.generalOptions.showOnDashboard.withLabelAndValue()
          + var.query.withSort(type='alphabetical'),

        volume:
          var.query.new('volume')
          + var.query.withDatasourceFromVariable(self.datasource)
          + var.query.queryTypes.withLabelValues(
            'persistentvolumeclaim',
            'kubelet_volume_stats_capacity_bytes{%(clusterLabel)s="$cluster", %(kubeletSelector)s, namespace="$namespace"}' % $._config,
          )
          + var.query.generalOptions.withLabel('PersistentVolumeClaim')
          + var.query.refresh.onTime()
          + var.query.generalOptions.showOnDashboard.withLabelAndValue()
          + var.query.withSort(type='alphabetical'),
      };

      local panels = {
        tsUsage:
          tsPanel.new('Volume Space Usage')
          + tsPanel.standardOptions.withUnit('bytes')
          + tsPanel.queryOptions.withTargets([
            prometheus.new('${datasource}', |||
              (
                sum without(instance, node) (topk(1, (kubelet_volume_stats_capacity_bytes{%(clusterLabel)s="$cluster", %(kubeletSelector)s, namespace="$namespace", persistentvolumeclaim="$volume"})))
                -
                sum without(instance, node) (topk(1, (kubelet_volume_stats_available_bytes{%(clusterLabel)s="$cluster", %(kubeletSelector)s, namespace="$namespace", persistentvolumeclaim="$volume"})))
              )
            ||| % $._config)
            + prometheus.withLegendFormat('Used Space'),

            prometheus.new('${datasource}', |||
              sum without(instance, node) (topk(1, (kubelet_volume_stats_available_bytes{%(clusterLabel)s="$cluster", %(kubeletSelector)s, namespace="$namespace", persistentvolumeclaim="$volume"})))
            ||| % $._config)
            + prometheus.withLegendFormat('Free Space'),
          ]),
        gaugeUsage:
          gaugePanel(
            'Volume Space Usage',
            'percent',
            |||
              max without(instance,node) (
              (
                topk(1, kubelet_volume_stats_capacity_bytes{%(clusterLabel)s="$cluster", %(kubeletSelector)s, namespace="$namespace", persistentvolumeclaim="$volume"})
                -
                topk(1, kubelet_volume_stats_available_bytes{%(clusterLabel)s="$cluster", %(kubeletSelector)s, namespace="$namespace", persistentvolumeclaim="$volume"})
              )
              /
              topk(1, kubelet_volume_stats_capacity_bytes{%(clusterLabel)s="$cluster", %(kubeletSelector)s, namespace="$namespace", persistentvolumeclaim="$volume"})
              * 100)
            ||| % $._config
          )
          + gauge.standardOptions.withMin(0)
          + gauge.standardOptions.withMax(100)
          + gauge.standardOptions.color.withMode('thresholds')
          + gauge.standardOptions.thresholds.withMode('absolute')
          + gauge.standardOptions.thresholds.withSteps(
            [
              gauge.thresholdStep.withColor('green')
              + gauge.thresholdStep.withValue(0),

              gauge.thresholdStep.withColor('orange')
              + gauge.thresholdStep.withValue(80),

              gauge.thresholdStep.withColor('red')
              + gauge.thresholdStep.withValue(90),
            ]
          ),

        tsInodes:
          tsPanel.new('Volume inodes Usage')
          + tsPanel.standardOptions.withUnit('none')
          + tsPanel.queryOptions.withTargets([
            prometheus.new('${datasource}', 'sum without(instance, node) (topk(1, (kubelet_volume_stats_inodes_used{%(clusterLabel)s="$cluster", %(kubeletSelector)s, namespace="$namespace", persistentvolumeclaim="$volume"})))' % $._config)
            + prometheus.withLegendFormat('Used inodes'),

            prometheus.new('${datasource}', |||
              (
                sum without(instance, node) (topk(1, (kubelet_volume_stats_inodes{%(clusterLabel)s="$cluster", %(kubeletSelector)s, namespace="$namespace", persistentvolumeclaim="$volume"})))
                -
                sum without(instance, node) (topk(1, (kubelet_volume_stats_inodes_used{%(clusterLabel)s="$cluster", %(kubeletSelector)s, namespace="$namespace", persistentvolumeclaim="$volume"})))
              )
            ||| % $._config)
            + prometheus.withLegendFormat('Free inodes'),
          ]),
        gaugeInodes:
          gaugePanel(
            'Volume inodes Usage',
            'percent',
            |||
              max without(instance,node) (
              topk(1, kubelet_volume_stats_inodes_used{%(clusterLabel)s="$cluster", %(kubeletSelector)s, namespace="$namespace", persistentvolumeclaim="$volume"})
              /
              topk(1, kubelet_volume_stats_inodes{%(clusterLabel)s="$cluster", %(kubeletSelector)s, namespace="$namespace", persistentvolumeclaim="$volume"})
              * 100)
            ||| % $._config
          )
          + gauge.standardOptions.withMin(0)
          + gauge.standardOptions.withMax(100)
          + gauge.standardOptions.color.withMode('thresholds')
          + gauge.standardOptions.thresholds.withMode('absolute')
          + gauge.standardOptions.thresholds.withSteps(
            [
              gauge.thresholdStep.withColor('green')
              + gauge.thresholdStep.withValue(0),

              gauge.thresholdStep.withColor('orange')
              + gauge.thresholdStep.withValue(80),

              gauge.thresholdStep.withColor('red')
              + gauge.thresholdStep.withValue(90),
            ]
          ),
      };

      g.dashboard.new('%(dashboardNamePrefix)sPersistent Volumes' % $._config.grafanaK8s)
      + g.dashboard.withUid($._config.grafanaDashboardIDs['persistentvolumesusage.json'])
      + g.dashboard.withTags($._config.grafanaK8s.dashboardTags)
      + g.dashboard.withEditable(false)
      + g.dashboard.time.withFrom('now-1h')
      + g.dashboard.time.withTo('now')
      + g.dashboard.withRefresh($._config.grafanaK8s.refresh)
      + g.dashboard.withVariables([variables.datasource, variables.cluster, variables.namespace, variables.volume])
      + g.dashboard.withPanels([
        panels.tsUsage { gridPos+: { w: 18, h: 7, y: 0 } },
        panels.gaugeUsage { gridPos+: { w: 6, h: 7, x: 18, y: 0 } },
        panels.tsInodes { gridPos+: { w: 18, h: 7, y: 7 } },
        panels.gaugeInodes { gridPos+: { w: 6, h: 7, x: 18, y: 7 } },
      ]),
  },
}
