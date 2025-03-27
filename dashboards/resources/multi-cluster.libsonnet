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
        + timeSeries.options.tooltip.withMode('single')
        + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
        + timeSeries.queryOptions.withInterval($._config.grafanaK8s.minimumTimeInterval),
    },

  grafanaDashboards+::
    if $._config.showMultiCluster then {
      'k8s-resources-multicluster.json':
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
        };

        local links = {
          cluster: {
            title: 'Drill down',
            url: '%(prefix)s/d/%(uid)s/kubernetes-compute-resources-cluster?${datasource:queryparam}&var-cluster=${__data.fields.Cluster}' % {
              uid: $._config.grafanaDashboardIDs['k8s-resources-cluster.json'],
              prefix: $._config.grafanaK8s.linkPrefix,
            },
          },
        };

        local panels = {
          highlights: [
            statPanel(
              'CPU Utilisation',
              'none',
              'sum(cluster:node_cpu:ratio_rate5m) / count(cluster:node_cpu:ratio_rate5m)'
            ),

            statPanel(
              'CPU Requests Commitment',
              'percentunit',
              'sum(kube_pod_container_resource_requests{%(kubeStateMetricsSelector)s, resource="cpu"}) / sum(kube_node_status_allocatable{%(kubeStateMetricsSelector)s, resource="cpu"})' % $._config
            ),

            statPanel(
              'CPU Limits Commitment',
              'percentunit',
              'sum(kube_pod_container_resource_limits{%(kubeStateMetricsSelector)s, resource="cpu"}) / sum(kube_node_status_allocatable{%(kubeStateMetricsSelector)s, resource="cpu"})' % $._config
            ),

            statPanel(
              'Memory Utilisation',
              'percentunit',
              '1 - sum(:node_memory_MemAvailable_bytes:sum) / sum(node_memory_MemTotal_bytes{%(nodeExporterSelector)s})' % $._config
            ),

            statPanel(
              'Memory Requests Commitment',
              'percentunit',
              'sum(kube_pod_container_resource_requests{%(kubeStateMetricsSelector)s, resource="memory"}) / sum(kube_node_status_allocatable{%(kubeStateMetricsSelector)s, resource="memory"})' % $._config
            ),

            statPanel(
              'Memory Limits Commitment',
              'percentunit',
              'sum(kube_pod_container_resource_limits{%(kubeStateMetricsSelector)s, resource="memory"}) / sum(kube_node_status_allocatable{%(kubeStateMetricsSelector)s, resource="memory"})' % $._config
            ),
          ],

          cpuUsage: [
            tsPanel.new('CPU Usage')
            + tsPanel.queryOptions.withTargets([
              prometheus.new('${datasource}', 'sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m) by (%(clusterLabel)s)' % $._config)
              + prometheus.withLegendFormat('__auto'),
            ]),
          ],

          cpuQuota: [
            g.panel.table.new('CPU Quota')
            + g.panel.table.queryOptions.withTargets([
              prometheus.new('${datasource}', 'sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m) by (%(clusterLabel)s)' % $._config)
              + prometheus.withInstant(true)
              + prometheus.withFormat('table'),
              prometheus.new('${datasource}', 'sum(kube_pod_container_resource_requests{%(kubeStateMetricsSelector)s, resource="cpu"}) by (%(clusterLabel)s)' % $._config)
              + prometheus.withInstant(true)
              + prometheus.withFormat('table'),
              prometheus.new('${datasource}', 'sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m) by (%(clusterLabel)s) / sum(kube_pod_container_resource_requests{%(kubeStateMetricsSelector)s, resource="cpu"}) by (%(clusterLabel)s)' % $._config)
              + prometheus.withInstant(true)
              + prometheus.withFormat('table'),
              prometheus.new('${datasource}', 'sum(kube_pod_container_resource_limits{%(kubeStateMetricsSelector)s, resource="cpu"}) by (%(clusterLabel)s)' % $._config)
              + prometheus.withInstant(true)
              + prometheus.withFormat('table'),
              prometheus.new('${datasource}', 'sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m) by (%(clusterLabel)s) / sum(kube_pod_container_resource_limits{%(kubeStateMetricsSelector)s, resource="cpu"}) by (%(clusterLabel)s)' % $._config)
              + prometheus.withInstant(true)
              + prometheus.withFormat('table'),
            ])
            + g.panel.table.queryOptions.withTransformations([
              g.panel.table.queryOptions.transformation.withId('joinByField')
              + g.panel.table.queryOptions.transformation.withOptions({
                byField: std.format('%s', $._config.clusterLabel),
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
                },
                indexByName: {
                  'Time 1': 0,
                  'Time 2': 1,
                  'Time 3': 2,
                  'Time 4': 3,
                  'Time 5': 4,
                  cluster: 5,
                  'Value #A': 6,
                  'Value #B': 7,
                  'Value #C': 8,
                  'Value #D': 9,
                  'Value #E': 10,
                },
                renameByName: {
                  cluster: 'Cluster',
                  'Value #A': 'CPU Usage',
                  'Value #B': 'CPU Requests',
                  'Value #C': 'CPU Requests %',
                  'Value #D': 'CPU Limits',
                  'Value #E': 'CPU Limits %',
                },
              }),
            ])

            + g.panel.table.standardOptions.withOverrides([
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
                  options: 'Cluster',
                },
                properties: [
                  {
                    id: 'links',
                    value: [links.cluster],
                  },
                ],
              },
            ]),
          ],

          memoryUsage: [
            tsPanel.new('Memory Usage (w/o cache)')
            + tsPanel.standardOptions.withUnit('bytes')
            + tsPanel.queryOptions.withTargets([
              // Not using container_memory_usage_bytes here because that includes page cache
              prometheus.new('${datasource}', 'sum(container_memory_rss{%(cadvisorSelector)s, container!=""}) by (%(clusterLabel)s)' % $._config)
              + prometheus.withLegendFormat('__auto'),
            ]),
          ],

          memoryRequests: [
            g.panel.table.new('Memory Requests by Cluster')
            + g.panel.table.standardOptions.withUnit('bytes')
            + g.panel.table.queryOptions.withTargets([
              prometheus.new('${datasource}', 'sum(container_memory_rss{%(cadvisorSelector)s, container!=""}) by (%(clusterLabel)s)' % $._config)
              + prometheus.withInstant(true)
              + prometheus.withFormat('table'),
              prometheus.new('${datasource}', 'sum(kube_pod_container_resource_requests{%(kubeStateMetricsSelector)s, resource="memory"}) by (%(clusterLabel)s)' % $._config)
              + prometheus.withInstant(true)
              + prometheus.withFormat('table'),
              prometheus.new('${datasource}', 'sum(container_memory_rss{%(cadvisorSelector)s, container!=""}) by (%(clusterLabel)s) / sum(kube_pod_container_resource_requests{%(kubeStateMetricsSelector)s, resource="memory"}) by (%(clusterLabel)s)' % $._config)
              + prometheus.withInstant(true)
              + prometheus.withFormat('table'),
              prometheus.new('${datasource}', 'sum(kube_pod_container_resource_limits{%(kubeStateMetricsSelector)s, resource="memory"}) by (%(clusterLabel)s)' % $._config)
              + prometheus.withInstant(true)
              + prometheus.withFormat('table'),
              prometheus.new('${datasource}', 'sum(container_memory_rss{%(cadvisorSelector)s, container!=""}) by (%(clusterLabel)s) / sum(kube_pod_container_resource_limits{%(kubeStateMetricsSelector)s, resource="memory"}) by (%(clusterLabel)s)' % $._config)
              + prometheus.withInstant(true)
              + prometheus.withFormat('table'),
            ])
            + g.panel.table.queryOptions.withTransformations([
              g.panel.table.queryOptions.transformation.withId('joinByField')
              + g.panel.table.queryOptions.transformation.withOptions({
                byField: std.format('%s', $._config.clusterLabel),
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
                },
                indexByName: {
                  'Time 1': 0,
                  'Time 2': 1,
                  'Time 3': 2,
                  'Time 4': 3,
                  'Time 5': 4,
                  cluster: 5,
                  'Value #A': 6,
                  'Value #B': 7,
                  'Value #C': 8,
                  'Value #D': 9,
                  'Value #E': 10,
                },
                renameByName: {
                  cluster: 'Cluster',
                  'Value #A': 'Memory Usage',
                  'Value #B': 'Memory Requests',
                  'Value #C': 'Memory Requests %',
                  'Value #D': 'Memory Limits',
                  'Value #E': 'Memory Limits %',
                },
              }),
            ])

            + g.panel.table.standardOptions.withOverrides([
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
                  options: 'Cluster',
                },
                properties: [
                  {
                    id: 'links',
                    value: [links.cluster],
                  },
                ],
              },
            ]),
          ],
        };

        g.dashboard.new('%(dashboardNamePrefix)sCompute Resources /  Multi-Cluster' % $._config.grafanaK8s)
        + g.dashboard.withUid($._config.grafanaDashboardIDs['k8s-resources-multicluster.json'])
        + g.dashboard.withTags($._config.grafanaK8s.dashboardTags)
        + g.dashboard.withEditable(false)
        + g.dashboard.time.withFrom('now-1h')
        + g.dashboard.time.withTo('now')
        + g.dashboard.withRefresh($._config.grafanaK8s.refresh)
        + g.dashboard.withVariables([variables.datasource])
        + g.dashboard.withPanels(
          g.util.grid.wrapPanels(panels.highlights, panelWidth=4, panelHeight=3, startY=0)
          + g.util.grid.wrapPanels(panels.cpuUsage, panelWidth=24, panelHeight=7, startY=1)
          + g.util.grid.wrapPanels(panels.cpuQuota, panelWidth=24, panelHeight=7, startY=2)
          + g.util.grid.wrapPanels(panels.memoryUsage, panelWidth=24, panelHeight=7, startY=3)
          + g.util.grid.wrapPanels(panels.memoryRequests, panelWidth=24, panelHeight=7, startY=4)
        ),
    } else {},
}
