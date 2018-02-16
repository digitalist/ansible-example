## What do we want?
To know how to create and destroy a bunch of servers on AWS/Digital Ocean for any task we might need:

- Build/Render farms
- ML farms
- Building services

We want to do it without using a lot of GUI or fighting with typos in a sequences of _endless_ shell commands.
This article contains only two entries (apart from installing all the things like pyenv) that you'll have to do using GUI, they are marked with __manualWork__. 

You don't have to copy/paste something from here, just clone the repo and start playing with it. But if you want to understand logic or give a tip (or angry curses)... just read.


> Digital Ocean is a lot easier to work with tho. AWS is a real enterprise monster pain in the ass.
>
> You may have to contact AWS support if you want to get huge instances with billions of RAM and CPU cores right from the start

## What we will get?
A working set of tools to work with AWS EC2 Cloud. Start/Stop/Delete instances (aka servers aka machines). Deploy some clusters. Make a distributed build of Yandex ClickHouse.

### What do we need to know?
- basic knowledge of using the terminal/shell/bash - whatever they call it
- basics of ssh usage

> ssh allows you to shell into another computer and run commands there. Ansible uses it to connect to your machines and run commands for you 

## Prerequisites (what do we need?)
- Any of this: FreeBSD/Linux/OSX, maybe Linux Subsystem for Windows. In other words, any modern OS capable of running Python 
- Python (preferably v3)
- AWS EC2 Account (free tier may suffice for testing purposes)
- git

### Some not-so-optional components  
- pipenv or pyenv: to keep your python installations clean and separated. Basically these tools allow you to keep a separate python versions with a separate libraries for every project you work with.
- dotenv: same as above but for shell: makes it easy to keep environment variables connected to projects/directory you're working with. 


### Notes on security:

A couple of assumptions:

- you're not a High Profile Criminal Public Enemy Target. 
- your passwords are not like '123'
- your computer/laptop or remote control server is protected enough.

The setup we're going to use here may be not the best in terms of security, for example:
 
- it maybe a bad idea to keep your AWS API keys in your env 
- it maybe a bad idea to reuse ssh-keys
- it's a bad idea to store passwords anywhere unencrypted

... but for now we're talking about uncompromised machine, which only you can access. 

__Tip__: never place your password or keys to a repository you might share with someone.

If your setup needs credentials, least you can do: store them outside of the repo and symlink them.  

For example:

We need AWS keys in `~/.ansible/aws/.env` file. 

Create `~/.secure/aws-env` file and do

`ln -s .secure/aws-env .ansible/aws/.env`
 
 `aws-env` lives outside your repo and maps to `.env` file. 

This is not secure, but for now we're not doing _secure Ansible_ tutorial here.

## Layout and basics
`git clone https://github.com/digitalist/ansible-example.git ~/.ansible/aws`
> You can just clone project's [repo](https://github.com/digitalist/ansible-example) and start using it by writing your own Ansible Playbooks or using those included, but it's useful to understand the logic behind it - in case of troubles/questions or just to add some ideas or criticism of yours.

    `mkdir -p ~/.ansible/aws/inventory`  
    
Here goes our main Ansible AWS directory.
   
Ansible has a concept of  *Inventory* - a static list of hosts and groups of hosts,  and *Dynamic Inventory* - hosts config is  dynamic and pulled in real time from somewhere (or from cache), in this case, from AWS EC2 API.
  
>Note: static inventory is enough if your hosts don't change often or you just automate your own little home/family/vpn network.
>
> But we want to create clusters of unknown size without ever touching GUI or writing these hosts by hand
  
To use AWS EC2 API we'll need to:
  
- create an AWS AMI policy (to decide who can do what with API keys)
- setup AWS EC2 keys and environment (to allow Ansible access to API )
- setup our own ssh keys or use an AWS-generated keypair  (Ansible needs them to access your machines)

- setup an inventory directory: it will contain a script talking to EC2 API, its settings and auxiliary static inventory file. Ansible will combine both static and dynamic inventories into one entity (for ease of use)

### AWS API keys and users:
__manualWork__:
Go to https://console.aws.amazon.com/, login.
upper right corner: Your Login Name->My security credentials->Access keys, get these keys and place them
somewhere like `~/.secure/aws-env`:
    
    # ~/.secure/aws-env:
    AWS_ACCESS_KEY_ID=SOME_STRING_IN_UPPER_CASE_W1TH_N4MB3RS
    AWS_SECRET_ACCESS_KEY=some_string_in_lower_case_with_numbers

