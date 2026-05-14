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
    kubeProxySelector: error 'must provide selector for kube-proxy',
  },

  prometheusAlerts+:: {
    groups+: [
      {
        name: 'kubernetes-system-kube-proxy',
        rules: [
          (import '../lib/absent_alert.libsonnet') {
            componentName:: 'KubeProxy',
            selector:: $._config.kubeProxySelector,
          },
          (import '../lib/instance_unreachable_alert.libsonnet') {
            componentName:: 'KubeProxy',
            selector:: $._config.kubeProxySelector,
          },
        ],
      },
    ],
  },
}
