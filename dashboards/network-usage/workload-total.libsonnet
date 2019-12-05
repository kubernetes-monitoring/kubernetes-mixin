local grafana = import 'grafonnet/grafana.libsonnet';
local dashboard = grafana.dashboard;
local row = grafana.row;
local prometheus = grafana.prometheus;
local template = grafana.template;
local graphPanel = grafana.graphPanel;
local annotation = grafana.annotation;
local singlestat = grafana.singlestat;
local piechart = grafana.pieChartPanel;
local promgrafonnet = import '../lib/promgrafonnet/promgrafonnet.libsonnet';
local numbersinglestat = promgrafonnet.numbersinglestat;
local gauge = promgrafonnet.gauge;

{
  grafanaDashboards+:: {

    'workload-total.json':

      local newPieChartPanel(pieChartTitle, pieChartQuery) =
        local target =
          prometheus.target(
            pieChartQuery
          ) + {
            instant: null,
            intervalFactor: 1,
            legendFormat: '{{pod}}',
          };

        piechart.new(
          title=pieChartTitle,
          datasource='$datasource',
          pieType='donut',
        ).addTarget(target) + {
          breakpoint: '50%',
          cacheTimeout: null,
          combine: {
            label: 'Others',
            threshold: 0,
          },
          fontSize: '80%',
          format: 'Bps',
          interval: null,
          legend: {
            percentage: true,
            percentageDecimals: null,
            show: true,
            values: true,
          },
          legendType: 'Right side',
          maxDataPoints: 3,
          nullPointMode: 'connected',
          valueName: 'current',
        };

      local newGraphPanel(graphTitle, graphQuery, graphFormat='Bps') =
        local target =
          prometheus.target(
            graphQuery
          ) + {
            intervalFactor: 1,
            legendFormat: '{{pod}}',
            step: 10,
          };

        graphPanel.new(
          title=graphTitle,
          span=12,
          datasource='$datasource',
          fill=2,
          linewidth=2,
          min_span=12,
          format=graphFormat,
          min=0,
          max=null,
          x_axis_mode='time',
          x_axis_values='total',
          lines=true,
          stack=true,
          legend_show=true,
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

      local namespaceTemplate =
        template.new(
          name='namespace',
          datasource='$datasource',
          query='label_values(container_network_receive_packets_total, namespace)',
          allValues='.+',
          current='kube-system',
          hide='',
          refresh=1,
          includeAll=true,
          sort=1
        ) + {
          auto: false,
          auto_count: 30,
          auto_min: '10s',
          definition: 'label_values(container_network_receive_packets_total, namespace)',
          skipUrlSync: false,
        };

      local workloadTemplate =
        template.new(
          name='workload',
          datasource='$datasource',
          query='label_values(mixin_pod_workload{namespace=~"$namespace"}, workload)',
          current='',
          hide='',
          refresh=1,
          includeAll=false,
          sort=1
        ) + {
          auto: false,
          auto_count: 30,
          auto_min: '10s',
          definition: 'label_values(mixin_pod_workload{namespace=~"$namespace"}, workload)',
          skipUrlSync: false,
        };

      local typeTemplate =
        template.new(
          name='type',
          datasource='$datasource',
          query='label_values(mixin_pod_workload{namespace=~"$namespace", workload=~"$workload"}, workload_type)',
          current='deployment',
          hide='',
          refresh=1,
          includeAll=false,
          sort=0
        ) + {
          auto: false,
          auto_count: 30,
          auto_min: '10s',
          definition: 'label_values(mixin_pod_workload{namespace=~"$namespace", workload=~"$workload"}, workload_type)',
          skipUrlSync: false,
        };

      local resolutionTemplate =
        template.new(
          name='resolution',
          datasource='$datasource',
          query='30s,5m,1h',
          current='5m',
          hide='',
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
              selected: false,
              text: '30s',
              value: '30s',
            },
            {
              selected: true,
              text: '5m',
              value: '5m',
            },
            {
              selected: false,
              text: '1h',
              value: '1h',
            },
          ],
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

      //#####  Average Bandwidth Row ######

      local averageBandwidthRow =
        row.new(
          title='Average Bandwidth',
          collapse=true,
        );

      //#####  Bandwidth History Row ######

      local bandwidthHistoryRow =
        row.new(
          title='Bandwidth HIstory',
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
        title='%(dashboardNamePrefix)sNetworking / Workload' % $._config.grafanaK8s,
        tags=($._config.grafanaK8s.dashboardTags),
        editable=true,
        schemaVersion=18,
        refresh='30s',
        time_from='now-1h',
        time_to='now',
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
      .addTemplate(namespaceTemplate)
      .addTemplate(workloadTemplate)
      .addTemplate(typeTemplate)
      .addTemplate(resolutionTemplate)
      .addTemplate(intervalTemplate)
      .addAnnotation(annotation.default)
      .addPanel(currentBandwidthRow, gridPos={ h: 1, w: 24, x: 0, y: 0 })
      .addPanel(
        newPieChartPanel(
          pieChartTitle='Current Rate of Bytes Received',
          pieChartQuery=|||
            sort_desc(sum(irate(container_network_receive_bytes_total{namespace=~"$namespace"}[$interval:$resolution])
            * on (namespace,pod)
            group_left(workload,workload_type) mixin_pod_workload{namespace=~"$namespace", workload=~"$workload", workload_type="$type"}) by (pod))
          |||,
        ),
        gridPos={ h: 9, w: 12, x: 0, y: 1 }
      )
      .addPanel(
        newPieChartPanel(
          pieChartTitle='Current Rate of Bytes Transmitted',
          pieChartQuery=|||
            sort_desc(sum(irate(container_network_transmit_bytes_total{namespace=~"$namespace"}[$interval:$resolution])
            * on (namespace,pod)
            group_left(workload,workload_type) mixin_pod_workload{namespace=~"$namespace", workload=~"$workload", workload_type="$type"}) by (pod))
          |||,
        ),
        gridPos={ h: 9, w: 12, x: 12, y: 1 }
      )
      .addPanel(
        averageBandwidthRow
        .addPanel(
          newPieChartPanel(
            pieChartTitle='Average Rate of Bytes Received',
            pieChartQuery=|||
              sort_desc(avg(irate(container_network_receive_bytes_total{namespace=~"$namespace"}[$interval:$resolution])
              * on (namespace,pod)
              group_left(workload,workload_type) mixin_pod_workload{namespace=~"$namespace", workload=~"$workload", workload_type="$type"}) by (pod))
            |||,
          ),
          gridPos={ h: 9, w: 12, x: 0, y: 11 }
        )
        .addPanel(
          newPieChartPanel(
            pieChartTitle='Average Rate of Bytes Transmitted',
            pieChartQuery=|||
              sort_desc(avg(irate(container_network_transmit_bytes_total{namespace=~"$namespace"}[$interval:$resolution])
              * on (namespace,pod)
              group_left(workload,workload_type) mixin_pod_workload{namespace=~"$namespace", workload=~"$workload", workload_type="$type"}) by (pod))
            |||,
          ),
          gridPos={ h: 9, w: 12, x: 12, y: 11 }
        ),
        gridPos={ h: 1, w: 24, x: 0, y: 10 },
      )
      .addPanel(
        bandwidthHistoryRow, gridPos={ h: 1, w: 24, x: 0, y: 11 }
      )
      .addPanel(
        newGraphPanel(
          graphTitle='Receive Bandwidth',
          graphQuery=|||
            sort_desc(sum(irate(container_network_receive_bytes_total{namespace=~"$namespace"}[$interval:$resolution])
            * on (namespace,pod)
            group_left(workload,workload_type) mixin_pod_workload{namespace=~"$namespace", workload=~"$workload", workload_type="$type"}) by (pod))
          |||,
        ),
        gridPos={ h: 9, w: 12, x: 0, y: 12 }
      )
      .addPanel(
        newGraphPanel(
          graphTitle='Transmit Bandwidth',
          graphQuery=|||
            sort_desc(sum(irate(container_network_transmit_bytes_total{namespace=~"$namespace"}[$interval:$resolution])
            * on (namespace,pod)
            group_left(workload,workload_type) mixin_pod_workload{namespace=~"$namespace", workload=~"$workload", workload_type="$type"}) by (pod))
          |||,
        ),
        gridPos={ h: 9, w: 12, x: 12, y: 12 }
      )
      .addPanel(
        packetRow
        .addPanel(
          newGraphPanel(
            graphTitle='Rate of Received Packets',
            graphQuery=|||
              sort_desc(sum(irate(container_network_receive_packets_total{namespace=~"$namespace"}[$interval:$resolution])
              * on (namespace,pod)
              group_left(workload,workload_type) mixin_pod_workload{namespace=~"$namespace", workload=~"$workload", workload_type="$type"}) by (pod))
            |||,
            graphFormat='pps'
          ),
          gridPos={ h: 9, w: 12, x: 0, y: 22 }
        )
        .addPanel(
          newGraphPanel(
            graphTitle='Rate of Transmitted Packets',
            graphQuery=|||
              sort_desc(sum(irate(container_network_transmit_packets_total{namespace=~"$namespace"}[$interval:$resolution])
              * on (namespace,pod)
              group_left(workload,workload_type) mixin_pod_workload{namespace=~"$namespace", workload=~"$workload", workload_type="$type"}) by (pod))
            |||,
            graphFormat='pps'
          ),
          gridPos={ h: 9, w: 12, x: 12, y: 22 }
        ),
        gridPos={ h: 1, w: 24, x: 0, y: 21 }
      )
      .addPanel(
        errorRow
        .addPanel(
          newGraphPanel(
            graphTitle='Rate of Received Packets Dropped',
            graphQuery=|||
              sort_desc(sum(irate(container_network_receive_packets_dropped_total{namespace=~"$namespace"}[$interval:$resolution])
              * on (namespace,pod)
              group_left(workload,workload_type) mixin_pod_workload{namespace=~"$namespace", workload=~"$workload", workload_type="$type"}) by (pod))
            |||,
            graphFormat='pps'
          ),
          gridPos={ h: 9, w: 12, x: 0, y: 23 }
        )
        .addPanel(
          newGraphPanel(
            graphTitle='Rate of Transmitted Packets Dropped',
            graphQuery=|||
              sort_desc(sum(irate(container_network_transmit_packets_dropped_total{namespace=~"$namespace"}[$interval:$resolution])
              * on (namespace,pod)
              group_left(workload,workload_type) mixin_pod_workload{namespace=~"$namespace", workload=~"$workload", workload_type="$type"}) by (pod))
            |||,
            graphFormat='pps'
          ),
          gridPos={ h: 9, w: 12, x: 12, y: 23 }
        ),
        gridPos={ h: 1, w: 24, x: 0, y: 22 }
      ),
  },
}
