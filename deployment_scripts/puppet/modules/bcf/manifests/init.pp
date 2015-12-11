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
class bcf {

    $bond_lacp = "bond-mode 4"
    $sys_desc_lacp = "5c:16:c7:00:00:04"
    $sys_desc_xor = "5c:16:c7:00:00:00"

    # Network configuration
    $network_scheme = hiera_hash('network_scheme', {})
    prepare_network_config($network_scheme)
    $gw = get_default_gateways()
    $phy_devs = get_network_role_property('neutron/private', 'phys_dev')
    $if_str = "$phy_devs"
    if $if_str =~ /^bond.*/ {
        $ifaces = join($phy_devs, ",")
        $bond = true
        $s = "${phy_devs[0]},"
        $r = split("abc$ifaces", $s)
        $itfs = $r[1]
    }
    else {
        $bond = false
        $itfs = $phy_devs
    }
    $network_metadata = hiera_hash('network_metadata', {})
    $public_vip = $network_metadata['vips']['public']['ipaddr']
}
