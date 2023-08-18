#!/bin/bash

PYTHON="${PYTHON:=python3}"
PYTHON_DEP="${PYTHON_DEP:=python3}"
REPO_HOME="$(pwd)"
LOCAL_USER="$(echo $USER)"

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
    fi
    sudo DEBIAN_FRONTEND=noninteractive apt install -y "$package"
    if [ $? -eq 0 ]; then
        echo "-- El paquete $package se ha instalado correctamente."
        # Disabling automatic service start for kamailio and pimd
        if [ "$package" = "pimd" ] || [ "$package" = "kamailio" ]; then
            sudo systemctl stop $package
            sudo systemctl disable $package
        # Enabling non-root user to sniff traffic
        elif [ "$package" = "wireshark" ]; then
            sudo usermod -a -G wireshark $LOCAL_USER
            newgrp wireshark
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
echo "- Installation of sipp v3.6.0: Done!"

# Installing jdk1.8.0_141
echo "+ Installing JAVA (version 8u141) ..."
cd $REPO_HOME
uname -a | grep 'x86_64'
if [ $? -eq 0 ]; then
    sudo wget -P /opt/ https://vm-images.netcom.it.uc3m.es/java_versions/jdk-8u141-linux-x64.tar.gz
    sudo tar -xvf /opt/jdk-8u141-linux-x64.tar.gz -C /opt/
    sudo rm /opt/jdk-8u141-linux-x64.tar.gz
else
    sudo wget -P /opt/ https://vm-images.netcom.it.uc3m.es/java_versions/jdk-8u141-linux-arm64-vfp-hflt.tar.gz
    sudo tar -xvf /opt/jdk-8u141-linux-arm64-vfp-hflt.tar.gz -C /opt/
    sudo rm /opt/jdk-8u141-linux-arm64-vfp-hflt.tar.gz
fi
echo "" >> $HOME/.bashrc
echo "# Included during Labit VM software installation" >> $HOME/.bashrc
echo 'export JAVA_PATH="/opt/jdk1.8.0_141"' >> $HOME/.bashrc
echo 'export PATH="$PATH:$JAVA_PATH/bin"' >> $HOME/.bashrc


echo "Do not forget this: After all this installation, a reboot is mandatory!"

