#!/bin/bash

client=$1

ssh root@$1 /bin/bash << EOF
  sudo su
  mkdir /opt/puppetlabs
  mkdir /etc/puppetlabs
  mount master.inf.puppet.vm:/opt/puppetlabs /opt/puppetlabs
  mount master:inf.puppet.vm:/var/puppetlabs/etc /etc/puppetlabs
  /opt/puppetlabs/bin/puppet agent -t
  exit
  exit
EOF
