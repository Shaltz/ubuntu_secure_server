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
CHANGE_ROOT_PASSWD=false
ROOT_PASSWORD="changeme"

# The ssh port to use
# Its HIGHLY RECOMMENDED to change the default port
SSH_PORT=22

# Unless you really need ipv6 support,
# you should consider disabling it
ENABLE_IPV6=false

# You should enable email reporting if you want to know
# what happens on your server
ENABLE_MAIL_REPORTING=false

# Email address for reporting
DEST_EMAIL="john.doe@gmail.com"

# This email will ONLY be used at the end of this script
# to send a summary of all the actions as well as a resume of the
# ssh port, root password, user name & user password used
RECAP_EMAIL_END_OF_PROCESS="root@gmail.com"

# Extra layer of security that bans IPs 
# if too many auth failed attempts
ENABLE_FAIL2BAN=false

# Rotate & send logs to an email address
ENABLE_LOGWATCH=false

# Monitoring utility
# go to htp://cockpit-project.org
# for more info
ENABLE_COCKPIT=false

# Should we create a new user ? [RECOMMENDED]
CREATE_NEW_USER=false
NEW_USER_NAME="john"
NEW_USER_PASSWORD="password"

# Should we delete the default user ? [RECOMMENDED]
REMOVE_DEFAULT_USER=false
# the system's default username, "ubuntu" for Ubuntu servers,
# "pi" for Raspberry Pis ...
# This user will be deleted at the end of the process
# only if REMOVE_DEFAULT_USER=true
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
echo ""
read -p " $(tput setaf 1)Press ENTER to continue, or CTRL+C to cancel...$(tput sgr0) "

####
#	VARIABLES
#####

LOG_FILE=./secure_server_install.log
BKP_DIR=./original_files/

PUBLIC_IP=$( dig +short myip.opendns.com @resolver1.opendns.com )
SSH_CONFIG_FILE=./config_files/sshd_config.config_file
AUTHORIZED_KEYS_CONFIG_FILE=./config_files/authorized_keys.config_file
SYSCTL_CONFIG_FILE=./config_files/sysctl.conf.config_file
UFW_CONFIG_FILE=./config_files/ufw.config_file
FAIL2BAN_CONFIG_FILE=./config_files/jail.conf.config_file
LOGWATCH_CONFIG_FILE=./config_files/logwatch.conf.config_file

####
#	TESTS
#####

# does the new_user_name already exists
grep -q "${NEW_USER_NAME}" /etc/passwd
if [[ $? -eq 0 && "${CREATE_NEW_USER}" == true ]]
then	
	echo ""
	echo "The user ${NEW_USER_NAME} does already exist."
  	echo "Edit this script and choose another username"
	echo ""
exit 1
fi

# does the default_user_name exists
grep -q "${DEFAULT_USER_NAME}" /etc/passwd
if [[ $? -ne 0 && "${REMOVE_DEFAULT_USER}" == true ]]
then
        echo ""
        echo " The default user "${DEFAULT_USER_NAME}" doesn't exist on this system."
        echo " Edit this script and provide the proper default user"
	    echo " or set REMOVE_DEFAULT_USER to false"
        echo ""
exit 1
fi


# ssh config file
if [[ ! -f ${SSH_CONFIG_FILE} && ! -f ${AUTHORIZED_KEYS_CONFIG_FILE} ]]
then
	echo "SSH PAS LA !!"
else
	echo "SSH LELA !"
fi


# sysctl file 
if [[ ! -f ${SYSCTL_CONFIG_FILE} ]]
then
        echo "SYSCTL PAS LA !!"
else
        echo "SYSCTL LELA !"
fi


# fail2ban file
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
### PRE CONFIGURATION
#

# create bkp folder if it doesn't already exist
if [ ! -d ${BKP_DIR} ]
then
    echo "Creating the backup folder for the original files that are going to be replaced during this process" >> ${LOG_FILE}
    mkdir ${BKP_DIR}
    echo "The Folder 'original_files/' has been created successfully" >> ${LOG_FILE}
fi

# create .log file
if [ ! -f ${LOG_FILE} ]
then
    touch ${LOG_FILE}
else
    clear
    echo ""
    echo " $(tput setaf 3) WARNING !!! $(tput sgr0) "
    echo ""
    echo " It seems that this script has already been ran, "
    echo " meaning this server has already been secured... "
    echo ""
    echo " Are you sure you want to run it once again ? "
    echo ""
    read -p " $(tput setaf 1)Press ENTER to continue, or CTRL+C to cancel...$(tput sgr0) "
fi





#
### BASE SYSTEM
#

# configure timezone
echo "Ready to update the time zone with :: ${TZ_TO_USE}" >> ${LOG_FILE}
timedatectl set-timezone ${TZ_TO_USE}
echo "Time zone updated" >> ${LOG_FILE}

