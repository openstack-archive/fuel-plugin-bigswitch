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
class bcf::compute {

    include bcf::params
    # all of the exec statements use this path
    $binpath = "/usr/local/bin/:/bin/:/usr/bin:/usr/sbin:/usr/local/sbin:/sbin"
    
    # lldp
    file { "/bin/send_lldp":
        ensure  => file,
        mode    => 0777,
    }
    file { "/etc/init/send_lldp.conf":
        ensure  => file,
        content => "
description \"BCF LLDP\"
start on runlevel [2345]
stop on runlevel [!2345]
respawn
script
    exec /bin/send_lldp --system-desc 5c:16:c7:00:00:04 --system-name $(uname -n) -i 10 --network_interface eth2,eth3 
end script
",
    }
    service { "send_lldp":
        ensure  => running,
        enable  => true,
        require => [File['/bin/send_lldp'], File['/etc/init/send_lldp.conf']],
    }
    
    # edit rc.local for cron job and default gw
    file { "/etc/rc.local":
        ensure  => file,
        mode    => 0777,
    }->
    
    # config /etc/neutron/neutron.conf
    ini_setting { "neutron.conf report_interval":
      ensure            => present,
      path              => '/etc/neutron/neutron.conf',
      section           => 'agent',
      key_val_separator => '=',
      setting           => 'report_interval',
      value             => '60',
    }
    ini_setting { "neutron.conf agent_down_time":
      ensure            => present,
      path              => '/etc/neutron/neutron.conf',
      section           => 'DEFAULT',
      key_val_separator => '=',
      setting           => 'agent_down_time',
      value             => '150',
    }
    ini_setting { "neutron.conf service_plugins":
      ensure            => present,
      path              => '/etc/neutron/neutron.conf',
      section           => 'DEFAULT',
      key_val_separator => '=',
      setting           => 'service_plugins',
      value             => 'router',
    }
    ini_setting { "neutron.conf dhcp_agents_per_network":
      ensure            => present,
      path              => '/etc/neutron/neutron.conf',
      section           => 'DEFAULT',
      key_val_separator => '=',
      setting           => 'dhcp_agents_per_network',
      value             => '1',
    }
    ini_setting { "neutron.conf notification driver":
      ensure            => present,
      path              => '/etc/neutron/neutron.conf',
      section           => 'DEFAULT',
      key_val_separator => '=',
      setting           => 'notification_driver',
      value             => 'messaging',
    }
    
    # set the correct properties in ml2_conf.ini on compute as well
    # config /etc/neutron/plugins/ml2/ml2_conf.ini
    ini_setting { "ml2 type dirvers":
      ensure            => present,
      path              => '/etc/neutron/plugins/ml2/ml2_conf.ini',
      section           => 'ml2',
      key_val_separator => '=',
      setting           => 'type_drivers',
      value             => 'vlan',
      notify            => Service['neutron-plugin-openvswitch-agent'],
    }
    ini_setting { "ml2 tenant network types":
      ensure            => present,
      path              => '/etc/neutron/plugins/ml2/ml2_conf.ini',
      section           => 'ml2',
      key_val_separator => '=',
      setting           => 'tenant_network_types',
      value             => 'vlan',
      notify            => Service['neutron-plugin-openvswitch-agent'],
    }
    ini_setting { "ml2 mechanism drivers":
      ensure            => present,
      path              => '/etc/neutron/plugins/ml2/ml2_conf.ini',
      section           => 'ml2',
      key_val_separator => '=',
      setting           => 'mechanism_drivers',
      value             => 'openvswitch,bsn_ml2',
      notify            => Service['neutron-plugin-openvswitch-agent'],
    }
    ini_setting { "ml2 restproxy ssl cert directory":
      ensure            => present,
      path              => '/etc/neutron/plugins/ml2/ml2_conf.ini',
      section           => 'restproxy',
      key_val_separator => '=',
      setting           => 'ssl_cert_directory',
      value             => '/etc/neutron/plugins/ml2',
      notify            => Service['neutron-plugin-openvswitch-agent'],
    }
    ini_setting { "ml2 restproxy servers":
      ensure            => present,
      path              => '/etc/neutron/plugins/ml2/ml2_conf.ini',
      section           => 'restproxy',
      key_val_separator => '=',
      setting           => 'servers',
      value             => '${bcf::params::openstack::bcf_controller_1},${bcf::params::openstack::bcf_controller_2}',
      notify            => Service['neutron-plugin-openvswitch-agent'],
    }
    ini_setting { "ml2 restproxy server auth":
      ensure            => present,
      path              => '/etc/neutron/plugins/ml2/ml2_conf.ini',
      section           => 'restproxy',
      key_val_separator => '=',
      setting           => 'server_auth',
      value             => '${bcf::params::openstack::bcf_username}:${bcf::params::openstack::bcf_password}',
      notify            => Service['neutron-plugin-openvswitch-agent'],
    }
    ini_setting { "ml2 restproxy server ssl":
      ensure            => present,
      path              => '/etc/neutron/plugins/ml2/ml2_conf.ini',
      section           => 'restproxy',
      key_val_separator => '=',
      setting           => 'server_ssl',
      value             => 'True',
      notify            => Service['neutron-plugin-openvswitch-agent'],
    }
    ini_setting { "ml2 restproxy auto sync on failure":
      ensure            => present,
      path              => '/etc/neutron/plugins/ml2/ml2_conf.ini',
      section           => 'restproxy',
      key_val_separator => '=',
      setting           => 'auto_sync_on_failure',
      value             => 'True',
      notify            => Service['neutron-plugin-openvswitch-agent'],
    }
    ini_setting { "ml2 restproxy consistency interval":
      ensure            => present,
      path              => '/etc/neutron/plugins/ml2/ml2_conf.ini',
      section           => 'restproxy',
      key_val_separator => '=',
      setting           => 'consistency_interval',
      value             => 60,
      notify            => Service['neutron-plugin-openvswitch-agent'],
    }
    ini_setting { "ml2 restproxy neutron_id":
      ensure            => present,
      path              => '/etc/neutron/plugins/ml2/ml2_conf.ini',
      section           => 'restproxy',
      key_val_separator => '=',
      setting           => 'neutron_id',
      value             => '${bcf::params::openstack::bcf_instance_id}',
      notify            => Service['neutron-plugin-openvswitch-agent'],
    }
    
