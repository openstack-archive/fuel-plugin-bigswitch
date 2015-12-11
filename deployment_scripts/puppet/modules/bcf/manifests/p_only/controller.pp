#
#    Copyright 2015 BigSwitch Networks, Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.
#
class bcf::p_only::controller {

    include bcf
    include bcf::params
    $binpath = "/usr/local/bin/:/bin/:/usr/bin:/usr/sbin:/usr/local/sbin:/sbin"

    $ifcfg_bond0 = "/etc/network/interfaces.d/ifcfg-bond0"
    $sys_desc_lacp = "5c:16:c7:00:00:04"
    $sys_desc_xor = "5c:16:c7:00:00:00"
    if $bcf::bond {
        # ensure bond-mode is 802.3ad
        exec { "ensure ${bcf::bond_lacp} in $ifcfg_bond0":
            command => "echo '${bcf::bond_lacp}' >> $ifcfg_bond0",
            unless => "grep -qe '${bcf::bond_lacp}' -- $ifcfg_bond0",
            path => "/bin:/usr/bin",
            require => Exec["update bond-mode in $ifcfg_bond0"],
        }
        exec { "update bond-mode in $ifcfg_bond0":
            command => "sed -i 's/bond-mode.*/${bcf::bond_lacp}/' $ifcfg_bond0",
            path => "/bin:/usr/bin"
        }
        $sys_desc = $bcf::sys_desc_lacp
    }
    else {
        $sys_desc = $bcf::sys_desc_xor
    }

    # lldp
    $a = file('/etc/fuel/plugins/fuel-plugin-bigswitch-1.0/python_scripts/send_lldp','/dev/null')
    if($a != '') {
        file { "/bin/send_lldp":
            content => $a,
            ensure  => file,
            mode    => 0777,
        }
    }

    file { "/etc/init/send_lldp.conf":
        ensure  => file,
        content => "
description \"BCF LLDP\"
start on runlevel [2345]
stop on runlevel [!2345]
respawn
script
    exec /bin/send_lldp --system-desc $sys_desc --system-name $(uname -n) -i 10 --network_interface $bcf::itfs
end script
",
    }
    service { "send_lldp":
        ensure  => running,
        enable  => true,
        require => [File['/bin/send_lldp'], File['/etc/init/send_lldp.conf']],
    }

    package { 'python-pip':
        ensure => 'installed',
    }
    exec { 'bsnstacklib':
        command => 'pip install "bsnstacklib<2015.2"',
        path    => "/usr/local/bin/:/usr/bin/:/bin",
        require => Package['python-pip']
    }

    # load bonding module
    file_line {'load bonding on boot':
        path    => '/etc/modules',
        line    => 'bonding',
        match   => '^bonding$',
    }

    # purge bcf controller public key
    exec { 'purge bcf key':
        command => "rm -rf /etc/neutron/plugins/ml2/host_certs/*",
        path    => $binpath,
        notify  => Service['neutron-server'],
    }

    # config /etc/neutron/neutron.conf
    ini_setting { "neutron.conf report_interval":
      ensure            => present,
      path              => '/etc/neutron/neutron.conf',
      section           => 'agent',
      key_val_separator => '=',
      setting           => 'report_interval',
      value             => '60',
      notify            => Service['neutron-server', 'neutron-plugin-openvswitch-agent', 'neutron-l3-agent', 'neutron-dhcp-agent'],
    }
    ini_setting { "neutron.conf agent_down_time":
      ensure            => present,
      path              => '/etc/neutron/neutron.conf',
      section           => 'DEFAULT',
      key_val_separator => '=',
      setting           => 'agent_down_time',
      value             => '150',
      notify            => Service['neutron-server', 'neutron-plugin-openvswitch-agent', 'neutron-l3-agent', 'neutron-dhcp-agent'],
    }
    ini_setting { "neutron.conf service_plugins":
      ensure            => present,
      path              => '/etc/neutron/neutron.conf',
      section           => 'DEFAULT',
      key_val_separator => '=',
      setting           => 'service_plugins',
      value             => 'router',
      notify            => Service['neutron-server'],
    }
    ini_setting { "neutron.conf dhcp_agents_per_network":
      ensure            => present,
      path              => '/etc/neutron/neutron.conf',
      section           => 'DEFAULT',
      key_val_separator => '=',
      setting           => 'dhcp_agents_per_network',
      value             => '1',
      notify            => Service['neutron-server'],
    }
    ini_setting { "neutron.conf notification driver":
      ensure            => present,
      path              => '/etc/neutron/neutron.conf',
      section           => 'DEFAULT',
      key_val_separator => '=',
      setting           => 'notification_driver',
      value             => 'messaging',
      notify            => Service['neutron-server'],
    }

