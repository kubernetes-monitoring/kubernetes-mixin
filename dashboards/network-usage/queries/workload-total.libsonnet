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
  receiveBandwidth(config):: |||
    sort_desc(sum((%(multiplier)s * rate(container_network_receive_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster",namespace=~"$namespace"}[%(grafanaIntervalVar)s]))
    * on (%(clusterLabel)s, namespace, pod)
    group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster",namespace=~"$namespace", workload=~"$workload", workload_type=~"$type"}) by (pod))
  ||| % (config { multiplier: config.units.networkMultiplier }),

  transmitBandwidth(config):: |||
    sort_desc(sum((%(multiplier)s * rate(container_network_transmit_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster",namespace=~"$namespace"}[%(grafanaIntervalVar)s]))
    * on (%(clusterLabel)s, namespace, pod)
    group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster",namespace=~"$namespace", workload=~"$workload", workload_type=~"$type"}) by (pod))
  ||| % (config { multiplier: config.units.networkMultiplier }),

  avgReceiveBandwidth(config):: |||
    sort_desc(avg((%(multiplier)s * rate(container_network_receive_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster",namespace=~"$namespace"}[%(grafanaIntervalVar)s]))
    * on (%(clusterLabel)s, namespace, pod)
    group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster",namespace=~"$namespace", workload=~"$workload", workload_type=~"$type"}) by (pod))
  ||| % (config { multiplier: config.units.networkMultiplier }),

  avgTransmitBandwidth(config):: |||
    sort_desc(avg((%(multiplier)s * rate(container_network_transmit_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster",namespace=~"$namespace"}[%(grafanaIntervalVar)s]))
    * on (%(clusterLabel)s, namespace, pod)
    group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster",namespace=~"$namespace", workload=~"$workload", workload_type=~"$type"}) by (pod))
  ||| % (config { multiplier: config.units.networkMultiplier }),

  rateReceivedPackets(config):: |||
    sort_desc(sum(rate(container_network_receive_packets_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster",namespace=~"$namespace"}[%(grafanaIntervalVar)s])
    * on (%(clusterLabel)s, namespace, pod)
    group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster",namespace=~"$namespace", workload=~"$workload", workload_type=~"$type"}) by (pod))
  ||| % config,

  rateTransmittedPackets(config):: |||
    sort_desc(sum(rate(container_network_transmit_packets_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster",namespace=~"$namespace"}[%(grafanaIntervalVar)s])
    * on (%(clusterLabel)s, namespace, pod)
    group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster",namespace=~"$namespace", workload=~"$workload", workload_type=~"$type"}) by (pod))
  ||| % config,

  rateReceivedPacketsDropped(config):: |||
    sort_desc(sum(rate(container_network_receive_packets_dropped_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster",namespace=~"$namespace"}[%(grafanaIntervalVar)s])
    * on (%(clusterLabel)s, namespace, pod)
    group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster",namespace=~"$namespace", workload=~"$workload", workload_type=~"$type"}) by (pod))
  ||| % config,

  rateTransmittedPacketsDropped(config):: |||
    sort_desc(sum(rate(container_network_transmit_packets_dropped_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster",namespace=~"$namespace"}[%(grafanaIntervalVar)s])
    * on (%(clusterLabel)s, namespace, pod)
    group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster",namespace=~"$namespace", workload=~"$workload", workload_type=~"$type"}) by (pod))
  ||| % config,
}
