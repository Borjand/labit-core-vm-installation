# Labit Virtual Machine Installation (CORE)
This repository contains the necessary elements to allow the automated installation of software tools involved in the creation of the Labit virtual machine (VM). Thus, enabling the necessary resources to undertake the laboratories of Audiovisual Services, Computer Networks and Design and Operation of Communication Networks, subject from the Department of Telematics Engineering of the Universidad Carlos III de Madrid.

## Requirements
* An operational VM with Ubuntu Desktop 22.04 (jammy) as Operating System. The Ubuntu image (depending on the host chipset, Intel, ARM, or M1/M2) can be found [here](https://cdimage.ubuntu.com/jammy/daily-live/current/)
* Python 3.9+ 

## Quick Start (Install)

The following should get you up and running on Ubuntu 22.04. This would
install CORE into a python3 virtual environment, install
[OSPF MDR](https://github.com/USNavalResearchLaboratory/ospf-mdr) from source, and all the software needed to set up the Labit VM. More information
about this can be found in the follwing link: (http://labit.lab.it.uc3m.es/en/versions) 

```shell
git clone https://github.com/Borjand/labit-core-vm-installation.git
cd labit-core-vm-installation
# install dependencies and run installation tasks
./setup.sh 2>&1 | tee installation_log.txt
```
> **NOTES:** 
> The installation process may take a long time, so be patient. Consider restarting the computer once the installation is complete.

> :warning: This development has been validated using **Linux Ubuntu Desktop 22.04.3 LTS** as Operating System, and **Python v3.10.12**. 

## Documentation & Support
We are leveraging a Wiki where you can find more documentation concerning the ulization of the Labit VM

* [Documentation](https://coreemu.github.io/core/](http://labit.lab.it.uc3m.es)http://labit.lab.it.uc3m.es)