then:
    
    ln -s ~/.secure/aws-env ~/.ansible/aws/.env
    
If you did install some version of dotenv this variables will be loaded when you `cd ~/.ansible/aws` and 
`inventory/ec2.py` will use them for authentication with API 

Otherwise you'll have to export them or find another way to provide them to `ec2.py`


### Strangest thing: IAM policy

__manualWork__: Amazon has a very, very, very, very, very detailed permission system. They have over 9k services so they need over 9k
permissions. We'll consider a set of _probably_ very unsecure permissions. 

Get the `iam.json`  from the repo and copy/paste it into AWS interface: __EC2 Console: All services->IAM->Policies->Create policy__

You link your API keys to users/groups and then link IAM policies to these users/groups.  After that everyone with this API key will be able to wreak havoc using these rights:


    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "VisualEditor0",
                "Effect": "Allow",
                "Action": [
                    "ec2:DeleteTags",
                    "ec2:DeleteRouteTable",
                    "ec2:DeleteVolume",
                    "ec2:StartInstances",
                    "ec2:CreateNetworkInterfacePermission",
                    "ec2:DeleteNetworkAcl",
                    "ec2:DetachVolume",
                    "ec2:RebootInstances",
                    "ec2:TerminateInstances",
                    "ec2:CreateTags",
                    "ec2:RunInstances",
                    "ec2:StopInstances",
                    "ec2:CreateVolume",
                    "ec2:DisassociateIamInstanceProfile",
                    "ec2:AssociateIamInstanceProfile",
                    "ec2:DeleteNetworkAclEntry",
                    "ec2:DescribeKeyPairs",
                    "ec2:CreateKeyPair",
                    "ec2:ImportKeyPair"
                ],
                "Resource": "*"
            }
        ]
    }
       

Since we're not starting a business Godzilla Devops Operation here, these should suffice.



creating envrionment for ansible is easy if you have pyenv or pipenv installed
like this (for pyenv):

       # already in our repo, just gory details
       cd ~/.ansible # assuming we did mkdir -p ~/.ansible/aws/inventory
       pyenv install 3.4.6 aws  # create separate python install named aws
       echo aws > .python-version # it will be activated next time you go to ~/.ansible dir
       cd ../ && cd ansible # or just pyenv local aws
       pip install ansible boto3 boto # we need ansible and we'll need botos to work with aws

### Inventory:

#### Dynamic inventory ec2.py: 
    # download official ec2 dynamic inventory script
    wget \
    https://raw.githubusercontent.com/ansible/ansible/devel/contrib/inventory/ec2.py \
    -O ~/.ansible/aws/inventory/ec2.py
    # make it executable. Ansible takes every executable inventory file as a dynamic source 
    chmod +x ~/.ansible/aws/inventory/ec2.py

#### Ansbile config 
Ansible searches for its config in a current directory (and some other default locations). Assuming we're going to work in `~/.ansible/aws`:    

    # ~/.ansible/aws/ansible.cfg
    [defaults] 
    # without a grin we told ansible to use local inventory dir as it's inventory
    inventory = inventory

#### AWS Keypairs: Important.

These are just your usual ssh-keys. You need to create them through AWS EC2 UI or upload your own key:

If you created ~/.ssh/default_ec2_key, you can run 

`ansible-playbook keypair.yml` to upload your own keypair for future usage:

    - hosts: localhost
      connection: local
      gather_facts: False
    
      tasks:
      - include_vars: "ec-vars.yml"
      - name: default ec2 key
        ec2_key:
          name: default_ec2_key
          region: "{{ ec_region }}"
          key_material: "{{ item }}"
        # IAM permissions needed: "ec2:CreateKeyPair", "ec2:ImportKeyPair"
        # to create: ssh-keygen -f ~/.ssh/default_ec2_key.pub
        with_file: ~/.ssh/default_ec2_key.pub


#### Testing:

If you cloned a repo to `~/.ansible/aws`, `cd` there and type
    
    ansible-playbook setup.yml 

This (with some luck) create a t2.micro instance. Wait a minute and run

    ansible-playbook facts.yml

You should see some info about your instances and list of their ids.
    

## Writing and using AWS playbooks

##Some tricks

Before observing some playbooks from example repository, you may want to take a look at layout and some Ansible tricks used there.

