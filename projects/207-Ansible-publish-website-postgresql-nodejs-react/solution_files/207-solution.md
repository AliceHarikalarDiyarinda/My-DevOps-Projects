## Part 1 - Launch the instances

- Create 4 `Red Hat Enterprise Linux 8 (HVM). 

- ansible_control (t2.medium) (tag: Name=ansible_control)

- ansible_postgresql, ansible_nodejs, ansible_react (t2.micro) (Add 5000, 3000, 5432 to security grıops)

## Part 2 - Prepare the scene

Connect the ansible_control node
   
   - Copy the student files

   - Run the commands below to install Python3 and Ansible. 

```bash
$ sudo yum update -y
```

```bash
$ sudo yum install -y python3 
```

```bash
$ sudo yum install -y python3-pip 
```

```bash
$ pip3 install --user ansible
```

- Check Ansible's installation with the command below.

```bash
$ ansible --version
```

- Create ansible directory and change directory to this directory.

```bash
mkdir ansible
cd ansible
```

- Create `ansible.cfg` files.

```
[defaults]
host_key_checking = False
inventory=inventory_aws_ec2.yml
interpreter_python=auto_silent
private_key_file=/home/ec2-user/aduncan.pem 
remote_user=ec2-user
```

- copy pem file from local to home directory of ec2-user.

```bash
scp -i <pem-file> <pem-file> ec2-user@<public-ip of ansible_control>:/home/ec2-user
```

## Part 3 - Creating dynamic inventory

- go to AWS Management Consol and select the IAM roles:

- click the  "create role" then create a role with "AmazonEC2FullAccess"

- go to EC2 instance Dashboard, and select the control-node instance

- select actions -> security -> modify IAM role

- select the role thay you have jsut created for EC2 full access and save it.

- install "boto3"

```bash
pip3 install --user boto3
```

- Tag the postgresql, nodejs and react instances as below.

```
Name=ansible_postgresql
Name=ansible_nodejs
Name=ansible_react
```

- Tag ansible_control, ansible_postgresql, ansible_nodejs, ansible_react instances as below.

```
stack=ansible_project
```

- Tag ansible_postgresql, ansible_nodejs, ansible_react instances as below.

```
environment=development
```

- Create `inventory_aws_ec2.yml` file under the ansible directory. 

```yaml
plugin: aws_ec2
regions:
  - "us-east-1"
filters:
  tag:stack: ansible_project
keyed_groups:
  - key: tags.Name
  - key: tags.environment
compose:
  ansible_host: public_ip_address
```

```bash
$ ansible-inventory -i inventory_aws_ec2.yml --graph
```

```
@all:
  |--@_ansible_control:
  |  |--ec2-3-80-96-146.compute-1.amazonaws.com
  |--@_ansible_nodejs:
  |  |--ec2-3-239-243-194.compute-1.amazonaws.com
  |--@_ansible_postgresql:
  |  |--ec2-3-236-160-236.compute-1.amazonaws.com
  |--@_ansible_react:
  |  |--ec2-3-236-197-117.compute-1.amazonaws.com
  |--@_development:
  |  |--ec2-3-236-160-236.compute-1.amazonaws.com
  |  |--ec2-3-236-197-117.compute-1.amazonaws.com
  |  |--ec2-3-239-243-194.compute-1.amazonaws.com
  |--@aws_ec2:
  |  |--ec2-3-236-160-236.compute-1.amazonaws.com
  |  |--ec2-3-236-197-117.compute-1.amazonaws.com
  |  |--ec2-3-239-243-194.compute-1.amazonaws.com
  |  |--ec2-3-80-96-146.compute-1.amazonaws.com
  |--@ungrouped:
```

- To make sure that all our hosts are reachable with dynamic inventory, we will run various ad-hoc commands that use the ping module.

```bash
$ ansible all -m ping 
```

## Part 4 - Prepare the playbook files

- Create `ansible-Project` directory under home directory and change directory to this directory.

```bash
cd
mkdir ansible-project
cd ansible-project
```

- Create `postgres`, `nodejs`, `react` directories.

```bash
mkdir postgres nodejs react
```

### postgres

- Copy the content of `~/student_files/todo-app-pern/database` directory to `~/ansible-project/postgres` folder.

- Change directory to `postgres` directory.

```bash
cd postgres
```

- Create a Dockerfile

```Dockerfile
FROM postgres

COPY ./init.sql /docker-entrypoint-initdb.d/

