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
    'k8s-resources-workloads-namespace.json':
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
          title: 'Drill down to workloads',
          url: '%(prefix)s/d/%(uid)s/k8s-resources-workload?${datasource:queryparam}&var-cluster=$cluster&var-namespace=$namespace&var-type=${__data.fields.Type}&var-workload=${__data.fields.Workload}' % {
            uid: $._config.grafanaDashboardIDs['k8s-resources-workload.json'],
            prefix: $._config.grafanaK8s.linkPrefix,
          },
        },
      };

      local cpuUsageQuery = |||
        sum(
          node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m{%(clusterLabel)s="$cluster", namespace="$namespace"}
        * on(namespace,pod)
          group_left(workload, workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster", namespace="$namespace", workload_type=~"$type"}
        ) by (workload, workload_type)
      ||| % $._config;

      local cpuRequestsQuery = |||
        sum(
          kube_pod_container_resource_requests{%(kubeStateMetricsSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", resource="cpu"}
        * on(namespace,pod)
          group_left(workload, workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster", namespace="$namespace", workload_type=~"$type"}
        ) by (workload, workload_type)
      ||| % $._config;

      local podCountQuery = 'count(namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster", namespace="$namespace", workload_type=~"$type"}) by (workload, workload_type)' % $._config;
      local cpuLimitsQuery = std.strReplace(cpuRequestsQuery, 'requests', 'limits');

      local memUsageQuery = |||
        sum(
            container_memory_working_set_bytes{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace", container!="", image!=""}
          * on(namespace,pod)
            group_left(workload, workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster", namespace="$namespace", workload_type=~"$type"}
        ) by (workload, workload_type)
      ||| % $._config;
      local memRequestsQuery = std.strReplace(cpuRequestsQuery, 'cpu', 'memory');
      local memLimitsQuery = std.strReplace(cpuLimitsQuery, 'cpu', 'memory');

      local cpuQuotaRequestsQuery = 'scalar(max(kube_resourcequota{%(clusterLabel)s="$cluster", namespace="$namespace", type="hard",resource=~"requests.cpu|cpu"}))' % $._config;
      local cpuQuotaLimitsQuery = std.strReplace(cpuQuotaRequestsQuery, 'requests.cpu|cpu', 'limits.cpu');
      local memoryQuotaRequestsQuery = std.strReplace(cpuQuotaRequestsQuery, 'requests.cpu|cpu', 'requests.memory|memory');
      local memoryQuotaLimitsQuery = std.strReplace(cpuQuotaRequestsQuery, 'requests.cpu|cpu', 'limits.memory');

      local networkColumns = [
        |||
          (sum(rate(container_network_receive_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace"}[%(grafanaIntervalVar)s])
          * on (namespace,pod)
          group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace", workload_type=~"$type"}) by (workload))
        ||| % $._config,
        |||
          (sum(rate(container_network_transmit_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace"}[%(grafanaIntervalVar)s])
          * on (namespace,pod)
          group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace", workload_type=~"$type"}) by (workload))
        ||| % $._config,
        |||
          (sum(rate(container_network_receive_packets_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace"}[%(grafanaIntervalVar)s])
          * on (namespace,pod)
          group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace", workload_type=~"$type"}) by (workload))
        ||| % $._config,
        |||
          (sum(rate(container_network_transmit_packets_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace"}[%(grafanaIntervalVar)s])
          * on (namespace,pod)
          group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace", workload_type=~"$type"}) by (workload))
        ||| % $._config,
        |||
          (sum(rate(container_network_receive_packets_dropped_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace"}[%(grafanaIntervalVar)s])
          * on (namespace,pod)
          group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace", workload_type=~"$type"}) by (workload))
        ||| % $._config,
        |||
          (sum(rate(container_network_transmit_packets_dropped_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace"}[%(grafanaIntervalVar)s])
          * on (namespace,pod)
          group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace", workload_type=~"$type"}) by (workload))
        ||| % $._config,
      ];

      local panels = [
        tsPanel.new('CPU Usage')
        + tsPanel.gridPos.withW(24)
        + tsPanel.queryOptions.withTargets([
          prometheus.new('${datasource}', cpuUsageQuery)
          + prometheus.withLegendFormat('{{workload}} - {{workload_type}}'),

          prometheus.new('${datasource}', cpuQuotaRequestsQuery)
          + prometheus.withLegendFormat('quota - requests'),

          prometheus.new('${datasource}', cpuQuotaLimitsQuery)
          + prometheus.withLegendFormat('quota - limits'),
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

        table.new('CPU Quota')
        + table.gridPos.withW(24)
        + table.queryOptions.withTargets([
          prometheus.new('${datasource}', podCountQuery)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', cpuUsageQuery)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', cpuRequestsQuery)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', cpuUsageQuery + '/' + cpuRequestsQuery)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', cpuLimitsQuery)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', cpuUsageQuery + '/' + cpuLimitsQuery)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
        ])
        + table.queryOptions.withTransformations([
          table.queryOptions.transformation.withId('joinByField')
          + table.queryOptions.transformation.withOptions({
            byField: 'workload',
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
              'workload_type 2': true,
              'workload_type 3': true,
              'workload_type 4': true,
              'workload_type 5': true,
              'workload_type 6': true,
            },
            indexByName: {
              'Time 1': 0,
              'Time 2': 1,
              'Time 3': 2,
              'Time 4': 3,
              'Time 5': 4,
              'Time 6': 5,
              workload: 6,
              'workload_type 1': 7,
              'Value #A': 8,
              'Value #B': 9,
              'Value #C': 10,
              'Value #D': 11,
              'Value #E': 12,
              'Value #F': 13,
              'workload_type 2': 14,
              'workload_type 3': 15,
              'workload_type 4': 16,
              'workload_type 5': 17,
              'workload_type 6': 18,
            },
            renameByName: {
              workload: 'Workload',
              'workload_type 1': 'Type',
              'Value #A': 'Running Pods',
              'Value #B': 'CPU Usage',
              'Value #C': 'CPU Requests',
              'Value #D': 'CPU Requests %',
              'Value #E': 'CPU Limits',
              'Value #F': 'CPU Limits %',
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
              options: 'Workload',
            },
            properties: [
              {
                id: 'links',
                value: [links.workload],
              },
            ],
          },
          {
            matcher: {
              id: 'byName',
              options: 'Running Pods',
            },
            properties: [
              {
                id: 'unit',
                value: 'none',
              },
            ],
          },
        ]),

        tsPanel.new('Memory Usage')
        + tsPanel.gridPos.withW(24)
        + tsPanel.standardOptions.withUnit('bytes')
        + tsPanel.queryOptions.withTargets([
          prometheus.new('${datasource}', memUsageQuery)
          + prometheus.withLegendFormat('{{workload}} - {{workload_type}}'),
          prometheus.new('${datasource}', memoryQuotaRequestsQuery)
          + prometheus.withLegendFormat('quota - requests'),
          prometheus.new('${datasource}', memoryQuotaLimitsQuery)
          + prometheus.withLegendFormat('quota - limits'),
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
          prometheus.new('${datasource}', podCountQuery)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', memUsageQuery)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', memRequestsQuery)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', memUsageQuery + '/' + memRequestsQuery)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', memLimitsQuery)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', memUsageQuery + '/' + memLimitsQuery)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
        ])
        + table.queryOptions.withTransformations([
          table.queryOptions.transformation.withId('joinByField')
          + table.queryOptions.transformation.withOptions({
            byField: 'workload',
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
              'workload_type 2': true,
              'workload_type 3': true,
              'workload_type 4': true,
              'workload_type 5': true,
              'workload_type 6': true,
            },
            indexByName: {
              'Time 1': 0,
              'Time 2': 1,
              'Time 3': 2,
              'Time 4': 3,
              'Time 5': 4,
              'Time 6': 5,
              workload: 6,
              'workload_type 1': 7,
              'Value #A': 8,
              'Value #B': 9,
              'Value #C': 10,
              'Value #D': 11,
              'Value #E': 12,
              'Value #F': 13,
              'workload_type 2': 14,
              'workload_type 3': 15,
              'workload_type 4': 16,
              'workload_type 5': 17,
              'workload_type 6': 18,
            },
            renameByName: {
              workload: 'Workload',
              'workload_type 1': 'Type',
              'Value #A': 'Running Pods',
              'Value #B': 'Memory Usage',
              'Value #C': 'Memory Requests',
              'Value #D': 'Memory Requests %',
              'Value #E': 'Memory Limits',
              'Value #F': 'Memory Limits %',
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
              options: 'Workload',
            },
            properties: [
              {
                id: 'links',
                value: [links.workload],
              },
            ],
          },
          {
            matcher: {
              id: 'byName',
              options: 'Running Pods',
            },
            properties: [
              {
                id: 'unit',
                value: 'none',
              },
            ],
          },
        ]),

        table.new('Current Network Usage')
        + table.gridPos.withW(24)
        + table.queryOptions.withTargets([
          prometheus.new('${datasource}', networkColumns[0])
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', networkColumns[1])
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', networkColumns[2])
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', networkColumns[3])
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', networkColumns[4])
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
          prometheus.new('${datasource}', networkColumns[5])
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
        ])

        + table.queryOptions.withTransformations([
          table.queryOptions.transformation.withId('joinByField')
          + table.queryOptions.transformation.withOptions({
            byField: 'workload',
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
              workload: 6,
              'Value #A': 7,
              'Value #B': 8,
              'Value #C': 9,
              'Value #D': 10,
              'Value #E': 11,
              'Value #F': 12,
            },
            renameByName: {
              workload: 'Workload',
              'Value #A': 'Current Receive Bandwidth',
              'Value #B': 'Current Transmit Bandwidth',
              'Value #C': 'Rate of Received Packets',
              'Value #D': 'Rate of Transmitted Packets',
              'Value #E': 'Rate of Received Packets Dropped',
              'Value #F': 'Rate of Transmitted Packets Dropped',
            },
          }),
        ])

        + table.standardOptions.withOverrides([
          {
            matcher: {
              id: 'byRegexp',
              options: '/Bandwidth/',
            },
            properties: [
              {
                id: 'unit',
                value: 'Bps',
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
              (sum(rate(container_network_receive_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace"}[%(grafanaIntervalVar)s])
              * on (namespace,pod)
              group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace", workload=~".+", workload_type=~"$type"}) by (workload))
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
              (sum(rate(container_network_transmit_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace"}[%(grafanaIntervalVar)s])
              * on (namespace,pod)
              group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace", workload=~".+", workload_type=~"$type"}) by (workload))
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
              (avg(rate(container_network_receive_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace"}[%(grafanaIntervalVar)s])
              * on (namespace,pod)
              group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace", workload=~".+", workload_type=~"$type"}) by (workload))
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
              (avg(rate(container_network_transmit_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace"}[%(grafanaIntervalVar)s])
              * on (namespace,pod)
              group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace", workload=~".+", workload_type=~"$type"}) by (workload))
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
              (sum(rate(container_network_receive_packets_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace"}[%(grafanaIntervalVar)s])
              * on (namespace,pod)
              group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace", workload=~".+", workload_type=~"$type"}) by (workload))
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
              (sum(rate(container_network_transmit_packets_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace"}[%(grafanaIntervalVar)s])
              * on (namespace,pod)
              group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace", workload=~".+", workload_type=~"$type"}) by (workload))
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
              (sum(rate(container_network_receive_packets_dropped_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace"}[%(grafanaIntervalVar)s])
              * on (namespace,pod)
              group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace", workload=~".+", workload_type=~"$type"}) by (workload))
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
              (sum(rate(container_network_transmit_packets_dropped_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", namespace="$namespace"}[%(grafanaIntervalVar)s])
              * on (namespace,pod)
              group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster", %(namespaceLabel)s="$namespace", workload=~".+", workload_type=~"$type"}) by (workload))
            ||| % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),
      ];

      g.dashboard.new('%(dashboardNamePrefix)sCompute Resources / Namespace (Workloads)' % $._config.grafanaK8s)
      + g.dashboard.withUid($._config.grafanaDashboardIDs['k8s-resources-workloads-namespace.json'])
      + g.dashboard.withTags($._config.grafanaK8s.dashboardTags)
      + g.dashboard.withEditable(false)
      + g.dashboard.time.withFrom('now-1h')
      + g.dashboard.time.withTo('now')
      + g.dashboard.withRefresh($._config.grafanaK8s.refresh)
      + g.dashboard.withVariables([variables.datasource, variables.cluster, variables.namespace, variables.workload_type])
      + g.dashboard.withPanels(g.util.grid.wrapPanels(panels, panelWidth=12, panelHeight=7)),
  },
}
