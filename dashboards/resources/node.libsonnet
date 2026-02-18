local defaultQueries = import './queries/node.libsonnet';
local defaultVariables = import './variables/node.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

local fieldOverride = g.panel.timeSeries.fieldOverride;
local prometheus = g.query.prometheus;
local table = g.panel.table;
local timeSeries = g.panel.timeSeries;

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
    'k8s-resources-node.json':
      // Allow overriding queries via $._queries.node, otherwise use default
      local queries = if std.objectHas($, '_queries') && std.objectHas($._queries, 'node')
      then $._queries.node
      else defaultQueries;

      // Allow overriding variables via $._variables.node, otherwise use default
      local variables = if std.objectHas($, '_variables') && std.objectHas($._variables, 'node')
      then $._variables.node($._config)
      else defaultVariables.node($._config);

      local links = {
        pod: {
          title: 'Drill down to pods',
          url: '%(prefix)s/d/%(uid)s/k8s-resources-pod?${datasource:queryparam}&var-cluster=$cluster&var-namespace=$namespace&var-pod=${__data.fields.Pod}' % {
            uid: $._config.grafanaDashboardIDs['k8s-resources-pod.json'],
            prefix: $._config.grafanaK8s.linkPrefix,
          },
        },
      };

      local panels = [
        tsPanel.new('CPU Usage')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.cpuUsageCapacity($._config)
          )
          + prometheus.withLegendFormat('max capacity'),

          prometheus.new(
            '${datasource}',
            queries.cpuUsageAllocatable($._config)
          )
          + prometheus.withLegendFormat('max allocatable'),

          prometheus.new(
            '${datasource}',
            queries.cpuUsageByPod($._config)
          )
          + prometheus.withLegendFormat('{{pod}}'),
        ])
        + tsPanel.fieldConfig.defaults.custom.withStacking({ mode: 'normal' })
        + tsPanel.standardOptions.withOverrides([
          fieldOverride.byName.new('max capacity')
          + fieldOverride.byName.withPropertiesFromOptions(
            timeSeries.standardOptions.color.withMode('fixed')
            + timeSeries.standardOptions.color.withFixedColor('red')
          )
          + fieldOverride.byName.withProperty('custom.stacking', { mode: 'none' })
          + fieldOverride.byName.withProperty('custom.hideFrom', { tooltip: true, viz: false, legend: false })
          + fieldOverride.byName.withProperty('custom.lineStyle', { fill: 'dash', dash: [10, 10] }),
          fieldOverride.byName.new('max allocatable')
          + fieldOverride.byName.withPropertiesFromOptions(
            timeSeries.standardOptions.color.withMode('fixed')
            + timeSeries.standardOptions.color.withFixedColor('super-light-red')
          )
          + fieldOverride.byName.withProperty('custom.stacking', { mode: 'none' })
          + fieldOverride.byName.withProperty('custom.hideFrom', { tooltip: true, viz: false, legend: false })
          + fieldOverride.byName.withProperty('custom.lineStyle', { fill: 'dash', dash: [10, 10] })
          + fieldOverride.byName.withProperty('custom.fillOpacity', 0),
        ]),

        table.new('CPU Quota')
        + table.queryOptions.withTargets([
          prometheus.new('${datasource}', queries.cpuUsageByPod($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', queries.cpuRequestsByPod($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', queries.cpuUsageVsRequests($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', queries.cpuLimitsByPod($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', queries.cpuUsageVsLimits($._config))
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
            renameByName: {
              pod: 'Pod',
              'Value #A': 'CPU Usage',
              'Value #B': 'CPU Requests',
              'Value #C': 'CPU Requests %',
              'Value #D': 'CPU Limits',
              'Value #E': 'CPU Limits %',
            },
            excludeByName: {
              Time: true,
              'Time 1': true,
              'Time 2': true,
              'Time 3': true,
              'Time 4': true,
              'Time 5': true,
            },
          }),
        ])
        + table.standardOptions.withOverrides([
          {
            matcher: {
              id: 'byRegexp',
              options: '/%/',
            },
            properties: [
              {
                id: 'unit',
                value: 'percentunit',
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

        tsPanel.new('Memory Usage (w/cache)')
        + tsPanel.standardOptions.withUnit('bytes')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.memoryCapacity($._config),
          )
          + prometheus.withLegendFormat('max capacity'),

          prometheus.new(
            '${datasource}',
            queries.memoryAllocatable($._config),
          )
          + prometheus.withLegendFormat('max allocatable'),

          prometheus.new(
            '${datasource}',
            queries.memoryWorkingSet($._config),
          )
          + prometheus.withLegendFormat('{{pod}}'),
        ])
        + tsPanel.fieldConfig.defaults.custom.withStacking({ mode: 'normal' })
        + tsPanel.standardOptions.withOverrides([
          fieldOverride.byName.new('max capacity')
          + fieldOverride.byName.withPropertiesFromOptions(
            timeSeries.standardOptions.color.withMode('fixed')
            + timeSeries.standardOptions.color.withFixedColor('red')
          )
          + fieldOverride.byName.withProperty('custom.stacking', { mode: 'none' })
          + fieldOverride.byName.withProperty('custom.hideFrom', { tooltip: true, viz: false, legend: false })
          + fieldOverride.byName.withProperty('custom.lineStyle', { fill: 'dash', dash: [10, 10] }),
          fieldOverride.byName.new('max allocatable')
          + fieldOverride.byName.withPropertiesFromOptions(
            timeSeries.standardOptions.color.withMode('fixed')
            + timeSeries.standardOptions.color.withFixedColor('super-light-red')
          )
          + fieldOverride.byName.withProperty('custom.stacking', { mode: 'none' })
          + fieldOverride.byName.withProperty('custom.hideFrom', { tooltip: true, viz: false, legend: false })
          + fieldOverride.byName.withProperty('custom.lineStyle', { fill: 'dash', dash: [10, 10] })
          + fieldOverride.byName.withProperty('custom.fillOpacity', 0),
        ]),

        tsPanel.new('Memory Usage (w/o cache)')
        + tsPanel.standardOptions.withUnit('bytes')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            queries.memoryCapacity($._config),
          )
          + prometheus.withLegendFormat('max capacity'),

          prometheus.new(
            '${datasource}',
            queries.memoryAllocatable($._config),
          )
          + prometheus.withLegendFormat('max allocatable'),

          prometheus.new(
            '${datasource}',
            queries.memoryUsageRssQuota($._config),
          )
          + prometheus.withLegendFormat('{{pod}}'),
        ])
        + tsPanel.fieldConfig.defaults.custom.withStacking({ mode: 'normal' })
        + tsPanel.standardOptions.withOverrides([
          fieldOverride.byName.new('max capacity')
          + fieldOverride.byName.withPropertiesFromOptions(
            timeSeries.standardOptions.color.withMode('fixed')
            + timeSeries.standardOptions.color.withFixedColor('red')
          )
          + fieldOverride.byName.withProperty('custom.stacking', { mode: 'none' })
          + fieldOverride.byName.withProperty('custom.hideFrom', { tooltip: true, viz: false, legend: false })
          + fieldOverride.byName.withProperty('custom.lineStyle', { fill: 'dash', dash: [10, 10] }),
          fieldOverride.byName.new('max allocatable')
          + fieldOverride.byName.withPropertiesFromOptions(
            timeSeries.standardOptions.color.withMode('fixed')
            + timeSeries.standardOptions.color.withFixedColor('super-light-red')
          )
          + fieldOverride.byName.withProperty('custom.stacking', { mode: 'none' })
          + fieldOverride.byName.withProperty('custom.hideFrom', { tooltip: true, viz: false, legend: false })
          + fieldOverride.byName.withProperty('custom.lineStyle', { fill: 'dash', dash: [10, 10] })
          + fieldOverride.byName.withProperty('custom.fillOpacity', 0),
        ]),

        table.new('Memory Quota')
        + table.standardOptions.withUnit('bytes')
        + table.queryOptions.withTargets([
          prometheus.new('${datasource}', queries.memoryWorkingSetQuota($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', queries.memoryRequestsByPod($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', queries.memoryUsageVsRequests($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', queries.memoryLimitsByPod($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', queries.memoryUsageVsLimits($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', queries.memoryUsageRssQuota($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', queries.memoryUsageCacheQuota($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', queries.memoryUsageSwapQuota($._config))
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
            renameByName: {
              pod: 'Pod',
              'Value #A': 'Memory Usage',
              'Value #B': 'Memory Requests',
              'Value #C': 'Memory Requests %',
              'Value #D': 'Memory Limits',
              'Value #E': 'Memory Limits %',
              'Value #F': 'Memory Usage (RSS)',
              'Value #G': 'Memory Usage (Cache)',
              'Value #H': 'Memory Usage (Swap)',
            },
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
          }),
        ])
        + table.standardOptions.withOverrides([
          {
            matcher: {
              id: 'byRegexp',
              options: '/%/',
            },
            properties: [
              {
                id: 'unit',
                value: 'percentunit',
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
      ];

      g.dashboard.new('%(dashboardNamePrefix)sCompute Resources / Node (Pods)' % $._config.grafanaK8s)
      + g.dashboard.withUid($._config.grafanaDashboardIDs['k8s-resources-node.json'])
      + g.dashboard.withTags($._config.grafanaK8s.dashboardTags)
      + g.dashboard.withEditable(false)
      + g.dashboard.time.withFrom('now-1h')
      + g.dashboard.time.withTo('now')
      + g.dashboard.withRefresh($._config.grafanaK8s.refresh)
      + g.dashboard.withVariables([variables.datasource, variables.cluster, variables.node])
      + g.dashboard.withPanels(g.util.grid.wrapPanels(panels, panelWidth=24, panelHeight=6)),
  },
}