#### Template variables and default settings

If you look at `setup.yml` you will see a lot of {{ jinja2 template variables }} there. 

    - hosts: localhost
      connection: local
      gather_facts: False
    
      tasks:
      - include_vars: "ec-vars.yml"
      - name: Provision a set of instances
        ec2:
          key_name: "{{ ec_key }}"
          region: "{{ ec_region }}"
          group: "{{ ec_group }}"
          instance_type: "{{ ec_instance_type }}"
          image: "{{ ami_id }}"
          wait: True
          exact_count: "{{ ec_exact_count }}"
          count_tag:
            Name: "{{ ec_tag }}"
          instance_tags:
            Name: "{{ ec_tag }}"
          volumes:
          - device_name: /dev/sda1
            device_type: gp2
            volume_size: 30
            delete_on_termination: true
        register: ec2
    
      - name: Add all instance public IPs to host group
        add_host: hostname={{ item.public_ip }} groups=ec2hosts
        with_items: "{{ ec2.instances }}"
      
They are includd by this line: `- include_vars: "ec-vars.yml"` : 

    #this book has default vars for all other books
    
    # OS image we install (ubuntu something here)
    # ami_id: "ami-97e953f8" #ubuntu 16.04
    # "ami-c041d3af" ubuntu 17.10 with gcc6
    ami_id: "{{ eami | default('ami-c041d3af') }}"
    
    
    # aws region, it's important. see docs and use what's better for you
    ec_region: "{{ eregion | default('eu-central-1') }}"
    
    # machine configuration, t2.micro is default, smol iron.
    # t2.xlarge
    ec_instance_type: "{{ etype | default('t2.micro') }}"
    
    # number of instances of given condition in our playbook conditions we want to have
    ec_exact_count: "{{ ecount | default('1') }}"
    
    # let's tag them by default
    ec_tag: "{{ etag | default('demo') }}"
    
    # this is useful for read-only tasks, it will capture all your instances
    ec_filters_tag_name: "{{ etag | default('*') }}"
    
    # in case of an error we don't want to kill important machine, let's stop it
    # you can always override it with "ekill=absent"
    ec_kill_state: "{{ ekill | default('stopped') }}"
    
    # bad practice: for the sake of simplicity allow ssh access for every machine,
    # assuming 'ssh' group allows port 22 access
    ec_group: "{{ egroup | default('ssh') }}"
    
    # see keypair.yml
    ec_key: "{{ ekey | default ('default_ec2_key') }}"

Nice trick to remember: every template variable here has a **default** value, which you can override using a CLI syntax like this:
    
    # from tasks/ubu16-start.sh, override default image and tag
    ansible-playbook -vvvv setup.yml --extra-vars "etag=ubu16  ecount=1 eami=ami-97e953f8"
    
This layout gives us great flexibility: you don't have to rewrite a playbook, just add a task script overriding those values and you're good to go.

For example, if your static inventory contains name of local virtualbox machine you can change `etag` and instead of picking hosts by AWS tags Ansible will work with local VM:

    ansible-playbook clickhouse-install-deps.yml --extra-vars "etag=ubuserver"

name 'ubuserver' should be configured in your .ssh

### Template loop trick

Ansible uses Jinja2 templates as a playbook basis. And Jinja2 supports loops and control structures. This allows us to iterate over any number of hosts, create configuration strings and place them into variables.

    # from https://github.com/AnsibleShipyard/ansible-zookeeper
    # for every host in tagged group we set internal ip from hostvars
          # ips[] list "returns" to zookeeper_hosts var, which this role uses
          zookeeper_hosts: "
            {%- set ips = [] %}
            {%- for zk in groups['tag_Name_zookeeper'] %}
            {%- set internal_ip = hostvars[zk]['ansible_default_ipv4']['address'] %}
              {{- ips.append(dict(host=zk, ip=internal_ip, id=loop.index)) }}
            {%- endfor %}
            {{- ips -}}
            "
    # {{- ips_variable_is_trimmed_by_this_syntax -}}          
   
