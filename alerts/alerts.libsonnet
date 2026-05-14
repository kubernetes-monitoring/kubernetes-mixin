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

(import 'apps_alerts.libsonnet') +
(import 'resource_alerts.libsonnet') +
(import 'storage_alerts.libsonnet') +
(import 'system_alerts.libsonnet') +
(import 'kube_apiserver.libsonnet') +
(import 'kubelet.libsonnet') +
(import 'kube_scheduler.libsonnet') +
(import 'kube_controller_manager.libsonnet') +
(import 'kube_proxy.libsonnet') +
(import '../lib/add-runbook-links.libsonnet')
