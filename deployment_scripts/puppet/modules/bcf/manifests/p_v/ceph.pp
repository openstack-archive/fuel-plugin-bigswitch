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
class bcf::ceph {

    include bcf
    include bcf::params
    # all of the exec statements use this path
    $binpath = "/usr/local/bin/:/bin/:/usr/bin:/usr/sbin:/usr/local/sbin:/sbin"

    $ifcfg_bond0 = "/etc/network/interfaces.d/ifcfg-bond0"
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
    exec /bin/send_lldp --system-desc $sys_desc --system-name $(uname -n) -i 10 --network_interface $bcf::itfs
end script
",
    }
    service { "send_lldp":
        ensure  => running,
        enable  => true,
        require => [File['/bin/send_lldp'], File['/etc/init/send_lldp.conf']],
    }
}
