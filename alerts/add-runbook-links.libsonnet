local utils = import '../lib/utils.libsonnet';

local lower(x) =
  local cp(c) = std.codepoint(c);
  local lowerLetter(c) =
    if cp(c) >= 65 && cp(c) < 91
    then std.char(cp(c) + 32)
    else c;
  std.join('', std.map(lowerLetter, std.stringChars(x)));

{
  _config+:: {
    runbookURLPattern: 'https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-%s',
  },

  prometheusAlerts+::
    local addRunbookURL(rule) = rule {
      local alert = lower(super.alert),
      annotations+: {
        runbook_url: $._config.runbookURLPattern % alert,
      },
    };
    utils.mapRuleGroups(addRunbookURL),
}
