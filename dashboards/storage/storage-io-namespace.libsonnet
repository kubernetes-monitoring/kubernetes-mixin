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

    'storage-io-namespace.json':

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

      local newGraphPanel(graphTitle, graphQuery, graphFormat='short', decimals='-1', unit='short') =
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
          fill=0,
          linewidth=2,
          min_span=12,
          format=graphFormat,
          min=0,
          max=null,
          x_axis_mode='time',
          x_axis_values='total',
          lines=true,
          stack=false,
          legend_show=true,
          nullPointMode='connected',
          decimals=decimals,
          formatY1=unit,
        ).addTarget(target) + {
          legend+: {
            hideEmpty: true,
            hideZero: true,
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

      local newTablePanel(tableTitle, colQueries) =
        local buildTarget(index, colQuery) =
          prometheus.target(
            colQuery,
            format='table',
            instant=true,
          ) + {
            legendFormat: '',
            step: 10,
            refId: std.char(65 + index),
          };

        local targets = std.mapWithIndex(buildTarget, colQueries);

        tablePanel.new(
          title=tableTitle,
          span=24,
          min_span=24,
          datasource='$datasource',
        )
        .addColumn(
          field='Time',
          style=newStyle(
            alias='Time',
            type='hidden',
          )
        )
        .addColumn(
          field='Value #A',
          style=newStyle(
            alias='IOPS(Reads)',
            unit='short',
            decimals='-1'
          ),
        )
        .addColumn(
          field='Value #B',
          style=newStyle(
            alias='IOPS(Reads)',
            unit='short',
            decimals='-1'
          ),
        )
        .addColumn(
          field='Value #C',
          style=newStyle(
            alias='IOPS(Reads + Writes)',
            unit='short',
            decimals='-1'
          ),
        )
        .addColumn(
          field='Value #D',
          style=newStyle(
            alias='Throughput(Read)',
            unit='Bps',
          ),
        )
        .addColumn(
          field='Value #E',
          style=newStyle(
            alias='Throughput(Write)',
            unit='Bps',
          ),
        )
        .addColumn(
          field='Value #F',
          style=newStyle(
            alias='Throughput(Read + Write)',
            unit='Bps',
          ),
        )
        .addColumn(
          field='pod',
          style=newStyle(
            alias='Pod',
            link=true,
            linkUrl='d/fc3f305911975d382b37be5699a47d22/kubernetes-storage-pod-io?orgId=1&refresh=30s&var-namespace=$namespace&var-pod=$__cell',
          ),
        ) + {

          fill: 1,
          fontSize: '100%',
          lines: true,
          linewidth: 1,
          nullPointMode: 'null as zero',
          renderer: 'flot',
          scroll: true,
          showHeader: true,
          spaceLength: 10,
          sort: {
            col: 5,
            desc: true,
          },
          targets: targets,
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

      dashboard.new(
        title='%(dashboardNamePrefix)sStorage / Namespace (Pods IO)' % $._config.grafanaK8s,
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
      .addTemplate(intervalTemplate)
      .addAnnotation(annotation.default)
      .addPanel(
        newGraphPanel(
          graphTitle='IOPS(Read+Write)',
          graphQuery='sum by(namespace, pod) (rate(container_fs_reads_total{container!="", %(clusterLabel)s="$cluster",namespace=~"$namespace"}[5m]) + rate(container_fs_writes_total{container!="", %(clusterLabel)s="$cluster",namespace=~"$namespace"}[5m]))' % $._config,
          decimals=-1,
          graphFormat='short',
          unit='short',
        ),
        gridPos={ h: 9, w: 12, x: 0, y: 0 },
      )
      .addPanel(
        newGraphPanel(
          graphTitle='ThroughPut(Read+Write)',
          graphQuery='sum by(namespace, pod) (rate(container_fs_reads_bytes_total{container!="", %(clusterLabel)s="$cluster",namespace=~"$namespace"}[5m]) + rate(container_fs_writes_bytes_total{container!="", %(clusterLabel)s="$cluster",namespace=~"$namespace"}[5m]))' % $._config,
          decimals=2,
          graphFormat='Bps',
          unit='Bps',
        ),
        gridPos={ h: 9, w: 12, x: 12, y: 0 }
      )
      .addPanel(
        newTablePanel(
          tableTitle='POD IO',
          colQueries=[
            'sum by(namespace, pod) (rate(container_fs_reads_total{container!="", %(clusterLabel)s="$cluster",namespace=~"$namespace"}[5m]))' % $._config,
            'sum by(namespace, pod) (rate(container_fs_writes_total{container!="", %(clusterLabel)s="$cluster",namespace=~"$namespace"}[5m]))' % $._config,
            'sum by(namespace, pod) (rate(container_fs_reads_total{container!="", %(clusterLabel)s="$cluster",namespace=~"$namespace"}[5m]) + rate(container_fs_writes_total{container!="", %(clusterLabel)s="$cluster",namespace=~"$namespace"}[5m]))' % $._config,
            'sum by(namespace, pod) (rate(container_fs_reads_bytes_total{container!="", %(clusterLabel)s="$cluster",namespace=~"$namespace"}[5m]))' % $._config,
            'sum by(namespace, pod) (rate(container_fs_writes_bytes_total{container!="", %(clusterLabel)s="$cluster",namespace=~"$namespace"}[5m]))' % $._config,
            'sum by(namespace, pod) (rate(container_fs_reads_bytes_total{container!="", %(clusterLabel)s="$cluster",namespace=~"$namespace"}[5m]) + rate(container_fs_writes_bytes_total{container!="", %(clusterLabel)s="$cluster",namespace=~"$namespace"}[5m]))' % $._config,
          ],
        ),
        gridPos={ h: 12, w: 24, x: 0, y: 9 }
      ),
  },
}
