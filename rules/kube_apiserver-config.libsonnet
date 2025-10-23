{
  _config+:: {
    kubeApiserverSelector: 'job="kube-apiserver"',
    podLabel: 'pod',
    kubeApiserverReadSelector: 'verb=~"LIST|GET"',
    kubeApiserverWriteSelector: 'verb=~"POST|PUT|PATCH|DELETE"',
    kubeApiserverNonStreamingSelector: 'subresource!~"proxy|attach|log|exec|portforward"',
    // These are buckets that exist on the apiserver_request_sli_duration_seconds_bucket histogram.
    // They are what the Kubernetes SIG Scalability is using to measure availability of Kubernetes clusters.
    // If you want to change these, make sure the "le" buckets exist on the histogram!
    kubeApiserverReadResourceLatency: '1(\\\\.0)?',
    kubeApiserverReadNamespaceLatency: '5(\\\\.0)?',
    kubeApiserverReadClusterLatency: '30(\\\\.0)?',
    kubeApiserverWriteLatency: '1(\\\\.0)?',
  },
}
