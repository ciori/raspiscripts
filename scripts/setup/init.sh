#!/usr/bin/bash

# Initialize the system with all the necessary parts

# update and install initial packages
sudo apt update -y && sudo apt full-upgrade -y && sudo autoremove -y
sudo apt install -y vim tree curl wget gpg git --install-recommends

# ufw (allow ssh)
sudo apt install -y ufw
sudo ufw allow ssh
sudo ufw enable
sudo systemctl enable --now ufw
# ...

# fail2ban
sudo apt install -y fail2ban

# wireguard
setup_wireguard () {
  sudo apt install -y wireguard-tools openresolv
  read -p "Type the Wireguard address for this peer [IP/Mask]: " wg_address
  read -p "Type the DNS server to use [IP]: " wg_dns
  read -p "Type the private key for this peer: " wg_privkey
  read -p "Type the Wireguard server endpoint [IP or FQDN:PORT]: " wg_endpoint
  read -p "Type the public key of the server: " wg_pubkey
  while true; do
    read -p "Do you want to route all the outgoing traffic through the tunnel (y/n)? " wg_ai_choice
    case $wg_ai_choice in
      [Yy]* ) wg_allowed_ips="0.0.0.0/0"; break;;
      [Nn]* ) read -p "Type the Wireguard allowed IPs [IP/Mask]: " wg_allowed_ips; break;;
      * ) echo "Please answer yes or no.";;
    esac
  done
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
  sudo mv temp-wg0.conf /etc/wireguard/wg0.conf
  systemctl enable --now wg-quick@wg0
}
echo "Do you want to configure Wireguard access to this machine?"
echo "(You need to have a Wireguard server already configured)"
while true; do
  read -p "Setup Wireguard (y/n)? " wg_choice
  case $wg_choice in
    [Yy]* ) setup_wireguard; break;;
    [Nn]* ) exit;;
    * ) echo "Please answer yes or no.";;
  esac
done

# nginx
sudo apt install -y nginx
sudo openssl req -x509 -nodes -newkey rsa:4096 -keyout /etc/ssl/private/nginx-selfsigned.key -out /etc/ssl/certs/nginx-selfsigned.crt -subj "/CN=localhost" -days 3650`
sudo mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak`
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
sudo mv temp-nginx.conf /etc/nginx/nginx.conf
rm -rf temp-nginx.conf
sudo mkdir /etc/nginx/streams-enabled`

# tor
sudo apt install -y tor`
echo "ControlPort 9051" | sudo tee -a /etc/tor/torrc
echo "CookieAuthentication 1" | sudo tee -a /etc/tor/torrc
echo "CookieAuthFileGroupReadable 1" | sudo tee -a /etc/tor/torrc
systemctl restart tor

# nodejs
curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
sudo apt install nodejs -y

# rust
sudo apt install -y cargo clang cmake