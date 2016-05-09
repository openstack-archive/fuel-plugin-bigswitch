#!/bin/bash
set -x

if [ "$#" -ne 6 ]; then
  echo "Usage: $0 <management interface> <management ip> <uplinks> <all used interfaces> <bridges' ip> <fuel_deployment_id>" >&2
  exit 1
fi

mgmt_itf=$1
IFS='/'
declare -a mgmt_ip_attr=($2)
mgmt_ip=${mgmt_ip_attr[0]}
IFS=','
declare -a uplinks=($3)
declare -a interfaces=($4)
IFS='{}'
read -ra array1 <<< $5
deployment_id=$6

cdr2mask ()
{
   # Number of args to shift, 255..255, first non-255 byte, zeroes
   set -- $(( 5 - ($1 / 8) )) 255 255 255 255 $(( (255 << (8 - ($1 % 8))) & 255 )) 0 0 0
   [ $1 -gt 1 ] && shift $1 || shift
   echo ${1-0}.${2-0}.${3-0}.${4-0}
}

echo '' > /etc/network/interfaces

# Process input arguments
IFS=','
declare -a array2=(${array1[0]})
#IFS='=>'
len=${#array2[@]}
for (( i=0; i<$len; i++ )); do
    # entry = "br-storage"=>["192.168.1.3/24"]
    entry=${array2[$i]}
    IFS='=>'
    declare -a bridge_ip=(${entry})
    key=$(echo "${bridge_ip[0]}" | sed -e 's/"//' -e 's/"//')
    netmask=""
    if [[ "$key" =~ "br-storage" ]] || [[ "$key" =~ "br-mgmt" ]]; then
        itf_ip=$(echo "${bridge_ip[2]}" | sed -e 's/\[//'  -e 's/"//' -e 's/"//' -e 's/]//')
        IFS='/'
        declare -a ip_address=(${itf_ip})
        netmask=$( cdr2mask ${ip_address[1]} )
    fi
    internal_interface=""
    if [[ "$key" =~ "br-storage" ]]; then
        internal_interface="sto${deployment_id}"
    elif [[ "$key" =~ "br-mgmt" ]]; then
        internal_interface="mgm${deployment_id}"
    elif [[ "$key" =~ "br-ex" ]]; then
        internal_interface="ex${deployment_id}"
    else
        continue
    fi

    if [[ "$internal_interface" =~ "$deployment_id" ]]; then
        echo -e 'auto' ${internal_interface} >> /etc/network/interfaces
        echo -e 'iface' ${internal_interface} 'inet manual' >> /etc/network/interfaces
        if [[ ! -z ${netmask} ]]; then
            echo -e '  address' ${ip_address[0]} >> /etc/network/interfaces
            echo -e '  netmask' ${netmask} >> /etc/network/interfaces

            ifconfig $internal_interface up
            ip link set $internal_interface up
            ifconfig $internal_interface ${ip_address[0]}
            ifconfig $internal_interface netmask ${netmask}
        fi
        echo -e '\n' >> /etc/network/interfaces
    fi
done

# /etc/network/interfaces
len=${#interfaces[@]}
for (( i=0; i<$len; i++ )); do
    echo -e 'auto' ${interfaces[$i]} >> /etc/network/interfaces
    echo -e 'iface' ${interfaces[$i]} 'inet manual' >> /etc/network/interfaces
    echo -e '\n' >> /etc/network/interfaces
done
echo -e 'auto br_fw_admin' >> /etc/network/interfaces
echo -e 'iface br_fw_admin inet static' >> /etc/network/interfaces
echo -e '  bridge_ports' ${mgmt_itf} >> /etc/network/interfaces
echo -e '  address' ${mgmt_ip} >> /etc/network/interfaces
echo -e '\n' >> /etc/network/interfaces

#reset uplinks to move them out of bond
len=${#uplinks[@]}
for (( i=0; i<$len; i++ )); do
    ip link set ${uplinks[$i]} down
done
sleep 2
for (( i=0; i<$len; i++ )); do
    ip link set ${uplinks[$i]} up
done

echo 'Restart openstack-nova-compute and neutron-bsn-agent'
service nova-compute restart
service neutron-bsn-agent restart

exit 0
