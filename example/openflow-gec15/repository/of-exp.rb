defProperty('wired', 'omf.nicta.node2', "Wired node (endpoint)") # baseline.ndz
defGroup('ap', property.ap) do |node|
  # wlan1 is part of OVS
defGroup('adhoc', property.adhoc) do |node|
defGroup('wireless', property.wireless) do |node|
defGroup('wired', property.wired) do |node|
  # no OVS on this node
onEvent(:ALL_UP) do |event|
  group("wired").startApplications
  while true