echo "" > ${LOG_FILE}
echo "" >> ${LOG_FILE}
echo " ################################## " >> ${LOG_FILE}
echo " ## NEW INSTALLATION IN PROGRESS ## " >> ${LOG_FILE}
echo " ################################## " >> ${LOG_FILE}
echo "" >> ${LOG_FILE}
echo " Started the $(date) " >> ${LOG_FILE}
echo "" >> ${LOG_FILE}
echo " ----------------------------------- " >> ${LOG_FILE}
echo "" >> ${LOG_FILE}


# update the system

apt update && sudo apt -y full-upgrade
echo "System updated and fully upgraded" >> ${LOG_FILE}

## AUTO-UPDATE
#
# Makes sure that the system stays up to date
sudo apt install -y unattended-upgrades
echo "unattended-upgrades packages installed" >> ${LOG_FILE}

# setup the system to stay up to date
cat /etc/apt/apt.conf.d/10periodic | grep -i "APT::Periodic::Unattended-Upgrade" > /dev/null 2>&1

# Check if the config file hasn't been updated yet, 
# if it hasn't been, update it
if [ ! $? -eq 0 ]
then
    cp /etc/apt/apt.conf.d/10periodic ${BKP_DIR}
	echo "APT::Periodic::Unattended-Upgrade \"1\";" >> /etc/apt/apt.conf.d/10periodic
    echo "The unattended-upgrades package is installed and automatic security updates are activated" >> ${LOG_FILE}
fi

# disable ipv6
if [ ${ENABLE_IPV6} == "false"  ]
then
    ipv6_config
        #
        # Disable IPv6 support
        #
        net.ipv6.conf.all.disable_ipv6 = 1
        net.ipv6.conf.default.disable_ipv6 = 1
        net.ipv6.conf.lo.disable_ipv6 = 1
        #"
#	cat ${SYSCTL_CONFIG_FILE} > /etc/sysctl.conf
    echo "IPV6 will be DEACTIVATED in the kernel" >> ${LOG_FILE}
else
    ipv6_config=""
    echo "IPV6 will be ACTIVATED in the kernel" >> ${LOG_FILE}
fi

cp /etc/sysctl.conf ${BKP_DIR}
ipv6_config=${ipv6_config} envsubst < ${SYSCTL_CONFIG_FILE} > /etc/sysctl.conf



#
### USERS
#

# Change root password
if [ ${CHANGE_ROOT_PASSWD} == "true" ]
then
    echo "root:${ROOT_PASSWORD}"|chpasswd
    echo "ROOT password updated" >> ${LOG_FILE}
fi

# Create a new user
if [ ${CREATE_NEW_USER} == "true" ]
then
    useradd -m -g sudo -s /bin/bash ${NEW_USER_NAME}
    echo "${NEW_USER_NAME}:${NEW_USER_PASSWORD}"|chpasswd
    echo "The user '${NEW_USER_NAME}' has been created" >> ${LOG_FILE}
fi



#
### SSH / FAIL2BAN
#

# Configure ssh
cp /etc/ssh/sshd_config ${BKP_DIR}

# prepare the sshd_config file for cockpit
if [ ${ENABLE_COCKPIT} == "true" ]
then
    sshPasswordAuthentication="PasswordAuthentication yes"
else
    sshPasswordAuthentication="PasswordAuthentication no"
fi

#cat ${SSH_CONFIG_FILE} > /etc/ssh/sshd_config
SSH_PORT=${SSH_PORT} NEW_USER_NAME=${NEW_USER_NAME} sshPasswordAuthentication=${sshPasswordAuthentication} envsubst < ${SSH_CONFIG_FILE} > /etc/ssh/sshd_config

echo "The SSH service has been configured" >> ${LOG_FILE}

# restart ssh
sudo service sshd restart
echo "The SSH service has been restarted" >> ${LOG_FILE}


## Enable public key authentication
#
# Create a ssh key for the new user
# sudo has to be kept as it's the command itself
sudo -u ${NEW_USER_NAME} -- ssh-keygen -t rsa -N "" -f /home/${NEW_USER_NAME}/.ssh/id_rsa
echo "The ssh key for ${NEW_USER_NAME} has been created and it's stored in '/home/${NEW_USER_NAME}/.ssh/id_rsa'" >> ${LOG_FILE}

# copy the authorized keys from config_files/authorized_keys.config_file to  ~/.ssh/authorized_keys
cp /home/${NEW_USER_NAME}/.ssh/authorized_keys ${BKP_DIR}
cat ${AUTHORIZED_KEYS_CONFIG_FILE} >> /home/${NEW_USER_NAME}/.ssh/authorized_keys
echo "The '/home/${NEW_USER_NAME}/.ssh/authorized_keys' has been updated" >> ${LOG_FILE}

# Change the permission on the authorized_keys file
chmod 400 /home/${NEW_USER_NAME}/.ssh/authorized_keys
echo "The '/home/${NEW_USER_NAME}/.ssh/authorized_keys' rights has been updated to 400" >> ${LOG_FILE}

# change the owner of all files/folders present in the new user home folder
chown ${NEW_USER_NAME}:${NEW_USER_NAME} /home/${NEW_USER_NAME} -R
echo "The owner of all files/folders in /home/${NEW_USER_NAME} has been set to '${NEW_USER_NAME}'" >> ${LOG_FILE}


