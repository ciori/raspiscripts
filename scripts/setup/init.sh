#!/usr/bin/bash

LOG=$1
SCRIPTS_DIR=$2
HEIGHT=$3
WIDTH=$4

if [ ! -f $LOG ]; then
  echo $(error)"Log file $LOG does not exists"
  exit 1
fi

. $SCRIPTS_DIR/utils.sh

echo $(info)"Starting System Initialization" >> $LOG

GPG_OK=false
GIT_OK=false
UFW_OK=false
UFW_SETUP_OK=false
FAIL2BAN_OK=false
NGINX_OK=false
NGINX_CERTIFICATE_OK=false
NGINX_CONF_OK=false
NGINX_DIR_CREATION_OK=false
NGINX_SETUP_OK=false
TOR_OK=false
TOR_CONF_OK=false
DATA_DIR_OK=false
MESSAGE=""

# gpg installation
if [[ $(sudo gpg --version 2>&1 | grep "command not found") == "" ]]; then
  GPG_OK=true
  MESSAGE="gpg is already installed"
  echo $(info)"gpg is already installed" >> $LOG
else
  echo $(info)"Installing gpg" >> $LOG
  echo $(info)"sudo apt install gpg --y output:" >> $LOG
  sudo apt install gpg -y &>> $LOG
  echo "" >> $LOG

  if [[ $(sudo gpg --version 2>&1 | grep "command not found") == "" ]]; then
    GPG_OK=true
    MESSAGE="gpg installation successfull"
    echo $(info)"gpg installation successfull" >> $LOG
  else
    MESSAGE="gpg installation failure"
    echo $(info)"gpg installation failure" >> $LOG
  fi
fi

# git installation
if [[ $(sudo git --version 2>&1 | grep "command not found") == "" ]]; then
  GIT_OK=true
  MESSAGE=$MESSAGE"\ngit is already installed"
  echo $(info)"git is already installed" >> $LOG
else
  echo $(info)"Installing git" >> $LOG
  echo $(info)"sudo apt install git --install-recommends -y output:" >> $LOG
  sudo apt install git --install-recommends -y &>> $LOG
  echo "" >> $LOG

  if [[ $(sudo git --version 2>&1 | grep "command not found") == "" ]]; then
    GIT_OK=true
    MESSAGE=$MESSAGE"\ngit installation successfull"
    echo $(info)"git installation successfull" >> $LOG
  else
    MESSAGE=$MESSAGE"\ngit installation failure"
    echo $(info)"git installation failure" >> $LOG
  fi
fi

# ufw installation
if [[ $(sudo ufw --version 2>&1 | grep "command not found") == "" ]]; then
  UFW_OK=true
  MESSAGE=$MESSAGE"\nufw is already installed"
  echo $(info)"ufw is already installed" >> $LOG
else
  echo $(info)"Installing ufw" >> $LOG
  echo $(info)"sudo apt install ufw -y output:" >> $LOG
  sudo apt install ufw -y &>> $LOG
  echo "" >> $LOG

  if [[ $(sudo ufw --version 2>&1 | grep "command not found") == "" ]]; then
    UFW_OK=true
    MESSAGE=$MESSAGE"\nufw installation successfull"
    echo $(info)"ufw installation successfull" &>> $LOG
  else
    MESSAGE=$MESSAGE"\nufw installation failure"
    echo $(info)"ufw installation failure" >> $LOG
  fi
fi

# ufw configuration
if $UFW_OK; then
  echo $(info)"Configuring ufw" &>> $LOG
  sudo ufw default deny incoming &>> $LOG
  sudo ufw default allow outgoing &>> $LOG
  sudo ufw allow ssh &>> $LOG
  sudo ufw logging off &>> $LOG
  echo "y" | sudo ufw enable &>> $LOG
  sudo systemctl enable ufw &>> $LOG
  if [[ $(sudo ufw status 2>&1 | grep "Status: active") != "" ]] && [[ $(sudo systemctl is-enabled ufw.service 2>&1 | grep "enabled") != "" ]]; then
    UFW_SETUP_OK=true
    MESSAGE=$MESSAGE"\nufw configuration successfull"
    echo $(info)"ufw configuration successfull" >> $LOG
  else
    MESSAGE=$MESSAGE"\nufw configuration failure"
    echo $(error)"ufw configuration failure" >> $LOG
  fi
