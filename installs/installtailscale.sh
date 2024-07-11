#!/bin/bash

tmp1=/tmp/tail.tmp

cleanup () {
     #  Delete temporary files, then optionally exit given status.
     local status=${1:-'0'}
     rm -f $tmp1
     [ $status = '-1' ] ||  exit $status      #  thus -1 prevents exit.
} #--------------------------------------------------------------------
warn () {
     #  Message with basename to stderr.          Usage: warn "message"
     echo -e "\n !!  ${program}: $1 "  >&2
} #--------------------------------------------------------------------
die () {
     #  Exit with status of most recent command or custom status, after
     #  cleanup and warn.      Usage: command || die "message" [status]
     local status=${2:-"$?"}
     cleanup -1  &&   warn "$1"  &&  exit $status
} #--------------------------------------------------------------------
trap "die 'SIG disruption, but cleanup finished.' 114" 1 2 3 15
#    Cleanup after INTERRUPT: 1=SIGHUP, 2=SIGINT, 3=SIGQUIT, 15=SIGTERM


[ "$(whoami)" == "root" ] || die "Must be run as sudo"

sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.tailscale-keyring.list | tee /etc/apt/sources.list.d/tailscale.list
apt-get update
apt-get -y install net-tools tailscale
#tailscale up
cat > /etc/sudoers.d/tailscaled <<EOF
%sudo ALL=NOPASSWD: /usr/sbin/tailscaled
%sudo ALL=NOPASSWD: /sbin/ifconfig
EOF
dir=$(dirname -- "$( readlink -f -- "$0"; )"; )
cp ${dir}/tailscale.init.d /etc/init.d/tailscale
chmod 755 /etc/init.d/tailscale


echo ""
echo ""
echo "/etc/wsl.conf should contain"
echo "[boot]"
echo command="\"/sbin/ifconfig eth0 mtu 1500; service ssh start; service tailscale start\""
echo ""
echo ""
echo "To start tailscale:"
echo "service tailscale start"
echo "To make initial login"
echo "tailscale up"
echo ""
