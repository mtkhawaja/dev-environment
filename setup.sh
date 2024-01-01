#!/usr/bin/env bash

sudo apt update
sudo apt install software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install ansible
ansible-pull -U https://github.com/mtkhawaja/dev-environment.git -i localhost, local.yaml