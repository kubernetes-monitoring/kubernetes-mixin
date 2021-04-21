local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local dashboard = grafana.dashboard;
local row = grafana.row;
local prometheus = grafana.prometheus;
local template = grafana.template;
local graphPanel = grafana.graphPanel;
local tablePanel = grafana.tablePanel;
local annotation = grafana.annotation;
local singlestat = grafana.singlestat;

{
  grafanaDashboards+:: {

    'network-cluster-total.json':

      local newStyle(
        alias,
        colorMode=null,
        colors=[],
        dateFormat='YYYY-MM-DD HH:mm:ss',
        decimals=2,
        link=false,
        linkTooltip='Drill down',
        linkUrl='',
        thresholds=[],
        type='number',
        unit='short'
            ) = {
        alias: alias,
        colorMode: colorMode,
        colors: colors,
        dateFormat: dateFormat,
        decimals: decimals,
        link: link,
        linkTooltip: linkTooltip,
        linkUrl: linkUrl,
        thresholds: thresholds,
        type: type,
        unit: unit,
      };

      local newBarplotPanel(graphTitle, graphQuery, graphFormat='Bps', legendFormat='{{namespace}}') =
        local target =
          prometheus.target(
            graphQuery
          ) + {
            intervalFactor: 1,
            legendFormat: legendFormat,
            step: 10,
          };

        graphPanel.new(
          title=graphTitle,
          span=24,
          datasource='$datasource',
          fill=2,
          min_span=24,
          format=graphFormat,
          min=0,
          max=null,
          show_xaxis=false,
          x_axis_mode='series',
          x_axis_values='current',
          lines=false,
          bars=true,
          stack=false,
          legend_show=true,
          legend_values=true,
          legend_min=false,
          legend_max=false,
          legend_current=true,
          legend_avg=false,
          legend_alignAsTable=true,
          legend_rightSide=true,
          legend_sort='current',
          legend_sortDesc=true,
          nullPointMode='null'
        ).addTarget(target) + {
          legend+: {
            hideEmpty: true,
            hideZero: true,
          },
          paceLength: 10,
          tooltip+: {
            sort: 2,
          },
        };

      local newGraphPanel(graphTitle, graphQuery, graphFormat='Bps', legendFormat='{{namespace}}') =
        local target =
          prometheus.target(
            graphQuery
          ) + {
            intervalFactor: 1,
            legendFormat: legendFormat,
            step: 10,
          };

        graphPanel.new(
          title=graphTitle,
          span=24,
          datasource='$datasource',
          fill=2,
          linewidth=2,
          min_span=24,
          format=graphFormat,
          min=0,
          max=null,
          x_axis_mode='time',
          x_axis_values='total',
          lines=true,
          stack=true,
          legend_show=true,
          legend_values=true,
          legend_min=true,
          legend_max=true,
          legend_current=true,
          legend_avg=true,
          legend_alignAsTable=true,
          legend_rightSide=true,
          nullPointMode='connected'
        ).addTarget(target) + {
          legend+: {
            hideEmpty: true,
            hideZero: true,
          },
          paceLength: 10,
          tooltip+: {
            sort: 2,
          },
        };

      local intervalTemplate =
        template.new(
          name='interval',
          datasource='$datasource',
          query='4h',
          current='5m',
          hide=2,
          refresh=2,
          includeAll=false,
          sort=1
        ) + {
          auto: false,
          auto_count: 30,
          auto_min: '10s',
          skipUrlSync: false,
          type: 'interval',
          options: [
            {
              selected: true,
              text: '4h',
              value: '4h',
            },
          ],
        };

      //#####  Current Bandwidth Row ######

      local currentBandwidthRow =
        row.new(
          title='Current Bandwidth'
        );

      //#####  Bandwidth History Row ######
      local bandwidthHistoryRow =
        row.new(
          title='Bandwidth History'
        );

      //##### Packet  Row ######
      // collapsed, so row must include panels
      local packetRow =
        row.new(
          title='Packets',
          collapse=true,
        );

      //##### Error Row ######
      // collapsed, so row must include panels
      local errorRow =
        row.new(
          title='Errors',
          collapse=true,
        );
      local clusterTemplate =
        template.new(
          name='cluster',
          datasource='$datasource',
          query='label_values(kube_pod_info, %s)' % $._config.clusterLabel,
          hide=if $._config.showMultiCluster then '' else '2',
          refresh=2
        );

      dashboard.new(
        title='%(dashboardNamePrefix)sNetworking / Cluster' % $._config.grafanaK8s,
        tags=($._config.grafanaK8s.dashboardTags + ['network-usage']),
        editable=false,
        schemaVersion=18,
        refresh=($._config.grafanaK8s.refresh),
        time_from='now-1h',
        time_to='now',
      )
      .addLink({
        title: 'Networking Dashboards',
        type: 'dashboards',
        asDropdown: false,
        includeVars: true,
        keepTime: true,
        tags: ($._config.grafanaK8s.dashboardTags + ['network-usage']),
      })
      .addTemplate(intervalTemplate)
      .addAnnotation(annotation.default)
      .addPanel(
        currentBandwidthRow, gridPos={ h: 1, w: 24, x: 0, y: 0 }
      )
      .addTemplate(
        {
          current: {
            text: 'default',
            value: 'default',
          },
          hide: 0,
          label: null,
          name: 'datasource',
          options: [],
          query: 'prometheus',
          refresh: 1,
          regex: '',
          type: 'datasource',
        },
      )
      .addTemplate(clusterTemplate)
      .addPanel(
        newBarplotPanel(
          graphTitle='Current Rate of Bytes Received',
          graphQuery='sort_desc(sum(irate(container_network_receive_bytes_total{%(clusterLabel)s="$cluster",namespace=~".+"}[%(grafanaIntervalVar)s])) by (namespace))' % $._config,
        ),
        gridPos={ h: 8, w: 12, x: 0, y: 1 }
      )
      .addPanel(
        newBarplotPanel(
          graphTitle='Current Rate of Bytes Transmitted',
          graphQuery='sort_desc(sum(irate(container_network_transmit_bytes_total{%(clusterLabel)s="$cluster",namespace=~".+"}[%(grafanaIntervalVar)s])) by (namespace))' % $._config,
        ),
        gridPos={ h: 8, w: 12, x: 12, y: 1 }
      )
      .addPanel(
        bandwidthHistoryRow, gridPos={ h: 1, w: 24, x: 0, y: 11 }
      )
      .addPanel(
        newGraphPanel(
          graphTitle='Receive Bandwidth',
          graphQuery='sort_desc(sum(rate(container_network_receive_bytes_total{%(clusterLabel)s="$cluster",namespace=~".+"}[%(grafanaIntervalVar)s])) by (namespace))' % $._config,
        ),
        gridPos={ h: 9, w: 24, x: 0, y: 12 }
      )
      .addPanel(
        newGraphPanel(
          graphTitle='Transmit Bandwidth',
          graphQuery='sort_desc(sum(rate(container_network_transmit_bytes_total{%(clusterLabel)s="$cluster",namespace=~".+"}[%(grafanaIntervalVar)s])) by (namespace))' % $._config,
        ),
        gridPos={ h: 9, w: 24, x: 0, y: 21 }
      )
      .addPanel(
        packetRow
        .addPanel(
          newGraphPanel(
            graphTitle='Rate of Received Packets',
            graphQuery='sort_desc(sum(rate(container_network_receive_packets_total{%(clusterLabel)s="$cluster",namespace=~".+"}[%(grafanaIntervalVar)s])) by (namespace))' % $._config,
            graphFormat='pps'
          ),
          gridPos={ h: 9, w: 24, x: 0, y: 31 }
        )
        .addPanel(
          newGraphPanel(
            graphTitle='Rate of Transmitted Packets',
            graphQuery='sort_desc(sum(rate(container_network_transmit_packets_total{%(clusterLabel)s="$cluster",namespace=~".+"}[%(grafanaIntervalVar)s])) by (namespace))' % $._config,
            graphFormat='pps'
          ),
          gridPos={ h: 9, w: 24, x: 0, y: 40 }
        ),
        gridPos={ h: 1, w: 24, x: 0, y: 30 }
      )
      .addPanel(
        errorRow
        .addPanel(
          newGraphPanel(
            graphTitle='Rate of Received Packets Dropped',
            graphQuery='sort_desc(sum(rate(container_network_receive_packets_dropped_total{%(clusterLabel)s="$cluster",namespace=~".+"}[%(grafanaIntervalVar)s])) by (namespace))' % $._config,
            graphFormat='pps'
          ),
          gridPos={ h: 9, w: 24, x: 0, y: 50 }
        )
        .addPanel(
          newGraphPanel(
            graphTitle='Rate of Transmitted Packets Dropped',
            graphQuery='sort_desc(sum(rate(container_network_transmit_packets_dropped_total{%(clusterLabel)s="$cluster",namespace=~".+"}[%(grafanaIntervalVar)s])) by (namespace))' % $._config,
            graphFormat='pps'
          ),
          gridPos={ h: 9, w: 24, x: 0, y: 59 }
        )
        .addPanel(
          newGraphPanel(
            graphTitle='Rate of TCP Retransmits out of all sent segments',
            graphQuery='sort_desc(sum(rate(node_netstat_Tcp_RetransSegs{%(clusterLabel)s="$cluster"}[%(grafanaIntervalVar)s]) / rate(node_netstat_Tcp_OutSegs{%(clusterLabel)s="$cluster"}[%(grafanaIntervalVar)s])) by (instance))' % $._config,
            graphFormat='percentunit',
            legendFormat='{{instance}}'
          ) + { links: [
            {
              url: 'https://accedian.com/enterprises/blog/network-packet-loss-retransmissions-and-duplicate-acknowledgements/',
              title: 'What is TCP Retransmit?',
              targetBlank: true,
            },
          ] },
          gridPos={ h: 9, w: 24, x: 0, y: 59 }
        ).addPanel(
          newGraphPanel(
            graphTitle='Rate of TCP SYN Retransmits out of all retransmits',
            graphQuery='sort_desc(sum(rate(node_netstat_TcpExt_TCPSynRetrans{%(clusterLabel)s="$cluster"}[%(grafanaIntervalVar)s]) / rate(node_netstat_Tcp_RetransSegs{%(clusterLabel)s="$cluster"}[%(grafanaIntervalVar)s])) by (instance))' % $._config,
            graphFormat='percentunit',
            legendFormat='{{instance}}'
          ) + { links: [
            {
              url: 'https://github.com/prometheus/node_exporter/issues/1023#issuecomment-408128365',
              title: 'Why monitor SYN retransmits?',
              targetBlank: true,
            },
          ] },
          gridPos={ h: 9, w: 24, x: 0, y: 59 }
        ),
        gridPos={ h: 1, w: 24, x: 0, y: 31 }
      ),
  },
}
