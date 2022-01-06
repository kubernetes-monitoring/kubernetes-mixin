local layout = import 'github.com/grafana/grafonnet-lib/contrib/layout.libsonnet';
local g = import 'github.com/grafana/grafonnet-lib/grafonnet-7.0/grafana.libsonnet';
local model = import 'model.libsonnet';
local config = import '../../config.libsonnet';

config {
  dashboard(kind):
    g.dashboard.new(title='Explore / %s' % kind, refresh='5m', uid=std.md5(kind))
    .setTime(from='now-1h', to='now')
    .addTemplate(
      g.template.datasource.new(name='datasource', query='prometheus')
      .setCurrent(text='default', value='default')
    )
    .addTemplate(
      g.template.query.new(
        datasource='${datasource}',
        label='cluster',
        name='cluster',
        query='label_values(up{%(kubeStateMetricsSelector)s}, cluster)' % $._config,
        refresh=1,
        regex='',
      )
    )
    + layout {
      // To make building dashboards easier, we use monads(!).
      //
      // The idea is that you build a a list of monads to a dashboard by
      // calling add.
      //
      // dashboard('test').chain([
      //     $.addTemplate('pod'),
      //     $.addRow('Info'),
      //     $.addTextRow('Name'),
      //     $.addLabelPanel('group by (name) (kube_pod_info{pod="$pod"})', 'name'),
      //     $.newRow,
      // ])
      //
      // This saves you having to nest the return value from each monad.
      chain(fs):: std.foldl(function(d, f) if f != null then f(d) else d, fs, self),
    },

  addTemplate(name):
    function(d)
      d.addTemplate(
        g.template.query.new(
          datasource='${datasource}',
          name=name,
          query='',
          refresh=1,
          regex='',
          hide=2,
        )
      ),

  addRow(title):
    function(d)
      d.addPanel({
        collapsed: false,
        datasource: null,
        gridPos: {
          h: 1,
          w: 24,
        },
        id: 25,
        panels: [],
        title: title,
        type: 'row',
      })
      .nextRow(),

  nextRow(d): d.nextRow(),

  addLinkPanel(kind, text, height=2):
    local icon = model.kinds[kind].icon;
    function(d)
      d.addPanel({
        gridPos: {
          w: 8,
          h: height,
        },
        type: 'text',
        options: {
          mode: 'html',
          content: |||
            <div style="padding: 0px;">
                <div style="display: flex; flex-direction: row; align-items: center; margin-top: 0px;">
                    <img style="height: 32px; width: 32px; margin-right: 10px;" src="%s" alt="%s"/>
                    <h2 style="margin-top: 5px;">%s</h1>
                </div>
            </div>
          ||| % [icon, kind, text],
        },
        transparent: true,
        datasource: null,
      }),

  addTextPanel(text, width=8, height=2):
    function(d)
      d.addPanel({
        type: 'text',
        title: '',
        gridPos: {
          w: width,
          h: height,
        },
        transparent: true,
        options: {
          mode: 'markdown',
          content: '%s' % text,
        },
      }),

  addLabelPanel(query, label, link=null):
    function(d)
      d.addPanel({
        type: 'stat',
        gridPos: {
          w: 16,
          h: 2,
        },
        transformations: [],
        datasource: '$datasource',
        targets: [
          {
            expr: query,
            legendFormat: '{{%s}} ' % label,  // TODO space to handle missing labels
            interval: '',
            exemplar: false,
            refId: 'A',
            datasource: '$datasource',
            instant: true,
          },
        ],
        options: {
          reduceOptions: {
            values: true,
            calcs: [
              'lastNotNull',
            ],
            fields: '',
          },
          orientation: 'auto',
          textMode: 'name',
          colorMode: 'value',
          graphMode: 'area',
          justifyMode: 'auto',
          text: {
            valueSize: 18,
          },
        },
        fieldConfig: {
          defaults: {
            thresholds: {
              mode: 'absolute',
              steps: [
                {
                  color: 'text',
                  value: null,
                },
              ],
            },
            mappings: [],
            color: {
              mode: 'thresholds',
            },
            [if link != null then 'links' else null]: [
              {
                title: label,
                url: link,
              },
            ],
          },
          overrides: [],
        },
      }),

  addNumberPanel(query):
    function(d)
      d.addPanel({
        type: 'stat',
        gridPos: {
          w: 16,
          h: 2,
        },
        transformations: [],
        datasource: '$datasource',
        targets: [
          {
            expr: query,
            legendFormat: '',
            interval: '',
            exemplar: false,
            refId: 'A',
            datasource: '$datasource',
            instant: true,
          },
        ],
        options: {
          reduceOptions: {
            values: true,
            calcs: [
              'lastNotNull',
            ],
            fields: '',
          },
          orientation: 'auto',
          textMode: 'value',
          colorMode: 'value',
          graphMode: 'area',
          justifyMode: 'auto',
          text: {
            valueSize: 18,
          },
        },
        fieldConfig: {
          defaults: {
            thresholds: {
              mode: 'absolute',
              steps: [
                {
                  color: 'text',
                  value: null,
                },
              ],
            },
            mappings: [],
            color: {
              mode: 'thresholds',
            },
          },
          overrides: [],
        },
      }),

  addDatetimePanel(query):
    function(d)
      d.addPanel({
        type: 'stat',
        gridPos: {
          w: 16,
          h: 2,
        },
        transformations: [],
        datasource: '$datasource',
        targets: [
          {
            expr: query,
            legendFormat: '',
            interval: '',
            exemplar: false,
            refId: 'A',
            datasource: '$datasource',
            instant: true,
          },
        ],
        options: {
          reduceOptions: {
            values: true,
            calcs: [
              'lastNotNull',
            ],
            fields: '',
          },
          orientation: 'auto',
          textMode: 'value',
          colorMode: 'value',
          graphMode: 'area',
          justifyMode: 'auto',
          text: {
            valueSize: 18,
          },
        },
        fieldConfig: {
          defaults: {
            thresholds: {
              mode: 'absolute',
              steps: [
                {
                  color: 'text',
                  value: null,
                },
              ],
            },
            mappings: [],
            color: {
              mode: 'thresholds',
            },
            unit: 'dateTimeAsIso',
          },
          overrides: [],
        },
      }),

  addTablePanel(query, label, link=null):
    function(d)
      d.addPanel({
        datasource: '$datasource',
        fieldConfig: {
          defaults: {
            custom: {
              align: null,
              filterable: false,
            },
            thresholds: {
              mode: 'absolute',
              steps: [
                {
                  color: 'text',
                  value: null,
                },
              ],
            },
            mappings: [
              {
                id: 1,
                type: 1,
                from: '',
                to: '',
                text: '',
              },
            ],
            links: [
              {
                title: label,
                url: link,
              },
            ],
            color: {
              mode: 'thresholds',
            },
          },
          overrides: [],
        },
        gridPos: {
          h: 4,
          w: 16,
        },
        options: {
          showHeader: true,
        },
        targets: [
          {
            expr: query,
            legendFormat: '',
            interval: '',
            datasource: '$datasource',
            exemplar: false,
            instant: true,
            refId: 'A',
          },
        ],
        transformations: [
          {
            id: 'labelsToFields',
            options: {},
          },
          {
            id: 'organize',
            options: {
              excludeByName: {
                Time: true,
                Value: true,
              },
              indexByName: {
                Time: 0,
                Value: 1,
                namespace: 2,
                [label]: 3,
              },
              renameByName: {},
            },
          },
        ],
        type: 'table',
        pluginVersion: '7.2.2',
      }),

  addLabelTablePanel(query, prefix):
    function(d)
      d.addPanel({
        type: 'table',
        title: '',
        gridPos: {
          w: 16,
          h: 2,
        },
        targets: [
          {
            expr: query,
            legendFormat: '',
            interval: '',
            refId: 'A',
            instant: true,
          },
        ],
        fieldConfig: {
          defaults: {
            custom: {
              align: null,
              filterable: false,
            },
            thresholds: {
              mode: 'absolute',
              steps: [
                {
                  value: null,
                  color: 'green',
                },
                {
                  value: 80,
                  color: 'red',
                },
              ],
            },
            mappings: [],
          },
          overrides: [],
        },
        pluginVersion: '7.2.2',
        timeFrom: null,
        timeShift: null,
        options: {
          showHeader: true,
        },
        transformations: [
          {
            id: 'labelsToFields',
            options: {},
          },
          {
            id: 'filterFieldsByName',
            options: {
              include: {
                pattern: prefix,
              },
            },
          },
        ],
        datasource: null,
      }),

  addLogsPanel(query):
    function(d)
      d.addPanel({
          gridPos: {
            w: 12,
            h: 8,
          },
          type: 'logs',
          title: 'Pod Logs',
          targets: [
            {
              refId: 'A',
              datasource: 'Grafana Logging',
              expr: query,
            },
          ],
          options: {
            showTime: false,
            showLabels: false,
            showCommonLabels: false,
            wrapLogMessage: false,
            prettifyLogMessage: false,
            enableLogDetails: true,
            dedupStrategy: 'none',
            sortOrder: 'Descending',
          },
          datasource: 'Grafana Logging',
        }),
}
