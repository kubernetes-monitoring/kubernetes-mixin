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

local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local var = g.dashboard.variable;

{
  persistentVolume(config):: {
    datasource:
      var.datasource.new('datasource', 'prometheus')
      + var.datasource.withRegex(config.datasourceFilterRegex)
      + var.datasource.generalOptions.showOnDashboard.withLabelAndValue()
      + var.datasource.generalOptions.withLabel('Data source')
      + {
        current: {
          selected: true,
          text: config.datasourceName,
          value: config.datasourceName,
        },
      },

    cluster:
      var.query.new('cluster')
      + var.query.withDatasourceFromVariable(self.datasource)
      + var.query.queryTypes.withLabelValues(
        config.clusterLabel,
        'kubelet_volume_stats_capacity_bytes{%(kubeletSelector)s}' % config,
      )
      + var.query.generalOptions.withLabel('cluster')
      + var.query.refresh.onTime()
      + (
        if config.showMultiCluster
        then var.query.generalOptions.showOnDashboard.withLabelAndValue()
        else var.query.generalOptions.showOnDashboard.withNothing()
      )
      + var.query.withSort(type='alphabetical'),

    namespace:
      var.query.new('namespace')
      + var.query.withDatasourceFromVariable(self.datasource)
      + var.query.queryTypes.withLabelValues(
        'namespace',
        'kubelet_volume_stats_capacity_bytes{%(clusterLabel)s="$cluster", %(kubeletSelector)s}' % config,
      )
      + var.query.generalOptions.withLabel('Namespace')
      + var.query.refresh.onTime()
      + var.query.generalOptions.showOnDashboard.withLabelAndValue()
      + var.query.withSort(type='alphabetical'),

    volume:
      var.query.new('volume')
      + var.query.withDatasourceFromVariable(self.datasource)
      + var.query.queryTypes.withLabelValues(
        'persistentvolumeclaim',
        'kubelet_volume_stats_capacity_bytes{%(clusterLabel)s="$cluster", %(kubeletSelector)s, namespace="$namespace"}' % config,
      )
      + var.query.generalOptions.withLabel('PersistentVolumeClaim')
      + var.query.refresh.onTime()
      + var.query.generalOptions.showOnDashboard.withLabelAndValue()
      + var.query.withSort(type='alphabetical'),
  },
}