    # configure /etc/keystone/keystone.conf
    ini_setting { "keystone.conf notification driver":
      ensure            => present,
      path              => '/etc/keystone/keystone.conf',
      section           => 'DEFAULT',
      key_val_separator => '=',
      setting           => 'notification_driver',
      value             => 'messaging',
      notify            => Service['keystone'],
    }

    # config /etc/neutron/plugin.ini
    ini_setting { "neutron plugin.ini firewall_driver":
      ensure            => present,
      path              => '/etc/neutron/plugin.ini',
      section           => 'securitygroup',
      key_val_separator => '=',
      setting           => 'firewall_driver',
      value             => 'neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver',
      notify            => Service['neutron-server'],
    }
    ini_setting { "neutron plugin.ini enable_security_group":
      ensure            => present,
      path              => '/etc/neutron/plugin.ini',
      section           => 'securitygroup',
      key_val_separator => '=',
      setting           => 'enable_security_group',
      value             => 'True',
      notify            => Service['neutron-server'],
    }
    file { '/etc/neutron/dnsmasq-neutron.conf':
      ensure            => file,
      content           => 'dhcp-option-force=26,1400',
    }

    # config /etc/neutron/l3-agent.ini
    ini_setting { "l3 agent disable metadata proxy":
      ensure            => present,
      path              => '/etc/neutron/l3_agent.ini',
      section           => 'DEFAULT',
      key_val_separator => '=',
      setting           => 'enable_metadata_proxy',
      value             => 'False',
      notify  => Service['neutron-l3-agent'],
    }
    ini_setting { "l3 agent external network bridge":
      ensure            => present,
      path              => '/etc/neutron/l3_agent.ini',
      section           => 'DEFAULT',
      key_val_separator => '=',
      setting           => 'external_network_bridge',
      value             => '',
      notify  => Service['neutron-l3-agent'],
    }
    ini_setting { "l3 agent handle_internal_only_routers":
      ensure            => present,
      path              => '/etc/neutron/l3_agent.ini',
      section           => 'DEFAULT',
      key_val_separator => '=',
      setting           => 'handle_internal_only_routers',
      value             => 'True',
      notify  => Service['neutron-l3-agent'],
    }

    # config /etc/neutron/plugins/ml2/ml2_conf.ini
    ini_setting { "ml2 type dirvers":
      ensure            => present,
      path              => '/etc/neutron/plugins/ml2/ml2_conf.ini',
      section           => 'ml2',
      key_val_separator => '=',
      setting           => 'type_drivers',
      value             => 'vlan',
      notify            => Service['neutron-server'],
    }
    ini_setting { "ml2 tenant network types":
      ensure            => present,
      path              => '/etc/neutron/plugins/ml2/ml2_conf.ini',
      section           => 'ml2',
      key_val_separator => '=',
      setting           => 'tenant_network_types',
      value             => 'vlan',
      notify            => Service['neutron-server'],
    }
    ini_setting { "ml2 mechanism drivers":
      ensure            => present,
      path              => '/etc/neutron/plugins/ml2/ml2_conf.ini',
      section           => 'ml2',
      key_val_separator => '=',
      setting           => 'mechanism_drivers',
      value             => 'openvswitch,bsn_ml2',
      notify            => Service['neutron-server'],
    }
    ini_setting { "ml2 restproxy ssl cert directory":
      ensure            => present,
      path              => '/etc/neutron/plugins/ml2/ml2_conf.ini',
      section           => 'restproxy',
      key_val_separator => '=',
      setting           => 'ssl_cert_directory',
      value             => '/etc/neutron/plugins/ml2',
      notify            => Service['neutron-server'],
    }
    if $bcf::params::openstack::bcf_controller_2 == ":8000" {
        $server = $bcf::params::openstack::bcf_controller_1
    }
    else {
        $server = "${bcf::params::openstack::bcf_controller_1},${bcf::params::openstack::bcf_controller_2}"
    }

