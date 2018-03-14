#!/bin/bash

# config_haproxy.sh: Check IP addresses from webserver instances and re-configure HAProxy accordingly

AutoScalingGroupName="my-webserver-auto-scaling-group"
tmp_file="/tmp/.ip_list"
haproxy_config_file="/etc/haproxy/haproxy.cfg"
haproxy_config_file_bak="${haproxy_config_file}.bak"

# Get all IP addresses from webservers by calling AWS API
aws autoscaling describe-auto-scaling-instances --query \
"AutoScalingInstances[?AutoScalingGroupName=='${AutoScalingGroupName}'].InstanceId" \
| xargs -n1 aws ec2 describe-instances --instance-ids $ID --query \
Reservations[].Instances[].PrivateIpAddress > ${tmp_file}

# Backup current haproxy config file
cp -p ${haproxy_config_file} ${haproxy_config_file_bak}

i=1

# Read all IP addresses from temporary file and use them in config file
while read -r var
do
	echo "ip${i}: ${var}"
	sed -i -r "s/(server ws${i}\s+).*(:.*$)/\1${var}\2/" ${haproxy_config_file}
	let "i += 1"
done < ${tmp_file}

# Check if config file has changed
cmp --silent ${haproxy_config_file} ${haproxy_config_file_bak}

# Check config file and restart service only if file had changed
if [ $? -ne 0 ]; then
	check=$(haproxy -f /etc/haproxy/haproxy.cfg -c)
	[ "${check}" == "Configuration file is valid" ] && service haproxy restart || echo "New configuration file is not valid"
else
	echo "Configuration has not changed, no need to restart service"
fi

exit 0
