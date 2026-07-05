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
  // Gauge queries (no `by`)
  gaugeReceiveBandwidth(config)::
    'sum((%(multiplier)s * rate(container_network_receive_bytes_total{%(clusterLabel)s="$cluster",namespace=~"$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s])))' % (config { multiplier: config.units.networkMultiplier }),

  gaugeTransmitBandwidth(config)::
    'sum((%(multiplier)s * rate(container_network_transmit_bytes_total{%(clusterLabel)s="$cluster",namespace=~"$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s])))' % (config { multiplier: config.units.networkMultiplier }),

  // Per-pod TimeSeries queries
  receiveBandwidth(config)::
    'sum((%(multiplier)s * rate(container_network_receive_bytes_total{%(clusterLabel)s="$cluster",namespace=~"$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s]))) by (pod)' % (config { multiplier: config.units.networkMultiplier }),

  transmitBandwidth(config)::
    'sum((%(multiplier)s * rate(container_network_transmit_bytes_total{%(clusterLabel)s="$cluster",namespace=~"$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s]))) by (pod)' % (config { multiplier: config.units.networkMultiplier }),

  receivePackets(config)::
    'sum(rate(container_network_receive_packets_total{%(clusterLabel)s="$cluster",namespace=~"$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s])) by (pod)' % config,

  transmitPackets(config)::
    'sum(rate(container_network_transmit_packets_total{%(clusterLabel)s="$cluster",namespace=~"$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s])) by (pod)' % config,

  receivePacketsDropped(config)::
    'sum(rate(container_network_receive_packets_dropped_total{%(clusterLabel)s="$cluster",namespace=~"$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s])) by (pod)' % config,

  transmitPacketsDropped(config)::
    'sum(rate(container_network_transmit_packets_dropped_total{%(clusterLabel)s="$cluster",namespace=~"$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s])) by (pod)' % config,
}
