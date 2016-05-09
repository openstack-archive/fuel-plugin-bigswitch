#!/bin/bash
set -x

if [[ "$(id -u)" != "0" ]]; then
   echo -e "Please run as root"
   exit 1
fi

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <bcf_version>" >&2
  exit 1
fi

bcf_version=$1

# install ivs
apt-get install -y libnl-genl-3-200
apt-get -f install -y
dpkg --force-all -i "/etc/fuel/plugins/fuel-plugin-bigswitch-1.0/ivs_packages/ubuntu/ivs_${bcf_version}_amd64.deb"
dpkg --force-all -i "/etc/fuel/plugins/fuel-plugin-bigswitch-1.0/ivs_packages/ubuntu/ivs-dbg_${bcf_version}_amd64.deb"
apt-get install -y apport

# full installation
if [[ -f /etc/init/neutron-plugin-openvswitch-agent.override ]]; then
    cp /etc/init/neutron-plugin-openvswitch-agent.override /etc/init/neutron-bsn-agent.override
fi

exit 0
