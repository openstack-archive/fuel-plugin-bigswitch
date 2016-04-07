#!/bin/iash

IFS=,
declare -a bridges=($1)
bond_name=$2

# stop ovs agent, otherwise, ovs bridges cannot be removed
pkill neutron-openvswitch-agent
service neutron-plugin-openvswitch-agent stop

rm -f /etc/init/neutron-plugin-openvswitch-agent.conf
rm -f /usr/bin/neutron-openvswitch-agent

# remove ovs and linux bridge, example ("br-storage" "br-prv" "br-ex")
len=${#bridges[@]}
for (( i=0; i<$len; i++ )); do
    ovs-vsctl del-br ${bridges[$i]}
    brctl delbr ${bridges[$i]}
    ip link del dev ${bridges[$i]}
done

# delete ovs br-int
while true; do
    service neutron-plugin-openvswitch-agent stop
    rm -f /etc/init/neutron-plugin-openvswitch-agent.conf
    ovs-vsctl del-br br-int
    ip link del dev br-int
    sleep 1
    ovs-vsctl show | grep br-int
    if [[ $? != 0 ]]; then
        break
    fi
done

#bring down all bonds
if [[ $bond_name != "none" ]]; then
    ip link del dev ${bond_name}
fi

exit 0

# /etc/network/interfaces
echo '' > /etc/network/interfaces
declare -a interfaces=("s0", "m0", "e0")
len=${#interfaces[@]}
for (( i=0; i<$len; i++ )); do
    echo -e 'auto' ${interfaces[$i]} >>/etc/network/interfaces
    echo -e 'iface' ${interfaces[$i]} 'inet manual' >>/etc/network/interfaces
    echo ${interfaces[$i]} | grep '\.'
    if [[ $? == 0 ]]; then
        intf=$(echo ${interfaces[$i]} | cut -d \. -f 1)
        echo -e 'vlan-raw-device ' $intf >> /etc/network/interfaces
    fi
    echo -e '\n' >> /etc/network/interfaces
done
echo -e 'auto br_fw_admin' >>/etc/network/interfaces
echo -e 'iface br_fw_admin inet static' >>/etc/network/interfaces
echo -e 'bridge_ports eth0' >>/etc/network/interfaces
echo -e 'address' >>/etc/network/interfaces

#reset uplinks to move them out of bond
uplinks=(%(uplinks)s)
len=${#uplinks[@]}
for (( i=0; i<$len; i++ )); do
    ip link set ${uplinks[$i]} down
done
sleep 2
for (( i=0; i<$len; i++ )); do
    ip link set ${uplinks[$i]} up
done

# assign ip to ivs internal ports
bash /etc/rc.local

echo 'Restart openstack-nova-compute and neutron-bsn-agent'
service nova-compute restart
service neutron-bsn-agent restart

set +e

# Make sure only root can run this script
if [[ "$(id -u)" != "0" ]]; then
   echo -e "Please run as root"
   exit 1
fi

apt-get install ubuntu-cloud-keyring
apt-get update -y
apt-get install -y linux-headers-$(uname -r) build-essential
apt-get install -y python-dev python-setuptools
apt-get install -y puppet dpkg
apt-get install -y vlan ethtool
apt-get install -y libssl-dev libffi6 libffi-dev
apt-get install -y libnl-genl-3-200
apt-get -f install -y
apt-get install -o Dpkg::Options::="--force-confold" --force-yes -y neutron-common
easy_install pip
puppet module install --force puppetlabs-inifile
puppet module install --force puppetlabs-stdlib

set -e

exit 0

