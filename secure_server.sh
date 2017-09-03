#!/bin/bash
#
##########
#
#	SCRIPT TO SECURE A DEBIAN / UBUNTU SERVER
#
##########

#####
#	SETTINGS
#####

# The time zone to use.
# To list all the timezones available :
# timedatectl list-timezones
TZ_TO_USE="Europe/Paris"

# The new root password to use
# DONT LEAVE THE DEFAULT ONE !!!
ROOT_PASSWORD="changeme"

# Unless you really need ipv6 support,
# you should consider disabling it
ENABLE_IPV6=false

# You should enable email reporting if you want to know
# what happens on your server
ENABLE_MAIL_REPORTING=true
# Email address for reporting
DEST_EMAIL="john.doe@gmail.com"

# Extra layer of security that bans IPs 
# if too many auth failed attempts
ENABLE_FAIL2BAN=true

# Rotate & send logs to an email address
ENABLE_LOGWATCH=true

# Monitoring utility
# go to htp://cockpit-project.org
# for more info
ENABLE_COCKPIT=true

# Should we create a new user ? [RECOMMENDED]
CREATE_NEW_USER=true
NEW_USER_NAME="john"
NEW_USER_PASSWORD="password"

# Should we delete the default user ? [RECOMMENDED]
REMOVE_DEFAULT_USER=true
# the system's default username, "ubuntu" for Ubuntu servers, "pi" for Raspberry Pis ...
# This user will be deleted at the end of the process if REMOVE_DEFAULT_USER=true
DEFAULT_USER_NAME="ubuntu"






##########################################
###	DO NOT EDIT THE LINES BELLOW
###   UNLESS YOU KNOW WHAT YOU ARE DOING
##########################################

#####
#	WARNINGS
#####

# make sure this script is ran as root
if [ $EUID -ne 0 ]
then
	echo ""
	echo " Run this script as root !"
	echo ""
	exit 1
else
	if [ ! $( whoami ) == 'root' ]
	then
		# Switch to root
		sudo su -s "${0}"
	fi
fi

clear

# General Warning
echo ""
echo ""
echo " $( tput setaf 9 )"
echo " Make sure the files in conf_files are "
echo " setup the way you want to. If you're not careful "
echo " you may end up locked out from this server. "
echo " $( tput sgr0 )"
echo " According to the settings you have specified, "
echo " you need to edit the following files :"
echo ""
echo " [List of files] "
echo ""
echo ""
#echo "$(tput setaf 11)"
#echo " Don't leave yet, you need to configure some things "
#echo " before the script can carry continue on its own "
#echo "$( tput sgr0 )"
echo ""
read -p " $(tput setaf 1)Press ENTER to continue, or CTRL+C to cancel...$(tput sgr0) "

####
#	VARIABLES
#####
PUBLIC_IP=$( dig +short myip.opendns.com @resolver1.opendns.com )
HOSTNAME=$( hostname )

echo "My IP :: $PUBLIC_IP"

SSH_CONFIG_FILE=./config_files/sshd_config.config_file
AUTHORIZED_KEYS_CONFIG_FILE=./config_files/authorized_keys.config_file
SYSCTL_CONFIG_FILE=./config_files/sysctl.conf.config_file
UFW_CONFIG_FILE=./config_files/ufw.config_file
FAIL2BAN_CONFIG_FILE=./config_files/jail.conf.config_file

####
#	TESTS
#####

# does the new_user_name already exists
grep -q "${NEW_USER_NAME}" /etc/passwd
if [ $? -eq 0 ] 
then	
	echo ""
	echo "The user ${NEW_USER_NAME} does already exist."
  	echo "Edit this script and chose another username"
	echo ""
exit 1
fi

# ssh config file
if [[ ! -f ${SSH_CONFIG_FILE} && ! -f ${AUTHORIZED_KEYS_CONFIG_FILE} ]]
then
	echo "SSH PAS LA !!"
