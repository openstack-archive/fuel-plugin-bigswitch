#
#    Copyright 2015 BigSwitch Networks
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
class bcf::params::openstack {

  $virtual_cluster_name  = 'OpenStackCluster'
  $ceph_virtual_cluster_name  = 'CephCluster'

  $keystone_vip          = hiera('management_vip')
  $db_vip                = hiera('management_vip')
  $nova_vip              = hiera('management_vip')
  $glance_vip            = hiera('management_vip')
  $cinder_vip            = hiera('management_vip')
  $rabbit_vip            = hiera('management_vip')
  $bcf_hash              = hiera('bigswitch')


  $access_hash           = hiera('access')
  $keystone_hash         = hiera('keystone')
  $nova_hash             = hiera('nova')
  $neutron_hash          = hiera('neutron_config')
  $cinder_hash           = hiera('cinder')
  $rabbit_hash           = hiera('rabbit')

  $bcf_mode              = $bcf_hash['bcf_mode']
  $bcf_controller_1      = $bcf_hash['bcf_controller_1']
  $bcf_controller_2      = $bcf_hash['bcf_controller_2']
  $bcf_username          = $bcf_hash['bcf_controller_username']
  $bcf_password          = $bcf_hash['bcf_controller_password']
  $bcf_instance_id       = $bcf_hash['openstack_instance_id']
  $bcf_controller_mgmt   = $bcf_hash['bcf_controller_os_mgmt']
  $access_tenant         = 'services'
  $keystone_db_password  = $keystone_hash['db_password']
  $nova_db_password      = $nova_hash['db_password']
  $neutron_db_password   = $neutron_hash['database']['passwd']
  $cinder_db_password    = $cinder_hash['db_password']
  $rabbit_password       = $rabbit_hash['password']
  $rabbitmq_service_name = 'rabbitmq-server'

  if !$rabbit_hash['user'] {
    $rabbit_user         = 'nova'
  } else {
    $rabbit_user         = $rabbit_hash['user']
  }
}