EXPOSE 5432
```

- change directory `~/ansible` directory.

```bash
cd ~/ansible
```

- Create a yaml file as postgres playbook and name it `docker_postgre.yml`.

```yaml
- name: Install docker
  gather_facts: No
  any_errors_fatal: true
  hosts: _ansible_postgresql
  become: true
  vars_files:
    - secret.yml
  tasks:
    - name: upgrade all packages
      ansible.builtin.yum: 
        name: '*'
        state: latest
    # we may need to uninstall any existing docker files from the centos repo first. 
    - name: Remove docker if installed from CentOS repo
      ansible.builtin.yum:
        name:
          - docker
          - docker-client
          - docker-client-latest
          - docker-common
          - docker-latest
          - docker-latest-logrotate
          - docker-logrotate
          - docker-engine
        state: removed

  # yum-utils is a collection of tools and programs for managing yum repositories, installing debug packages, source packages, extended information from repositories and administration.
    - name: Install yum utils
      ansible.builtin.yum:
        name: "yum-utils"
        state: latest

  # set up the repository (`yum_repository` modul can be used)
    - name: Add Docker repo
      ansible.builtin.get_url:
        url: https://download.docker.com/linux/centos/docker-ce.repo
        dest: /etc/yum.repos.d/docker-ce.repo

    - name: Install Docker
      ansible.builtin.package:
        name: docker-ce
        state: latest

    - name: Add user ec2-user to docker group
      ansible.builtin.user:
        name: ec2-user
        groups: docker
        append: yes

    - name: Start Docker service
      ansible.builtin.service:
        name: docker
        state: started
        enabled: yes

    - name: copy files to the postgresql node
      ansible.builtin.copy:
        src: /home/ec2-user/ansible-project/postgres/
        dest: /home/ec2-user/postgresql

# Remove the container if it exists
    - name: remove cla_postgre container
      community.docker.docker_container:
        name: cla_postgre
        state: absent
        force_kill: true

# Remove the image if it exists
    - name: remove clarusway/postgre image
      community.docker.docker_image:
        name: clarusway/postgre
        state: absent

    - name: build container image
      community.docker.docker_image:
        name: clarusway/postgre
        build:
          path: /home/ec2-user/postgresql
        source: build
        state: present
      register: image_info

    - name: print the image info
      ansible.builtin.debug:
        var: image_info

    - name: Launch postgresql docker container
      community.docker.docker_container:
        name: cla_postgre
        image: clarusway/postgre
        state: started
        ports: 
        - "5432:5432"
        env:
          POSTGRES_PASSWORD: "{{ password }}"
        volumes:
          - /db-data:/var/lib/postgresql/data
      register: container_info
    
    - name: print the container info
      ansible.builtin.debug:
        var: container_info
```

- Execute it.

```bash
ansible-vault create secret.yml
```

```secret.yml
password: Pp123456789
```

```
ansible-playbook --ask-vault-pass docker_postgre.yml
```

```
ansible _ansible_postgresql -b -m shell -a "docker ps"
```

```
ansible-inventory --graph #if you get ansible host match error
```

### nodejs

- Copy the content of `~/student_files/todo-app-pern/server` directory to `~/ansible-project/nodejs` folder.


- Change directory to `~/ansible-project/nodejs` directory.

```bash
cd ~/ansible-project/nodejs
```

- Create a Dockerfile.

```Dockerfile
FROM node:14

# Create app directory
WORKDIR /usr/src/app


COPY package*.json ./

RUN npm install
# If you are building your code for production
# RUN npm ci --only=production


# copy all files into the image
COPY . .

EXPOSE 5000

