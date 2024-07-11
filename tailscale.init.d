#! /bin/sh

### BEGIN INIT INFO
# Provides:		tailscale tailscaled
# Required-Start:	$remote_fs $syslog
# Required-Stop:	$remote_fs $syslog
# Default-Start:	2 3 4 5
# Default-Stop:		
# Short-Description:	tailscaled server
### END INIT INFO

set -e

# /etc/init.d/tailscale: start and stop the tailscale daemon

test -x /usr/sbin/tailscaled || exit 0

umask 022

if test -f /etc/default/tailscaled; then
    . /etc/default/tailscaled
fi

. /lib/lsb/init-functions

[ -n "$2" ] && TAILSCALED_OPTS="$TAILSCALED_OPTS $2"

# Are we running from init?
run_by_init() {
    ([ "$previous" ] && [ "$runlevel" ]) || [ "$runlevel" = S ]
}

#/usr/sbin/tailscaled $TAILSCALED_OPTS || exit 1

export PATH="${PATH:+$PATH:}/usr/sbin:/sbin"

case "$1" in
  start)
	log_daemon_msg "Starting Tailscale server" "tailscaled" || true
	# shellcheck disable=SC2086
	if start-stop-daemon --start --background --quiet --oknodo --chuid 0:0 --pidfile /run/tailscaled.pid --make-pidfile --startas /usr/sbin/tailscaled -- $TAILSCALED_OPTS > /var/log/tail.log; then
	    log_end_msg 0 || true
	else
	    log_end_msg 1 || true
	fi
	;;
  stop)
	log_daemon_msg "Stopping Tailscale server" "tailscaled" || true
	if start-stop-daemon --stop --quiet --oknodo --retry 10 --pidfile /run/tailscaled.pid --exec /usr/sbin/tailscaled; then
	    log_end_msg 0 || true
	else
	    log_end_msg 1 || true
	fi
	;;
  restart)
	log_daemon_msg "Restarting Tailscale server" "tailscaled" || true
	start-stop-daemon --stop --quiet --oknodo --retry 30 --pidfile /run/tailscaled.pid --exec /usr/sbin/tailscaled
	# shellcheck disable=SC2086
	if start-stop-daemon --start --background --quiet --oknodo --chuid 0:0 --pidfile /run/tailscaled.pid --make-pidfile --startas /usr/sbin/tailscaled -- $TAILSCALED_OPTS > /var/log/tail.log; then
	    log_end_msg 0 || true
	else
	    log_end_msg 1 || true
	fi
	;;
  status)
	status_of_proc -p /run/tailscaled.pid /usr/sbin/tailscaled tailscaled && exit 0 || exit $?
	;;
  *)
	log_action_msg "Usage: /etc/init.d/tailscale {start|stop|reload|force-reload|restart|try-restart|status}" || true
	exit 1
esac

exit 0
