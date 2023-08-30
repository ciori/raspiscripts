#!/usr/bin/bash

# Find current relative path of script
rel_path=$(echo $0 | sed 's|/.[^/]*/.[^/]*.sh$||;s|\./||')

# Import functions
. $rel_path/utils.sh
. $rel_path/utils_update.sh

# Create log directory if not exists and new log file
init_log init

sudo -E bash $rel_path/update/update_system.sh

# update and install initial packages

apt update -y && apt full-upgrade -y && autoremove -y
apt install -y vim tree gpg git --install-recommends

# ufw (allow ssh)

apt install -y ufw
ufw allow ssh
echo "y" | ufw enable
systemctl enable --now ufw

# fail2ban

apt install -y fail2ban

# wireguard

setup_wireguard () {
  apt install -y wireguard-tools openresolv
  backtitle="Raspiscripts"
  wg_address=$(dialog --clear --backtitle "$backtitle" --title "Wireguard Address" \
    --inputbox "Please type the Wireguard address for this peer [IP/Mask]:" 15 40 2>&1 >/dev/tty)
  wg_dns=$(dialog --clear --backtitle "$backtitle" --title "Wireguard DNS" \
    --inputbox "Please type the DNS server to use [IP]:" 15 40 2>&1 >/dev/tty)
  wg_privkey=$(dialog --clear --backtitle "$backtitle" --title "Wireguard Private Key" \
    --inputbox "Please type the private key for this peer:" 15 40 2>&1 >/dev/tty)
  wg_endpoint=$(dialog --clear --backtitle "$backtitle" --title "Wireguard Endpoint" \
    --inputbox "Please type the Wireguard server endpoint [IP or FQDN:PORT]:" 15 40 2>&1 >/dev/tty)
  wg_pubkey=$(dialog --clear --backtitle "$backtitle" --title "Wireguard Server Public Key" \
    --inputbox "Please type the public key of the server:" 15 40 2>&1 >/dev/tty)
  wg_allowed_ips=$(dialog --clear --backtitle "$backtitle" --title "Wireguard Server Public Key" \
    --inputbox "Please type the the allowed IPs [0.0.0.0/0 to route all traffic through the tunnel]:" 15 40 2>&1 >/dev/tty)
  cat <<EOF > temp-wg0.conf
[Interface]
Address = $wg_address
DNS = $wg_dns
PrivateKey = $wg_privkey
[Peer]
AllowedIPs = $wg_allowed_ips
Endpoint = $wg_endpoint
PersistentKeepalive = 25
PublicKey = $wg_pubkey
EOF
  mv temp-wg0.conf /etc/wireguard/wg0.conf
  systemctl enable --now wg-quick@wg0
}

dialog --clear --backtitle "Raspiscripts" --title "Wireguard Configuration" \
  --yesno "Do you want to configure Wireguard access to this machine? (You need to have a Wireguard server already configured)" \
  15 40
wg_choice=$?
clear
if [ "$wg_choice" -eq 0 ]; then
  setup_wireguard
else
  echo "Wireguard will NOT be configured"
fi

# nginx

apt install -y nginx
openssl req -x509 -nodes -newkey rsa:4096 -keyout /etc/ssl/private/nginx-selfsigned.key -out /etc/ssl/certs/nginx-selfsigned.crt -subj "/CN=localhost" -days 3650
mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
cat <<EOF > temp-nginx.conf
user www-data;
worker_processes 1;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
  worker_connections 768;
}

stream {
  ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;
  ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;
  ssl_session_cache shared:SSL:1m;
  ssl_session_timeout 4h;
  ssl_protocols TLSv1.2 TLSv1.3;
  ssl_prefer_server_ciphers on;

  include /etc/nginx/streams-enabled/*.conf;

}
EOF
mv temp-nginx.conf /etc/nginx/nginx.conf
rm -rf temp-nginx.conf
mkdir /etc/nginx/streams-enabled

# tor

apt install -y tor
mv /etc/tor/torrc /etc/tor/torrc.bak
cat <<EOF > /etc/tor/torrc
ControlPort 9051
CookieAuthentication 1
CookieAuthFileGroupReadable 1
EOF
systemctl restart tor

# nodejs

curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
apt install nodejs -y

# rust

apt install -y cargo clang cmake