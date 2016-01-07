#!/bin/bash
# Filename:		proxy_config.sh
# By:			Dan Burkland
# Date:			2015-12-23
# Purpose:		The purpose of this script is to add the appropriate proxy configuration lines
#			to the 1) "/root/docker/harvest/{bashrc,Dockerfile}" files which will be used to
#			build the NetApp Harvest docker container 
#			2) "/etc/sysconfig/Docker" file which controls the Docker service on the host. 
#			The configuration file in list item #2 is only present in CentOS & Red Hat Enteprise Linux (RHEL)
#			so its path my vary depending on the Docker host's Linux distribution. This script has been
#			tested against CentOS/RHEL 6.7+/7.0+ and SUSE Linux 12.0+.

# Variables
HARVEST_BUILDDIR="/root/docker/harvest"
PROXY_SERVER_ADDRESS="$1"

if [ ! $1 ]; then
	# If a Proxy server URL is not specified exit with error
	echo "Usage: $0 PROXY_SERVER_ADDRESS"
	echo ""
	echo "Example: $0 10.0.0.200:3128"
	exit 1
else
	# Add appropriate configuraiton options to ${HARVEST_BUILDDIR}/bashrc
	echo "Adding the appropriate proxy configuration lines to ${HARVEST_BUILDDIR}/bashrc..."
	sed -i "s/#PROXY_PLACEHOLDER1/export http_proxy=http:\/\/${PROXY_SERVER_ADDRESS}\nexport HTTP_PROXY=http:\/\/${PROXY_SERVER_ADDRESS}\nexport https_proxy=https:\/\/${PROXY_SERVER_ADDRESS}\nexport HTTPS_PROXY=https:\/\/${PROXY_SERVER_ADDRESS}/g" ${HARVEST_BUILDDIR}/bashrc
	sed -i "s/#PROXY_PLACEHOLDER1/export http_proxy=http:\/\/${PROXY_SERVER_ADDRESS}\nexport HTTP_PROXY=http:\/\/${PROXY_SERVER_ADDRESS}\nexport https_proxy=https:\/\/${PROXY_SERVER_ADDRESS}\nexport HTTPS_PROXY=https:\/\/${PROXY_SERVER_ADDRESS}/g" ${HARVEST_BUILDDIR}/netapp_harvest_automated_setup

	# Add appropriate configuraiton options to ${HARVEST_BUILDDIR}/Dockerfile
	echo "Adding the appropriate proxy configuration lines to ${HARVEST_BUILDDIR}/Dockerfile..."
	sed -i "s/#PROXY_PLACEHOLDER1/ENV http_proxy http:\/\/${PROXY_SERVER_ADDRESS}\nENV HTTP_PROXY http:\/\/${PROXY_SERVER_ADDRESS}\nENV https_proxy https:\/\/${PROXY_SERVER_ADDRESS}\nENV HTTPS_PROXY https:\/\/${PROXY_SERVER_ADDRESS}/g" ${HARVEST_BUILDDIR}/Dockerfile
	sed -i "s/#PROXY_PLACEHOLDER2/ENV http_proxy \"\"\nENV HTTP_PROXY \"\"\nENV https_proxy \"\"\nENV HTTPS_PROXY \"\"/g" ${HARVEST_BUILDDIR}/Dockerfile

	if [ -f /etc/SuSE-release ]; then
       		# SUSE-based Distribution
		DOCKERCONF="/etc/sysconfig/docker"

		echo "Adding the appropriate proxy configuration lines to ${DOCKERCONF}..."
		echo -e "HTTP_PROXY=http:\/\/${PROXY_SERVER_ADDRESS}\nHTTPS_PROXY=https:\/\/${PROXY_SERVER_ADDRESS}/g" >> ${DOCKERCONF}
		
		echo "Restarting the Docker service to apply the recent configuration change..."
		/bin/systemctl restart docker
	elif [ -f /etc/debian_version ]; then
		# Debian-based Distribution
		DOCKERCONF="/etc/defaults/docker.io"

		echo "Adding the appropriate proxy configuration lines to ${DOCKERCONF}..."
		echo -e "http_proxy=http:\/\/${PROXY_SERVER_ADDRESS}\nHTTP_PROXY=http:\/\/${PROXY_SERVER_ADDRESS}\nhttps_proxy=https:\/\/${PROXY_SERVER_ADDRESS}\nHTTPS_PROXY=https:\/\/${PROXY_SERVER_ADDRESS}/g" >> ${DOCKERCONF}

		echo "Restarting the Docker service to apply the recent configuration change..."
		if [ -f /bin/systemctl ]; then
			/bin/systemctl restart docker
		else
			service docker.io restart
		fi
	elif [ -f /etc/redhat-release ]; then
		# RHEL-based Distribution
		DOCKERCONF="/etc/sysconfig/docker"
		
		echo "Adding the appropriate proxy configuration lines to ${DOCKERCONF}..."
		echo -e "HTTP_PROXY=http:\/\/${PROXY_SERVER_ADDRESS}\nHTTPS_PROXY=https:\/\/${PROXY_SERVER_ADDRESS}/g" >> ${DOCKERCONF}

		echo "Restarting the Docker service to apply the recent configuration change..."
		if [ -f /usr/bin/systemctl ]; then
			/usr/bin/systemctl restart docker
		else
			/etc/init.d/docker restart
		fi
	fi
fi
