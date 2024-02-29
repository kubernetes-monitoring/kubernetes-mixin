// add logs
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-v10.0.0/main.libsonnet';
local logsDashboard = import 'github.com/grafana/jsonnet-libs/logs-lib/logs/main.libsonnet';

{
  local filterSelector = 'namespace!=""',
  local labels = [$._config.clusterLabel, $._config.namespaceLabel, $._config.applicationLabel, $._config.podLabel, 'container'],

  local formatParser = null,
  local logsDash =
    logsDashboard.new(
      '%s Pod Logs' % $._config.grafanaK8s.dashboardNamePrefix,
      datasourceRegex='',
      filterSelector=filterSelector,
      labels=labels,
      formatParser=formatParser,
      showLogsVolume=$._config.showLogsVolume,
      logsVolumeGroupBy=$._config.logsVolumeGroupBy,
      extraFilters=|||
        | label_format timestamp="{{__timestamp__}}"
        | line_format `{{ if eq "[[pod]]" ".*" }}{{.pod | trunc 20}}:{{else}}{{.container}}:{{end}} {{__line__}}`
      |||
    )

    {
      // overwrite dashboard 'log'
      dashboards+:
        {
          logs+: g.dashboard.withLinksMixin($.grafanaDashboards['k8s-resources-cluster.json'].links)
                 + g.dashboard.withUid($._config.grafanaDashboardIDs['pods-logs.json'])
                 + g.dashboard.withTags($._config.grafanaK8s.dashboardTags)
                 + g.dashboard.withRefresh($._config.grafanaK8s.refresh),
        },
      // overwrite panel 'log'
      panels+:
        {
          logs+: g.panel.logs.options.withEnableLogDetails(true)
                 + g.panel.logs.options.withShowTime(false),
        },
    },

  grafanaDashboards+:: if $._config.enableLokiLogs then {
    'pods-logs':
      logsDash.dashboards.logs,
  } else {},
}
