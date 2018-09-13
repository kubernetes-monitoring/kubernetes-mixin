local grafana = import 'grafonnet/grafana.libsonnet';
local dashboard = grafana.dashboard;
local row = grafana.row;
local prometheus = grafana.prometheus;
local template = grafana.template;
local graphPanel = grafana.graphPanel;
local promgrafonnet = import '../lib/promgrafonnet/promgrafonnet.libsonnet';
local numbersinglestat = promgrafonnet.numbersinglestat;
local gauge = promgrafonnet.gauge;

{
  grafanaDashboards+:: {
    'nodes.json':
      local systemLoad =
        graphPanel.new(
          'System load',
          datasource='$datasource',
          span=6,
          format='percentunit',
        )
        .addTarget(prometheus.target('max(node_load1{%(nodeExporterSelector)s, instance="$instance"})' % $._config, legendFormat='load 1m'))
        .addTarget(prometheus.target('max(node_load5{%(nodeExporterSelector)s, instance="$instance"})' % $._config, legendFormat='load 5m'))
        .addTarget(prometheus.target('max(node_load15{%(nodeExporterSelector)s, instance="$instance"})' % $._config, legendFormat='load 15m'));

      local cpuByCore =
        graphPanel.new(
          'System load',
          datasource='$datasource',
          span=6,
          format='percentunit',
        )
        .addTarget(prometheus.target('avg by (cpu) (irate(node_cpu{%(nodeExporterSelector)s, mode!="idle", instance="$instance"}[5m])) * 100' % $._config, legendFormat='{{cpu}}'));

      local memoryGraph =
        graphPanel.new(
          'Memory Usage',
          datasource='$datasource',
          span=9,
          format='bytes',
        )
        .addTarget(prometheus.target(
          |||
            max(
              node_memory_MemTotal{%(nodeExporterSelector)s, instance="$instance"}
              - node_memory_MemFree{%(nodeExporterSelector)s, instance="$instance"}
              - node_memory_Buffers{%(nodeExporterSelector)s, instance="$instance"}
              - node_memory_Cached{%(nodeExporterSelector)s, instance="$instance"}
            )
          ||| % $._config, legendFormat='memory used'
        ))
        .addTarget(prometheus.target('max(node_memory_Buffers{%(nodeExporterSelector)s, instance="$instance"})' % $._config, legendFormat='memory buffers'))
        .addTarget(prometheus.target('max(node_memory_Cached{%(nodeExporterSelector)s, instance="$instance"})' % $._config, legendFormat='memory cached'))
        .addTarget(prometheus.target('max(node_memory_MemFree{%(nodeExporterSelector)s, instance="$instance"})' % $._config, legendFormat='memory free'));

      local memoryGauge = gauge.new(
        'Memory Usage',
        |||
          max(
            (
              (
                node_memory_MemTotal{%(nodeExporterSelector)s, instance="$instance"}
              - node_memory_MemFree{%(nodeExporterSelector)s, instance="$instance"}
              - node_memory_Buffers{%(nodeExporterSelector)s, instance="$instance"}
              - node_memory_Cached{%(nodeExporterSelector)s, instance="$instance"}
              )
              / node_memory_MemTotal{%(nodeExporterSelector)s, instance="$instance"}
            ) * 100)
        ||| % $._config,
      ).withLowerBeingBetter();

      // cpu
      local cpuGraph = graphPanel.new(
        'CPU Utilizaion',
        datasource='$datasource',
        span=9,
        format='percent',
        max=100,
        min=0,
        legend_show='true',
        legend_values='true',
        legend_min='false',
        legend_max='false',
        legend_current='true',
        legend_total='false',
        legend_avg='true',
        legend_alignAsTable='true',
        legend_rightSide='true',
      ).addTarget(prometheus.target(
        |||
          avg (sum by (cpu) (irate(node_cpu{%(nodeExporterSelector)s, mode!="idle", instance="$instance"}[2m])) ) * 100
        ||| % $._config,
        legendFormat='{{ cpu }}',
        intervalFactor=10,
      ));

      local cpuGauge = gauge.new(
        'CPU Usage',
        |||
          avg(sum by (cpu) (irate(node_cpu{%(nodeExporterSelector)s, mode!="idle", instance="$instance"}[2m]))) * 100
        ||| % $._config,
      ).withLowerBeingBetter();

      local diskIO =
        graphPanel.new(
          'Disk I/O',
          datasource='$datasource',
          span=6,
        )
        .addTarget(prometheus.target('max(rate(node_disk_bytes_read{%(nodeExporterSelector)s, instance="$instance"}[2m]))' % $._config, legendFormat='read'))
        .addTarget(prometheus.target('max(rate(node_disk_bytes_written{%(nodeExporterSelector)s, instance="$instance"}[2m]))' % $._config, legendFormat='written'))
        .addTarget(prometheus.target('max(rate(node_disk_io_time_ms{%(nodeExporterSelector)s,  instance="$instance"}[2m]))' % $._config, legendFormat='io time')) +
        {
          seriesOverrides: [
            {
              alias: 'read',
              yaxis: 1,
            },
            {
              alias: 'io time',
              yaxis: 2,
            },
          ],
          yaxes: [
            self.yaxe(format='bytes'),
            self.yaxe(format='ms'),
          ],
        };

      local diskSpaceUsage = graphPanel.new(
        'Disk Space Usage',
        datasource='$datasource',
        span=6,
        format='percentunit',
      ).addTarget(prometheus.target(
        |||
          node:node_filesystem_usage:
        ||| % $._config, legendFormat='{{device}}',
      ));

      local networkReceived =
        graphPanel.new(
          'Network Received',
          datasource='$datasource',
          span=6,
          format='bytes',
        )
        .addTarget(prometheus.target('max(rate(node_network_receive_bytes{%(nodeExporterSelector)s, instance="$instance", device!~"lo"}[5m]))' % $._config, legendFormat='{{device}}'));

      local networkTransmitted =
        graphPanel.new(
          'Network Transmitted',
          datasource='$datasource',
          span=6,
          format='bytes',
        )
        .addTarget(prometheus.target('max(rate(node_network_transmit_bytes{%(nodeExporterSelector)s, instance="$instance", device!~"lo"}[5m]))' % $._config, legendFormat='{{device}}'));

      dashboard.new(
        'Nodes',
        time_from='now-1h',
      ).addTemplate(
        {
          current: {
            text: 'Prometheus',
            value: 'Prometheus',
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
      .addTemplate(
        template.new(
          'instance',
          '$datasource',
          'label_values(node_boot_time{%(nodeExporterSelector)s}, instance)' % $._config,
          refresh='time',
        )
      )
      .addRow(
        row.new()
        .addPanel(systemLoad)
        .addPanel(cpuByCore)
      )
      .addRow(
        row.new()
        .addPanel(cpuGraph)
        .addPanel(cpuGauge)
      )
      .addRow(
        row.new()
        .addPanel(memoryGraph)
        .addPanel(memoryGauge)
      )
      .addRow(
        row.new()
        .addPanel(diskIO)
        .addPanel(diskSpaceUsage)
      )
      .addRow(
        row.new()
        .addPanel(networkReceived)
        .addPanel(networkTransmitted)
      ),
  },
}