CMD ["node","app.js"]
```

- Change the `~/ansible-project/nodejs/.env` file as below.

```
SERVER_PORT=5000
DB_USER=postgres
DB_PASSWORD=Pp123456789
DB_NAME=clarustodo
DB_HOST=172.31.12.133 # (private ip of postgresql instance)
DB_PORT=5432
```

- change directory `~/ansible` directory.

```bash
cd ~/ansible
```

- Create a yaml file as nodejs playbook and name it `docker_nodejs.yml`.

```yaml
- name: Install docker
  gather_facts: No
  any_errors_fatal: true
  hosts: _ansible_nodejs
  become: true
  tasks:
    - name: upgrade all packages
      ansible.builtin.yum: 
        name: '*'
        state: latest
    # we may need to uninstall any existing docker files from the centos repo first. 
    - name: Remove docker if installed from CentOS repo
      ansible.builtin.yum:
        name:
          - docker
          - docker-client
          - docker-client-latest
          - docker-common
          - docker-latest
          - docker-latest-logrotate
          - docker-logrotate
          - docker-engine
        state: removed

  # yum-utils is a collection of tools and programs for managing yum repositories, installing debug packages, source packages, extended information from repositories and administration.
    - name: Install yum utils
      ansible.builtin.yum:
        name: "yum-utils"
        state: latest

  # set up the repository (`yum_repository` modul can be used.)
    - name: Add Docker repo
      ansible.builtin.get_url:
        url: https://download.docker.com/linux/centos/docker-ce.repo
        dest: /etc/yum.repos.d/docker-ce.repo

    - name: Install Docker
      ansible.builtin.package:
        name: docker-ce
        state: latest

    - name: Add user ec2-user to docker group
      ansible.builtin.user:
        name: ec2-user
        groups: docker
        append: yes

    - name: Start Docker service
      ansible.builtin.service:
        name: docker
        state: started
        enabled: yes

    - name: copy files to the nodejs node
      ansible.builtin.copy:
        src: /home/ec2-user/ansible-project/nodejs/
        dest: /home/ec2-user/nodejs

  # Remove the container if it exists
    - name: remove cla_nodejs container
      community.docker.docker_container:
        name: cla_nodejs
        state: absent
        force_kill: true

  # Remove the image if it exists
    - name: remove clarusway/nodejs image
      community.docker.docker_image:
        name: clarusway/nodejs
        state: absent

    - name: build container image
      community.docker.docker_image:
        name: clarusway/nodejs
        build:
          path: /home/ec2-user/nodejs
        source: build
        state: present
      register: image_info

    - name: print the image info
      ansible.builtin.debug:
        var: image_info

    - name: Launch nodejs docker container
      community.docker.docker_container:
        name: cla_nodejs
        image: clarusway/nodejs
        state: started
        ports: 
        - "5000:5000"
      register: container_info
    
    - name: print the container info
      ansible.builtin.debug:
        var: container_info
```

- Execute it.

```
ansible-playbook docker_nodejs.yml
```

```
ansible _ansible_nodejs -b -m shell -a "docker ps"
```

```
ansible-inventory --graph #if you get ansible host match error
```

### react

- Copy the content of `~/student_files/todo-app-pern/client` directory to `~/ansible-project/react` folder.

- Change directory to `~/ansible-Project/react` directory.

```bash
cd ~/ansible-project/react
```

- Create a Dockerfile.

```Dockerfile
FROM node:14

# Create app directory
WORKDIR /app


COPY package*.json ./

RUN yarn install

# copy all files into the image
COPY . .

EXPOSE 3000

CMD ["yarn", "run", "start"]
```

- Change the `~/ansible-project/react/.env` file as below.

```
REACT_APP_BASE_URL=http://<public ip of nodejs>:5000/
```

- change directory `~/ansible` directory.

```bash
cd ~/ansible
```

- Create a yaml file as react playbook and name it `docker_react.yml`.

```yaml
- name: Docker install and configuration
  gather_facts: No
  any_errors_fatal: true
  hosts: _ansible_react
  become: true
  tasks:
    - name: upgrade all packages
      ansible.builtin.yum: 
        name: '*'
        state: latest
    # we may need to uninstall any existing docker files from the centos repo first. 
    - name: Remove docker if installed from CentOS repo
      ansible.builtin.yum:
        name:
          - docker
          - docker-client
          - docker-client-latest
          - docker-common
          - docker-latest
          - docker-latest-logrotate
          - docker-logrotate
          - docker-engine
        state: removed

  # yum-utils is a collection of tools and programs for managing yum repositories, installing debug packages, source packages, extended information from repositories and administration.
    - name: Install yum utils
      ansible.builtin.yum:
        name: "yum-utils"
        state: latest

  # set up the repository (`yum_repository` modul can be used.)
    - name: Add Docker repo
      ansible.builtin.get_url:
        url: https://download.docker.com/linux/centos/docker-ce.repo
        dest: /etc/yum.repos.d/docker-ce.repo

    - name: Install Docker
      ansible.builtin.package:
        name: docker-ce
        state: latest

    - name: Add user ec2-user to docker group
      ansible.builtin.user:
        name: ec2-user
        groups: docker
        append: yes

    - name: Start Docker service
      ansible.builtin.service:
        name: docker
        state: started
        enabled: yes

  # at this point do not forget change REACT_APP_BASE_URL env variable for nodejs node

    - name: copy files to the react node
      copy:
        src: /home/ec2-user/ansible-project/react/
        dest: /home/ec2-user/react

    - name: remove cla_react container
      community.docker.docker_container:
        name: cla_react
        state: absent
        force_kill: true

    - name: remove clarusway/react image
      community.docker.docker_image:
        name: clarusway/react
        state: absent
  
    - name: build container image
      community.docker.docker_image:
        name: clarusway/react
        build:
          path: /home/ec2-user/react
        source: build
        state: present

    - name: Launch postgresql docker container
      community.docker.docker_container:
        name: cla_react
        image: clarusway/react
        state: started
        ports: 
        - "3000:3000"
      register: container_info
    
    - name: print the container info
      debug:
        var: container_info
