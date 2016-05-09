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
