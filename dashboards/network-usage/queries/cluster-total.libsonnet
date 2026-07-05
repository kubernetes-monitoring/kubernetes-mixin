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
    sum by (namespace) (
        (%(multiplier)s * rate(container_network_receive_bytes_total{%(clusterLabel)s="$cluster",namespace!=""}[%(grafanaIntervalVar)s]))
      * on (%(clusterLabel)s,namespace,pod) group_left ()
        topk by (%(clusterLabel)s,namespace,pod) (
          1,
          max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false",%(clusterLabel)s="$cluster"})
        )
    )
  ||| % (config { multiplier: config.units.networkMultiplier }),

  transmitBandwidth(config):: |||
    sum by (namespace) (
        (%(multiplier)s * rate(container_network_transmit_bytes_total{%(clusterLabel)s="$cluster",namespace!=""}[%(grafanaIntervalVar)s]))
      * on (%(clusterLabel)s,namespace,pod) group_left ()
        topk by (%(clusterLabel)s,namespace,pod) (
          1,
          max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false",%(clusterLabel)s="$cluster"})
        )
    )
  ||| % (config { multiplier: config.units.networkMultiplier }),

  avgReceiveBandwidth(config):: |||
    avg by (namespace) (
        (%(multiplier)s * rate(container_network_receive_bytes_total{%(clusterLabel)s="$cluster",namespace!=""}[%(grafanaIntervalVar)s]))
      * on (%(clusterLabel)s,namespace,pod) group_left ()
        topk by (%(clusterLabel)s,namespace,pod) (
          1,
          max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false",%(clusterLabel)s="$cluster"})
        )
    )
  ||| % (config { multiplier: config.units.networkMultiplier }),

  avgTransmitBandwidth(config):: |||
    avg by (namespace) (
        (%(multiplier)s * rate(container_network_transmit_bytes_total{%(clusterLabel)s="$cluster",namespace!=""}[%(grafanaIntervalVar)s]))
      * on (%(clusterLabel)s,namespace,pod) group_left ()
        topk by (%(clusterLabel)s,namespace,pod) (
          1,
          max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false",%(clusterLabel)s="$cluster"})
        )
    )
  ||| % (config { multiplier: config.units.networkMultiplier }),

  receivePackets(config):: |||
    sum by (namespace) (
        rate(container_network_receive_packets_total{%(clusterLabel)s="$cluster",namespace!=""}[%(grafanaIntervalVar)s])
      * on (%(clusterLabel)s,namespace,pod) group_left ()
        topk by (%(clusterLabel)s,namespace,pod) (
          1,
          max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false",%(clusterLabel)s="$cluster"})
        )
    )
  ||| % config,

  transmitPackets(config):: |||
    sum by (namespace) (
        rate(container_network_transmit_packets_total{%(clusterLabel)s="$cluster",namespace!=""}[%(grafanaIntervalVar)s])
      * on (%(clusterLabel)s,namespace,pod) group_left ()
        topk by (%(clusterLabel)s,namespace,pod) (
          1,
          max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false",%(clusterLabel)s="$cluster"})
        )
    )
  ||| % config,

  receivePacketsDropped(config):: |||
    sum by (namespace) (
        rate(container_network_receive_packets_dropped_total{%(clusterLabel)s="$cluster",namespace!=""}[%(grafanaIntervalVar)s])
      * on (%(clusterLabel)s,namespace,pod) group_left ()
        topk by (%(clusterLabel)s,namespace,pod) (
          1,
          max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false",%(clusterLabel)s="$cluster"})
        )
    )
  ||| % config,

  transmitPacketsDropped(config):: |||
    sum by (namespace) (
        rate(container_network_transmit_packets_dropped_total{%(clusterLabel)s="$cluster",namespace!=""}[%(grafanaIntervalVar)s])
      * on (%(clusterLabel)s,namespace,pod) group_left ()
        topk by (%(clusterLabel)s,namespace,pod) (
          1,
          max by (%(clusterLabel)s,namespace,pod) (kube_pod_info{host_network="false",%(clusterLabel)s="$cluster"})
        )
    )
  ||| % config,

  tcpRetransmitRate(config):: |||
    sum by (instance) (
        rate(node_netstat_Tcp_RetransSegs{%(clusterLabel)s="$cluster"}[%(grafanaIntervalVar)s]) / rate(node_netstat_Tcp_OutSegs{%(clusterLabel)s="$cluster"}[%(grafanaIntervalVar)s])
    )
  ||| % config,

  tcpSynRetransmitRate(config):: |||
    sum by (instance) (
        rate(node_netstat_TcpExt_TCPSynRetrans{%(clusterLabel)s="$cluster"}[%(grafanaIntervalVar)s]) / rate(node_netstat_Tcp_RetransSegs{%(clusterLabel)s="$cluster"}[%(grafanaIntervalVar)s])
    )
  ||| % config,
}
