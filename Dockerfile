FROM ubuntu:jammy AS base
WORKDIR /usr/local/bin
ENV DEBIAN_FRONTEND=noninteractive
ENV USERNAME=mtkhawaja
ENV ANSIBLE_LOCALHOST_WARNING=False
RUN apt update && \
    apt upgrade -y && \
    apt install -y software-properties-common curl git build-essential sudo && \
    apt-add-repository -y ppa:ansible/ansible && \
    apt update && \
    apt install -y curl git ansible build-essential && \
    apt clean autoclean && \
    apt autoremove --yes

FROM base AS setup
ARG TAGS
RUN useradd -m ${USERNAME}
RUN adduser ${USERNAME} sudo
RUN echo "${USERNAME} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/sudoers
USER "${USERNAME}"
WORKDIR "/home/${USERNAME}"

FROM setup AS runnable
COPY . .
RUN sh -c "ansible-playbook $TAGS local.yaml"
ENTRYPOINT ["/bin/zsh"]