fi

# fail2ban installation
if [[ $(sudo systemctl is-enabled fail2ban.service 2>&1 | grep "enabled") != "" ]]; then
  FAIL2BAN_OK=true
  MESSAGE=$MESSAGE"\nfail2ban is already installed"
  echo $(info)"fail2ban is already installed" >> $LOG
else
  echo $(info)"Installing fail2ban" >> $LOG
  echo $(info)"sudo apt install fail2ban -y output:" >> $LOG
  sudo apt install fail2ban -y &>> $LOG
  echo "" >> $LOG

  if [[ $(sudo systemctl is-enabled fail2ban.service 2>&1 | grep "enabled") != "" ]]; then
    FAIL2BAN_OK=true
    MESSAGE=$MESSAGE"\nfail2ban installation successfull"
    echo $(info)"fail2ban installation successfull" >> $LOG
  else
    MESSAGE=$MESSAGE"\nfail2ban installation failure"
    echo $(info)"fail2ban installation failure" >> $LOG
  fi
fi

# nginx installation
if [[ $(sudo systemctl is-enabled nginx.service 2>&1 | grep "enabled") != "" ]]; then
  NGINX_OK=true
  MESSAGE=$MESSAGE"\nnginx is already installed"
  echo $(info)"nginx is already installed" >> $LOG
else
  echo $(info)"Installing nginx" >> $LOG
  echo $(info)"sudo apt install nginx -y output:" >> $LOG
  sudo apt install nginx -y &>> $LOG
  echo "" >> $LOG

  if [[ $(sudo systemctl is-enabled nginx.service 2>&1 | grep "enabled") != "" ]]; then
    NGINX_OK=true
    MESSAGE=$MESSAGE"\nnginx installation successfull"
    echo $(info)"nginx installation successfull" >> $LOG
  else
    MESSAGE=$MESSAGE"\nnginx installation failure"
    echo $(info)"nginx installation failure" >> $LOG
  fi
fi

