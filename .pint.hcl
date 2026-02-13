checks {
  # promql/impossible can't deal with label_join or label_replace
  # https://github.com/cloudflare/pint/issues/1631
  disabled = ["promql/impossible"]
}
