#!/bin/sh
# vim:noet:sw=4:ts=4
#    systemd2init - convert a systemd service file into init shell script
#    Copyright (C) 2014 Ondřej Surý <ondrej@sury.org>
#                       Lukáš Zapletal <lzap+git@redhat.com>
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

lsconf() {
    RET=
	aug_path="/files/lib/systemd/system//${SYSTEMD_SERVICE}${1}"
	[ -f "$SYSTEMD_SERVICE" ] && aug_path="/files$(pwd)//${SYSTEMD_SERVICE}${1}"
	augtool -r "$WORKINGDIR" -t "Systemd incl $(pwd)/$SYSTEMD_SERVICE" ls "$aug_path"
}

getconf() {
    RET=
	aug_path="/files/lib/systemd/system/${SYSTEMD_SERVICE}${1}"
	[ -f "$SYSTEMD_SERVICE" ] && aug_path="/files$(pwd)/${SYSTEMD_SERVICE}${1}"
	augtool -r "$WORKINGDIR" -t "Systemd incl $(pwd)/$SYSTEMD_SERVICE" get "$aug_path" | \
		sed -e "s;^${aug_path}[[:space:]]*\((none)\|(o)\|= \)[[:space:]]*;;"
}

getcommand() {
    echo "$(getconf $1/command)"
}

getvalue() {
    echo "$(getconf $1/value)"
}

getarg() {
    echo "$(getconf $1/arguments/$2)"
}

getargs() {
    RET=
    arg=0
    while arg=$(($arg+1)); do
	V=$(getarg $1 $arg)
	if [ -n "$V" ]; then
	    RET=" $V"
	else
	    break
	fi
    done
    [ -n "$RET" ] && echo $RET
}

getenvironment() {
    RET="$(lsconf $1 | sed -e 's/ = /=/g')"
    [ -n "$RET" ] && echo $RET
}

[ -z "$1" ] && echo "usage: $0 <name>" && exit 1

NAME=$1
SYSTEMD_SERVICE="${NAME}.service"

if [ -f /etc/redhat-release ]; then
	WORKINGDIR="$(pwd)"
	SKELETON=skeleton.redhat
	OUTPUT=$WORKINGDIR/${NAME}.init
	DEFAULT_PIDFILE="/var/run/\$NAME.pid"
else
	WORKINGDIR="$(pwd)/debian"
	SKELETON=skeleton.debian
	OUTPUT=$WORKINGDIR/${NAME}.init
	DEFAULT_PIDFILE="/run/\$NAME.pid"
fi

DESC="$(getvalue /Unit/Description)"
DAEMON="$(getcommand /Service/ExecStart)"
[ -z "$DAEMON" ] && DAEMON="/usr/sbin/\$NAME"
DAEMON_ARGS="$(getargs /Service/ExecStart)"
DAEMONIZE="$(getvalue /Service/X-Debian-Daemonize)"
[ -n "$DAEMONIZE" ] && DAEMON_ARGS="$DAEMONIZE $DAEMON_ARGS"
PIDFILE="$(getvalue /Service/PidFile)"
[ -z "$PIDFILE" ] && PIDFILE=$DEFAULT_PIDFILE
ENVIRONMENT="$(getenvironment /Service/Environment)"
ENVIRONMENTFILE="$(getvalue /Service/EnvironmentFile)"
[ -z "$ENVIRONMENTFILE" ] && ENVIRONMENTFILE="/etc/default/\$NAME"
RELOAD_SIGNAL="-1"
CASE_RESTART="restart"
CASE_RELOAD="reload|force-reload"
USAGE="{start|stop|restart|reload|force-reload}"

RELOAD_COMMAND="$(getcommand /Service/ExecReload)"
case "$RELOAD_COMMAND" in
    kill|/bin/kill)
	CUSTOM_RELOAD=false
	RELOAD_SIGNAL="$(getarg /Service/ExecReload 1)"
	;;
    "")
	CASE_RESTART="restart|force-reload"
	CASE_RELOAD="not-implemented"
	USAGE="{start|stop|status|restart|force-reload}"
    ;;
    *)
	CUSTOM_RELOAD=true
	RELOAD_ARGS="$(getargs /Service/ExecReload)"
	;;
esac

CUSTOM_STOP=false
STOP_COMMAND="$(getcommand /Service/ExecStop)"
case "$STOP_COMMAND" in
    "") ;;
    *)
	CUSTOM_STOP=true
	STOP_ARGS="$(getargs /Service/ExecStop)"
	;;
esac

STARTPRE="$(getcommand /Service/ExecStartPre)$(getargs /Service/ExecStartPre)"
STARTPOST="$(getcommand /Service/ExecStartPost)$(getargs /Service/ExecStartPost)"
STOPPRE="$(getcommand /Service/ExecStopPre)$(getargs /Service/ExecStopPre)"
STOPPOST="$(getcommand /Service/ExecStopPost)$(getargs /Service/ExecStopPost)"

sed -e "s^#NAME#^$NAME^g;" \
    -e "s^#DESC#^$DESC^g;" \
    -e "s^#DAEMON#^$DAEMON^g;" \
    -e "s^#DAEMON_ARGS#^$DAEMON_ARGS^g;" \
    -e "s^#PIDFILE#^$PIDFILE^g;" \
    -e "s^#ENVIRONMENT#^$ENVIRONMENT^g;" \
    -e "s^#ENVIRONMENTFILE#^$ENVIRONMENTFILE^g;" \
    -e "s^#CUSTOM_RELOAD#^$CUSTOM_RELOAD^g;" \
    -e "s^#RELOAD_SIGNAL#^$RELOAD_SIGNAL^g;" \
    -e "s^#RELOAD_COMMAND#^$RELOAD_COMMAND^g;" \
    -e "s^#RELOAD_ARGS#^$RELOAD_ARGS^g;" \
    -e "s^#CASE_RELOAD#^$CASE_RELOAD^g;" \
    -e "s^#CASE_RESTART#^$CASE_RESTART^g;" \
    -e "s^#USAGE#^$USAGE^g;" \
    -e "s^#STARTPRE#^$STARTPRE^g;" \
    -e "s^#STARTPOST#^$STARTPOST^g;" \
    -e "s^#STOPPRE#^$STOPPRE^g;" \
    -e "s^#STOPPOST#^$STOPPOST^g;" \
    -e "s^#CUSTOM_STOP#^$CUSTOM_STOP^g;" \
    -e "s^#STOP_COMMAND#^$STOP_COMMAND^g;" \
    -e "s^#STOP_ARGS#^$STOP_ARGS^g;" \
	< $SKELETON \
	> $OUTPUT
