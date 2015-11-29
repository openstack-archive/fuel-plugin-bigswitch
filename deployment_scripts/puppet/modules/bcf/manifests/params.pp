#
#    Copyright 2015 Mirantis, Inc.
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
class bcf::params {

  include bcf::params::openstack

  $bcf_hash = hiera('bigswitch')
  $network_metadata = hiera('network_metadata')
  $ssl = hiera('public_ssl')

  case $::operatingsystem {
    'Ubuntu', 'Debian': {
    }
    'CentOS', 'RedHat': {
    }
    default: {
    }
  }

  #server parameters
  $server_ip                         = $network_metadata['vips'][$vip_name]['ipaddr']
  $mgmt_vip                          = $network_metadata['vips']['management']['ipaddr']
}