else
	echo "SSH LELA !"
	
	# check to make sure the port has been changed
	cat ${SSH_CONFIG_FILE} | grep -i "Port 22" > /dev/null 2>&1
	# if the default port hasn't been changed
	if [ $? -eq 0 ]
	then
		clear
		echo ""
		echo " The SSH port is set to the default $(tput setaf 11)Port 22$(tput sgr0)"
		echo ""
		echo "$(tput setaf 9) it is HIGHLY RECOMMENDED to change the ssh port$(tput sgr0) "
		echo ""
		echo " Set it to some port > 1024 and < 65535"
		echo ""
		read -p " $(tput setaf 1)Press ENTER to continue, or CTRL+C to cancel...$(tput sgr0) "
	fi
fi


# sysctl file 
if [[ ! -f ${SYSCTL_CONFIG_FILE} ]]
then
        echo "SYSCTL PAS LA !!"
else
        echo "SYSCTL LELA !"
fi


# sysctl file
if [[ ! -f ${FAIL2BAN_CONFIG_FILE} ]]
then
        echo "FAIL2BAN PAS LA !!"
else
        echo "FAIL2BAN LELA !"
fi


#####
#	SCRIPT
#####



#
### BASE SYSTEM
#

# configure timezone
#sudo dpkg-reconfigure tzdata
#echo ""
#echo "$( tput setaf 10 )"
#echo " From now on, the script is fully automatic and "
#echo " doesn't need inputs from you anymore, "
#echo " come back in a few minutes... "
#echo "$( tput sgr0 )"
#echo ""
#read -p " $(tput setaf 1)Press ENTER to continue, or CTRL+C to cancel...$(tput sgr0) "

# update the system
apt update && sudo apt -y full-upgrade

# configure timezone
timedatectl set-timezone ${TZ_TO_USE}


## AUTO-UPDATE
#
# Makes sure that the system stays up to date
sudo apt install -y unattended-upgrades

# setup the system to stay up to date      
cat /etc/apt/apt.conf.d/10periodic | grep -i "APT::Periodic::Unattended-Upgrade" > /dev/null 2>&1

# Check if the config file hasn't been updated yet, 
# if it hasn't been, update it
if [ ! $? -eq 0 ]
then
	echo "APT::Periodic::Unattended-Upgrade \"1\";" >> /etc/apt/apt.conf.d/10periodic
fi

# disable ipv6
if [ ${ENABLE_IPV6} == "false"  ]
then
	cat ${SYSCTL_CONFIG_FILE} > /etc/sysctl.conf
fi

#
### USERS
#

# Change root password
echo "root:${ROOT_PASSWORD}"|chpasswd

# Create a new user
useradd -m -g sudo -s /bin/bash ${NEW_USER_NAME}
echo "${NEW_USER_NAME}:${NEW_USER_PASSWORD}"|chpasswd


#
### SSH / FAIL2BAN
#

# Configure ssh
cat ${SSH_CONFIG_FILE} > /etc/ssh/sshd_config
# restart ssh
sudo service sshd restart

## Enable public key authentication
#
# Create a ssh key for the new user
sudo -u ${NEW_USER_NAME} -- ssh-keygen -t rsa -N "" -f /home/ubuntu/.ssh/id_rsa

chmod 400 /home/${NEW_USER_NAME}/.ssh/authorized_keys
chown ${NEW_USER_NAME}:${NEW_USER_NAME} /home/${NEW_USER_NAME} -R

# copy the authorized keys from config_files/authorized_keys.config_file to  ~/.ssh/authorized_keys 
cat ${AUTHORIZED_KEYS_CONFIG_FILE} >> /home/${NEW_USER_NAME}/.ssh/authorized_keys

# Install / Configure fail2ban

if [ "${ENABLE_FAIL2BAN}" == true ]
then
	apt install -y fail2ban
	
fi


#
### FIREWALL (ufw)
#

# check if ufw is installed
if [ ! -x $( command -v ufw ) ]
then
        # if not, install it
        apt install -y ufw
fi

# Disable ipv6
cat ${UFW_CONFIG_FILE} > /etc/default/ufw

# Allow SSH port
ufw allow ssh
# Enable logging
ufw logging medium
# start the firewall
echo "y" | ufw enable


#
### REPORTING / MONITORING
#

# Install sendmail

# Install logwatch

# Configure fail2ban for mail reporting

# Install cockpit (for monitoring)


#
### CLEANING UP
#

# Delete default user

# reboot
echo ""
echo "C'est fini !"
echo ""

