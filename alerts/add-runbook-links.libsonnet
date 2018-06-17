local utils = import '../lib/utils.libsonnet';

{
  _config+:: {
    runbookURLPattern: 'https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-%s',
  },

  prometheusAlerts+::
    local addRunbookURL(rule) = rule {
      local alert = std.asciiLower(super.alert),
      annotations+: {
        runbook_url: $._config.runbookURLPattern % alert,
      },
    };
    utils.mapRuleGroups(addRunbookURL),
}
