// Copyright kubernetes-mixin Authors
// SPDX-License-Identifier: Apache-2.0
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

local defaultQueries = import './queries/cluster-total.libsonnet';
local defaultVariables = import './variables/cluster-total.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
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
        + timeSeries.options.tooltip.withMode('single')
        + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
        + timeSeries.queryOptions.withInterval($._config.grafanaK8s.minimumTimeInterval),
    },

  grafanaDashboards+:: {
    'cluster-total.json':
      // Allow overriding queries via $._queries.clusterTotal, otherwise use default
      local queries = if std.objectHas($, '_queries') && std.objectHas($._queries, 'clusterTotal')
      then $._queries.clusterTotal
      else defaultQueries;

      // Allow overriding variables via $._variables.clusterTotal, otherwise use default
      local variables = if std.objectHas($, '_variables') && std.objectHas($._variables, 'clusterTotal')
      then $._variables.clusterTotal($._config)
      else defaultVariables.clusterTotal($._config);

      local links = {
        namespace: {
          title: 'Drill down',
          url: '%(prefix)s/d/%(uid)s?${datasource:queryparam}&var-cluster=${cluster}&var-namespace=${__data.fields.Namespace}' % {
            uid: $._config.grafanaDashboardIDs['namespace-by-pod.json'],
            prefix: $._config.grafanaK8s.linkPrefix,
          },
        },
      };

      local panels = [
        tsPanel.new('Current Rate of %(unit)s Received' % { unit: $._config.units.networkUnitLabel })
        + tsPanel.standardOptions.withUnit($._config.units.network)
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}', queries.receiveBandwidth($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Current Rate of %(unit)s Transmitted' % { unit: $._config.units.networkUnitLabel })
        + tsPanel.standardOptions.withUnit($._config.units.network)
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}', queries.transmitBandwidth($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        table.new('Current Status')
        + table.gridPos.withW(24)
        + table.queryOptions.withTargets([
          prometheus.new('${datasource}', queries.receiveBandwidth($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.transmitBandwidth($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.avgReceiveBandwidth($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.avgTransmitBandwidth($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.receivePackets($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.transmitPackets($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.receivePacketsDropped($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', queries.transmitPacketsDropped($._config))
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
        ])
        + table.queryOptions.withTransformations([
          table.queryOptions.transformation.withId('joinByField')
          + table.queryOptions.transformation.withOptions({
            byField: 'namespace',
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
              namespace: 8,
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
              namespace: 'Namespace',
              'Value #A': 'Rx %(unit)s' % { unit: $._config.units.networkUnitLabel },
              'Value #B': 'Tx %(unit)s' % { unit: $._config.units.networkUnitLabel },
              'Value #C': 'Rx %(unit)s (Avg)' % { unit: $._config.units.networkUnitLabel },
              'Value #D': 'Tx %(unit)s (Avg)' % { unit: $._config.units.networkUnitLabel },
              'Value #E': 'Rx Packets',
              'Value #F': 'Tx Packets',
              'Value #G': 'Rx Packets Dropped',
              'Value #H': 'Tx Packets Dropped',
            },
          }),
        ])

        + table.standardOptions.withOverrides([
          {
            matcher: {
              id: 'byRegexp',
              options: '/%(unit)s/' % { unit: $._config.units.networkUnitLabel },
            },
            properties: [
              {
                id: 'unit',
                value: $._config.units.network,
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
              options: 'Namespace',
            },
            properties: [
              {
                id: 'links',
                value: [links.namespace],
              },
            ],
          },
        ]),

        tsPanel.new('Average Rate of %(unit)s Received' % { unit: $._config.units.networkUnitLabel })
        + tsPanel.standardOptions.withUnit($._config.units.network)
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}', queries.avgReceiveBandwidth($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Average Rate of %(unit)s Transmitted' % { unit: $._config.units.networkUnitLabel })
        + tsPanel.standardOptions.withUnit($._config.units.network)
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}', queries.avgTransmitBandwidth($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Receive Bandwidth')
        + tsPanel.standardOptions.withUnit($._config.units.network)
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}', queries.receiveBandwidth($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Transmit Bandwidth')
        + tsPanel.standardOptions.withUnit($._config.units.network)
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}', queries.transmitBandwidth($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of Received Packets')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new('${datasource}', queries.receivePackets($._config))
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of Transmitted Packets')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new('${datasource}', queries.transmitPackets($._config))
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of Received Packets Dropped')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new('${datasource}', queries.receivePacketsDropped($._config))
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of Transmitted Packets Dropped')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new('${datasource}', queries.transmitPacketsDropped($._config))
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of TCP Retransmits out of all sent segments')
        + tsPanel.standardOptions.withUnit('percentunit')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}', queries.tcpRetransmitRate($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of TCP SYN Retransmits out of all retransmits')
        + tsPanel.standardOptions.withUnit('percentunit')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}', queries.tcpSynRetransmitRate($._config)
          )
          + prometheus.withLegendFormat('__auto'),
        ]),
      ];

      g.dashboard.new('%(dashboardNamePrefix)sNetworking / Cluster' % $._config.grafanaK8s)
      + g.dashboard.withUid($._config.grafanaDashboardIDs['cluster-total.json'])
      + g.dashboard.withTags($._config.grafanaK8s.dashboardTags)
      + g.dashboard.withEditable(false)
      + g.dashboard.time.withFrom('now-1h')
      + g.dashboard.time.withTo('now')
      + g.dashboard.withRefresh($._config.grafanaK8s.refresh)
      + g.dashboard.withVariables([variables.datasource, variables.cluster])
      + g.dashboard.withPanels(g.util.grid.wrapPanels(panels, panelWidth=12, panelHeight=9)),
  },
}
