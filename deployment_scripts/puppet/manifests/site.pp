$fuel_settings = parseyaml($astute_settings_yaml)

if $fuel_settings {

  class { 'ext_net':
    ext_net_phy_name   => $fuel_settings['neutron-ext-net']['ext_provider'],
    ext_vlan_min       => $fuel_settings['neutron-ext-net']['ext_vlan_min'],
    ext_vlan_max       => $fuel_settings['neutron-ext-net']['ext_vlan_max'],
  }
}
