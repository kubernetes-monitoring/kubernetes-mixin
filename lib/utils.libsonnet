{
  mapRuleGroups(f): {
    groups: [
      group {
        rules: [
          f(rule)
          for rule in super.rules
        ],
      }
      for group in super.groups
    ],
  },

  humanizeSeconds(s)::
    if s > 60 * 60 * 24
    then '%.1f days' % (s / 60 / 60 / 24)
    else '%.1f hours' % (s / 60 / 60),

  processConfig(config)::
    {
      clusterLabel: config.clusterLabel,
      namespaceLabel: config.namespaceLabel,
      grafanaIntervalVar: config.grafanaIntervalVar,
      diskDeviceSelector: config.diskDeviceSelector,
      containerfsSelector: config.containerfsSelector,
      kubeStateMetricsSelector: config.kubeStateMetricsSelector,
      // in metric up, cadvisor is the only label, no need to add trailing comma
      upCadvisorSelector: config.cadvisorSelector,
      cadvisorSelector: if config.cadvisorSelector != '' then '%s, ' % config.cadvisorSelector else '',
    },
}