```

- Execute it.

```
ansible-playbook docker_react.yml
```

## Part 5 - Prepare one playbook file for all instances.

- Create a `docker_project.yml` file under `the ~/ansible` folder.

```yaml
- name: Docker install and configuration
  gather_facts: No
  any_errors_fatal: true
  hosts: _development
  become: true
  tasks:
    - name: upgrade all packages
      ansible.builtin.yum: 
        name: '*'
        state: latest
    # we may need to uninstall any existing docker files from the centos repo first. 
    - name: Remove docker if installed from CentOS repo
      ansible.builtin.yum:
        name:
          - docker
          - docker-client
          - docker-client-latest
          - docker-common
          - docker-latest
          - docker-latest-logrotate
          - docker-logrotate
          - docker-engine
        state: removed

  # yum-utils is a collection of tools and programs for managing yum repositories, installing debug packages, source packages, extended information from repositories and administration.
    - name: Install yum utils
      ansible.builtin.yum:
        name: "yum-utils"
        state: latest

  # set up the repository (`yum_repository` modul can be used.)
    - name: Add Docker repo
      ansible.builtin.get_url:
        url: https://download.docker.com/linux/centos/docker-ce.repo
        dest: /etc/yum.repos.d/docker-ce.repo

    - name: Install Docker
      ansible.builtin.package:
        name: docker-ce
        state: latest

    - name: Add user ec2-user to docker group
      ansible.builtin.user:
        name: ec2-user
        groups: docker
        append: yes

    - name: Start Docker service
      ansible.builtin.service:
        name: docker
        state: started
        enabled: yes


- name: Postgre Database configuration
  hosts: _ansible_postgresql
  become: true
  gather_facts: No
  any_errors_fatal: true
  vars:
    container_path: /home/ec2-user/postgresql
    container_name: cla_postgre
    image_name: clarusway/postgre

  tasks:
    - name: copy files to the postgresql node
      ansible.builtin.copy:
        src: /home/ec2-user/ansible-project/postgres/
        dest: "{{ container_path }}"

    - name: remove {{ container_name }} container
      community.docker.docker_container:
        name: "{{ container_name }}"
        state: absent
        force_kill: true

    - name: remove "{{ image_name }}" image
      community.docker.docker_image:
        name: "{{ image_name }}"
        state: absent

    - name: build container image
      community.docker.docker_image:
        name: "{{ image_name }}"
        build:
          path: "{{ container_path }}"
        source: build
        state: present

    - name: Launch postgresql docker container
      community.docker.docker_container:
        name: "{{ container_name }}"
        image: "{{ image_name }}"
        state: started
        ports: 
        - "5432:5432"
        env:
          POSTGRES_PASSWORD: "Pp123456789"
        volumes:
          - /db-data:/var/lib/postgresql/data
      register: container_info
    
    - name: print the container info
      ansible.builtin.debug:
        var: container_info


- name: Nodejs Server configuration
  hosts: _ansible_nodejs
  become: true
  gather_facts: No
  any_errors_fatal: true
  vars: 
    container_path: /home/ec2-user/nodejs
    container_name: cla_nodejs
    image_name: clarusway/nodejs

  tasks:
    - name: copy files to the nodejs node
      copy:
        src: /home/ec2-user/ansible-project/nodejs/
        dest: "{{ container_path }}"

    - name: remove {{ container_name }} container
      community.docker.docker_container:
        name: "{{ container_name }}"
        state: absent
        force_kill: true

    - name: remove "{{ image_name }}" image
      community.docker.docker_image:
        name: "{{ image_name }}"
        state: absent
  
    - name: build container image
      community.docker.docker_image:
        name: "{{ image_name }}"
        build:
          path: "{{ container_path }}"
        source: build
        state: present

    - name: Launch postgresql docker container
      community.docker.docker_container:
        name: "{{ container_name }}"
        image: "{{ image_name }}"
        state: started
        ports: 
        - "5000:5000"
      register: container_info
    
    - name: print the container info
      ansible.builtin.debug:
        var: container_info