another example: iterate over hosts, skip first, concatenate others into strings

    - name: collect compiler slaves
        #192.168.0.3,lzo,cpp 192.168.0.4,lzo,cpp #cpp for pump mode
        set_fact:
          zookeeper_hosts: "
          {%- set ips = [] %}
          {%- set master_host = groups['tag_Name_zookeeper'][0] %}
          {%- for zk in groups['tag_Name_zookeeper'] %}
            {%- set internal_ip = hostvars[zk]['ansible_default_ipv4']['address'] %}
            {%- if zk ==  master_host %}
              {%- set internal_ip='JUST IGNORE THIS LINE' %}
            {%- else %}
              {{- ips.append( internal_ip+',lzo')}}
            {%- endif %}
          {%- endfor %}
          {{- ips | join(' ') -}}
          "
        register: zookeeper_hosts    

                
### Array append trick

Using `with_item` with Jinja2 magic we can populate an array and use it later:

     # collect instance_ids to ids[] list
      - with_items: " {{instances.instances}} "
        set_fact:
          ids: "{{ ids }} + [ '{{ item.instance_id }}' ]"

from [Crisp's blog](https://blog.crisp.se/2016/10/20/maxwenzin/how-to-append-to-lists-in-ansible) by @maxwenzin 


### Ansible Galaxy 

In short Ansible Galaxy is a hub for Ansible Roles. Ansible Roles are like packaged tasks which can be included into your own playbooks. Typical usage for roles is installing software. We'll use some of them here. When you see `role` command inside a playbook, it means it will be executed from its installed location (you install roles into your current working tree by running `ansible-galaxy install author.role_name`)  

> Some good folks shared their work to make everyone's life easier. Be like them.

Here we will use Zookeper role from [Ansible Shipyard](https://github.com/AnsibleShipyard)
Ansible Roles are very good source for learning Ansible tricks and code style: take a look at `roles/AnsibleShipyard.ansible-zookeeper` 
It's pretty neat and declarative (unlike my attempts here)

## Let's go

Our tasks are: 
- Create 3 instances on AWS,
- Install Zookeeper, Kafka
- Build ClickHouse

If prerequisites are met:
    - You have AWS API keys and AMI Policy setup
    - You can create t2.xlarge or other big instances
    
You can run these commands and inspect/modify playbooks to your needs 
copy-paste from 'tasks/install_clickhouse.sh':

 Create 3 machines tagged "zookeeper". Make them large enough to hugebuild 
 inside our playbooks, Ansible will address them as tag_Name_zookeeper
  
    ansible-playbook setup.yml --extra-vars "etag=zookeeper ecount=3 etype=t2.xlarge"
    
 One of this instances will be also tagged as Role:master, we can use it for tasks
 that require only one machine to run, or for being default zookeepr master  
    
 Let's inform local ec2.py we have some new hosts:
  
    ./inventory/ec2.py --refresh-cache

 Zookeeper and Kafka need Java. apt will take care of this
  
    ansible-playbook jdk-8.yml
                
 We use AnsibleShipyard.ansible-zookeeper role and template loop trick 
 to setup a configured cluster
 
    ansible-playbook zookeeper-cluster.yml
    
 We'll build our own clickhouse! We need some build tools and libs
 
    ansible-playbook clickhouse-install-deps.yml
    
 Clone from github
 
    ansible-playbook clickhouse-clone-repos.yml
    
 install cache and distcc for distributed builds
 
    ansible-playbook distributed-compile-setup.yml
    
 Actually build it on all 3 machines, you can check it using 
 `distccmon-text 2` or tail -f ~/build/ubuntu/cl/ClickHouse/distcc.log
  
    ansible-playbook clickhouse-release.yml
    
 Archive and download *.deb packages. Depends on yor setup.
 
    ansible-playbook clickhouse-release.yml
    
 Upload and install *.deb. We could do it without downloading,
 but I needed those debs locally, so you can make this an exercise.
 
    ansible-playbook clickhouse-distribute-build.yml \
    --extra-vars "file_name=/tmp/clickhouse/clickhouse.tar.bz2"
    
 Configure & start zookeeper/clickhouse
 
    ansible-playbook clickhouse-zookeeper-config.yml
    


    
Finally, stop all instances or face a financial crash
    
    ansible-playbook state-by-filter.yml --extra-vars "etag=zookeeper ekill=stopped"

Start them again 
    
    ansible-playbook state-by-filter.yml --extra-vars "etag=zookeeper ekill=running"

Fin! Kill them. Wipe all the traces.
    
    ansible-playbook state-by-filter.yml --extra-vars "etag=zookeeper ekill=absent"


That's all. If you encounter any errors (you will), feel free to leave a comment. I'll be updating this post.