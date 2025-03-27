local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

local fieldOverride = g.panel.timeSeries.fieldOverride;
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
    'k8s-resources-node.json':
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
        node:
          var.query.new('node')
          + var.query.withDatasourceFromVariable(self.datasource)
          + var.query.queryTypes.withLabelValues(
            'node',
            'kube_node_info{%(clusterLabel)s="$cluster"}' % $._config
          )
          + var.query.generalOptions.withLabel('node')
          + var.query.refresh.onTime()
          + var.query.generalOptions.showOnDashboard.withLabelAndValue()
          + var.query.selectionOptions.withMulti(true),
      };

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
            'sum(kube_node_status_capacity{%(clusterLabel)s="$cluster", %(kubeStateMetricsSelector)s, node=~"$node", resource="cpu"})' % $._config,
          )
          + prometheus.withLegendFormat('max capacity'),

          prometheus.new(
            '${datasource}',
            'sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m{%(clusterLabel)s="$cluster", node=~"$node"}) by (pod)' % $._config,
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
        ]),

        table.new('CPU Quota')
        + table.queryOptions.withTargets([
          prometheus.new('${datasource}', 'sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m{%(clusterLabel)s="$cluster", node=~"$node"}) by (pod)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', 'sum(cluster:namespace:pod_cpu:active:kube_pod_container_resource_requests{%(clusterLabel)s="$cluster", node=~"$node"}) by (pod)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', 'sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m{%(clusterLabel)s="$cluster", node=~"$node"}) by (pod) / sum(cluster:namespace:pod_cpu:active:kube_pod_container_resource_requests{%(clusterLabel)s="$cluster", node=~"$node"}) by (pod)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', 'sum(cluster:namespace:pod_cpu:active:kube_pod_container_resource_limits{%(clusterLabel)s="$cluster", node=~"$node"}) by (pod)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', 'sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m{%(clusterLabel)s="$cluster", node=~"$node"}) by (pod) / sum(cluster:namespace:pod_cpu:active:kube_pod_container_resource_limits{%(clusterLabel)s="$cluster", node=~"$node"}) by (pod)' % $._config)
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
            'sum(kube_node_status_capacity{%(clusterLabel)s="$cluster", %(kubeStateMetricsSelector)s, node=~"$node", resource="memory"})' % $._config,
          )
          + prometheus.withLegendFormat('max capacity'),

          prometheus.new(
            '${datasource}',
            'sum(node_namespace_pod_container:container_memory_working_set_bytes{%(clusterLabel)s="$cluster", node=~"$node", container!=""}) by (pod)' % $._config,
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
        ]),

        tsPanel.new('Memory Usage (w/o cache)')
        + tsPanel.standardOptions.withUnit('bytes')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'sum(kube_node_status_capacity{%(clusterLabel)s="$cluster", %(kubeStateMetricsSelector)s, node=~"$node", resource="memory"})' % $._config,
          )
          + prometheus.withLegendFormat('max capacity'),

          prometheus.new(
            '${datasource}',
            'sum(node_namespace_pod_container:container_memory_rss{%(clusterLabel)s="$cluster", node=~"$node", container!=""}) by (pod)' % $._config,
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
        ]),

        table.new('Memory Quota')
        + table.standardOptions.withUnit('bytes')
        + table.queryOptions.withTargets([
          prometheus.new('${datasource}', 'sum(node_namespace_pod_container:container_memory_working_set_bytes{%(clusterLabel)s="$cluster", node=~"$node",container!=""}) by (pod)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', 'sum(cluster:namespace:pod_memory:active:kube_pod_container_resource_requests{%(clusterLabel)s="$cluster", node=~"$node"}) by (pod)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', 'sum(node_namespace_pod_container:container_memory_working_set_bytes{%(clusterLabel)s="$cluster", node=~"$node",container!=""}) by (pod) / sum(cluster:namespace:pod_memory:active:kube_pod_container_resource_requests{%(clusterLabel)s="$cluster", node=~"$node"}) by (pod)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', 'sum(cluster:namespace:pod_memory:active:kube_pod_container_resource_limits{%(clusterLabel)s="$cluster", node=~"$node"}) by (pod)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', 'sum(node_namespace_pod_container:container_memory_working_set_bytes{%(clusterLabel)s="$cluster", node=~"$node",container!=""}) by (pod) / sum(cluster:namespace:pod_memory:active:kube_pod_container_resource_limits{%(clusterLabel)s="$cluster", node=~"$node"}) by (pod)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', 'sum(node_namespace_pod_container:container_memory_rss{%(clusterLabel)s="$cluster", node=~"$node",container!=""}) by (pod)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', 'sum(node_namespace_pod_container:container_memory_cache{%(clusterLabel)s="$cluster", node=~"$node",container!=""}) by (pod)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', 'sum(node_namespace_pod_container:container_memory_swap{%(clusterLabel)s="$cluster", node=~"$node",container!=""}) by (pod)' % $._config)
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
