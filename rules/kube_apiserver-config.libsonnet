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
  _config+:: {
    kubeApiserverSelector: 'job="kube-apiserver"',
    podLabel: 'pod',
    kubeApiserverReadSelector: 'verb=~"LIST|GET"',
    kubeApiserverWriteSelector: 'verb=~"POST|PUT|PATCH|DELETE"',
    kubeApiserverNonStreamingSelector: 'subresource!~"proxy|attach|log|exec|portforward"',
    // These are buckets that exist on the apiserver_request_sli_duration_seconds_bucket histogram.
    // They are what the Kubernetes SIG Scalability is using to measure availability of Kubernetes clusters.
    // If you want to change these, make sure the "le" buckets exist on the histogram!
    kubeApiserverReadResourceLatency: '1(\\\\.0)?',
    kubeApiserverReadNamespaceLatency: '5(\\\\.0)?',
    kubeApiserverReadClusterLatency: '30(\\\\.0)?',
    kubeApiserverWriteLatency: '1(\\\\.0)?',
  },
}
