#!/usr/bin/env bash
# End-to-end test under real systemd: Ubuntu 26.04, headless, password-protected
# sudo (like a real server). Runs local.yaml twice, then ssh-server.yaml and
# tailscale.yaml, then checks the units they manage. Used by CI; runs locally
# too (native arch; needs Docker with privileged containers).
set -euo pipefail
cd "$(dirname "$0")/../.."

docker build --target setup -t dev-env:setup .
docker build -t dev-env:systemd - <<'EOF'
FROM dev-env:setup
USER root
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y systemd systemd-sysv && apt-get clean
STOPSIGNAL SIGRTMIN+3
ENTRYPOINT ["/sbin/init"]
EOF

cid=$(docker run -d --privileged --cgroupns=host -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
  --tmpfs /run --tmpfs /run/lock -v "$PWD":/repo:ro dev-env:systemd)
trap 'docker container rm -f "$cid" >/dev/null' EXIT
for _ in $(seq 1 30); do docker exec "$cid" test -d /run/systemd/system && break; sleep 2; done

# Run as the unprivileged user, in /repo, with the test sudo password on file.
run() { docker exec -u mtkhawaja -w /repo -e ANSIBLE_LOCAL_TEMP=/tmp/ansible "$cid" bash -lc "$1"; }
run 'umask 077 && printf %s mtkhawaja > ~/.become-pass'
PB='ansible-playbook -i localhost, --become-password-file ~/.become-pass'

echo "::group::local.yaml (headless), first run";  run "$PB -e headless=true local.yaml";  echo "::endgroup::"
# The second run must be a no-op: a task that reports "changed" on every run is a
# bug (non-idempotent), so fail and name the offenders.
echo "::group::local.yaml (headless), second run (must be changed=0)"
second="$(run "$PB -e headless=true local.yaml")"
echo "$second"
echo "::endgroup::"
if ! grep -qE '^localhost +: .*changed=0 ' <<<"$second"; then
  echo "FAIL: the second run changed something (not idempotent):"
  grep -B3 -E '^changed:' <<<"$second" | grep -E '^TASK' || true
  exit 1
fi
echo "ok: second run is idempotent (changed=0)"

echo "::group::ssh-server.yaml"
run 'ssh-keygen -q -t ed25519 -N "" -f ~/.ssh/ci_key'
run "$PB -e \"ssh_authorized_keys='\$(cat ~/.ssh/ci_key.pub)'\" ssh-server.yaml"
echo "::endgroup::"

echo "::group::tailscale.yaml (no auth key)"; run "$PB tailscale.yaml"; echo "::endgroup::"

echo "::group::checks"
# shellcheck disable=SC2016  # expands inside the container, not here
run 'set -e
  [ "$(systemctl is-active ssh.socket)" = active ]          && echo "ok: ssh.socket active"
  ssh -o BatchMode=yes -o StrictHostKeyChecking=no -i ~/.ssh/ci_key localhost true && echo "ok: key login works"
  out=$(ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o IdentitiesOnly=yes -o IdentityFile=/dev/null localhost true 2>&1 || true)
  case "$out" in *"Permission denied (publickey)."*) echo "ok: only public-key auth offered";; *) echo "FAIL: $out"; exit 1;; esac
  [ "$(systemctl is-active tailscaled)" = active ]          && echo "ok: tailscaled active"
  [ "$(systemctl is-enabled apt-daily-upgrade.timer)" = enabled ] && echo "ok: apt-daily-upgrade.timer enabled"
  lid=$(busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager HandleLidSwitch)
  [ "$lid" = "s \"ignore\"" ] && echo "ok: logind ignores the lid switch"'
echo "::endgroup::"
