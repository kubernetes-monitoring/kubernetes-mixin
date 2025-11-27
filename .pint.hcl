checks {
  # promql/impossible can't deal with label_join or label_replace
  disabled = ["promql/impossible"]
}
