FROM ubuntu:resolute AS base
WORKDIR /usr/local/bin
ENV DEBIAN_FRONTEND=noninteractive
ENV USERNAME=mtkhawaja
ENV ANSIBLE_LOCALHOST_WARNING=False
RUN apt update && \
    apt upgrade -y && \
    apt install -y software-properties-common curl git build-essential sudo locales && \
    locale-gen en_US.UTF-8 && \
    apt-add-repository -y ppa:ansible/ansible && \
    apt update && \
    apt install -y curl git ansible build-essential && \
    apt clean autoclean && \
    apt autoremove --yes

# Mirror a real Ubuntu server: a UTF-8 locale and password-protected sudo (the
# default; passwordless sudo hid the sudo-rs become bug). The password is the
# username; this is a throwaway test image.
ENV LANG=en_US.UTF-8

FROM base AS setup
ARG TAGS
RUN useradd -m -s /bin/bash ${USERNAME}
RUN adduser ${USERNAME} sudo
RUN echo "${USERNAME}:${USERNAME}" | chpasswd
USER "${USERNAME}"
WORKDIR "/home/${USERNAME}"

FROM setup AS runnable
COPY . .
# Same become-password handoff as setup.sh; the file is removed in this layer.
RUN printf '%s' "${USERNAME}" > /tmp/become-pass && \
    (ansible-playbook --become-password-file /tmp/become-pass $TAGS local.yaml; rc=$?; rm -f /tmp/become-pass; exit $rc)
ENTRYPOINT ["/bin/zsh"]

