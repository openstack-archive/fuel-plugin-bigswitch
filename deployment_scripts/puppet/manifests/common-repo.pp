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

notice('MODULAR: bigswitch/common-repo.pp')

class bcf::common-repo {

    $binpath = "/usr/local/bin/:/bin/:/usr/bin:/usr/sbin:/usr/local/sbin:/sbin"

    package { 'python-pip':
        ensure => 'installed',
    }
    exec { 'bsnstacklib':
        command => 'pip install "bsnstacklib<2015.2"',
        path    => "/usr/local/bin/:/usr/bin/:/bin",
        require => Package['python-pip']
    }
}

