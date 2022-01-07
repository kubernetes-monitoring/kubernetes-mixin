local c = import 'common.libsonnet';

(import 'object-dashboard.libsonnet') {
  grafanaDashboards+:: {
    'model-pod.json':
      super['model-pod.json'].chain([
        c.addRow('Debugging'),
        c.addTextPanel(|||
          ### Shell into Pod:

          ```
          $ kubectl exec -ti --namespace "$namespace" --pod "$pod" -- /bin/sh
          ```

          ### Port forward to the pod

          ```
          $ kubectl port-forward --namespace "$namespace" --pod "$pod" 8080:8080
          ```

          ### Delete Pod:

          ```
          $ kubectl delete pod --namespace "$namespace" --pod "$pod"
          ```
        |||, width=12, height=8),
        c.addLogsPanel('{cluster="$cluster", namespace="$namespace", pod="$pod"}'),
      ]),

    'model-deployment.json':
      super['model-deployment.json'].chain([
        c.addRow('Debugging'),
        c.addTextPanel(|||
          ### Scale Deployment:

          ```
          $ kubectl scale --replicas=3 --namespace "$namespace" deploy/$deployment
          ```
        |||, width=12, height=8),
        c.addLogsPanel('{cluster="$cluster", namespace="$namespace", name="$deployment"}'),
      ]),

    'model-statefulset.json':
      super['model-statefulset.json'].chain([
        c.addRow('Debugging'),
        c.addTextPanel(|||
          ### Scale Deployment:

          ```
          $ kubectl scale --replicas=3 --namespace "$namespace" statefulset/$statefulset
          ```
        |||, width=12, height=8),
        c.addLogsPanel('{cluster="$cluster", namespace="$namespace", name="$statefulset"}'),
      ]),

    'model-node.json':
      super['model-node.json'].chain([
        c.addRow('Debugging'),
        c.addTextPanel(|||
          ### Cordon Node:

          ```
          $ kubectl cordon $node
          $ kubectl uncordon $node
          ```

          ### Drain Node:

          ```
          $ kubectl drain $node
          ```
        |||, width=12, height=8),
      ]),
  },
}
