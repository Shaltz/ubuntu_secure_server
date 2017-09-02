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

# Unless you really need ipv6 support,
# you should consider disabling it
ENABLE_IPV6=false

# You should enable email reporting if you want to know
# what happens on your server
ENABLE_MAIL_REPORTING=true

# Extra layer of security that bans IPs 
# if too many auth failed attempts
ENABLE_FAIL2BAN=true

# Rotate & send logs to an email address
ENABLE_LOGWATCH=true

# Monitoring utility
# go to htp://cockpit-project.org
# for more info
ENABLE_COCKPIT=true

# Should a new user be created
# and old default user delete ?
REMOVE_DEFAULT_USER= true
NEW_USER="john"
# the system's default user, "ubuntu" for Ubuntu servers, "pi" for Raspberry Pis ...
SYSTEM_DEFAULT_USER="ubuntu"






##########################################
###	DO NOT EDIT THE LINES BELLOW
###   UNLESS YOU KNOW WHAT YOU ARE DOING
##########################################

#####
#	DISPLAY WARNING
#####

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
echo "$(tput setaf 11)"
echo " Don't leave yet, you need to configure some things "
echo " before the script can carry continue on its own "
echo "$( tput sgr0 )"
echo ""
read -p " $(tput setaf 1)Press ENTER to continue, or CTRL+C to cancel...$(tput sgr0) "



####
#	VARIABLES
#####
PUBLIC_IP=$( dig +short myip.opendns.com @resolver1.opendns.com )

echo "My IP :: $PUBLIC_IP"


####
#	TESTS
#####




#####
#	SCRIPT
#####

#
### BASE SYSTEM
#

# configure timezone
sudo dpkg-reconfigure tzdata


echo ""
echo "$( tput setaf 10 )"
echo " From now on, the script is fully automatic and "
echo " doesn't need inputs from you anymore, "
echo " come back in a few minutes... "
echo "$( tput sgr0 )"
echo ""
read -p " $(tput setaf 1)Press ENTER to continue, or CTRL+C to cancel...$(tput sgr0) "

# update the system
sudo apt update && sudo apt -y full-upgrade

# tweak auto-update for security patches to be tighten

# disable ipv6 



#
### FIREWALL
#

# Disable ipv6

# Allow SSH port

# Enable logging

# start the firewall


#
### USERS
#

# Change root password

# Create a new user


#
### SSH / FAIL2BAN
#

# Configure ssh

# Enable public key authentication

# Install / Configure fail2ban


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

# Switch to the newly created user

# Delete default user

# reboot

echo ""
echo "C'est fini !"
echo ""

