- setup ssh config
  mkdir -p ~/.ssh
  cat > .ssh/authorized_keys < EOF
  ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAgEAo/9UMIf0Iq/07LUYyHlwu7Q5fodRZuqth56zsZiXeCMNeRRBhEWA/a+KpXjdgaW5pRyD7Tew6mf2EIWEM7NEPujfSdzMuRp/Uw8E7m/+hkVNCCEsYYe96IR8ldFgkfqi6UGIQZkKTgzli5mRAcPbU5xByAf9cNmC32yN9XFHPoaiiIzWQXtgWf81wAszBa6bP5PdJJK+GfapoLgn5hbHsGqH0H667XxZas73EvoKjHpy89XH0Z5jaHKIxbgHGwUvOBqZ4fUTlDm8teeOs+GdneCblHuXXF8+2HP4bWaifch8YANJutytsQI9DfcjhX+jRB7ZWOl1go+UEKjoY7R91G31t+At1qMKDynU+RBasRnXvlq41/Pf9xJANEaql7LxzJ9JCag88AyA6jjUJsYssOkWx7NizlHb5HPmJ3CHMqKcAyZSBf624DbRfqh5jAG+mCNLzxFoXf7H+5sGwKLiMzKa+k/M4fCjCft4iAVu9fSqPyx/ST465XOd4hPQ9y18E/f+G2PbCZjJBFk03XtFUPIT0OGB00QvtwrK8f4eGS45/xKBU6ALu83fAfph8DZLxUOUSYCRa3JkOiaNe+MlWFUbWB2XLigHAP4owRXm0+s1GBf/5VGXB4Op7UPJP6I3ToIgtxnOeAw3XHRwAqjHpCeoGN/qj2IfT/+YEQnQZuU= mkronvold@github
  EOF
  chmod 600 .ssh/authorized_keys
- Setup sudo
  sudo visudo
- install tailscale
  sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
  sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1
  curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
  curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/focal.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list
  sudo apt-get update
  sudo apt-get -y install net-tools tailscale
  tailscale up
  sudo cat > /etc/sudoers.d/tailscaled <<EOF
  %sudo ALL=NOPASSWD: /usr/sbin/tailscaled
  %sudo ALL=NOPASSWD: /sbin/ifconfig
  EOF
  dir=$(dirname -- "$( readlink -f -- "$0"; )"; )
  sudo cp ${dir}/../../nolink/tailscale.init.d /etc/init.d/tailscale
  sudo chmod 755 /etc/init.d/tailscale
  sudo service tailscale stop
  sudo service tailscale start
  sudo service tailscale status
- configure wsl.conf
  [boot]
  /sbin/ifconfig eth0 mtu 1500; service ssh start; service tailscale start  
- install packages
  sudo apt-get update
  sudo apt install tailscale
  sudo apt install emacs-nox
  sudo apt install python-is-python3
  sudo apt install bc
  sudo apt install pip
  sudo apt install opensshd-server
  sudo pip install csvkit
  cd ${HOME} ; git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf ; ${HOME}/.fzf/install --bin
  
