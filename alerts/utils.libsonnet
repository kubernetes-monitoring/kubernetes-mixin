{
  humanizeSeconds(s)::
    if s > 60 * 60 * 24
    then '%d days' % (s / 60 / 60 / 24)
    else '%d hours' % (s / 60 / 60),
}