    ini_setting { "ml2 restproxy servers":
      ensure            => present,
      path              => '/etc/neutron/plugins/ml2/ml2_conf.ini',
      section           => 'restproxy',
      key_val_separator => '=',
      setting           => 'servers',
      value             => $server,
      notify            => Service['neutron-server'],
    }
    ini_setting { "ml2 restproxy server auth":
      ensure            => present,
      path              => '/etc/neutron/plugins/ml2/ml2_conf.ini',
      section           => 'restproxy',
      key_val_separator => '=',
      setting           => 'server_auth',
      value             => "${bcf::params::openstack::bcf_username}:${bcf::params::openstack::bcf_password}",
      notify            => Service['neutron-server'],
    }
    ini_setting { "ml2 restproxy server ssl":
      ensure            => present,
      path              => '/etc/neutron/plugins/ml2/ml2_conf.ini',
      section           => 'restproxy',
      key_val_separator => '=',
      setting           => 'server_ssl',
      value             => 'True',
      notify            => Service['neutron-server'],
    }
    ini_setting { "ml2 restproxy auto sync on failure":
      ensure            => present,
      path              => '/etc/neutron/plugins/ml2/ml2_conf.ini',
      section           => 'restproxy',
      key_val_separator => '=',
      setting           => 'auto_sync_on_failure',
      value             => 'True',
      notify            => Service['neutron-server'],
    }
    ini_setting { "ml2 restproxy consistency interval":
      ensure            => present,
      path              => '/etc/neutron/plugins/ml2/ml2_conf.ini',
      section           => 'restproxy',
      key_val_separator => '=',
      setting           => 'consistency_interval',
      value             => 60,
      notify            => Service['neutron-server'],
    }
    ini_setting { "ml2 restproxy neutron_id":
      ensure            => present,
      path              => '/etc/neutron/plugins/ml2/ml2_conf.ini',
      section           => 'restproxy',
      key_val_separator => '=',
      setting           => 'neutron_id',
      value             => "${bcf::params::openstack::bcf_instance_id}",
      notify            => Service['neutron-server'],
    }
    ini_setting { "ml2 restproxy auth_url":
      ensure            => present,
      path              => '/etc/neutron/plugins/ml2/ml2_conf.ini',
      section           => 'restproxy',
      key_val_separator => '=',
      setting           => 'auth_url',
      value             => "http://${bcf::params::openstack::keystone_vip}:35357",
      notify            => Service['neutron-server'],
    }
    ini_setting { "ml2 restproxy auth_user":
      ensure            => present,
      path              => '/etc/neutron/plugins/ml2/ml2_conf.ini',
      section           => 'restproxy',
      key_val_separator => '=',
      setting           => 'auth_user',
      value             => "${bcf::params::openstack::auth_user}",
      notify            => Service['neutron-server'],
    }
    ini_setting { "ml2 restproxy auth_password":
      ensure            => present,
      path              => '/etc/neutron/plugins/ml2/ml2_conf.ini',
      section           => 'restproxy',
      key_val_separator => '=',
      setting           => 'auth_password',
      value             => "${bcf::params::openstack::auth_password}",
      notify            => Service['neutron-server'],
    }
    ini_setting { "ml2 restproxy auth_tenant_name":
      ensure            => present,
      path              => '/etc/neutron/plugins/ml2/ml2_conf.ini',
      section           => 'restproxy',
      key_val_separator => '=',
      setting           => 'auth_tenant',
      value             => "${bcf::params::openstack::auth_tenant_name}",
      notify            => Service['neutron-server'],
    }

    # change ml2 ownership
    file { '/etc/neutron/plugins/ml2':
      owner   => neutron,
      group   => neutron,
      recurse => true,
      notify  => Service['neutron-server'],
    }

    # heat-engine, neutron-server, neutron-dhcp-agent and neutron-metadata-agent
    service { 'heat-engine':
      ensure  => running,
      enable  => true,
    }
    service { 'neutron-server':
      ensure  => running,
      enable  => true,
    }
    service { 'neutron-plugin-openvswitch-agent':
      ensure  => running,
      enable  => true,
    }
    service { 'neutron-l3-agent':
      ensure  => running,
      enable  => true,
    }
    service { 'neutron-dhcp-agent':
      ensure  => running,
      enable  => true,
    }
    service { 'keystone':
      ensure  => running,
      enable  => true,
    }
}