- name: React UI Server configuration
  hosts: _ansible_react
  become: true
  gather_facts: No
  any_errors_fatal: true
  vars:
    container_path: /home/ec2-user/react
    container_name: cla_react
    image_name: clarusway/react

  tasks:
    - name: copy files to the react node
      copy:
        src: /home/ec2-user/ansible-project/react/
        dest: "{{ container_path }}"

    - name: remove {{ container_name }} container
      community.docker.docker_container:
        name: "{{ container_name }}"
        state: absent
        force_kill: true

    - name: remove "{{ image_name }}" image
      community.docker.docker_image:
        name: "{{ image_name }}"
        state: absent
  
    - name: build container image
      community.docker.docker_image:
        name: "{{ image_name }}"
        build:
          path: "{{ container_path }}"
        source: build
        state: present

    - name: Launch postgresql docker container
      community.docker.docker_container:
        name: "{{ container_name }}"
        image: "{{ image_name }}"
        state: started
        ports: 
        - "3000:3000"
      register: container_info
    
    - name: print the container info
      ansible.builtin.debug:
        var: container_info
```

- Execute it.

```bash
ansible-playbook docker_project.yml
```


## Part 6 - Prepare playbook with roles solution.

- Cretae a role folder in /home/ec2-user/ansible. Then create role folders.

mkdir roles && cd roles
ansible-galaxy init docker
ansible-galaxy init postgre
ansible-galaxy init nodejs
ansible-galaxy init react

- Add the roles_path=/home/ec2-user/ansible/roles to the ansible.cfg.

- Go to the /home/ec2-user/ansible/roles/docker/tasks/main.yml and copy the following.

```yaml
    - name: upgrade all packages
      ansible.builtin.yum: 
        name: '*'
        state: latest
    # we may need to uninstall any existing docker files from the centos repo first. 
    - name: Remove docker if installed from CentOS repo
      ansible.builtin.yum:
        name:
          - docker
          - docker-client
          - docker-client-latest
          - docker-common
          - docker-latest
          - docker-latest-logrotate
          - docker-logrotate
          - docker-engine
        state: removed

  # yum-utils is a collection of tools and programs for managing yum repositories, installing debug packages, source packages, extended information from repositories and administration.
    - name: Install yum utils
      ansible.builtin.yum:
        name: "yum-utils"
        state: latest

  # set up the repository (`yum_repository` modul can be used.)
    - name: Add Docker repo
      ansible.builtin.get_url:
        url: https://download.docker.com/linux/centos/docker-ce.repo
        dest: /etc/yum.repos.d/docker-ce.repo

    - name: Install Docker
      ansible.builtin.package:
        name: docker-ce
        state: latest

    - name: Add user ec2-user to docker group
      ansible.builtin.user:
        name: ec2-user
        groups: docker
        append: yes

    - name: Start Docker service
      ansible.builtin.service:
        name: docker
        state: started
        enabled: yes
```


- Go to the /home/ec2-user/ansible/roles/postgre/tasks/main.yml and copy the followings.

```yaml
    - name: copy the Dockerfile
      ansible.builtin.copy:
        src: postgres/ # write only file name
        dest: "{{ container_path }}"

    - name: remove {{ container_name }} container
      community.docker.docker_container:
        name: "{{ container_name }}"
        state: absent
        force_kill: true

    - name: remove "{{ image_name }}" image
      community.docker.docker_image:
        name: "{{ image_name }}"
        state: absent

    - name: build container image
      community.docker.docker_image:
        name: "{{ image_name }}"
        build:
          path: "{{ container_path }}"
        source: build
        state: present

    - name: Launch postgresql docker container
      community.docker.docker_container:
        name: "{{ container_name }}"
        image: "{{ image_name }}"
        state: started
        ports: 
        - "5432:5432"
        env:
          POSTGRES_PASSWORD: "Pp123456789"
        volumes:
          - /db-data:/var/lib/postgresql/data
      register: container_info
    
    - name: print the container info
      ansible.builtin.debug:
        var: container_info