if $NGINX_OK; then

  # nginx certificate creation
  if sudo test -f /etc/ssl/private/nginx-selfsigned.key && sudo test -f /etc/ssl/certs/nginx-selfsigned.crt; then
    NGINX_CERTIFICATE_OK=true
    echo $(info)"nginx self-signed certificate already exists" >> $LOG
  else
    echo $(info)"creating nginx self-signed certificate" >> $LOG
    sudo openssl req -x509 -nodes -newkey rsa:4096 -keyout /etc/ssl/private/nginx-selfsigned.key -out /etc/ssl/certs/nginx-selfsigned.crt -subj "/CN=localhost" -days 3650 &>> $LOG
  
    if sudo test -f /etc/ssl/private/nginx-selfsigned.key && sudo test -f /etc/ssl/certs/nginx-selfsigned.crt; then
      NGINX_CERTIFICATE_OK=true
      echo $(info)"nginx self-signed certificate creation successfull" >> $LOG
    else
      echo $(error)"nginx self-signed certificate creation failure" >> $LOG
    fi
  fi

  # nginx configuration
  sudo mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak &>> $LOG

  sudo cat > temp-nginx.conf <<EOF
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
  sudo rm -rf temp-nginx.conf

  curr_date=$(date +%s)
  conf_file_last_modified_date=$(stat -c %Y /etc/nginx/nginx.conf)
  seconds_since_last_modified_date=$(($curr_date - $conf_file_last_modified_date))
  
  if [[ $seconds_since_last_modified_date -lt 5 ]]; then
    NGINX_CONF_OK=true
    echo $(info)"nginx conf file write successfull" >> $LOG
  else
    echo $(error)"nginx conf file write failure" >> $LOG
  fi

  # /etc/nginx/streams-enabled directory creation
  if sudo test -d "/etc/nginx/streams-enabled"; then
    NGINX_DIR_CREATION_OK=true
    MESSAGE=$MESSAGE"\n/etc/nginx/streams-enabled directory already exists"
    echo $(info)"/etc/nginx/streams-enabled directory already exists" >> $LOG
  else
    echo $(info)"Creating /etc/nginx/streams-enabled directory" >> $LOG
    sudo mkdir -p /etc/nginx/streams-enabled
    if sudo test -d "/etc/nginx/streams-enabled"; then
      NGINX_DIR_CREATION_OK=true
      echo $(info)"/etc/nginx/streams-enabled directory created" >> $LOG
    else
      echo $(info)"impossible to create /etc/nginx/streams-enabled directory" >> $LOG
    fi
  fi

  if $NGINX_CERTIFICATE_OK && $NGINX_CONF_OK && $NGINX_DIR_CREATION_OK; then
    NGINX_SETUP_OK=true
    MESSAGE=$MESSAGE"\nnginx configuration successfull"
    echo $(info)"nginx configuration successfull" >> $LOG
  else
    MESSAGE=$MESSAGE"\nnginx configuration failure"
    echo $(error)"nginx configuration failure" >> $LOG
  fi
fi

# tor installation
if [[ $(sudo tor --version 2>&1 | grep "command not found") == "" ]]; then
  TOR_OK=true
  MESSAGE=$MESSAGE"\ntor is already installed"
  echo $(info)"tor is already installed" >> $LOG
else
  echo $(info)"Installing apt-transport-https" >> $LOG
  echo $(info)"sudo apt install apt-transport-https -y output:" >> $LOG
  sudo apt install apt-transport-https -y &>> $LOG
  echo "" >> $LOG

  echo $(info)"Adding torproject repositories to apt sources" >> $LOG
  sudo cat > temp-tor.list <<EOF
