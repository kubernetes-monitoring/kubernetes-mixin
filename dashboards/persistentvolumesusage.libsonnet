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

local defaultQueries = import './queries/persistentvolumesusage.libsonnet';
local defaultVariables = import './variables/persistentvolumesusage.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local prometheus = g.query.prometheus;
local gauge = g.panel.gauge;
local timeSeries = g.panel.timeSeries;

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
      // Allow overriding queries via $._queries.persistentVolume, otherwise use default
      local queries = if std.objectHas($, '_queries') && std.objectHas($._queries, 'persistentVolume')
      then $._queries.persistentVolume
      else defaultQueries;

      // Allow overriding variables via $._variables.persistentVolume, otherwise use default
      local variables = if std.objectHas($, '_variables') && std.objectHas($._variables, 'persistentVolume')
      then $._variables.persistentVolume($._config)
      else defaultVariables.persistentVolume($._config);

      local panels = {
        tsUsage:
          tsPanel.new('Volume Space Usage')
          + tsPanel.standardOptions.withUnit('bytes')
          + tsPanel.queryOptions.withTargets([
            prometheus.new('${datasource}', queries.volumeSpaceUsageUsed($._config))
            + prometheus.withLegendFormat('Used Space'),

            prometheus.new('${datasource}', queries.volumeSpaceUsageFree($._config))
            + prometheus.withLegendFormat('Free Space'),
          ]),
        gaugeUsage:
          gaugePanel(
            'Volume Space Usage',
            'percent',
            queries.volumeSpaceUsagePercent($._config)
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
            prometheus.new('${datasource}', queries.volumeInodesUsageUsed($._config))
            + prometheus.withLegendFormat('Used inodes'),

            prometheus.new('${datasource}', queries.volumeInodesUsageFree($._config))
            + prometheus.withLegendFormat('Free inodes'),
          ]),
        gaugeInodes:
          gaugePanel(
            'Volume inodes Usage',
            'percent',
            queries.volumeInodesUsagePercent($._config)
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
