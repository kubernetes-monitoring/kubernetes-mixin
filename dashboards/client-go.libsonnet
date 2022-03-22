local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local dashboard = grafana.dashboard;
local row = grafana.row;
local prometheus = grafana.prometheus;
local template = grafana.template;
local graphPanel = grafana.graphPanel;

{
  grafanaDashboards+:: {
    'client-go.json':
      local requestRate =
        graphPanel.new(
          'Request rate',
          datasource='$datasource',
          format='ops',
          legend_show=true,
          legend_values=true,
          legend_current=true,
          legend_alignAsTable=true,
          legend_rightSide=true,
        )
        .addTarget(prometheus.target('sum(rate(rest_client_requests_total{%(clusterLabel)s="$cluster", code=~"$code", host=~"$host",method=~"$verb"}[%(grafanaIntervalVar)s])) by (%(clusterLabel)s, code, host)' % $._config, legendFormat='{{%(clusterLabel)s}} {{code}} {{host}}' % $._config));

      local requestErrorRate =
        graphPanel.new(
          'Request network error rate',
          datasource='$datasource',
          format='ops',
          legend_show=true,
          legend_values=true,
          legend_current=true,
          legend_alignAsTable=true,
          legend_rightSide=true,
        )
        .addTarget(prometheus.target('sum(rate(rest_client_requests_total{%(clusterLabel)s="$cluster", code="<error>", host=~"$host",method=~"$verb"}[%(grafanaIntervalVar)s])) by (%(clusterLabel)s, host) / sum(rate(rest_client_requests_total{%(clusterLabel)s="$cluster"}[%(grafanaIntervalVar)s])) by (%(clusterLabel)s) ' % $._config, legendFormat='{{%(clusterLabel)s}} {{code}} {{host}}' % $._config));

      local requestDuration =
        graphPanel.new(
          'Request duration 99th quantile',
          datasource='$datasource',
          format='s',
          legend_show=true,
          legend_values=true,
          legend_current=true,
          legend_alignAsTable=true,
          legend_rightSide=true,
        )
        .addTarget(prometheus.target('histogram_quantile(0.99, sum(rate(rest_client_request_duration_seconds_bucket{%(clusterLabel)s="$cluster", host=~"$host", verb=~"$verb"}[%(grafanaIntervalVar)s])) by (verb, host, le))' % $._config, legendFormat='{{verb}} {{host}}'));

      local rateLimiterDuration =
        graphPanel.new(
          'Rate Limiter duration 99th quantile',
          datasource='$datasource',
          format='s',
          legend_show=true,
          legend_values=true,
          legend_current=true,
          legend_alignAsTable=true,
          legend_rightSide=true,
        )
        .addTarget(prometheus.target('histogram_quantile(0.99, sum(rate(rest_client_rate_limiter_duration_seconds_bucket{%(clusterLabel)s="$cluster", host=~"$host", verb=~"$verb"}[%(grafanaIntervalVar)s])) by (verb, host, le))' % $._config, legendFormat='{{verb}} {{host}}'));

      local requestSize =
        graphPanel.new(
          'Request size 99th quantile',
          datasource='$datasource',
          format='s',
          legend_show=true,
          legend_values=true,
          legend_current=true,
          legend_alignAsTable=true,
          legend_rightSide=true,
        )
        .addTarget(prometheus.target('histogram_quantile(0.99, sum(rate(rest_client_request_size_bytes_bucket{%(clusterLabel)s="$cluster", host=~"$host", verb=~"$verb"}[%(grafanaIntervalVar)s])) by (verb, host, le))' % $._config, legendFormat='{{verb}} {{host}}'));

      local responseSize =
        graphPanel.new(
          'Response size 99th quantile',
          datasource='$datasource',
          format='s',
          legend_show=true,
          legend_values=true,
          legend_current=true,
          legend_alignAsTable=true,
          legend_rightSide=true,
        )
        .addTarget(prometheus.target('histogram_quantile(0.99, sum(rate(rest_client_response_size_bytes{%(clusterLabel)s="$cluster", host=~"$host", verb=~"$verb"}[%(grafanaIntervalVar)s])) by (verb, host, le))' % $._config, legendFormat='{{verb}} {{host}}'));

      dashboard.new(
        '%(dashboardNamePrefix)sClient-go' % $._config.grafanaK8s,
        time_from='now-1h',
        uid=($._config.grafanaDashboardIDs['client-go.json']),
        tags=($._config.grafanaK8s.dashboardTags),
      ).addTemplate(
        {
          current: {
            text: 'default',
            value: $._config.datasourceName,
          },
          hide: 0,
          label: 'Data Source',
          name: 'datasource',
          options: [],
          query: 'prometheus',
          refresh: 1,
          regex: $._config.datasourceFilterRegex,
          type: 'datasource',
        },
      )
      .addTemplate(
        template.new(
          'host',
          '$datasource',
          'label_values(rest_client_requests_total{%(clusterLabel)s="$cluster"}, host)' % $._config,
          label='host',
          refresh='time',
          includeAll=true,
          sort=1,
        )
      )
      .addTemplate(
        template.new(
          'verb',
          '$datasource',
          'label_values(rest_client_requests_total{%(clusterLabel)s="$cluster"}, verb)' % $._config,
          label='verb',
          refresh='time',
          includeAll=true,
          sort=1,
        )
      )
      .addTemplate(
        template.new(
          'code',
          '$datasource',
          'label_values(rest_client_requests_total{%(clusterLabel)s="$cluster"}, code)' % $._config,
          label='code',
          refresh='time',
          includeAll=true,
          sort=1,
        )
      )

      .addRow(
        row.new()
        .addPanel(requestRate)
        .addPanel(requestErrorRate)
      )
      .addRow(
        row.new()
        .addPanel(requestDuration)
        .addPanel(rateLimiterDuration)
      )
      .addRow(
        row.new()
        .addPanel(requestSize)
        .addPanel(responseSize)
      ),
  },
}
