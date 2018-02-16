#!/usr/bin/env bash
ansible-playbook state-by-filter.yml --extra-vars "etag=zookeeper ekill=stopped"