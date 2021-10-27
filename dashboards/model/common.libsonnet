local g = import 'github.com/grafana/grafonnet-lib/grafonnet-7.0/grafana.libsonnet';
local layout = import 'github.com/grafana/grafonnet-lib/contrib/layout.libsonnet';

{
    dashboard(kind):
        g.dashboard.new(title='Explore / %s' % kind, refresh='5m', uid=std.md5(kind))
        .setTime(from='now-1h', to='now')
        .addTemplate(
            g.template.datasource.new(name='datasource', query='prometheus')
            .setCurrent(text='default', value='default')
        )
        .addTemplate(
            g.template.query.new(
                allValue='.+',
                datasource='${datasource}',
                includeAll=true,
                label='cluster',
                name='cluster',
                query='',
                refresh=1,
                regex='',
                //hide=2,
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
                    //hide=2,
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

    addTextPanel(text, height=2):
        function(d)
            d.addPanel({
                type: 'text',
                title: '',
                gridPos: {
                    w: 8,
                    h: height,
                },
                transparent: true,
                options: {
                    mode: "markdown",
                    content: "## %s" % text
                },
            }),

    addLabelPanel(query, label, link=null):
        function(d)
            d.addPanel({
                type: "stat",
                gridPos: {
                    "w": 16,
                    "h": 2,
                },
                transformations: [],
                datasource: '$datasource',
                targets: [
                    {
                        "expr": query,
                        "legendFormat": '{{%s}} ' % label, // TODO space to handle missing labels
                        "interval": "",
                        "exemplar": false,
                        "refId": "A",
                        "datasource": "$datasource",
                        "instant": true,
                    }
                ],
                options: {
                    "reduceOptions": {
                        "values": true,
                        "calcs": [
                            "lastNotNull"
                        ],
                        "fields": ""
                    },
                    "orientation": "auto",
                    "textMode": "name",
                    "colorMode": "value",
                    "graphMode": "area",
                    "justifyMode": "auto",
                    "text": {
                        "valueSize": 18
                    }
                },
                fieldConfig: {
                    "defaults": {
                        "thresholds": {
                            "mode": "absolute",
                            "steps": [
                                {
                                "color": "text",
                                "value": null
                                }
                            ]
                        },
                        "mappings": [],
                        "color": {
                            "mode": "thresholds"
                        },
                        [if link != null then 'links' else null]: [
                            {
                                title: label,
                                url: link,
                            }
                        ],
                    },
                    "overrides": []
                },
            }),

    addTablePanel(query, label, link=null):
        function(d)
            d.addPanel({
                "datasource": "$datasource",
                "fieldConfig": {
                    "defaults": {
                        "custom": {
                            "align": null,
                            "filterable": false
                        },
                        "thresholds": {
                            "mode": "absolute",
                            "steps": [
                                {
                                    "color": "text",
                                    "value": null
                                }
                            ]
                        },
                        "mappings": [
                            {
                                "id": 1,
                                "type": 1,
                                "from": "",
                                "to": "",
                                "text": ""
                            }
                        ],
                        "links": [
                            {
                                "title": label,
                                "url": link,
                            }
                        ],
                        "color": {
                            "mode": "thresholds"
                        }
                    },
                    "overrides": []
                },
                "gridPos": {
                    "h": 4,
                    "w": 16,
                },
                "options": {
                    "showHeader": false
                },
                "targets": [
                    {
                        "expr": query,
                        "legendFormat": "",
                        "interval": "",
                        "datasource": "$datasource",
                        "exemplar": false,
                        "instant": true,
                        "refId": "A"
                    }
                ],
                "transformations": [
                    {
                        "id": "labelsToFields",
                        "options": {}
                    },
                    {
                        "id": "organize",
                        "options": {
                            "excludeByName": {
                            "Time": true,
                            "Value": true
                            },
                            "indexByName": {},
                            "renameByName": {}
                        }
                    }
                ],
                "type": "table",
                "pluginVersion": "7.2.2"
            }),

    addLabelTablePanel(query, prefix):
        function(d)
             d.addPanel({
                "type": "table",
                "title": "",
                "gridPos": {
                    "w": 16,
                    "h": 2
                },
                "targets": [
                    {
                    "expr": query,
                    "legendFormat": "",
                    "interval": "",
                    "refId": "A",
                    "instant": true
                    }
                ],
                "fieldConfig": {
                    "defaults": {
                    "custom": {
                        "align": null,
                        "filterable": false
                    },
                    "thresholds": {
                        "mode": "absolute",
                        "steps": [
                            {
                                "value": null,
                                "color": "green"
                            },
                            {
                                "value": 80,
                                "color": "red"
                            }
                        ]
                    },
                    "mappings": []
                    },
                    "overrides": []
                },
                "pluginVersion": "7.2.2",
                "timeFrom": null,
                "timeShift": null,
                "options": {
                    "showHeader": true
                },
                "transformations": [
                    {
                        "id": "labelsToFields",
                        "options": {}
                    },
                    {
                        "id": "filterFieldsByName",
                        "options": {
                            "include": {
                                "pattern": prefix,
                            }
                        }
                    }
                ],
                "datasource": null
            }),
}
