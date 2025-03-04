local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
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
    'k8s-resources-pod.json':
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
            'up{%(kubeStateMetricsSelector)s}' % $._config,
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
            'kube_namespace_status_phase{%(kubeStateMetricsSelector)s, %(clusterLabel)s="$cluster"}' % $._config,
          )
          + var.query.generalOptions.withLabel('namespace')
          + var.query.refresh.onTime()
          + var.query.generalOptions.showOnDashboard.withLabelAndValue()
          + var.query.withSort(type='alphabetical'),

        pod:
          var.query.new('pod')
          + var.query.withDatasourceFromVariable(self.datasource)
          + var.query.queryTypes.withLabelValues(
            'pod',
            'kube_pod_info{%(kubeStateMetricsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace"}' % $._config,
          )
          + var.query.generalOptions.withLabel('pod')
          + var.query.refresh.onTime()
          + var.query.generalOptions.showOnDashboard.withLabelAndValue()
          + var.query.withSort(type='alphabetical'),
      };

      local cpuRequestsQuery = |||
        sum(
            kube_pod_container_resource_requests{%(kubeStateMetricsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", resource="cpu"}
        )
      ||| % $._config;

      local cpuLimitsQuery = std.strReplace(cpuRequestsQuery, 'requests', 'limits');
      local memRequestsQuery = std.strReplace(cpuRequestsQuery, 'cpu', 'memory');
      local memLimitsQuery = std.strReplace(cpuLimitsQuery, 'cpu', 'memory');

      local panels = [
        tsPanel.new('CPU Usage')
        + tsPanel.gridPos.withW(24)
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m{namespace="$namespace", pod="$pod", %(clusterLabel)s="$cluster", container!=""}) by (container)' % $._config
          )
          + prometheus.withLegendFormat('__auto'),

          prometheus.new('${datasource}', cpuRequestsQuery)
          + prometheus.withLegendFormat('requests'),

          prometheus.new('${datasource}', cpuLimitsQuery)
          + prometheus.withLegendFormat('limits'),
        ])
        + tsPanel.standardOptions.withOverrides([
          {
            matcher: {
              id: 'byFrameRefID',
              options: 'B',
            },
            properties: [
              {
                id: 'custom.lineStyle',
                value: {
                  fill: 'dash',
                },
              },
              {
                id: 'custom.lineWidth',
                value: 2,
              },
              {
                id: 'color',
                value: {
                  mode: 'fixed',
                  fixedColor: 'red',
                },
              },
            ],
          },
          {
            matcher: {
              id: 'byFrameRefID',
              options: 'C',
            },
            properties: [
              {
                id: 'custom.lineStyle',
                value: {
                  fill: 'dash',
                },
              },
              {
                id: 'custom.lineWidth',
                value: 2,
              },
              {
                id: 'color',
                value: {
                  mode: 'fixed',
                  fixedColor: 'orange',
                },
              },
            ],
          },
        ]),

        tsPanel.new('CPU Throttling')
        + tsPanel.gridPos.withW(24)
        + tsPanel.standardOptions.withUnit('percentunit')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'sum(increase(container_cpu_cfs_throttled_periods_total{%(cadvisorSelector)s, namespace="$namespace", pod="$pod", container!="", %(clusterLabel)s="$cluster"}[%(grafanaIntervalVar)s])) by (container) /sum(increase(container_cpu_cfs_periods_total{%(cadvisorSelector)s, namespace="$namespace", pod="$pod", container!="", %(clusterLabel)s="$cluster"}[%(grafanaIntervalVar)s])) by (container)' % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ])
        + tsPanel.fieldConfig.defaults.custom.withAxisSoftMin(0)
        + tsPanel.fieldConfig.defaults.custom.withAxisSoftMax(1)
        + tsPanel.fieldConfig.defaults.custom.thresholdsStyle.withMode('dashed+area')
        + tsPanel.fieldConfig.defaults.custom.withAxisColorMode('thresholds')
        + tsPanel.standardOptions.withOverrides([
          {
            matcher: {
              id: 'byFrameRefID',
              options: 'A',
            },
            properties: [
              {
                id: 'thresholds',
                value: {
                  mode: 'absolute',
                  steps: [
                    {
                      color: 'green',
                      value: null,
                    },
                    {
                      color: 'red',
                      value: $._config.cpuThrottlingPercent / 100,
                    },
                  ],
                },
              },
              {
                id: 'color',
                value: {
                  mode: 'thresholds',
                  seriesBy: 'lastNotNull',
                },
              },
            ],
          },
        ]),

        table.new('CPU Quota')
        + table.gridPos.withW(24)
        + table.queryOptions.withTargets([
          prometheus.new('${datasource}', 'sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", container!=""}) by (container)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', 'sum(cluster:namespace:pod_cpu:active:kube_pod_container_resource_requests{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", container!=""}) by (container)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', 'sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", container!=""}) by (container) / sum(cluster:namespace:pod_cpu:active:kube_pod_container_resource_requests{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", container!=""}) by (container)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', 'sum(cluster:namespace:pod_cpu:active:kube_pod_container_resource_limits{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", container!=""}) by (container)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', 'sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", container!=""}) by (container) / sum(cluster:namespace:pod_cpu:active:kube_pod_container_resource_limits{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", container!=""}) by (container)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
        ])
        + table.queryOptions.withTransformations([
          table.queryOptions.transformation.withId('joinByField')
          + table.queryOptions.transformation.withOptions({
            byField: 'container',
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
            },
            indexByName: {
              'Time 1': 0,
              'Time 2': 1,
              'Time 3': 2,
              'Time 4': 3,
              'Time 5': 4,
              container: 5,
              'Value #A': 6,
              'Value #B': 7,
              'Value #C': 8,
              'Value #D': 9,
              'Value #E': 10,
            },
            renameByName: {
              container: 'Container',
              'Value #A': 'CPU Usage',
              'Value #B': 'CPU Requests',
              'Value #C': 'CPU Requests %',
              'Value #D': 'CPU Limits',
              'Value #E': 'CPU Limits %',
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
        ]),

        tsPanel.new('Memory Usage (WSS)')
        + tsPanel.gridPos.withW(24)
        + tsPanel.standardOptions.withUnit('bytes')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'sum(container_memory_working_set_bytes{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", container!="", image!=""}) by (container)' % $._config
          )
          + prometheus.withLegendFormat('__auto'),

          prometheus.new('${datasource}', memRequestsQuery)
          + prometheus.withLegendFormat('requests'),

          prometheus.new('${datasource}', memLimitsQuery)
          + prometheus.withLegendFormat('limits'),
        ])
        + tsPanel.standardOptions.withOverrides([
          {
            matcher: {
              id: 'byFrameRefID',
              options: 'B',
            },
            properties: [
              {
                id: 'custom.lineStyle',
                value: {
                  fill: 'dash',
                },
              },
              {
                id: 'custom.lineWidth',
                value: 2,
              },
              {
                id: 'color',
                value: {
                  mode: 'fixed',
                  fixedColor: 'red',
                },
              },
            ],
          },
          {
            matcher: {
              id: 'byFrameRefID',
              options: 'C',
            },
            properties: [
              {
                id: 'custom.lineStyle',
                value: {
                  fill: 'dash',
                },
              },
              {
                id: 'custom.lineWidth',
                value: 2,
              },
              {
                id: 'color',
                value: {
                  mode: 'fixed',
                  fixedColor: 'orange',
                },
              },
            ],
          },
        ]),

        table.new('Memory Quota')
        + table.gridPos.withW(24)
        + table.standardOptions.withUnit('bytes')
        + table.queryOptions.withTargets([
          prometheus.new('${datasource}', 'sum(container_memory_working_set_bytes{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", container!="", image!=""}) by (container)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', 'sum(cluster:namespace:pod_memory:active:kube_pod_container_resource_requests{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}) by (container)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', 'sum(container_memory_working_set_bytes{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", image!=""}) by (container) / sum(cluster:namespace:pod_memory:active:kube_pod_container_resource_requests{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}) by (container)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', 'sum(cluster:namespace:pod_memory:active:kube_pod_container_resource_limits{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}) by (container)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', 'sum(container_memory_working_set_bytes{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", container!="", image!=""}) by (container) / sum(cluster:namespace:pod_memory:active:kube_pod_container_resource_limits{%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}) by (container)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', 'sum(container_memory_rss{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", container != "", container != "POD"}) by (container)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', 'sum(container_memory_cache{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", container != "", container != "POD"}) by (container)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', 'sum(container_memory_swap{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod", container != "", container != "POD"}) by (container)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
        ])
        + table.queryOptions.withTransformations([
          table.queryOptions.transformation.withId('joinByField')
          + table.queryOptions.transformation.withOptions({
            byField: 'container',
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
              'Time 7': true,
              'Time 8': true,
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
              container: 8,
              'Value #A': 9,
              'Value #B': 10,
              'Value #C': 11,
              'Value #D': 12,
              'Value #E': 13,
              'Value #F': 14,
              'Value #G': 15,
              'Value #H': 16,
            },
            renameByName: {
              container: 'Container',
              'Value #A': 'Memory Usage',
              'Value #B': 'Memory Requests',
              'Value #C': 'Memory Requests %',
              'Value #D': 'Memory Limits',
              'Value #E': 'Memory Limits %',
              'Value #F': 'Memory Usage (RSS)',
              'Value #G': 'Memory Usage (Cache)',
              'Value #H': 'Memory Usage (Swap)',
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
        ]),


        tsPanel.new('Receive Bandwidth')
        + tsPanel.standardOptions.withUnit('Bps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'sum(irate(container_network_receive_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s])) by (pod)' % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Transmit Bandwidth')
        + tsPanel.standardOptions.withUnit('Bps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'sum(rate(container_network_transmit_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s])) by (pod)' % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of Received Packets')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'sum(rate(container_network_receive_packets_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s])) by (pod)' % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of Transmitted Packets')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'sum(rate(container_network_transmit_packets_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s])) by (pod)' % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of Received Packets Dropped')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'sum(rate(container_network_receive_packets_dropped_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s])) by (pod)' % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of Transmitted Packets Dropped')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'sum(rate(container_network_transmit_packets_dropped_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s])) by (pod)' % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('IOPS (Pod)')
        + tsPanel.standardOptions.withUnit('iops')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'ceil(sum by(pod) (rate(container_fs_reads_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s])))' % $._config
          )
          + prometheus.withLegendFormat('Reads'),
          prometheus.new(
            '${datasource}',
            'ceil(sum by(pod) (rate(container_fs_writes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster",namespace="$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s])))' % $._config
          )
          + prometheus.withLegendFormat('Writes'),
        ]),

        tsPanel.new('ThroughPut (Pod)')
        + tsPanel.standardOptions.withUnit('Bps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'sum by(pod) (rate(container_fs_reads_bytes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s]))' % $._config
          )
          + prometheus.withLegendFormat('Reads'),
          prometheus.new(
            '${datasource}',
            'sum by(pod) (rate(container_fs_writes_bytes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s]))' % $._config
          )
          + prometheus.withLegendFormat('Writes'),
        ]),

        tsPanel.new('IOPS (Containers)')
        + tsPanel.standardOptions.withUnit('iops')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'ceil(sum by(container) (rate(container_fs_reads_total{%(cadvisorSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}[%(grafanaIntervalVar)s]) + rate(container_fs_writes_total{%(cadvisorSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}[%(grafanaIntervalVar)s])))' % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('ThroughPut (Containers)')
        + tsPanel.standardOptions.withUnit('Bps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'sum by(container) (rate(container_fs_reads_bytes_total{%(cadvisorSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}[%(grafanaIntervalVar)s]) + rate(container_fs_writes_bytes_total{%(cadvisorSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}[%(grafanaIntervalVar)s]))' % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        table.new('Current Storage IO')
        + table.gridPos.withW(24)
        + table.queryOptions.withTargets([
          prometheus.new('${datasource}', 'sum by(container) (rate(container_fs_reads_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}[%(grafanaIntervalVar)s]))' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum by(container) (rate(container_fs_writes_total{%(cadvisorSelector)s,%(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}[%(grafanaIntervalVar)s]))' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum by(container) (rate(container_fs_reads_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}[%(grafanaIntervalVar)s]) + rate(container_fs_writes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}[%(grafanaIntervalVar)s]))' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum by(container) (rate(container_fs_reads_bytes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}[%(grafanaIntervalVar)s]))' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum by(container) (rate(container_fs_writes_bytes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}[%(grafanaIntervalVar)s]))' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum by(container) (rate(container_fs_reads_bytes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}[%(grafanaIntervalVar)s]) + rate(container_fs_writes_bytes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}[%(grafanaIntervalVar)s]))' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
        ])

        + table.queryOptions.withTransformations([
          table.queryOptions.transformation.withId('joinByField')
          + table.queryOptions.transformation.withOptions({
            byField: 'container',
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
              container: 6,
              'Value #A': 7,
              'Value #B': 8,
              'Value #C': 9,
              'Value #D': 10,
              'Value #E': 11,
              'Value #F': 12,
            },
            renameByName: {
              container: 'Container',
              'Value #A': 'IOPS(Reads)',
              'Value #B': 'IOPS(Writes)',
              'Value #C': 'IOPS(Reads + Writes)',
              'Value #D': 'Throughput(Read)',
              'Value #E': 'Throughput(Write)',
              'Value #F': 'Throughput(Read + Write)',
            },
          }),
        ])

        + table.standardOptions.withOverrides([
          {
            matcher: {
              id: 'byRegexp',
              options: '/IOPS/',
            },
            properties: [
              {
                id: 'unit',
                value: 'iops',
              },
            ],
          },
          {
            matcher: {
              id: 'byRegexp',
              options: '/Throughput/',
            },
            properties: [
              {
                id: 'unit',
                value: 'Bps',
              },
            ],
          },
        ]),
      ];

      g.dashboard.new('%(dashboardNamePrefix)sCompute Resources / Pod' % $._config.grafanaK8s)
      + g.dashboard.withUid($._config.grafanaDashboardIDs['k8s-resources-pod.json'])
      + g.dashboard.withTags($._config.grafanaK8s.dashboardTags)
      + g.dashboard.withEditable(false)
      + g.dashboard.time.withFrom('now-1h')
      + g.dashboard.time.withTo('now')
      + g.dashboard.withRefresh($._config.grafanaK8s.refresh)
      + g.dashboard.withVariables([variables.datasource, variables.cluster, variables.namespace, variables.pod])
      + g.dashboard.withPanels(g.util.grid.wrapPanels(panels, panelWidth=12, panelHeight=7)),
  },
}
