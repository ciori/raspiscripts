#!/usr/bin/bash

# Initialize the system with all the necessary parts

# update and install initial packages
apt update -y && apt full-upgrade -y && autoremove -y
apt install -y vim tree gpg git --install-recommends

# ufw (allow ssh)
apt install -y ufw
ufw allow ssh
ufw enable
systemctl enable --now ufw

# fail2ban
apt install -y fail2ban

# wireguard
setup_wireguard () {
  apt install -y wireguard-tools openresolv
  read -p "Type the Wireguard address for this peer [IP/Mask]: " wg_address
  read -p "Type the DNS server to use [IP]: " wg_dns
  read -p "Type the private key for this peer: " wg_privkey
  read -p "Type the Wireguard server endpoint [IP or FQDN:PORT]: " wg_endpoint
  read -p "Type the public key of the server: " wg_pubkey
  read -p "Do you want to route all outgoing traffic through the tunnel (y/n)? " wg_ai_choice
  case $wg_ai_choice in
    [Nn]* ) read -p "Type the Wireguard allowed IPs [IP/Mask]: " wg_allowed_ips; break;;
    * ) wg_allowed_ips="0.0.0.0/0"; break;;
  esac
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
echo "Do you want to configure Wireguard access to this machine?"
echo "(You need to have a Wireguard server already configured)"
read -p "Setup Wireguard (y/n)? " wg_choice
case $wg_choice in
  [Nn]* ) echo "Wireguard will NOT be configured"; break;;
  * ) setup_wireguard; break;;
esac

# nginx
apt install -y nginx
openssl req -x509 -nodes -newkey rsa:4096 -keyout /etc/ssl/private/nginx-selfsigned.key -out /etc/ssl/certs/nginx-selfsigned.crt -subj "/CN=localhost" -days 3650`
mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak`
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
mkdir /etc/nginx/streams-enabled`

# tor
apt install -y tor`
echo "ControlPort 9051" | tee -a /etc/tor/torrc
echo "CookieAuthentication 1" | tee -a /etc/tor/torrc
echo "CookieAuthFileGroupReadable 1" | tee -a /etc/tor/torrc
systemctl restart tor

# nodejs
curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
apt install nodejs -y

# rust
apt install -y cargo clang cmake