    # change ml2 ownership
    file { '/etc/neutron/plugins/ml2':
      owner   => neutron,
      group   => neutron,
      recurse => true,
      notify  => Service['neutron-plugin-openvswitch-agent'],
    }
    
    # make sure neutron-bsn-agent is stopped
    service {'neutron-bsn-agent':
      ensure  => stopped,
      enable  => false,
    }
    
    # ensure neutron-plugin-openvswitch-agent is running
    file { "/etc/init/neutron-plugin-openvswitch-agent.conf":
        ensure  => file,
        mode    => 0644,
    }
    service { 'neutron-plugin-openvswitch-agent':
      ensure     => 'running',
      enable     => 'true',
      provider   => 'upstart',
      hasrestart => 'true',
      hasstatus  => 'true',
      subscribe  => [File['/etc/init/neutron-plugin-openvswitch-agent.conf']],
    }
    
    file { '/etc/neutron/dnsmasq-neutron.conf':
      ensure            => file,
      content           => 'dhcp-option-force=26,1400',
    }
    
    # dhcp configuration
    ini_setting { "dhcp agent interface driver":
        ensure            => present,
        path              => '/etc/neutron/dhcp_agent.ini',
        section           => 'DEFAULT',
        key_val_separator => '=',
        setting           => 'interface_driver',
        value             => 'neutron.agent.linux.interface.OVSInterfaceDriver',
    }
    ini_setting { "dhcp agent dhcp driver":
        ensure            => present,
        path              => '/etc/neutron/dhcp_agent.ini',
        section           => 'DEFAULT',
        key_val_separator => '=',
        setting           => 'dhcp_driver',
        value             => 'neutron.agent.linux.dhcp.Dnsmasq',
    }
    ini_setting { "dhcp agent enable isolated metadata":
        ensure            => present,
        path              => '/etc/neutron/dhcp_agent.ini',
        section           => 'DEFAULT',
        key_val_separator => '=',
        setting           => 'enable_isolated_metadata',
        value             => 'True',
    }
    ini_setting { "dhcp agent disable metadata network":
        ensure            => present,
        path              => '/etc/neutron/dhcp_agent.ini',
        section           => 'DEFAULT',
        key_val_separator => '=',
        setting           => 'enable_metadata_network',
        value             => 'False',
    }
    ini_setting { "dhcp agent disable dhcp_delete_namespaces":
        ensure            => present,
        path              => '/etc/neutron/dhcp_agent.ini',
        section           => 'DEFAULT',
        key_val_separator => '=',
        setting           => 'dhcp_delete_namespaces',
        value             => 'False',
    }
}    