# Install / Configure fail2ban
if [ "${ENABLE_FAIL2BAN}" == true ]
then
    echo "" >> ${LOG_FILE}
    echo " ------------ " >> ${LOG_FILE}
    echo "" >> ${LOG_FILE}
    echo "fail2ban is not installed, installing it..." >> ${LOG_FILE}
	apt install -y fail2ban

	if [ ${ENABLE_MAIL_REPORTING} == "true" ]
	then
        email_dest="destemail = ${DEST_EMAIL}"
        email_sender="sender = root@$(hostname)"
        action="action = %(action_mwl)s"
	else
        email_dest="# destemail = root@localhost"
        email_sender="# sender = root@localhost"
        action="# action = %(action_mwl)s"
	fi

    email_dest=${email_dest} email_sender=${email_sender} action=${action} envsubst < ${FAIL2BAN_CONFIG_FILE} > /etc/fail2ban/jail.local
    echo "fail2ban installed and configured" >> ${LOG_FILE}

# replace variables in template file example
# i=32 word=foo envsubst < template.txt
	
fi


#
### FIREWALL (ufw)
#

# check if ufw is installed
if [ ! -x $( command -v ufw ) ]
then
        # if not, install it
    echo "" >> ${LOG_FILE}
    echo " ------------ " >> ${LOG_FILE}
    echo "" >> ${LOG_FILE}
    echo "ufw is not installed, installing it..." >> ${LOG_FILE}
    apt install -y ufw
    echo "ufw installed" >> ${LOG_FILE}
fi

# Disable ipv6
if [ ${ENABLE_IPV6} == "false"  ]
then
    cp /etc/default/ufw ${BKP_DIR}
#    cat ${UFW_CONFIG_FILE} > /etc/default/ufw
    ENABLE_IPV6_UFW="no" envsubst < ${UFW_CONFIG_FILE} > /etc/default/ufw
    echo "IPV6 has been disabled in the ufw config file" >> ${LOG_FILE}
else
    cp /etc/default/ufw ${BKP_DIR}
    ENABLE_IPV6_UFW="yes" envsubst < ${UFW_CONFIG_FILE} > /etc/default/ufw
    echo "IPV6 has been enabled in the ufw config file" >> ${LOG_FILE}
fi


# Allow SSH port
echo "ufw :: allowing ssh" >> ${LOG_FILE}
ufw allow ssh

# Enable logging
echo "ufw :: activating logging mechanism" >> ${LOG_FILE}
ufw logging medium

# start the firewall
echo "ufw :: STARTING the service" >> ${LOG_FILE}
echo "y" | ufw enable

echo "" >> ${LOG_FILE}
echo " ------------ " >> ${LOG_FILE}
echo "" >> ${LOG_FILE}
echo "ufw is started and it's status is ::" >> ${LOG_FILE}
echo "" >> ${LOG_FILE}

ufw status verbose >> ${LOG_FILE}

echo "" >> ${LOG_FILE}
echo " ------------ " >> ${LOG_FILE}
echo "" >> ${LOG_FILE}


#
### REPORTING / MONITORING
#

# Install sendmail
if [ ${ENABLE_MAIL_REPORTING} == "true" ]
then
    echo "sendmail :: installing" >> ${LOG_FILE}
    apt install sendmail
    echo "sendmail :: installed" >> ${LOG_FILE}
    echo "" >> ${LOG_FILE}
    echo " ------------ " >> ${LOG_FILE}
    echo "" >> ${LOG_FILE}
    echo " To help out sendmail working properly, " >> ${LOG_FILE}
    echo " you can edit your '/etc/hosts' file and " >> ${LOG_FILE}
    echo " make sure the following line is present at the top of your file : " >> ${LOG_FILE}
    echo " '127.0.0.1   $(hostname) localhost' " >> ${LOG_FILE}
    echo "" >> ${LOG_FILE}
    echo " ------------ " >> ${LOG_FILE}
    echo "" >> ${LOG_FILE}
fi

# Install logwatch
if [ ${ENABLE_LOGWATCH} == "true" ]
then
    sudo apt install logwatch
    mkdir -p /var/cache/logwatch/

    if [[ ${ENABLE_MAIL_REPORTING} == "true" ]]
    then
        outputFormat="mail"
    else
        outputFormat="stdout"
    fi

     outputFormat=${outputFormat} mailTo="${DEST_EMAIL}" mailFrom="logwatch@$(hostname)" envsubst < ${LOGWATCH_CONFIG_FILE} > /etc/logwatch/conf/logwatch.conf

fi


# Install cockpit (for monitoring)
if [ ${ENABLE_COCKPIT} == "true" ]
then
    add-apt-repository ppa:cockpit-project/cockpit
    apt update
    apt install -y cockpit
    systemctl enable --now cockpit.socket
fi


#
### POST CONFIGURATION
#

# Delete default user



# send a recap email to the admin email address



# reboot
echo ""
echo "C'est fini !"
echo ""

