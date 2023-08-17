#!/bin/bash

PYTHON="${PYTHON:=python3}"
PYTHON_DEP="${PYTHON_DEP:=python3}"
REPO_HOME="$(pwd)"

# install pre-reqs using yum/apt
if [ -z "${NO_SYSTEM}" ]; then
  if command -v apt &> /dev/null
  then
    echo "+ Setup to install CORE..."
    sudo apt update && sudo apt upgrade -y 
    sudo apt install -y ${PYTHON_DEP}-pip ${PYTHON_DEP}-venv
  elif command -v yum &> /dev/null
  then
    echo "setup to install CORE using yum"
    sudo yum install -y ${PYTHON_DEP}-pip
  else
    echo "apt/yum was not found"
    echo "install python3, pip, venv, pipx, and invoke to run the automated install"
    exit 1
  fi
fi

# install tooling for invoke based installation
${PYTHON} -m pip install --user pipx==0.16.4
${PYTHON} -m pipx ensurepath
export PATH=$PATH:~/.local/bin
pipx install invoke==1.4.1
pipx install poetry==1.2.1

# invoke the core installation
inv install
echo "- CORE successfully installed!"

# install apt packages 
echo "+ Installing required apt packages (vlc, wireshark, pimd, kamailio) ..."
# List of apt packages
apt_packages=("vlc" "wireshark" "pimd" "kamailio" "tcpdump" "openssh-server" "traceroute" "wget")

for package in "${apt_packages[@]}"; do
    if [ "$package" = "wireshark" ]; then
        echo "wireshark-common wireshark-common/install-setuid boolean true" | sudo debconf-set-selections
        sudo usermod -aG wireshark $USER
    fi
    sudo DEBIAN_FRONTEND=noninteractive apt install -y "$package"
    if [ $? -eq 0 ]; then
        echo "-- El paquete $package se ha instalado correctamente."
        # Disabling automatic service start for kamailio and pimd
        if [ "$package" = "pimd" ] || [ "$package" = "kamailio" ]; then
            sudo systemctl stop $package
            sudo systemctl disable $package
        fi
    else
        echo "-- Error al instalar el paquete $package."
    fi
done
sudo apt autoremove -y
echo "- Installation of apt packages: Done!"

# install snap packages (usin classic option)
echo "+ Installing snap packages (VistualStudio and Eclipse) ..."
# List of apt packages
snap_packages=("code" "eclipse")

for package in "${snap_packages[@]}"; do
    sudo snap install --classic "$package"
    if [ $? -eq 0 ]; then
        echo "-- El paquete $package se ha instalado correctamente."
    else
        echo "-- Error al instalar el paquete $package."
    fi
done
echo "- Installation of snap packages: Done!"

# Installing sipp v3.6.0:
echo "+ Installing sipp v3.6.0 ..."
sudo wget -P /opt/ https://github.com/SIPp/sipp/releases/download/v3.6.0/sipp-3.6.0.tar.gz
sudo tar -xvf /opt/sipp-3.6.0.tar.gz -C /opt/
sudo rm /opt/sipp-3.6.0.tar.gz
cd /opt/sipp-3.6.0/
./configure
make
sudo cp sipp /usr/local/bin/
cd $REPO_HOME
echo "- Installation of sipp v3.6.0: Done!"

# Installing jdk1.8.0_141 



echo "After all this installation, a reboot is mandatory!"
sudo reboot

