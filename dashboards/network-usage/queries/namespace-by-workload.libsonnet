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

local columnQuery(config, aggFunc, metric, multiplier) =
  local rateExpr = 'sum by (%%(clusterLabel)s, namespace, pod) (%(multiplier)s * rate(%(metric)s{%%(clusterLabel)s="$cluster",namespace="$namespace"}[%%(grafanaIntervalVar)s]))' % { metric: metric, multiplier: multiplier };
  |||
    sort_desc(
      %(aggFunc)s by (workload, workload_type) (
        %(rateExpr)s
        * on (%%(clusterLabel)s, namespace, pod)
        topk by (%%(clusterLabel)s, namespace, pod) (
          1,
          max by (%%(clusterLabel)s, namespace, pod) (kube_pod_info{%%(clusterLabel)s="$cluster",namespace="$namespace",host_network="false"})
        )
        * on (%%(clusterLabel)s, namespace, pod) group_left (workload, workload_type)
        namespace_workload_pod:kube_pod_owner:relabel{%%(clusterLabel)s="$cluster",namespace="$namespace", workload=~".+", workload_type=~"$type"}
      )
    )
  ||| % { aggFunc: aggFunc, rateExpr: rateExpr } % config;

{
  // Current Status table columns
  currentStatusColumns(config):: [
    columnQuery(config, 'sum', 'container_network_receive_bytes_total', config.units.networkMultiplier),
    columnQuery(config, 'sum', 'container_network_transmit_bytes_total', config.units.networkMultiplier),
    columnQuery(config, 'avg', 'container_network_receive_bytes_total', config.units.networkMultiplier),
    columnQuery(config, 'avg', 'container_network_transmit_bytes_total', config.units.networkMultiplier),
    columnQuery(config, 'sum', 'container_network_receive_packets_total', 1),
    columnQuery(config, 'sum', 'container_network_transmit_packets_total', 1),
    columnQuery(config, 'sum', 'container_network_receive_packets_dropped_total', 1),
    columnQuery(config, 'sum', 'container_network_transmit_packets_dropped_total', 1),
  ],

  // Bandwidth / packet TimeSeries + bar gauge queries
  receiveBandwidth(config):: |||
    sort_desc(sum((%(multiplier)s * rate(container_network_receive_bytes_total{%(clusterLabel)s="$cluster",namespace="$namespace"}[%(grafanaIntervalVar)s]))
    * on (%(clusterLabel)s,namespace,pod) group_left ()
        topk by (%(clusterLabel)s,namespace,pod) (
          1,
          max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false"})
        )
    * on (%(clusterLabel)s,namespace,pod)
    group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster",namespace="$namespace", workload=~".+", workload_type=~"$type"}) by (workload))
  ||| % (config { multiplier: config.units.networkMultiplier }),

  transmitBandwidth(config):: |||
    sort_desc(sum((%(multiplier)s * rate(container_network_transmit_bytes_total{%(clusterLabel)s="$cluster",namespace="$namespace"}[%(grafanaIntervalVar)s]))
    * on (%(clusterLabel)s,namespace,pod) group_left ()
        topk by (%(clusterLabel)s,namespace,pod) (
          1,
          max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false"})
        )
    * on (%(clusterLabel)s,namespace,pod)
    group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster",namespace="$namespace", workload=~".+", workload_type=~"$type"}) by (workload))
  ||| % (config { multiplier: config.units.networkMultiplier }),

  avgContainerReceiveBandwidth(config):: |||
    sort_desc(avg((%(multiplier)s * rate(container_network_receive_bytes_total{%(clusterLabel)s="$cluster",namespace="$namespace"}[%(grafanaIntervalVar)s]))
    * on (%(clusterLabel)s,namespace,pod) group_left ()
        topk by (%(clusterLabel)s,namespace,pod) (
          1,
          max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false"})
        )
    * on (%(clusterLabel)s,namespace,pod)
    group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster",namespace="$namespace", workload=~".+", workload_type=~"$type"}) by (workload))
  ||| % (config { multiplier: config.units.networkMultiplier }),

  avgContainerTransmitBandwidth(config):: |||
    sort_desc(avg((%(multiplier)s * rate(container_network_transmit_bytes_total{%(clusterLabel)s="$cluster",namespace="$namespace"}[%(grafanaIntervalVar)s]))
    * on (%(clusterLabel)s,namespace,pod) group_left ()
        topk by (%(clusterLabel)s,namespace,pod) (
          1,
          max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false"})
        )
    * on (%(clusterLabel)s,namespace,pod)
    group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster",namespace="$namespace", workload=~".+", workload_type=~"$type"}) by (workload))
  ||| % (config { multiplier: config.units.networkMultiplier }),

  rateReceivedPackets(config):: |||
    sort_desc(sum(rate(container_network_receive_packets_total{%(clusterLabel)s="$cluster",namespace="$namespace"}[%(grafanaIntervalVar)s])
    * on (%(clusterLabel)s,namespace,pod) group_left ()
        topk by (%(clusterLabel)s,namespace,pod) (
          1,
          max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false"})
        )
    * on (%(clusterLabel)s,namespace,pod)
    group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster",namespace="$namespace", workload=~".+", workload_type=~"$type"}) by (workload))
  ||| % config,

  rateTransmittedPackets(config):: |||
    sort_desc(sum(rate(container_network_transmit_packets_total{%(clusterLabel)s="$cluster",namespace="$namespace"}[%(grafanaIntervalVar)s])
    * on (%(clusterLabel)s,namespace,pod) group_left ()
        topk by (%(clusterLabel)s,namespace,pod) (
          1,
          max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false"})
        )
    * on (%(clusterLabel)s,namespace,pod)
    group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster",namespace="$namespace", workload=~".+", workload_type=~"$type"}) by (workload))
  ||| % config,

  rateReceivedPacketsDropped(config):: |||
    sort_desc(sum(rate(container_network_receive_packets_dropped_total{%(clusterLabel)s="$cluster",namespace="$namespace"}[%(grafanaIntervalVar)s])
    * on (%(clusterLabel)s,namespace,pod) group_left ()
        topk by (%(clusterLabel)s,namespace,pod) (
          1,
          max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false"})
        )
    * on (%(clusterLabel)s,namespace,pod)
    group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster",namespace="$namespace", workload=~".+", workload_type=~"$type"}) by (workload))
  ||| % config,

  rateTransmittedPacketsDropped(config):: |||
    sort_desc(sum(rate(container_network_transmit_packets_dropped_total{%(clusterLabel)s="$cluster",namespace="$namespace"}[%(grafanaIntervalVar)s])
    * on (%(clusterLabel)s,namespace,pod) group_left ()
        topk by (%(clusterLabel)s,namespace,pod) (
          1,
          max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false"})
        )
    * on (%(clusterLabel)s,namespace,pod)
    group_left(workload,workload_type) namespace_workload_pod:kube_pod_owner:relabel{%(clusterLabel)s="$cluster",namespace="$namespace", workload=~".+", workload_type=~"$type"}) by (workload))
  ||| % config,
}
