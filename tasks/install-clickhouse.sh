#!/usr/bin/env bash

# create 3 machines tagged "zookeeper". Make them large enough to hugebuild
# inside our playbooks, Ansible will address them as tag_Name_zookeeper
ansible-playbook setup.yml --extra-vars "etag=zookeeper ecount=3 etype=t2.xlarge"

# one of this instances will be also tagged as Role:master, we can use it for tasks
# that require only one machine to run, or for being default zookeepr master

# let's inform local ec2.py we have some new hosts:
./inventory/ec2.py --refresh-cache

# Zookeeper and Kafka need Java. apt will take care of this
ansible-playbook jdk-8.yml

# we use AnsibleShipyard.ansible-zookeeper role and template loop trick
# to setup a configured cluster
ansible-playbook zookeeper-cluster.yml

# We'll build our own clickhouse! We need some build tools and libs
ansible-playbook clickhouse-install-deps.yml

# Clone from github
ansible-playbook clickhouse-clone-repos.yml

# install cache and distcc for distributed builds
ansible-playbook distributed-compile-setup.yml

# Actually build it on all 3 machines, you can check it using
# `distccmon-text 2` or tail -f ~/build/ubuntu/cl/ClickHouse/distcc.log
ansible-playbook clickhouse-release.yml

# Archive and download *.deb packages. Depends on yor setup.
ansible-playbook clickhouse-release.yml

# Upload and install *.deb. Actually, we could do it without downloading,
# but I needed those debs locally, so you can make this an exercise.
ansible-playbook clickhouse-distribute-build.yml \
--extra-vars "file_name=/tmp/clickhouse/clickhouse.tar.bz2"

# Configure & start zookeeper/clickhouse
ansible-playbook clickhouse-zookeeper-config.yml