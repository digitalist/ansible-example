#!/usr/bin/env bash

ansible-playbook setup.yml --extra-vars "etag=zookeeper ecount=3"

