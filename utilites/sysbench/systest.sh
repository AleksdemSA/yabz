#!/bin/bash

if [ -f /etc/redhat-release ]; then
  curl -s https://packagecloud.io/install/repositories/akopytov/sysbench/script.rpm.sh | sudo bash
  sudo yum -y install sysbench
fi

if [ -f /etc/lsb-release ]; then
  curl -s https://packagecloud.io/install/repositories/akopytov/sysbench/script.deb.sh | sudo bash
  sudo apt -y install sysbench
fi


echo "######## CPU Test ########"
sysbench --test=cpu --cpu-max-prime=20000 run

echo "######## Memory Test ########"
sysbench --test=memory run
