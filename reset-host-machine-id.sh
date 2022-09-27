#!/bin/bash

if [ $(id -u) -ne "0" ]; then
	echo "WARNING: This script requires root access!"
	exit 1
fi

TRIGGER_FILE="/RESET-HOST-MACHINE-ID"
SCRIPT_PATH="/usr/local/sbin/reset-host-machine-id.sh"
SERVICE_NAME="reset-host-machine-id.service"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}"

SCRIPT=$( readlink -m $( type -p "${0}" ))

install_serv() {
	if [ "${SCRIPT_PATH}" != "${SCRIPT}" ]; then
		cp "${SCRIPT}" "${SCRIPT_PATH}"
		rm -rf "${SCRIPT}"
		chown root:root "${SCRIPT_PATH}"
		chmod 0700 "${SCRIPT_PATH}"
	fi
	echo "[Unit]
Description=Reset hostname and machine ID on system start if required
Wants=basic.target
After=basic.target dbus-org.freedesktop.hostname1.service systemd-hostnamed.service

[Service]
Type=notify
ExecStart=${SCRIPT_PATH}

[Install]
WantedBy=multi-user.target" > "${SERVICE_PATH}"
	systemctl daemon-reload
	systemctl enable "${SERVICE_NAME}"
	if [ "${1}" = "prep" ]; then
		touch "${TRIGGER_FILE}"
		poweroff
	fi
}

if [ "${1}" = "install" -o "${1}" = "prep" ]; then
	install_serv "${1}"
	exit 0
fi

if [ -f "${TRIGGER_FILE}" ]; then
	rm -rf "${TRIGGER_FILE}"
	rm -rf /etc/ssh/ssh_host_* /etc/sysconfig/rhn/systemid /etc/machine-id /var/lib/dbus/machine-id /etc/venv-salt-minion/pki/minion/* /etc/venv-salt-minion/minion_id 2> /dev/null
	dbus-uuidgen --ensure
	systemd-machine-id-setup
	systemctl disable reset-host-machine-id.service
	rm -rf "${SERVICE_PATH}" "${SCRIPT_PATH}"
	systemctl daemon-reload
	reboot
fi
