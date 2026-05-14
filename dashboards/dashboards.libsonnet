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

(import 'network.libsonnet') +
(import 'persistentvolumesusage.libsonnet') +
(import 'resources.libsonnet') +
(import 'apiserver.libsonnet') +
(import 'controller-manager.libsonnet') +
(import 'scheduler.libsonnet') +
(import 'proxy.libsonnet') +
(import 'kubelet.libsonnet') +
(import 'windows.libsonnet') +
(import 'defaults.libsonnet')
