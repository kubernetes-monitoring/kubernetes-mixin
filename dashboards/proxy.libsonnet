local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

local prometheus = g.query.prometheus;
local stat = g.panel.stat;
local timeSeries = g.panel.timeSeries;
local var = g.dashboard.variable;

{
  local statPanel(title, unit, query) =
    stat.new(title)
    + stat.options.withColorMode('none')
    + stat.standardOptions.withUnit(unit)
    + stat.queryOptions.withInterval($._config.grafanaK8s.minimumTimeInterval)
    + stat.queryOptions.withTargets([
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
    'proxy.json':
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
            'up{%(kubeProxySelector)s}' % $._config
          )
          + var.query.generalOptions.withLabel('cluster')
          + var.query.refresh.onTime()
          + (
            if $._config.showMultiCluster
            then var.query.generalOptions.showOnDashboard.withLabelAndValue()
            else var.query.generalOptions.showOnDashboard.withNothing()
          )
          + var.query.withSort(type='alphabetical'),

        instance:
          var.query.new('instance')
          + var.query.withDatasourceFromVariable(self.datasource)
          + var.query.queryTypes.withLabelValues(
            'instance',
            'up{%(kubeProxySelector)s, %(clusterLabel)s="$cluster", %(kubeProxySelector)s}' % $._config,
          )
          + var.query.generalOptions.withLabel('instance')
          + var.query.refresh.onTime()
          + var.query.generalOptions.showOnDashboard.withLabelAndValue()
          + var.query.selectionOptions.withIncludeAll(true, '.+'),
      };

      local panels = [
        statPanel('Up', 'none', 'sum(up{%(clusterLabel)s="$cluster", %(kubeProxySelector)s})' % $._config)
        + stat.gridPos.withW(4),

        tsPanel.new('Rules Sync Rate')
        + tsPanel.gridPos.withW(10)
        + tsPanel.standardOptions.withUnit('ops')
        + tsPanel.queryOptions.withTargets([
          prometheus.new('${datasource}', 'sum(rate(kubeproxy_sync_proxy_rules_duration_seconds_count{%(clusterLabel)s="$cluster", %(kubeProxySelector)s, instance=~"$instance"}[%(grafanaIntervalVar)s]))' % $._config)
          + prometheus.withLegendFormat('rate'),
        ]),

        tsPanel.new('Rules Sync Latency 99th Quantile')
        + tsPanel.gridPos.withW(10)
        + tsPanel.standardOptions.withUnit('s')
        + tsPanel.queryOptions.withTargets([
          prometheus.new('${datasource}', 'histogram_quantile(0.99,rate(kubeproxy_sync_proxy_rules_duration_seconds_bucket{%(clusterLabel)s="$cluster", %(kubeProxySelector)s, instance=~"$instance"}[%(grafanaIntervalVar)s]))' % $._config)
          + prometheus.withLegendFormat('{{instance}}'),
        ]),

        tsPanel.new('Network Programming Rate')
        + tsPanel.standardOptions.withUnit('ops')
        + tsPanel.queryOptions.withTargets([
          prometheus.new('${datasource}', 'sum(rate(kubeproxy_network_programming_duration_seconds_count{%(clusterLabel)s="$cluster", %(kubeProxySelector)s, instance=~"$instance"}[%(grafanaIntervalVar)s]))' % $._config)
          + prometheus.withLegendFormat('rate'),
        ]),

        tsPanel.new('Network Programming Latency 99th Quantile')
        + tsPanel.standardOptions.withUnit('s')
        + tsPanel.queryOptions.withTargets([
          prometheus.new('${datasource}', 'histogram_quantile(0.99, sum(rate(kubeproxy_network_programming_duration_seconds_bucket{%(clusterLabel)s="$cluster", %(kubeProxySelector)s, instance=~"$instance"}[%(grafanaIntervalVar)s])) by (instance, le))' % $._config)
          + prometheus.withLegendFormat('{{instance}}'),
        ]),

        tsPanel.new('Kube API Request Rate')
        + tsPanel.gridPos.withW(8)
        + tsPanel.standardOptions.withUnit('ops')
        + tsPanel.queryOptions.withTargets([
          prometheus.new('${datasource}', 'sum(rate(rest_client_requests_total{%(clusterLabel)s="$cluster",%(kubeProxySelector)s, instance=~"$instance",code=~"2.."}[%(grafanaIntervalVar)s]))' % $._config)
          + prometheus.withLegendFormat('2xx'),

          prometheus.new('${datasource}', 'sum(rate(rest_client_requests_total{%(clusterLabel)s="$cluster",%(kubeProxySelector)s, instance=~"$instance",code=~"3.."}[%(grafanaIntervalVar)s]))' % $._config)
          + prometheus.withLegendFormat('3xx'),

          prometheus.new('${datasource}', 'sum(rate(rest_client_requests_total{%(clusterLabel)s="$cluster",%(kubeProxySelector)s, instance=~"$instance",code=~"4.."}[%(grafanaIntervalVar)s]))' % $._config)
          + prometheus.withLegendFormat('4xx'),

          prometheus.new('${datasource}', 'sum(rate(rest_client_requests_total{%(clusterLabel)s="$cluster",%(kubeProxySelector)s, instance=~"$instance",code=~"5.."}[%(grafanaIntervalVar)s]))' % $._config)
          + prometheus.withLegendFormat('5xx'),
        ]),

        tsPanel.new('Post Request Latency 99th Quantile')
        + tsPanel.gridPos.withW(16)
        + tsPanel.standardOptions.withUnit('ops')
        + tsPanel.queryOptions.withTargets([
          prometheus.new('${datasource}', 'histogram_quantile(0.99, sum(rate(rest_client_request_duration_seconds_bucket{%(clusterLabel)s="$cluster", %(kubeProxySelector)s,instance=~"$instance",verb="POST"}[%(grafanaIntervalVar)s])) by (verb, le))' % $._config)
          + prometheus.withLegendFormat('{{verb}}'),
        ]),

        tsPanel.new('Get Request Latency 99th Quantile')
        + tsPanel.gridPos.withW(24)
        + tsPanel.standardOptions.withUnit('s')
        + tsPanel.queryOptions.withTargets([
          prometheus.new('${datasource}', 'histogram_quantile(0.99, sum(rate(rest_client_request_duration_seconds_bucket{%(clusterLabel)s="$cluster", %(kubeProxySelector)s, instance=~"$instance", verb="GET"}[%(grafanaIntervalVar)s])) by (verb, le))' % $._config)
          + prometheus.withLegendFormat('{{verb}}'),
        ]),


        tsPanel.new('Memory')
        + tsPanel.gridPos.withW(8)
        + tsPanel.standardOptions.withUnit('bytes')
        + tsPanel.queryOptions.withTargets([
          prometheus.new('${datasource}', 'process_resident_memory_bytes{%(clusterLabel)s="$cluster", %(kubeProxySelector)s,instance=~"$instance"}' % $._config)
          + prometheus.withLegendFormat('{{instance}}'),
        ]),

        tsPanel.new('CPU usage')
        + tsPanel.gridPos.withW(8)
        + tsPanel.standardOptions.withUnit('short')
        + tsPanel.queryOptions.withTargets([
          prometheus.new('${datasource}', 'rate(process_cpu_seconds_total{%(clusterLabel)s="$cluster", %(kubeProxySelector)s,instance=~"$instance"}[%(grafanaIntervalVar)s])' % $._config)
          + prometheus.withLegendFormat('{{instance}}'),
        ]),

        tsPanel.new('Goroutines')
        + tsPanel.gridPos.withW(8)
        + tsPanel.standardOptions.withUnit('short')
        + tsPanel.queryOptions.withTargets([
          prometheus.new('${datasource}', 'go_goroutines{%(clusterLabel)s="$cluster", %(kubeProxySelector)s,instance=~"$instance"}' % $._config)
          + prometheus.withLegendFormat('{{instance}}'),
        ]),
      ];

      g.dashboard.new('%(dashboardNamePrefix)sProxy' % $._config.grafanaK8s)
      + g.dashboard.withUid($._config.grafanaDashboardIDs['proxy.json'])
      + g.dashboard.withTags($._config.grafanaK8s.dashboardTags)
      + g.dashboard.withEditable(false)
      + g.dashboard.time.withFrom('now-1h')
      + g.dashboard.time.withTo('now')
      + g.dashboard.withRefresh($._config.grafanaK8s.refresh)
      + g.dashboard.withVariables([variables.datasource, variables.cluster, variables.instance])
      + g.dashboard.withPanels(g.util.grid.wrapPanels(panels, panelWidth=12, panelHeight=7)),
  },
}
