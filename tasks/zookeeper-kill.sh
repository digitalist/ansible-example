#!/usr/bin/env bash
ansible-playbook stop-by-filter.yml --extra-vars "etag=zookeeper ekill=absent"