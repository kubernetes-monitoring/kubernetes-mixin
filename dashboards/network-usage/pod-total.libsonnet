local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local dashboard = grafana.dashboard;
local row = grafana.row;
local prometheus = grafana.prometheus;
local template = grafana.template;
local graphPanel = grafana.graphPanel;
local annotation = grafana.annotation;
local singlestat = grafana.singlestat;

{
  grafanaDashboards+:: {

    'network-pod-total.json':

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

      local newGraphPanel(graphTitle, graphQuery, graphFormat='Bps', legendFormat='{{pod}}') =
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
      local clusterTemplate =
        template.new(
          name='cluster',
          datasource='$datasource',
          query='label_values(kube_pod_info, %s)' % $._config.clusterLabel,
          hide=if $._config.showMultiCluster then '' else '2',
          refresh=2
        );


      local namespaceTemplate =
        template.new(
          name='namespace',
          datasource='$datasource',
          query='label_values(container_network_receive_packets_total{%(clusterLabel)s="$cluster"}, namespace)' % $._config,
          allValues='.+',
          current='kube-system',
          hide='',
          refresh=2,
          includeAll=true,
          sort=1
        ) + {
          auto: false,
          auto_count: 30,
          auto_min: '10s',
          definition: 'label_values(container_network_receive_packets_total{%(clusterLabel)s="$cluster"}, namespace)' % $._config,
          skipUrlSync: false,
        };

      local podTemplate =
        template.new(
          name='pod',
          datasource='$datasource',
          query='label_values(container_network_receive_packets_total{%(clusterLabel)s="$cluster",namespace=~"$namespace"}, pod)' % $._config,
          allValues='.+',
          current='',
          hide='',
          refresh=2,
          includeAll=true,
          multi=true,
          sort=1
        ) + {
          auto: false,
          auto_count: 30,
          auto_min: '10s',
          definition: 'label_values(container_network_receive_packets_total{%(clusterLabel)s="$cluster",namespace=~"$namespace"}, pod)' % $._config,
          skipUrlSync: false,
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

      //#####  Bandwidth Row ######

      local bandwidthRow =
        row.new(
          title='Bandwidth'
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

      dashboard.new(
        title='%(dashboardNamePrefix)sNetworking / Namespace' % $._config.grafanaK8s,
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
      .addTemplate(namespaceTemplate)
      .addTemplate(podTemplate)
      .addTemplate(intervalTemplate)
      .addAnnotation(annotation.default)
      .addPanel(currentBandwidthRow, gridPos={ h: 1, w: 24, x: 0, y: 0 })
      .addPanel(
        newBarplotPanel(
          graphTitle='Current Rate of Bytes Received',
          graphQuery='sum by (pod) (irate(container_network_receive_bytes_total{%(clusterLabel)s="$cluster",namespace=~"$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s]))' % $._config,
        ),
        gridPos={ h: 8, w: 12, x: 0, y: 1 }
      )
      .addPanel(
        newBarplotPanel(
          graphTitle='Current Rate of Bytes Transmitted',
          graphQuery='sum by (pod) (irate(container_network_transmit_bytes_total{%(clusterLabel)s="$cluster",namespace=~"$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s]))' % $._config,
        ),
        gridPos={ h: 8, w: 12, x: 12, y: 1 }
      )
      .addPanel(bandwidthRow, gridPos={ h: 1, w: 24, x: 0, y: 10 })
      .addPanel(
        newGraphPanel(
          graphTitle='Receive Bandwidth',
          graphQuery='sum by (pod) (rate(container_network_receive_bytes_total{%(clusterLabel)s="$cluster",namespace=~"$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s]))' % $._config,
        ),
        gridPos={ h: 9, w: 24, x: 0, y: 11 }
      )
      .addPanel(
        newGraphPanel(
          graphTitle='Transmit Bandwidth',
          graphQuery='sum by (pod) (rate(container_network_transmit_bytes_total{%(clusterLabel)s="$cluster",namespace=~"$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s]))' % $._config,
        ),
        gridPos={ h: 9, w: 24, x: 12, y: 11 }
      )
      .addPanel(
        packetRow
        .addPanel(
          newGraphPanel(
            graphTitle='Rate of Received Packets',
            graphQuery='sum by (pod) (rate(container_network_receive_packets_total{%(clusterLabel)s="$cluster",namespace=~"$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s]))' % $._config,
            graphFormat='pps'
          ),
          gridPos={ h: 10, w: 24, x: 0, y: 21 }
        )
        .addPanel(
          newGraphPanel(
            graphTitle='Rate of Transmitted Packets',
            graphQuery='sum by (pod) (rate(container_network_transmit_packets_total{%(clusterLabel)s="$cluster",namespace=~"$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s]))' % $._config,
            graphFormat='pps'
          ),
          gridPos={ h: 10, w: 24, x: 12, y: 21 }
        ),
        gridPos={ h: 1, w: 24, x: 0, y: 20 }
      )
      .addPanel(
        errorRow
        .addPanel(
          newGraphPanel(
            graphTitle='Rate of Received Packets Dropped',
            graphQuery='sum by (pod) (rate(container_network_receive_packets_dropped_total{%(clusterLabel)s="$cluster",namespace=~"$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s]))' % $._config,
            graphFormat='pps'
          ),
          gridPos={ h: 10, w: 24, x: 0, y: 32 }
        )
        .addPanel(
          newGraphPanel(
            graphTitle='Rate of Transmitted Packets Dropped',
            graphQuery='sum by (pod) (rate(container_network_transmit_packets_dropped_total{%(clusterLabel)s="$cluster",namespace=~"$namespace", pod=~"$pod"}[%(grafanaIntervalVar)s]))' % $._config,
            graphFormat='pps'
          ),
          gridPos={ h: 10, w: 24, x: 12, y: 32 }
        ),
        gridPos={ h: 1, w: 24, x: 0, y: 21 }
      ),
  },
}
