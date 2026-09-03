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
  prometheusRules+:: {
    local windowSeconds(window) =
      local unit = std.substr(window, std.length(window) - 1, 1);
      local count = std.parseInt(std.substr(window, 0, std.length(window) - 1));
      local multiplier =
        if unit == 's' then 1
        else if unit == 'm' then 60
        else if unit == 'h' then 60 * 60
        else if unit == 'd' then 24 * 60 * 60
        else error 'unsupported burn rate window unit %s in %s' % [unit, window];
      count * multiplier,

    local shorter(a, b) = if windowSeconds(b) < windowSeconds(a) then b else a,
    local longer(a, b) = if windowSeconds(b) > windowSeconds(a) then b else a,

    local shortWindows = std.set([w.short for w in $._config.SLOs.apiserver.windows]),
    local windows = std.set(shortWindows + [w.long for w in $._config.SLOs.apiserver.windows]),

    // The intermediate series are recorded on the shortest window in use, so that the
    // burn rate for that window stays an exact rewrite rather than an approximation.
    local baseWindow = std.foldl(shorter, windows, windows[0]),

    // Short windows decide how fast an alert reacts, so they keep reading the raw series.
    // Longer windows are averaged from the intermediate series instead: their cost is
    // dominated by the range length, and a range that long over the raw apiserver series
    // is what makes this group expensive. The averaged value trails the raw one by half
    // the base window while the request rate is changing, and matches it once the rate
    // holds steady, which is the condition the long window is there to detect.
    local longestShortWindow = std.foldl(longer, shortWindows, shortWindows[0]),
    local rawWindows = [w for w in windows if windowSeconds(w) <= windowSeconds(longestShortWindow)],
    local averagedWindows = [w for w in windows if windowSeconds(w) > windowSeconds(longestShortWindow)],

    local badRecord = 'apiserver_request:bad:rate%s' % baseWindow,
    local totalRecord = 'apiserver_request:total:rate%s' % baseWindow,

    // Requests that either breached the latency objective for their scope or returned 5xx.
    local badExpr(verb, window) =
      if verb == 'read' then
        |||
          (
            (
              # too slow
              sum by (%(clusterLabel)s) (rate(apiserver_request_sli_duration_seconds_count{%(kubeApiserverSelector)s,%(kubeApiserverReadSelector)s,%(kubeApiserverNonStreamingSelector)s}[%(window)s]))
              -
              (
                (
                  sum by (%(clusterLabel)s) (rate(apiserver_request_sli_duration_seconds_bucket{%(kubeApiserverSelector)s,%(kubeApiserverReadSelector)s,%(kubeApiserverNonStreamingSelector)s,scope=~"resource|",le=~"%(kubeApiserverReadResourceLatency)s"}[%(window)s]))
                  or
                  vector(0)
                )
                +
                sum by (%(clusterLabel)s) (rate(apiserver_request_sli_duration_seconds_bucket{%(kubeApiserverSelector)s,%(kubeApiserverReadSelector)s,%(kubeApiserverNonStreamingSelector)s,scope="namespace",le=~"%(kubeApiserverReadNamespaceLatency)s"}[%(window)s]))
                +
                sum by (%(clusterLabel)s) (rate(apiserver_request_sli_duration_seconds_bucket{%(kubeApiserverSelector)s,%(kubeApiserverReadSelector)s,%(kubeApiserverNonStreamingSelector)s,scope="cluster",le=~"%(kubeApiserverReadClusterLatency)s"}[%(window)s]))
              )
            )
            +
            # errors
            sum by (%(clusterLabel)s) (rate(apiserver_request_total{%(kubeApiserverSelector)s,%(kubeApiserverReadSelector)s,code=~"5.."}[%(window)s]))
          )
        ||| % {
          clusterLabel: $._config.clusterLabel,
          window: window,
          kubeApiserverSelector: $._config.kubeApiserverSelector,
          kubeApiserverReadSelector: $._config.kubeApiserverReadSelector,
          kubeApiserverNonStreamingSelector: $._config.kubeApiserverNonStreamingSelector,
          kubeApiserverReadResourceLatency: $._config.kubeApiserverReadResourceLatency,
          kubeApiserverReadNamespaceLatency: $._config.kubeApiserverReadNamespaceLatency,
          kubeApiserverReadClusterLatency: $._config.kubeApiserverReadClusterLatency,
        }
      else
        |||
          (
            (
              # too slow
              sum by (%(clusterLabel)s) (rate(apiserver_request_sli_duration_seconds_count{%(kubeApiserverSelector)s,%(kubeApiserverWriteSelector)s,%(kubeApiserverNonStreamingSelector)s}[%(window)s]))
              -
              sum by (%(clusterLabel)s) (rate(apiserver_request_sli_duration_seconds_bucket{%(kubeApiserverSelector)s,%(kubeApiserverWriteSelector)s,%(kubeApiserverNonStreamingSelector)s,le=~"%(kubeApiserverWriteLatency)s"}[%(window)s]))
            )
            +
            # errors
            sum by (%(clusterLabel)s) (rate(apiserver_request_total{%(kubeApiserverSelector)s,%(kubeApiserverWriteSelector)s,code=~"5.."}[%(window)s]))
          )
        ||| % {
          clusterLabel: $._config.clusterLabel,
          window: window,
          kubeApiserverSelector: $._config.kubeApiserverSelector,
          kubeApiserverWriteSelector: $._config.kubeApiserverWriteSelector,
          kubeApiserverNonStreamingSelector: $._config.kubeApiserverNonStreamingSelector,
          kubeApiserverWriteLatency: $._config.kubeApiserverWriteLatency,
        },

    local totalExpr(verb, window) =
      |||
        sum by (%(clusterLabel)s) (rate(apiserver_request_total{%(kubeApiserverSelector)s,%(verbSelector)s}[%(window)s]))
      ||| % {
        clusterLabel: $._config.clusterLabel,
        window: window,
        kubeApiserverSelector: $._config.kubeApiserverSelector,
        verbSelector: if verb == 'read' then $._config.kubeApiserverReadSelector else $._config.kubeApiserverWriteSelector,
      },

    groups+: [
      {
        name: 'kube-apiserver-burnrate.rules',
        rules: [
          {
            record: badRecord,
            expr: badExpr(verb, baseWindow),
            labels: {
              verb: verb,
            },
          }
          for verb in ['read', 'write']
        ] + [
          {
            record: totalRecord,
            expr: totalExpr(verb, baseWindow),
            labels: {
              verb: verb,
            },
          }
          for verb in ['read', 'write']
        ] + [
          // Both verbs at once: the intermediate series already carry the verb label.
          {
            record: 'apiserver_request:burnrate%s' % baseWindow,
            expr: |||
              %s
              /
              %s
            ||| % [badRecord, totalRecord],
          },
        ] + [
          {
            record: 'apiserver_request:burnrate%(window)s' % { window: window },
            expr: |||
              %(bad)s
              /
              %(total)s
            ||| % {
              bad: std.rstripChars(badExpr(verb, window), '\n'),
              total: std.rstripChars(totalExpr(verb, window), '\n'),
            },
            labels: {
              verb: verb,
            },
          }
          for window in rawWindows
          if window != baseWindow
          for verb in ['read', 'write']
        ] + [
          {
            record: 'apiserver_request:burnrate%(window)s' % { window: window },
            expr: |||
              avg_over_time(%(bad)s[%(window)s])
              /
              avg_over_time(%(total)s[%(window)s])
            ||| % {
              bad: badRecord,
              total: totalRecord,
              window: window,
            },
          }
          for window in averagedWindows
        ],
      },
    ],
  },
}
