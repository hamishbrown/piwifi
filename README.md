# PiWiFi

Trivial WiFi Access Point setup and configuration for the Raspberry Pi 3. Use Raspbian Jessie based distribution for best results.

# Easy install

```sh
sudo apt-get update
```
```sh
sudo apt-get upgrade
```
```sh
sudo apt-get install git
```
```sh
git clone https://github.com/hamishbrown/piwifi.git
```
```sh
cd piwifi
```
```sh
sudo ./install.sh
```

Enter a name for your new network.

A random password will be generated for your new network, you can change it to whatever you want, but you must enter a password. You can find the network name (ssid)  and network password (wpa_passphrase)
  post install in

```sh
/etc/hostapd/hostapd.conf
```

Finally
```sh
sudo reboot
```

For extra credit visit https://pi-hole.net/ and add an ad-blocker to your new network, select the wifi interface when installing Pi-Hole

Then
```sh
sudo ./piwifi.sh -ph
```
to use PiHole as the domain name server for your new network. Any connected devices will have a faster, more secure and ad-free online experience.

See 
```sh
./piwifi.sh --help
```
for all options
