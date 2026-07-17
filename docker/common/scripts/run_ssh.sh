#! /usr/bin/bash

### Setup to custom command
if [ -z $ssh_setuped ]; then
	if [ -z $SSH_PORT ]; then
		echo "SSH disable"
		echo "ssh_disable=true" >>$profile
		ssh_disable=true
	else
		echo "SSH enable Port=$SSH_PORT"
		echo "root:root" | chpasswd
		echo "PermitRootLogin yes" >>/etc/ssh/sshd_config
		# echo "PasswordAuthentication yes" >>/etc/ssh/sshd_config
		echo "Port $SSH_PORT" >>/etc/ssh/sshd_config
		mkdir /run/sshd
	fi
	echo "ssh_setuped=true" >>$profile
fi
if [ -z $ssh_disable ]; then
	service ssh start &
fi
