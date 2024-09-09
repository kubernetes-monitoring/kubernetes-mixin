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
    kubeApiserverReadResourceLatency: '1',
    kubeApiserverReadNamespaceLatency: '5',
    kubeApiserverReadClusterLatency: '30',
    kubeApiserverWriteLatency: '1',
  },
}
