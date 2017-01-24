#!/bin/sh

MYUSER="avahi"
MYGID="111"
MYUID="106"

AutoUpgrade(){
  if [ -e /etc/alpine-release ]; then
    /sbin/apk --no-cache upgrade
    /bin/rm -rf /var/cache/apk/*
  elif [ -e /etc/os-release ]; then
    if /bin/grep -q "NAME=\"Ubuntu\"" /etc/os-release ; then 
      export DEBIAN_FRONTEND=noninteractive
      /usr/bin/apt-get update
      /usr/bin/apt-get -y --no-install-recommends dist-upgrade
      /usr/bin/apt-get -y autoclean
      /usr/bin/apt-get -y clean 
      /usr/bin/apt-get -y autoremove
      /bin/rm -rf /var/lib/apt/lists/*
    fi
  fi
}

ConfigureUser () {
  # Managing user
  if [ -n "${DOCKUID}" ]; then
    MYUID="${DOCKUID}"
  fi
  # Managing group
  if [ -n "${DOCKGID}" ]; then
    MYGID="${DOCKGID}"
  fi
  local OLDHOME="/home/${MYUSER}"
  local OLDGID
  local OLDUID
  /bin/grep -q "${MYUSER}" /etc/passwd
  if [ $? -eq 0 ]; then
    OLDUID=$(/usr/bin/id -u "${MYUSER}")
    OLDGID=$(/usr/bin/id -g "${MYUSER}")
    if [ "${DOCKUID}" != "${OLDUID}" ]; then
      OLDHOME=$(cd ~${MYUSER} && pwd)
      /usr/sbin/deluser "${MYUSER}"
      /usr/bin/logger "Deleted user ${MYUSER}"
    fi
    /bin/grep -q "${MYUSER}" /etc/group
    if [ $? -eq 0 ]; then
      local OLDGID=$(/usr/bin/id -g "${MYUSER}")
      if [ "${DOCKGID}" != "${OLDGID}" ]; then
        /usr/sbin/delgroup "${MYUSER}"
        /usr/bin/logger "Deleted group ${MYUSER}"
      fi
    fi
  fi
  /usr/sbin/addgroup --system --gid "${MYGID}" "${MYUSER}"
  /usr/sbin/adduser --system --shell /sbin/nologin --gid "${MYGID}" --home "${OLDHOME}" --uid "${MYUID}" "${MYUSER}"
  if [ -n "${OLDUID}" ] && [ "${DOCKUID}" != "${OLDUID}" ]; then
    /usr/bin/find / -user "${OLDUID}" -exec /bin/chown ${MYUSER} {} \;
  fi
  if [ -n "${OLDGID}" ] && [ "${DOCKGID}" != "${OLDGID}" ]; then
    /usr/bin/find / -group "${OLDGID}" -exec /bin/chgrp ${MYUSER} {} \;
  fi
}

AutoUpgrade
ConfigureUser

if [ "$1" = 'avahi' ]; then
  until [ -e /var/run/dbus/system_bus_socket ]; do
    /usr/bin/logger  "dbus-daemon is not running on hosting server..."
    sleep 1s
  done
  exec avahi-daemon --no-chroot
fi

exec "$@"