deb     [arch=amd64 signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org bullseye main
deb-src [arch=amd64 signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org bullseye main
EOF

  sudo mv temp-tor.list /etc/apt/sources.list.d/tor.list
  sudo rm -rf temp-tor.list
  
  echo $(info)"Importing tor signing key as root user" >> $LOG
  sudo su -c "wget -qO- https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc | gpg --dearmor | tee /usr/share/keyrings/tor-archive-keyring.gpg >/dev/null"

  echo $(info)"sudo apt update -y output:" >> $LOG
  sudo apt update -y &>> $LOG
  echo "" >> $LOG
  
  echo $(info)"sudo apt install tor deb.torproject.org-keyring -y output:" >> $LOG
  sudo apt install tor deb.torproject.org-keyring -y &>> $LOG
  echo "" >> $LOG

  if [[ $(sudo tor --version 2>&1 | grep "command not found") == "" ]]; then
    TOR_OK=true
    MESSAGE=$MESSAGE"\ntor installation successfull"
    echo $(info)"tor installation successfull" >> $LOG
  else
    MESSAGE=$MESSAGE"\ntor installation failure"
    echo $(info)"tor installation failure" >> $LOG
  fi
fi

if $TOR_OK; then
  # tor configuration
  if grep -q '^ControlPort' /etc/tor/torrc && grep -q '^CookieAuthentication' /etc/tor/torrc && grep -q '^CookieAuthFileGroupReadable' /etc/tor/torrc && [[ $(sudo ss -tulpn | grep tor | grep LISTEN | wc -l) == 2 ]]; then
    TOR_SETUP_OK=true
    echo $(info)"tor configuration already configured as expected" >> $LOG
    MESSAGE=$MESSAGE"\ntor configuration already configured as expected"
  else
    echo $(info)"modifying tor configuration" >> $LOG
    sudo cp /etc/tor/torrc /etc/tor/torrc.bak
    
    sudo sed -e '/^#ControlPort [0-9]*$/ s/^#//' /etc/tor/torrc.bak | sed -e '/^#CookieAuthentication 1$/ s/^#//' | sed '/^CookieAuthentication 1$/ a CookieAuthFileGroupReadable 1' >> temp-torrc
    
    sudo mv temp-torrc /etc/tor/torrc
    sudo rm -rf temp-torrc

    sudo systemctl reload tor
    
    if grep -q '^ControlPort' /etc/tor/torrc && grep -q '^CookieAuthentication' /etc/tor/torrc && grep -q '^CookieAuthFileGroupReadable' /etc/tor/torrc && [[ $(sudo ss -tulpn | grep tor | grep LISTEN | wc -l) == 2 ]]; then
      TOR_SETUP_OK=true
      MESSAGE=$MESSAGE"\ntor configuration successfull"
      echo $(info)"tor configuration successfull" >> $LOG
    else
      MESSAGE=$MESSAGE"\ntor configuration failure"
      echo $(error)"tor configuration failure" >> $LOG
    fi
  fi
fi

# /data directory creation
if [[ -d "/data" ]]; then
  if [[ $(stat -c "%U" /data) == $(whoami) && $(stat -c "%G" /data) == $(whoami) ]]; then
    DATA_DIR_OK=true
    MESSAGE=$MESSAGE"\n/data directory already exists and has correct ownership"
    echo $(info)"/data directory already exists and has correct ownership" >> $LOG
  else
    sudo chown $(whoami):$(whoami) /data
    if [[ $(stat -c "%U" /data) == $(whoami) && $(stat -c "%G" /data) == $(whoami) ]]; then
      DATA_DIR_OK=true
      MESSAGE=$MESSAGE"\n/data directory already exists, ownership assigned"
      echo $(info)"/data directory already exists, ownership assigned" >> $LOG
    else
      MESSAGE=$MESSAGE"\n/data directory already exists, ownership assignment failed"
      echo $(info)"/data directory already exists, ownership assignment failed" >> $LOG
    fi
  fi
else
  echo $(info)"Creating /data directory" >> $LOG
  sudo mkdir /data
  if [[ -d "/data" ]]; then
    sudo chown $(whoami):$(whoami) /data
    if [[ $(stat -c "%U" /data) == $(whoami) && $(stat -c "%G" /data) == $(whoami) ]]; then
      DATA_DIR_OK=true
      MESSAGE=$MESSAGE"\n/data directory created, ownership assigned"
      echo $(info)"/data directory created created, ownership assigned" >> $LOG
    else
      MESSAGE=$MESSAGE"\n/data directory created, ownership assignment failed"
      echo $(info)"/data directory created created, ownership assignment failed" >> $LOG
    fi
  else
    MESSAGE=$MESSAGE"\n/impossible to create /data directory"
    echo $(info)"impossible to create /data directory" >> $LOG
  fi
fi

# display init results
dialog \
        --title "System Initialization" \
        --yes-label "Continue" \
        --no-label "Abort" \
        --input-fd 2 \
        --output-fd 1 \
        --yesno "$MESSAGE" \
        $HEIGHT $WIDTH

DIALOG_OUTPUT=$?
if [ ! "$DIALOG_OUTPUT" -eq 0 ]; then
  echo $(info)"User aborted execution" >> $LOG
  exit 1
fi

if $GPG_OK && $GIT_OK && $UFW_OK && $FAIL2BAN_OK && $NGINX_OK && $TOR_OK && $DATA_DIR_OK; then
  echo $(info)"System Initialization Completed" >> $LOG
else
  echo $(error)"Execution aborted" >> $LOG
  exit 1
fi
