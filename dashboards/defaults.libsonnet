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
  local kubernetesMixin = self,
  local grafanaDashboards = super.grafanaDashboards,

  // Automatically add a uid to each dashboard based on the base64 encoding
  // of the file name and set the timezone to be 'default'.
  grafanaDashboards:: {
    [filename]: grafanaDashboards[filename] {
      uid: std.get(kubernetesMixin._config.grafanaDashboardIDs, filename, default=std.md5(filename)),
      timezone: kubernetesMixin._config.grafanaK8s.grafanaTimezone,
      refresh: kubernetesMixin._config.grafanaK8s.refresh,
      tags: kubernetesMixin._config.grafanaK8s.dashboardTags,
      links: [
        {
          asDropdown: true,
          includeVars: true,
          keepTime: true,
          tags: kubernetesMixin._config.grafanaK8s.dashboardTags,
          targetBlank: false,
          title: 'Kubernetes',
          type: 'dashboards',
        },
      ],

      [if 'rows' in super then 'rows']: [
        row {
          panels: [
            panel {
              // Modify tooltip to only show a single value
              tooltip+: {
                shared: false,
              },
              // Modify legend to always show as table on right side
              legend+: {
                alignAsTable: true,
                rightSide: true,
              },
              // Set minimum time interval for all panels
              interval: kubernetesMixin._config.grafanaK8s.minimumTimeInterval,
            }
            for panel in super.panels
          ],
        }
        for row in super.rows
      ],

    }
    for filename in std.objectFields(grafanaDashboards)
  },
}
