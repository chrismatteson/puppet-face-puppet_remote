#!/bin/bash

client=$1

mkdir -p /opt/puppetlabs/puppet/cache/remote/nodes/$1/puppet
echo "[main]" > /opt/puppetlabs/puppet/cache/remote/nodes/$1/puppet/puppet.conf
echo "certname = $1" >> /opt/puppetlabs/puppet/cache/remote/nodes/$1/puppet/puppet.conf
echo "server = `puppet config print server`" >> /opt/puppetlabs/puppet/cache/remote/nodes/$1/puppet/puppet.conf

ssh root@$1 /bin/bash << EOF
  sudo su
  mkdir /opt/puppetlabs
  mkdir /etc/puppetlabs
  mount master.inf.puppet.vm:/opt/puppetlabs/puppet/cache/remote/agents/puppet-agent-1.9.3-1.el7.x86_64/opt/puppetlabs /opt/puppetlabs
  mount master.inf.puppet.vm:/opt/puppetlabs/puppet/cache/remote/nodes/$1 /etc/puppetlabs
  /opt/puppetlabs/bin/puppet agent -t
  umount /opt/puppetlabs
  umount /etc/puppetlabs
  rmdir /opt/puppetlabs
  rmdir /etc/puppetlabs
  exit
  exit
EOF
