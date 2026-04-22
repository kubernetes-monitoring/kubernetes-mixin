local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

local prometheus = g.query.prometheus;
local stat = g.panel.stat;
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
    'k8s-resources-nodes-overview.json':
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
            'up{%(kubeStateMetricsSelector)s}' % $._config
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

      local panels = [
        // Node count over time
        tsPanel.new('Node Count')
        + tsPanel.standardOptions.withUnit('short')
        + tsPanel.standardOptions.withDecimals(0)
        + tsPanel.fieldConfig.defaults.custom.withFillOpacity(0)
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'count(kube_node_info{%(clusterLabel)s="$cluster", %(kubeStateMetricsSelector)s})' % $._config,
          )
          + prometheus.withLegendFormat('nodes'),
        ]),

        // Total CPU — available vs used
        tsPanel.new('CPU — Total Available & Used')
        + tsPanel.standardOptions.withUnit('short')
        + tsPanel.fieldConfig.defaults.custom.withFillOpacity(0)
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'sum(kube_node_status_allocatable{%(clusterLabel)s="$cluster", %(kubeStateMetricsSelector)s, resource="cpu"})' % $._config,
          )
          + prometheus.withLegendFormat('allocatable'),

          prometheus.new(
            '${datasource}',
            'sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m{%(clusterLabel)s="$cluster"})' % $._config,
          )
          + prometheus.withLegendFormat('used'),
        ]),

        // Total Memory — available vs used
        tsPanel.new('Memory — Total Available & Used')
        + tsPanel.standardOptions.withUnit('bytes')
        + tsPanel.fieldConfig.defaults.custom.withFillOpacity(0)
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'sum(kube_node_status_allocatable{%(clusterLabel)s="$cluster", %(kubeStateMetricsSelector)s, resource="memory"})' % $._config,
          )
          + prometheus.withLegendFormat('allocatable'),

          prometheus.new(
            '${datasource}',
            'sum(node_namespace_pod_container:container_memory_working_set_bytes{%(clusterLabel)s="$cluster", container!=""})' % $._config,
          )
          + prometheus.withLegendFormat('used'),
        ]),

        // CPU utilization per node (percentage)
        tsPanel.new('CPU Utilization per Node')
        + tsPanel.standardOptions.withUnit('percentunit')
        + tsPanel.fieldConfig.defaults.custom.withFillOpacity(0)
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            |||
              sum by (node) (node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m{%(clusterLabel)s="$cluster"})
              /
              sum by (node) (kube_node_status_allocatable{%(clusterLabel)s="$cluster", %(kubeStateMetricsSelector)s, resource="cpu"})
            ||| % $._config,
          )
          + prometheus.withLegendFormat('{{node}}'),
        ]),

        // Memory utilization per node (percentage)
        tsPanel.new('Memory Utilization per Node')
        + tsPanel.standardOptions.withUnit('percentunit')
        + tsPanel.fieldConfig.defaults.custom.withFillOpacity(0)
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            |||
              sum by (node) (node_namespace_pod_container:container_memory_working_set_bytes{%(clusterLabel)s="$cluster", container!=""})
              /
              sum by (node) (kube_node_status_allocatable{%(clusterLabel)s="$cluster", %(kubeStateMetricsSelector)s, resource="memory"})
            ||| % $._config,
          )
          + prometheus.withLegendFormat('{{node}}'),
        ]),

        // Pod count per node
        tsPanel.new('Pod Count per Node')
        + tsPanel.standardOptions.withUnit('short')
        + tsPanel.standardOptions.withDecimals(0)
        + tsPanel.fieldConfig.defaults.custom.withFillOpacity(0)
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'sum by (node) (kubelet_running_pods{%(clusterLabel)s="$cluster", %(kubeletSelector)s})' % $._config,
          )
          + prometheus.withLegendFormat('{{node}}'),
        ]),
      ];

      g.dashboard.new('%(dashboardNamePrefix)sCompute Resources / Nodes Overview' % $._config.grafanaK8s)
      + g.dashboard.withUid($._config.grafanaDashboardIDs['k8s-resources-nodes-overview.json'])
      + g.dashboard.withTags($._config.grafanaK8s.dashboardTags)
      + g.dashboard.withEditable(false)
      + g.dashboard.time.withFrom('now-6h')
      + g.dashboard.time.withTo('now')
      + g.dashboard.withRefresh($._config.grafanaK8s.refresh)
      + g.dashboard.withVariables([variables.datasource, variables.cluster])
      + g.dashboard.withPanels(g.util.grid.wrapPanels(panels, panelWidth=24, panelHeight=8)),
  },
}
