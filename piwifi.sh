#!/bin/bash

### VARIABLES
PROGRAM_NAME=PiWiFi
VERSION=0.2

### FUNCTIONS
helpmenu() {
  cat << _END_
Usage: ${PROGRAM_NAME} [-h]
   -h,  --help          display this help and exit
   -v,  --version       output version information and exit
   -i,  --install       install PiWiFi: trivial WiFi Access Point setup and configuration for the Raspberry Pi 3
   -b,  --backup	backup affected files
   -r,  --restore       restore affected files
   -ph, --pi-hole       switch domain name server to local Pi-Hole installation (see https://pi-hole.net/)
_END_
}

install() {
  echo "Installing ${PROGRAM_NAME}..."
  mustBeRoot
  $SUDO ./install.sh
}

show_version() {
  echo "${PROGRAM_NAME} ${VERSION}"
}

backup() {
  echo "Backing up files..."
  if [[ ! -e ./orig ]]; then
    mkdir ./orig
  fi
  yes | cp /etc/dhcp/dhcpd.conf ./orig/
  yes | cp /etc/default/isc-dhcp-server ./orig/
  yes | cp /etc/network/interfaces ./orig/
  yes | cp /etc/sysctl.conf ./orig/
}

restore() {
  echo "Restoring files..."
  mustBeRoot
  $SUDO yes | cp ./orig/dhcpd.conf /etc/dhcp/
  $SUDO yes | cp ./orig/isc-dhcp-server /etc/default/
  $SUDO yes | cp ./orig/interfaces /etc/network/
  $SUDO yes | cp ./orig/sysctl.conf /etc/
}

usePiHole() {
  echo "Switching Domain Name Server to local Pi-Hole installation (see https://pi-hole.net/)..."
  mustBeRoot
  $SUDO yes | cp ./dhcpd.pihole /etc/dhcp/dhcpd.conf
  echo "*********** Using Pi-Hole at 192.168.42.1 as Domain Name Server, reboot to complete install *******"
}

mustBeRoot() {
  ######## FIRST CHECK ########
  # Must  be root
  echo ":::"
  if [[ $EUID -eq 0 ]];then
    echo "::: You are root."
  else
    echo "::: sudo will be used for the install."
    # Check if it is actually installed
    # If it isn't, exit because the install cannot complete
    if [[ $(dpkg-query -s sudo) ]];then
        export SUDO="sudo"
        export SUDOE="sudo -E"
        export SUDOC="sudo sh -c"
    else
        echo "::: Please install sudo or run this as root."
        exit 1
    fi
fi
}

### SCRIPT
while [ ! $# -eq 0 ]
do
  case "$1" in
    --help | -h)
      helpmenu
      exit
      ;;
    --version | -v)
      show_version
      exit
      ;;
    --install | -i)
      install
      exit
      ;;
    --backup | -b)
      backup
      exit
      ;;
    --restore | -r)
      restore
      exit
      ;;
    --pi-hole | -ph)
      usePiHole
      exit
      ;;
  esac
  shift
done
