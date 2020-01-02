#!/bin/bash -ex
sudo apt-get update
sudo apt-get install -y python-minimal python-pip python-boto software-properties-common ntp unzip build-essential
sudo apt-add-repository --yes --update ppa:ansible/ansible
sudo apt-get install -y ansible
sudo apt-get install -y python3-pip
pip install boto boto3
git clone https://oakinogundeji:d1338d90e9f787cbf901b6207b09b3ba91e6c737@github.com/oakinogundeji/terraform_zdt /home/ubuntu/devops
ansible-playbook -c local /home/ubuntu/devops/install-nginx.yaml
