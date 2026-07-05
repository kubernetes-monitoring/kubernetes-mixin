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

{
  // Highlight stat queries
  cpuUtilisation(config)::
    'sum(cluster:node_cpu:ratio_rate5m) / count(cluster:node_cpu:ratio_rate5m)',

  cpuRequestsCommitment(config)::
    'sum(kube_pod_container_resource_requests{%(kubeStateMetricsSelector)s, resource="cpu"}) / sum(kube_node_status_allocatable{%(kubeStateMetricsSelector)s, resource="cpu"})' % config,

  cpuLimitsCommitment(config)::
    'sum(kube_pod_container_resource_limits{%(kubeStateMetricsSelector)s, resource="cpu"}) / sum(kube_node_status_allocatable{%(kubeStateMetricsSelector)s, resource="cpu"})' % config,

  memoryUtilisation(config)::
    '1 - sum(:node_memory_MemAvailable_bytes:sum) / sum(node_memory_MemTotal_bytes{%(nodeExporterSelector)s})' % config,

  memoryRequestsCommitment(config)::
    'sum(kube_pod_container_resource_requests{%(kubeStateMetricsSelector)s, resource="memory"}) / sum(kube_node_status_allocatable{%(kubeStateMetricsSelector)s, resource="memory"})' % config,

  memoryLimitsCommitment(config)::
    'sum(kube_pod_container_resource_limits{%(kubeStateMetricsSelector)s, resource="memory"}) / sum(kube_node_status_allocatable{%(kubeStateMetricsSelector)s, resource="memory"})' % config,

  // CPU Usage / Quota
  cpuUsageByCluster(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m)) by (%(clusterLabel)s)' % config,

  cpuRequestsByCluster(config)::
    'sum(kube_pod_container_resource_requests{%(kubeStateMetricsSelector)s, resource="cpu"}) by (%(clusterLabel)s)' % config,

  cpuUsageVsRequests(config)::
    '%s / %s' % [self.cpuUsageByCluster(config), self.cpuRequestsByCluster(config)],

  cpuLimitsByCluster(config)::
    'sum(kube_pod_container_resource_limits{%(kubeStateMetricsSelector)s, resource="cpu"}) by (%(clusterLabel)s)' % config,

  cpuUsageVsLimits(config)::
    '%s / %s' % [self.cpuUsageByCluster(config), self.cpuLimitsByCluster(config)],

  // Memory Usage / Quota
  memoryUsageByCluster(config)::
    'sum(max by (%(clusterLabel)s, %(namespaceLabel)s, pod, container)(container_memory_rss{%(cadvisorSelector)s, container!=""})) by (%(clusterLabel)s)' % config,

  memoryRequestsByCluster(config)::
    'sum(kube_pod_container_resource_requests{%(kubeStateMetricsSelector)s, resource="memory"}) by (%(clusterLabel)s)' % config,

  memoryUsageVsRequests(config)::
    '%s / %s' % [self.memoryUsageByCluster(config), self.memoryRequestsByCluster(config)],

  memoryLimitsByCluster(config)::
    'sum(kube_pod_container_resource_limits{%(kubeStateMetricsSelector)s, resource="memory"}) by (%(clusterLabel)s)' % config,

  memoryUsageVsLimits(config)::
    '%s / %s' % [self.memoryUsageByCluster(config), self.memoryLimitsByCluster(config)],
}
