#!/usr/bin/env bash

sudo apt update
sudo apt install -y software-properties-common -y
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install -y ansible
ansible-pull -U https://github.com/mtkhawaja/dev-environment.git -i localhost, local.yaml
