{
  local grafanaDashboards = super.grafanaDashboards,

  // Automatically add a uid to each dashboard based on the base64 encoding
  // of the file name and set the timezone to be 'default'.
  grafanaDashboards:: {
    [filename]: grafanaDashboards[filename] {
      uid: $._config.grafanaDashboardIDs[filename],
      timezone: '',
    }
    for filename in std.objectFields(grafanaDashboards)
  },
}
