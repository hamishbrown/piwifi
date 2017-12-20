#!/bin/bash
# PiWiFi: Trivial WiFi Access Point setup and configuration


######## VARIABLES #########

PROGRAM_NAME=piwifi
PIWIFI_NAME=PiWiFi
PIWIFI_SSID=PiWiFi
PIWIFI_wpa_passphrase=

tmpLog="/tmp/${PROGRAM_NAME}-install.log"
instalLogLoc="/etc/${PROGRAM_NAME}/install.log"

### PKG Vars ###
PKG_MANAGER="apt-get"
PKG_CACHE="/var/lib/apt/lists/"
UPDATE_PKG_CACHE="${PKG_MANAGER} update"
PKG_INSTALL="${PKG_MANAGER} --yes --no-install-recommends install"
PKG_COUNT="${PKG_MANAGER} -s -o Debug::NoLocking=true upgrade | grep -c ^Inst || true"
PIWIFI_DEPS=( hostapd isc-dhcp-server iptables-persistent grep wget expect whiptail )
###          ###


# Find the rows and columns. Will default to 80x24 if it can not be detected.
screen_size=$(stty size 2>/dev/null || echo 24 80)
rows=$(echo $screen_size | awk '{print $1}')
columns=$(echo $screen_size | awk '{print $2}')

# Divide by two so the dialogs take up half of the screen, which looks nice.
r=$(( rows / 2 ))
c=$(( columns / 2 ))
# Unless the screen is tiny
r=$(( r < 20 ? 20 : r ))
c=$(( c < 70 ? 70 : c ))



######## FIRST CHECK ########
# Must be root to install
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
    else
        echo "::: Please install sudo or run this as root."
        exit 1
    fi
fi

######## FUNCTIONS ########


welcomeDialogs() {
    # Display the welcome dialog
    whiptail --msgbox --backtitle "Welcome" --title "${PIWIFI_NAME} Automated Installer" "This installer will transform your Raspberry Pi 3 into a WiFi Access Point!" ${r} ${c}
}

endDialog() {
  whiptail --msgbox --backtitle "Install complete" --title "${PIWIFI_NAME} Automated Installer" "${PIWIFI_NAME} successfully installed! Your settings are as follows:

SSID :${PIWIFI_SSID}

Password :${PIWIFI_wpa_passphrase}

Please reboot your Pi to complete the installation." ${r} ${c}
}

update_package_cache() {
  #Running apt-get update/upgrade with minimal output can cause some issues with
  #requiring user input

  #Check to see if apt-get update has already been run today
  #it needs to have been run at least once on new installs!
  timestamp=$(stat -c %Y ${PKG_CACHE})
  timestampAsDate=$(date -d @"${timestamp}" "+%b %e")
  today=$(date "+%b %e")

  if [ ! "${today}" == "${timestampAsDate}" ]; then
    #update package lists
    echo ":::"
    echo -n "::: ${PKG_MANAGER} update has not been run today. Running now..."
    $SUDO ${UPDATE_PKG_CACHE} &> /dev/null
    echo " done!"
  fi
}

notify_package_updates_available() {
  # Let user know if they have outdated packages on their system and
  # advise them to run a package update at soonest possible.
  echo ":::"
  echo -n "::: Checking ${PKG_MANAGER} for upgraded packages...."
  updatesToInstall=$(eval "${PKG_COUNT}")
  echo " done!"
  echo ":::"
  if [[ ${updatesToInstall} -eq "0" ]]; then
    echo "::: Your system is up to date! Continuing with ${PIWIFI_NAME} installation..."
  else
    echo "::: There are ${updatesToInstall} updates available for your system!"
    echo "::: We recommend you update your OS after installing ${PIWIFI_NAME}! "
    echo ":::"
  fi
}

