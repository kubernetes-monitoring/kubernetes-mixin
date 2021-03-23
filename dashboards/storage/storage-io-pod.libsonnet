local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local dashboard = grafana.dashboard;
local row = grafana.row;
local prometheus = grafana.prometheus;
local template = grafana.template;
local graphPanel = grafana.graphPanel;
local tablePanel = grafana.tablePanel;
local annotation = grafana.annotation;

{
  grafanaDashboards+:: {

    'storage-io-pod.json':

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

      local newGraphPanelPod(graphTitle, graphQuery1, graphQuery2, graphFormat='short', decimals='-1', unit='short') =
        local target1 =
          prometheus.target(
            graphQuery1
          ) + {
            intervalFactor: 1,
            legendFormat: 'Reads',
            step: 10,
          };
        local target2 =
          prometheus.target(
            graphQuery2
          ) + {
            intervalFactor: 1,
            legendFormat: 'Writes',
            step: 10,
          };

        graphPanel.new(
          title=graphTitle,
          span=12,
          datasource='$datasource',
          fill=3,
          fillGradient=5,
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
          nullPointMode='connected',
          decimals=decimals,
          formatY1=unit,
        ).addTarget(target1)
         .addTarget(target2) + {
          legend+: {
            hideEmpty: true,
            hideZero: false,
            alignAsTable: true,
            rightSide: true,
            values: true,
            current: true,
          },
          paceLength: 10,
          tooltip+: {
            sort: 2,
          },
        };
      local newGraphPanelContainer(graphTitle, graphQuery, graphFormat='short', decimals='-1', unit='short') =
        local target =
          prometheus.target(
            graphQuery
          ) + {
            intervalFactor: 1,
            legendFormat: '{{container}}',
            step: 10,
          };

        graphPanel.new(
          title=graphTitle,
          span=12,
          datasource='$datasource',
          fill=3,
          fillGradient=5,
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
          nullPointMode='connected',
          decimals=decimals,
          formatY1=unit,
        ).addTarget(target) + {
          legend+: {
            hideEmpty: true,
            hideZero: false,
            alignAsTable: true,
            rightSide: true,
            sortDesc: true,
            values: true,
            current: true,
            sort: 'current',
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
          refresh=1
        );

      local namespaceTemplate =
        template.new(
          name='namespace',
          datasource='$datasource',
          query='label_values(container_fs_io_current{%(clusterLabel)s="$cluster"}, namespace)' % $._config,
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
          definition: 'label_values(container_fs_io_current{%(clusterLabel)s="$cluster"}, namespace)' % $._config,
          skipUrlSync: false,
        };
        
      local podTemplate =
        template.new(
          name='pod',
          datasource='$datasource',
          query='label_values(container_fs_io_current{%(clusterLabel)s="$cluster",namespace=~"$namespace"}, pod)' % $._config,
          allValues='.+',
          current='',
          hide='',
          refresh=1,
          includeAll=false,
          sort=1
        ) + {
          auto: false,
          auto_count: 30,
          auto_min: '10s',
          definition: 'label_values(container_fs_io_current{%(clusterLabel)s="$cluster",namespace=~"$namespace"}, pod)' % $._config,
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

      local containersViewRow =
        row.new(
          title='Containers View',
          collapse=false,
        );

      dashboard.new(
        title='%(dashboardNamePrefix)sStorage / Pod (IO)' % $._config.grafanaK8s,
        tags=($._config.grafanaK8s.dashboardTags),
        editable=true,
        schemaVersion=18,
        refresh=($._config.grafanaK8s.refresh),
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
      .addTemplate(clusterTemplate)
      .addTemplate(namespaceTemplate)
      .addTemplate(podTemplate)
      .addTemplate(intervalTemplate)
      .addAnnotation(annotation.default)
      .addPanel(
        newGraphPanelPod(
          graphTitle='IOPS',
          graphQuery1='sum by(namespace, pod) (rate(container_fs_reads_total{container!="", %(clusterLabel)s="$cluster",namespace=~"$namespace", pod=~"$pod"}[5m]))' % $._config,
          graphQuery2='sum by(namespace, pod) (rate(container_fs_writes_total{container!="", %(clusterLabel)s="$cluster",namespace=~"$namespace", pod=~"$pod"}[5m]))' % $._config,
          decimals=-1,
          graphFormat='short',
          unit='short',
        ),
        gridPos={ h: 9, w: 12, x: 0, y: 0 },
      )
      .addPanel(
        newGraphPanelPod(
          graphTitle='ThroughPut',
          graphQuery1='sum by(namespace, pod) (rate(container_fs_reads_bytes_total{container!="", %(clusterLabel)s="$cluster",namespace=~"$namespace", pod=~"$pod"}[5m]))' % $._config,
          graphQuery2='sum by(namespace, pod) (rate(container_fs_writes_bytes_total{container!="", %(clusterLabel)s="$cluster",namespace=~"$namespace", pod=~"$pod"}[5m]))' % $._config,
          decimals=2,
          graphFormat='Bps',
          unit='Bps',
        ),
        gridPos={ h: 9, w: 12, x: 12, y: 0 }
      )
      .addPanel(containersViewRow, gridPos={ h: 1, w: 24, x: 0, y: 9 })
      .addPanel(
        newGraphPanelContainer(
          graphTitle='IOPS (Reads)',
          graphQuery='sum by(container) (rate(container_fs_reads_total{container!="", %(clusterLabel)s="$cluster",namespace=~"$namespace", pod=~"$pod"}[5m]))' % $._config,
          decimals=-1,
          graphFormat='short',
          unit='short',
        ),
        gridPos={ h: 9, w: 12, x: 0, y: 10 },
      )
      .addPanel(
        newGraphPanelContainer(
          graphTitle='IOPS (Writes)',
          graphQuery='sum by(container) (rate(container_fs_writes_total{container!="", %(clusterLabel)s="$cluster",namespace=~"$namespace", pod=~"$pod"}[5m]))' % $._config,
          decimals=-1,
          graphFormat='short',
          unit='short',
        ),
        gridPos={ h: 9, w: 12, x: 0, y: 19 },
      )
      .addPanel(
        newGraphPanelContainer(
          graphTitle='ThroughPut (Reads)',
          graphQuery='sum by(container) (rate(container_fs_reads_bytes_total{container!="", %(clusterLabel)s="$cluster",namespace=~"$namespace", pod=~"$pod"}[5m]))' % $._config,
          decimals=2,
          graphFormat='Bps',
          unit='Bps',
        ),
        gridPos={ h: 9, w: 12, x: 12, y: 10 }
      )
      .addPanel(
        newGraphPanelContainer(
          graphTitle='ThroughPut (Writes)',
          graphQuery='sum by(container) (rate(container_fs_writes_bytes_total{container!="", %(clusterLabel)s="$cluster",namespace=~"$namespace", pod=~"$pod"}[5m]))' % $._config,
          decimals=2,
          graphFormat='Bps',
          unit='Bps',
        ),
        gridPos={ h: 9, w: 12, x: 12, y: 19 }
      )

  },
}
