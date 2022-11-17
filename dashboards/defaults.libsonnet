{
  local kubernetesMixin = self,
  local grafanaDashboards = super.grafanaDashboards,

  // Automatically add a uid to each dashboard based on the base64 encoding
  // of the file name and set the timezone to be 'default'.
  grafanaDashboards:: {
    [filename]: grafanaDashboards[filename] {
      uid: std.md5(filename),
      timezone: kubernetesMixin._config.grafanaK8s.grafanaTimezone,
      refresh: kubernetesMixin._config.grafanaK8s.refresh,
      tags: kubernetesMixin._config.grafanaK8s.dashboardTags,

      local setPanelDefaults = function(panel)
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
        },

      rows: [
        row {
          panels: [
            setPanelDefaults(panel)
            for panel in super.panels
          ],
        }
        for row in super.rows
      ],

      [if 'panels' in grafanaDashboards[filename] then 'panels']: [
        setPanelDefaults(panel)
        for panel in super.panels
      ],
    }
    for filename in std.objectFields(grafanaDashboards)
  },
}