install_dependent_packages() {
  # Install packages passed in via argument array
  # No spinner - conflicts with set -e
  declare -a argArray1=("${!1}")

  echo iptables-persistent iptables-persistent/autosave_v4 boolean true | $SUDO debconf-set-selections
  echo iptables-persistent iptables-persistent/autosave_v6 boolean false | $SUDO debconf-set-selections

  if command -v debconf-apt-progress &> /dev/null; then
    $SUDO debconf-apt-progress -- ${PKG_INSTALL} "${argArray1[@]}"
  else
    for i in "${argArray1[@]}"; do
      echo -n ":::    Checking for $i..."
      $SUDO package_check_install "${i}" &> /dev/null
      echo " installed!"
    done
  fi
}

# PiWiFi specific
#################

update_dhcp_conf() {
  echo 'Configure DNS server, using:'
  cat ./dhcpd.piwifi
  if [[ ! -e ./orig ]]; then
    mkdir ./orig
  fi
  $SUDO yes | cp /etc/dhcp/dhcpd.conf ./orig/
  $SUDO yes | cp ./dhcpd.piwifi /etc/dhcp/dhcpd.conf
}

update_isc_dhcp_server() {
  echo 'update isc-dhcp-server:'
  $SUDO yes | cp /etc/default/isc-dhcp-server ./orig/
  $SUDO yes | cp ./isc-dhcp-server.piwifi /etc/default/isc-dhcp-server
  #$SUDO sed -i 's/INTERFACES=""/INTERFACES="wlan0"/' /etc/default/isc-dhcp-server
}

setup_static_ip() {
  echo 'setup_static_ip:'
  $SUDO ifdown wlan0
  $SUDO yes | cp  /etc/network/interfaces ./orig/
  $SUDO yes | cp ./interfaces.piwifi /etc/network/interfaces

  $SUDO ifconfig wlan0 192.168.42.1

  $SUDO yes | cp /etc/hostapd/hostapd.conf ./orig/

  sed -i "/PIWIFI_SSID/s/PIWIFI_SSID/$PIWIFI_SSID/" ./hostapd.conf
  sed -i "/PIWIFI_wpa_passphrase/s/PIWIFI_wpa_passphrase/$PIWIFI_wpa_passphrase/" ./hostapd.conf

  $SUDO yes | cp ./hostapd.conf /etc/hostapd/

  $SUDO sed -i '/^#DAEMON_CONF=""/s|#DAEMON_CONF=""|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd
  $SUDO sed -i '/^DAEMON_CONF=/s|DAEMON_CONF=|DAEMON_CONF=/etc/hostapd/hostapd.conf|' /etc/init.d/hostapd
}

configure_NAT() {
  echo 'configure_NAT:'
  $SUDO sed -i '/^#net.ipv4.ip_forward/s/#//g' /etc/sysctl.conf
    $SUDO iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
    $SUDO iptables -A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
    $SUDO iptables -A FORWARD -i wlan0 -o eth0 -j ACCEPT
    $SUDO sh -c "iptables-save > /etc/iptables/rules.v4"
  $SUDO systemctl daemon-reload
  $SUDO service hostapd start
  $SUDO service isc-dhcp-server start
  $SUDO update-rc.d hostapd enable
  $SUDO update-rc.d isc-dhcp-server enable
}


installPiWifi() {

  update_package_cache

  notify_package_updates_available

  install_dependent_packages PIWIFI_DEPS[@]

  # Configure DHCP
  update_dhcp_conf

  # Configure isc-dhcp-server
  update_isc_dhcp_server

  # set up static IP
  setup_static_ip

  # Configure Network Address Translation
  configure_NAT

  ifup wlan0
}

randpw(){ < /dev/urandom tr -dc A-Z-a-z-0-9 | head -c${1:-16};echo;}

welcomeDialogs

PIWIFI_wpa_passphrase=`randpw`
PIWIFI_SSID=$(whiptail --backtitle "Configure Wireless Access Point" --title "Network name" --inputbox "Enter your desired network name" ${r} ${c} "${PIWIFI_SSID}" 3>&1 1>&2 2>&3)
PIWIFI_wpa_passphrase=$(whiptail --backtitle "Configure Wireless Access Point" --title "Network password" --inputbox "Enter the network password" ${r} ${c} "${PIWIFI_wpa_passphrase}" 3>&1 1>&2 2>&3)

installPiWifi

endDialog

echo "*********** ${PIWIFI_NAME} installed, reboot to complete install *******"
