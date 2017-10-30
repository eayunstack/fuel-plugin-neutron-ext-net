# == Class: ext_net
#
# Full description of class ext_net here.
#
# === Parameters
#
# Document parameters here.
#
# [*sample_parameter*]
#   Explanation of what this parameter affects and what it defaults to.
#   e.g. "Specify one or more upstream ntp servers as an array."
#
# === Variables
#
# Here you should define a list of variables that this module would require.
#
# [*sample_variable*]
#   Explanation of how this variable affects the funtion of this class and if
#   it has a default. e.g. "The parameter enc_ntp_servers must be set by the
#   External Node Classifier as a comma separated list of hostnames." (Note,
#   global variables should be avoided in favor of class parameters as
#   of Puppet 2.6.)
#
# === Examples
#
#
# === Authors
#
# Author Name <author@domain.com>
#
# === Copyright
#
# Copyright 2014 Your name here, unless otherwise noted.
#
class ext_net (
  $ext_net_phy_name = 'ext_provider',
  $ext_vlan_min     = 3000,
  $ext_vlan_max     = 3050,
) {

  $ext_br_ex_name = $::fuel_settings['network_scheme']['roles']['ex']
  $ext_br_phy_name = get_ext_phy_bridge($::fuel_settings['network_scheme'])

  # for update net04_ext network
  $auth_url         = "http://${::fuel_settings['management_vip']}:5000/v2.0/"
  $auth_username    = $::fuel_settings['access']['user']
  $auth_password    = $::fuel_settings['access']['password']
  $auth_tenant      = $::fuel_settings['access']['tenant']
  $neutron_url      = "http://${::fuel_settings['management_vip']}:9696/v2.0/"
  $net_name         = 'net04_ext'
  $net_info         = get_network_info($auth_url, $auth_username, $auth_password, $auth_tenant, $neutron_url, $net_name)
  $ext_provider     = $::fuel_settings['neutron-ext-net']['ext_provider']
  $vlan_id          = $ext_vlan_max
  $roles            = node_roles($::fuel_settings['nodes'], $::fuel_settings['uid'])

  ovs_patch_trunk { 'add-ovs-patch-trunk':
    ensure  => present,
    bridges => [$ext_br_ex_name, $ext_br_phy_name],
    trunks  => [$ext_vlan_min, $ext_vlan_max],
  }

  l3agent_config {
    'DEFAULT/gateway_external_network_id': value => '';
    'DEFAULT/external_network_bridge':     value => '';
  }

  plugin_config {
    'ml2_type_vlan/network_vlan_ranges':
    value          => "${ext_net_phy_name}:${ext_vlan_min}:${ext_vlan_max}",
    append_to_list => true;
    'ovs/bridge_mappings':
    value          => "${ext_net_phy_name}:${ext_br_ex_name}",
    append_to_list => true;
  }

  service { 'neutron-server':
    ensure => running,
    enable => true,
  }

  service { 'neutron-openvswitch-agent':
    ensure   => running,
    enable   => true,
    provider => 'pacemaker'
  }

  L3agent_config<||> -> Plugin_config<||>
    ~> Service['neutron-openvswitch-agent']
      ~> Service['neutron-server']
        ~> Ovs_patch_trunk['add-ovs-patch-trunk']

  $is_ha_mode = $fuel_settings['deployment_mode'] ? { 'ha_compact' => true, default => false }

  if ($is_ha_mode and member($roles, 'primary-controller') and $net_info) or (! $is_ha_mode and member($roles, 'controller') and $net_info) {

    $net_type = $net_info['provider:network_type']

    if $net_type != 'vlan' {
      # net_id used in mysql_update.sql.erb
      $net_id = $net_info['id']

      if $is_ha_mode {
        service { 'neutron-l3-agent':
          ensure   => running,
          enable   => true,
          provider => 'pacemaker'
        }
      } else {
        service { 'neutron-l3-agent':
          ensure   => running,
          enable   => true,
        }
      }

      file { "/tmp/mysql_neutron_update.sql":
        ensure  => present,
        owner   => 'root',
        group   => 'root',
        mode    => '0640',
        content => template('ext_net/mysql_update.sql.erb'),
      }

      exec { 'mysql_neutron_update':
        command     => "mysql -uroot < /tmp/mysql_neutron_update.sql",
        path        => '/usr/bin',
        refreshonly => true,
        user        => "root",
        provider    => shell,
        require     => Service['neutron-server'],
        subscribe   => File["/tmp/mysql_neutron_update.sql"],
        notify      => Service['neutron-l3-agent']
      }

    }

  }
}
