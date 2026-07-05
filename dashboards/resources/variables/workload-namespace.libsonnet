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
local common = import './common.libsonnet';

{
  workloadNamespace(config):: {
    datasource: common.datasource(config),

    cluster:
      var.query.new('cluster')
      + var.query.withDatasourceFromVariable(self.datasource)
      + var.query.queryTypes.withLabelValues(
        config.clusterLabel,
        'up{%(kubeStateMetricsSelector)s}' % config,
      )
      + var.query.generalOptions.withLabel('cluster')
      + var.query.refresh.onTime()
      + (
        if config.showMultiCluster
        then var.query.generalOptions.showOnDashboard.withLabelAndValue()
        else var.query.generalOptions.showOnDashboard.withNothing()
      )
      + var.query.withSort(type='alphabetical'),

    namespace: common.namespace(config, self.datasource),

    workload_type:
      var.query.new('type')
      + var.query.selectionOptions.withIncludeAll()
      + var.query.withDatasourceFromVariable(self.datasource)
      + var.query.queryTypes.withLabelValues(
        'workload_type',
        'namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster", namespace="$namespace", workload=~".+"}' % config,
      )
      + var.query.generalOptions.withLabel('workload_type')
      + var.query.refresh.onTime()
      + var.query.generalOptions.showOnDashboard.withLabelAndValue()
      + var.query.withSort(type='alphabetical'),
  },
}
