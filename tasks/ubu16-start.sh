#!/usr/bin/env bash
#ec_region: "{{ eregion | default('eu-central-1') }}"
#ec_instance_type: "{{ etype | default('t2.micro') }}"
#ec_exact_count: "{{ ecount | default('1') }}"
#ec_tag: "{{ etag | default('demo') }}"


ansible-playbook -vvvv setup.yml --extra-vars "etag=ubu16  ecount=1 eami=ami-97e953f8"