```


- Copy /home/ec2-user/ansible-project/postgres folder to /home/ec2-user/ansible/roles/postgre/files.

- Copy these variables to /home/ec2-user/ansible/roles/postgre/vars/main.yml.

```
container_path: /home/ec2-user/postgresql
container_name: cla_postgre
image_name: clarusway/postgre
```

- Go to the /home/ec2-user/ansible/roles/nodejs/tasks/main.yml and copy the followings.

```yaml
    - name: copy files to the nodejs node
      copy:
        src: nodejs/
        dest: "{{ container_path }}"

    - name: remove {{ container_name }} container
      community.docker.docker_container:
        name: "{{ container_name }}"
        state: absent
        force_kill: true

    - name: remove "{{ image_name }}" image
      community.docker.docker_image:
        name: "{{ image_name }}"
        state: absent
  
    - name: build container image
      community.docker.docker_image:
        name: "{{ image_name }}"
        build:
          path: "{{ container_path }}"
        source: build
        state: present

    - name: Launch postgresql docker container
      community.docker.docker_container:
        name: "{{ container_name }}"
        image: "{{ image_name }}"
        state: started
        ports: 
        - "5000:5000"
      register: container_info
    
    - name: print the container info
      ansible.builtin.debug:
        var: container_info
```

- Copy /home/ec2-user/ansible-project/nodejs folder to /home/ec2-user/ansible/roles/nodejs/files.


- Copy these variables to /home/ec2-user/ansible/roles/nodejs/vars/main.yml.

```
container_path: /home/ec2-user/nodejs
container_name: cla_nodejs
image_name: clarusway/nodejs
```

- Go to the /home/ec2-user/ansible/roles/react/tasks/main.yml and copy the followings.

```yaml
    - name: copy files to the react node
      copy:
        src: react/
        dest: "{{ container_path }}"

    - name: remove {{ container_name }} container
      community.docker.docker_container:
        name: "{{ container_name }}"
        state: absent
        force_kill: true

    - name: remove "{{ image_name }}" image
      community.docker.docker_image:
        name: "{{ image_name }}"
        state: absent
  
    - name: build container image
      community.docker.docker_image:
        name: "{{ image_name }}"
        build:
          path: "{{ container_path }}"
        source: build
        state: present

    - name: Launch postgresql docker container
      community.docker.docker_container:
        name: "{{ container_name }}"
        image: "{{ image_name }}"
        state: started
        ports: 
        - "3000:3000"
      register: container_info
    
    - name: print the container info
      ansible.builtin.debug:
        var: container_info
```

- Copy /home/ec2-user/ansible-project/react folder to /home/ec2-user/ansible/roles/react/files.

- Copy these variables to /home/ec2-user/ansible/roles/react/vars/main.yml.

```
container_path: /home/ec2-user/react
container_name: cla_react
image_name: clarusway/react
```

- Update the ansible.cfg file. Add roles_path as below.

```cfg
roles_path=/home/ec2-user/ansible/roles
```

- Go to the /home/ec2-user/ansible/ and create a playbook.

```
cd /home/ec2-user/ansible/
nano play-role.yml
```

```yaml
- name: Docker install and configuration
  hosts: _development
  become: true
  roles: 
    - docker
- name: Postgre Database configuration
  hosts: _ansible_postgresql
  become: true
  roles:
    - postgre
- name: Nodejs server configuration
  hosts: _ansible_nodejs
  become: true
  roles:
    - nodejs
- name: React UI Server configuration
  hosts: _ansible_react
  become: true
  roles:
    - react
```

- Execute the follow.

```bash
ansible-playbook play-role.yml
```

## Part 7 - Using role from ansible-galaxy.

- Search for a docker role.

```bash
ansible-galaxy search docker --platform EL | grep geerl
```

- Change directory to ansible folder.

```bash
cd /home/ec2-user/ansible
```

- install the role.

```bash
ansible-galaxy install geerlingguy.docker
```

- Create a new play-newrole.yml

```yaml
- name: Docker install and configuration
  hosts: _development
  become: true
  roles: 
    - geerlingguy.docker
- name: Postgre Database configuration
  hosts: _ansible_postgresql
  become: true
  roles:
    - postgre
- name: Nodejs server configuration
  hosts: _ansible_nodejs
  become: true
  roles:
    - nodejs
- name: React UI Server configuration
  hosts: _ansible_react
  become: true
  roles:
    - react
```

- Execute the follow.

```bash
ansible-playbook play-newrole.yml
```