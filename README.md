# dev-environment

## Try it out in a Docker container

```bash
#!/usr/bin/env bash

docker build -t mtkhawaja/dev-env:latest . && docker run -it --rm mtkhawaja/dev-env:latest

```

or for windows:

```powershell
#!/usr/bin/env pwsh

docker build -t mtkhawaja/dev-env:latest . ; if ($?) { docker run -it --rm mtkhawaja/dev-env:latest }\
```

## Setting up a new machine

Run the [convenience script](./setup.sh) below to install Ansible and run the playbook i.e.

```shell
#!/usr/bin/env bash

curl -s https://raw.githubusercontent.com/mtkhawaja/dev-environment/main/setup.sh | bash

```
or for windows:

```powershell

```


Alternatively, you can run the commands below manually:

```shell
#!/usr/bin/env bash

# Install Ansible

sudo apt update
sudo apt install -y software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install -y ansible

# Run the playbook

ansible-pull -U https://github.com/mtkhawaja/dev-environment.git -i localhost, local.yaml

```

## References

- [Developer Productivity](https://frontendmasters.com/courses/developer-productivity/introduction/)
- [dev-productivity](https://github.com/ThePrimeagen/dev-productivity)
- [Explain DEBIAN_FRONTEND apt-get variable for Ubuntu / Debian](https://www.cyberciti.biz/faq/explain-debian_frontend-apt-get-variable-for-ubuntu-debian)
- [Ansible Pull Arguments playbook.yml](https://docs.ansible.com/ansible/latest/cli/ansible-pull.html#cmdoption-ansible-pull-arg-playbook.yml)
- [Ansible Installation](https://docs.ansible.com/ansible/latest/installation_guide/installation_distros.html#installing-ansible-on-ubuntu)