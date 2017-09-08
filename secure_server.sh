#!/bin/bash
#

##########
#
#	SCRIPT TO SECURE A DEBIAN / UBUNTU SERVER
#
##########

#####
#
#	SETTINGS
#
#####

#####
## TIMEZONE
#####
## The time zone to use.
## To list all the timezones available :
## timedatectl list-timezones
    TZ_TO_USE="Europe/Paris"


#####
## SSH
#####
## The ssh port to use
## Its HIGHLY RECOMMENDED to change the default port
    SSH_PORT=22022


#####
## IPV6
#####
## Unless you really need ipv6 support,
## you should consider disabling it
    ENABLE_IPV6=false


#####
## EMAIL REPORTING
#####
# You should enable email reporting if you want to know
# what happens on this server
    ENABLE_MAIL_REPORTING=true

        # Email address for reporting
        DEST_EMAIL="john.doe@gmail.com"


#####
## FAIL2BAN
#####
## Extra layer of security that bans IPs
## if too many auth attempts fail
    ENABLE_FAIL2BAN=true


#####
## LOGWATCH
#####
## Rotate & send logs to an email address
    ENABLE_LOGWATCH=true


#####
## COCKPIT
#####
## Monitoring utility
## go to htp://cockpit-project.org
## for more info
    ENABLE_COCKPIT=true


#####
## ROOT USER
#####
# Change the root password ? [HIGHLY RECOMMENDED]
    CHANGE_ROOT_PASSWD=true

        # The new root password to use
        # DONT LEAVE THE DEFAULT ONE !!!
        ROOT_PASSWORD="changeme"

        ## This email will ONLY be used at the end of this script
        ## to send a summary of all the actions performed as well as
        ## a resume of all the necessary information to connect & admin
        ## this server
        ROOT_EMAIL="root@gmail.com"


#####
## NEW USER
#####
## Should we create a new user ? [RECOMMENDED]
    CREATE_NEW_USER=true

        # The login and password for this new user
        NEW_USER_NAME="john"
        NEW_USER_PASSWORD="changeme"


#####
## DEFAULT USER
#####
## Should we delete the default user ? [RECOMMENDED]
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

# clear the screen
clear

# General Warning
echo ""
echo ""
echo " $( tput setaf 9 )"
echo " Make sure the files in conf_files are "
echo " setup the way you want to. If you're not careful "
echo " you may end up locked out from this server. "
echo " $( tput sgr0 )"
echo ""
echo ""
read -p " $(tput setaf 1)Press ENTER to continue, or CTRL+C to cancel...$(tput sgr0) "

####
#	VARIABLES
#####

TOP_PID=$$

LOG_FILE=./secure_server_install.log
BKP_DIR=./original_files/

SSH_CONFIG_FILE=./config_files/sshd_config.config_file
AUTHORIZED_KEYS_CONFIG_FILE=./config_files/authorized_keys.config_file
SYSCTL_CONFIG_FILE=./config_files/sysctl.conf.config_file
UFW_CONFIG_FILE=./config_files/ufw.config_file
FAIL2BAN_CONFIG_FILE=./config_files/jail.local.config_file
LOGWATCH_CONFIG_FILE=./config_files/logwatch.conf.config_file
EMAIL_TEMPLATE=./config_files/email.template


##############
#   FUNCTIONS
##############


function handle_command_error {
# pass the exit code of the command we want to test
# as the 1st argument and the string to display as the 2nd
if [ $1 -ne 0 ]
then
    echo "" >> ${LOG_FILE}
    echo "" >> ${LOG_FILE}
    echo " [ ERROR ] $2 " >> ${LOG_FILE}
    echo ' /!\ Exiting the script /!\' >> ${LOG_FILE}
    echo "" >> ${LOG_FILE}

    echo ""
    echo ""
    echo " [ ERROR ] $2 "
    echo ' /!\ Exiting the script /!\'
    echo ""

    kill ${TOP_PID}
fi
}


#####
#	TESTS
#####

if [[ "${CREATE_NEW_USER}" == "true" ]]
then
    # does the new_user_name already exists
    grep -q "${NEW_USER_NAME}" /etc/passwd
    if [ $? -eq 0 ]
    then
        echo " [ ERROR ] The user ${NEW_USER_NAME} does already exist. "
        echo ' /!\ Exiting the script /!\'
        echo ""

        exit 1
    fi
fi


# check the the authorized_keys.config_file is NOT empty
if [ ! -s ${AUTHORIZED_KEYS_CONFIG_FILE} ]
then
    echo ""
    echo " $(tput setaf 3)The ./config_files/authorized_keys.config_file is empty "
    echo " You need to copy the public keys that you want"
    echo " to use (to connect to this server) in it or"
    echo " you will be LOCKED OUT from this server $(tput sgr0)"
    echo ""
    echo " $(tput setaf 1) Exiting the script $(tput sgr0)"
    echo ""

    exit 1
fi

if [[ "${REMOVE_DEFAULT_USER}" == "true" ]]
then
    # does the default_user_name exists
    grep -q "${DEFAULT_USER_NAME}" /etc/passwd
    if [ $? -ne 0 ]
    then
        echo " [ ERROR ] The default user "${DEFAULT_USER_NAME}" doesn't exist on this system. "
        echo ' /!\ Exiting the script /!\'
        echo ""

        exit 1
    fi
fi


# ssh config file
if [[ ! -f ${SSH_CONFIG_FILE} ]]
then
	echo "SSH PAS LA !!"
else
	echo "SSH LELA !"
fi


# sysctl config file (to enable/disable IPV6 in the kernel
if [[ ! -f ${SYSCTL_CONFIG_FILE} ]]
then
        echo "SYSCTL PAS LA !!"
else
        echo "SYSCTL LELA !"
fi


# fail2ban config file
if [[ ! -f ${FAIL2BAN_CONFIG_FILE} ]]
then
        echo "FAIL2BAN PAS LA !!"
else
        echo "FAIL2BAN LELA !"
fi


#####
#	SCRIPT
#####


#######
#
### PRE CONFIGURATION
#

# create .log file
if [ ! -f ${LOG_FILE} ]
then
    echo "Creating the log file "
    touch ${LOG_FILE}

        if [ $? -ne 0 ]
        then
            echo ""
            echo ""
            echo " [ ERROR ] Couldn't create the log file : ${LOG_FILE} "
            echo ' /!\ Exiting the script /!\'
            echo ""

            exit 1
        fi

else
    # If the log file already exists
    # Display a warning and exit the script
    clear
    echo ""
    echo ""
    echo " $(tput setaf 3) WARNING !!! $(tput sgr0) "
    echo ""
    echo ' It seems that this script has already been ran, '
    echo ' running it again may result in some undesired side effects !'
    echo ""
    echo ""
    read -p " $(tput setaf 1)Press ENTER to continue, or CTRL+C to cancel...$(tput sgr0) "

    clear

    echo ""
    echo ""
    echo " $(tput setaf 3)Are you REALLY sure you want to continue ?$(tput sgr0)"
    echo ""
    echo " Last warning... "
    echo ""
    read -p " $(tput setaf 1)Press ENTER to continue, or CTRL+C to cancel...$(tput sgr0) "

fi

# create bkp folder if it doesn't already exist
if [ ! -d ${BKP_DIR} ]
then
    echo "Creating the backup folder for the original files that are going to be replaced during this process" >> ${LOG_FILE}

    # create the folder
    mkdir ${BKP_DIR}
    handle_command_error $? "Couldn't create ${BKP_DIR}"
    echo "The Folder 'original_files/' has been created successfully" >> ${LOG_FILE}
fi


########
#
### BASE SYSTEM
#
# configure the timezone
timedatectl set-timezone ${TZ_TO_USE}
# Start writing to the log file
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
echo "Time zone updated :: ${TZ_TO_USE}" >> ${LOG_FILE}
# update the system

apt update && apt -y full-upgrade && apt install -y unattended-upgrades
handle_command_error $? "Couldn't update the system"

echo "System updated and fully upgraded" >> ${LOG_FILE}
echo "Unattended-upgrades package installed" >> ${LOG_FILE}


##########
#
## AUTO-UPDATE
#
# setup the system to stay up to date
cp /etc/apt/apt.conf.d/10periodic ${BKP_DIR}
echo "APT::Periodic::Unattended-Upgrade \"1\";" >> /etc/apt/apt.conf.d/10periodic
handle_command_error $? "Couldn't update the file :: /etc/apt/apt.conf.d/10periodic"

echo "The unattended-upgrades package is installed and automatic security updates are activated" >> ${LOG_FILE}


########
#
## IPV6
#
# disable ipv6
if [ "${ENABLE_IPV6}" == "false"  ]
then
    ipv6_status="DEACTIVATED"
    ipv6_config="
#
# Disable IPv6 support
#
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
#"
else
    ipv6_status="ACTIVATED"
    ipv6_config="
#
# Disable IPv6 support
#
# Uncomment the following lines and
# and reboot this server to DISABLE IPV6
#
# net.ipv6.conf.all.disable_ipv6 = 1
# net.ipv6.conf.default.disable_ipv6 = 1
# net.ipv6.conf.lo.disable_ipv6 = 1
#"
fi

cp /etc/sysctl.conf ${BKP_DIR}
ipv6_config=${ipv6_config} envsubst < ${SYSCTL_CONFIG_FILE} > /etc/sysctl.conf
handle_command_error $? "Couldn't update the file : /etc/sysctl.conf"

echo "IPV6 has been ${ipv6_status} in the kernel" >> ${LOG_FILE}


#########
#
### USERS
#
# Change root password
if [ ${CHANGE_ROOT_PASSWD} == "true" ]
then
    echo "root:${ROOT_PASSWORD}"|chpasswd
    handle_command_error $? "Couldn't change the root password"

    echo "ROOT password updated" >> ${LOG_FILE}
fi

# Create a new user
if [ ${CREATE_NEW_USER} == "true" ]
then
    groupadd ${NEW_USER_NAME}
    handle_command_error $? "Couldn't create the new group : ${NEW_USER_NAME}"

    useradd --create-home --groups sudo -g ${NEW_USER_NAME} -s /bin/bash ${NEW_USER_NAME}
    handle_command_error $? "Couldn't create the new user : ${NEW_USER_NAME}"

    echo "${NEW_USER_NAME}:${NEW_USER_PASSWORD}"| chpasswd
    handle_command_error $? "Couldn't change the password of the new user : ${NEW_USER_NAME}"

    echo "The user '${NEW_USER_NAME}' has been created" >> ${LOG_FILE}
fi


########
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

SSH_PORT=${SSH_PORT} NEW_USER_NAME=${NEW_USER_NAME} sshPasswordAuthentication=${sshPasswordAuthentication} envsubst < ${SSH_CONFIG_FILE} > /etc/ssh/sshd_config
handle_command_error $? "Couldn't setup SSH"

echo "The SSH service has been configured" >> ${LOG_FILE}

# restart ssh
sudo service sshd restart
echo "The SSH service has been restarted" >> ${LOG_FILE}


#
## Enable public key authentication
#
# Create a ssh key for the new user
# sudo has to be kept as it's the command itself
sudo -u ${NEW_USER_NAME} -- ssh-keygen -t rsa -N "" -f /home/${NEW_USER_NAME}/.ssh/id_rsa
handle_command_error $? "Couldn't create the SSH key for the new user : ${NEW_USER_NAME}"

echo "The ssh key for ${NEW_USER_NAME} has been created and it's stored in '/home/${NEW_USER_NAME}/.ssh/id_rsa'" >> ${LOG_FILE}

# copy the authorized_keys from the config file to the new user ssh folder
cp /home/${NEW_USER_NAME}/.ssh/authorized_keys ${BKP_DIR}
cat ${AUTHORIZED_KEYS_CONFIG_FILE} >> /home/${NEW_USER_NAME}/.ssh/authorized_keys
handle_command_error $? "Couldn't update the authorized_keys file for the new user : ${NEW_USER_NAME}"

echo "The '/home/${NEW_USER_NAME}/.ssh/authorized_keys' has been updated" >> ${LOG_FILE}

# Change the permission on the authorized_keys file
chmod 400 /home/${NEW_USER_NAME}/.ssh/authorized_keys
handle_command_error $? "Couldn't change the access rights for the authorized_keys file of the new user : ${NEW_USER_NAME}"

echo "The '/home/${NEW_USER_NAME}/.ssh/authorized_keys' rights has been updated to 400" >> ${LOG_FILE}

# change the owner of all files/folders present in the new user home folder
chown ${NEW_USER_NAME}:${NEW_USER_NAME} /home/${NEW_USER_NAME} -R
handle_command_error $? "Couldn't change the owner of the new user's home folder to : ${NEW_USER_NAME}"

echo "The owner of all files/folders in /home/${NEW_USER_NAME} has been set to '${NEW_USER_NAME}'" >> ${LOG_FILE}


# Install / Configure fail2ban
if [ "${ENABLE_FAIL2BAN}" == true ]
then
    echo "" >> ${LOG_FILE}
    echo " ------------ " >> ${LOG_FILE}
    echo "" >> ${LOG_FILE}
    echo "fail2ban is not installed, installing it..." >> ${LOG_FILE}
	apt install -y fail2ban
    handle_command_error $? "Couldn't install fail2ban"


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
    handle_command_error $? "Couldn't setup Fail2Ban"

    echo "fail2ban is installed and configured" >> ${LOG_FILE}
fi


###########
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
    handle_command_error $? "Couldn't install ufw"

    echo "ufw installed" >> ${LOG_FILE}
fi

# Disable ipv6
if [ ${ENABLE_IPV6} == "false"  ]
then
    cp /etc/default/ufw ${BKP_DIR}
    ENABLE_IPV6_UFW="no" envsubst < ${UFW_CONFIG_FILE} > /etc/default/ufw
    handle_command_error $? "Couldn't disable iv6 support in ufw"
else
    cp /etc/default/ufw ${BKP_DIR}
    ENABLE_IPV6_UFW="yes" envsubst < ${UFW_CONFIG_FILE} > /etc/default/ufw
    handle_command_error $? "Couldn't enable iv6 support in ufw"
fi

echo "IPV6 has been ${ipv6_status} in the ufw config file" >> ${LOG_FILE}


# Allow SSH port
echo "ufw :: allowing ssh" >> ${LOG_FILE}
ufw allow ${SSH_PORT}

# Enable logging
echo "ufw :: activating logging mechanism" >> ${LOG_FILE}
ufw logging medium

# start the firewall
echo "ufw :: STARTING the service" >> ${LOG_FILE}
echo "y" | ufw enable
handle_command_error $? "Couldn't enable ufw [FIREWALL IS NOT STARTED]"

echo "" >> ${LOG_FILE}
echo " ------------ " >> ${LOG_FILE}
echo "" >> ${LOG_FILE}
echo "ufw is started and it's status is ::" >> ${LOG_FILE}
echo "" >> ${LOG_FILE}

ufw status verbose >> ${LOG_FILE}

echo "" >> ${LOG_FILE}
echo " ------------ " >> ${LOG_FILE}
echo "" >> ${LOG_FILE}


#########
#
### REPORTING / MONITORING
#

# Install sendmail
if [ ${ENABLE_MAIL_REPORTING} == "true" ]
then
    echo "sendmail :: installing" >> ${LOG_FILE}
    apt install -y sendmail
    handle_command_error $? "Couldn't install sendmail"

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
    apt install -y logwatch
    handle_command_error $? "Couldn't install logwatch"

    mkdir -p /var/cache/logwatch/
    handle_command_error $? "Couldn't create logwatch log folder : /var/cache/logwatch/"

    if [[ ${ENABLE_MAIL_REPORTING} == "true" ]]
    then
        outputFormat="mail"
    else
        outputFormat="stdout"
    fi

    outputFormat=${outputFormat} mailTo="${DEST_EMAIL}" mailFrom="logwatch@$(hostname)" envsubst < ${LOGWATCH_CONFIG_FILE} > /etc/logwatch/conf/logwatch.conf
    handle_command_error $? "Couldn't setup logwatch"

fi


# Install cockpit (for monitoring)
if [ ${ENABLE_COCKPIT} == "true" ]
then
    add-apt-repository -y ppa:cockpit-project/cockpit
    handle_command_error $? "Couldn't add the repo for cockpit"

    apt update
    apt install -y cockpit
    handle_command_error $? "Couldn't install cockpit"

    systemctl enable --now cockpit.socket
    handle_command_error $? "Couldn't enable cockpit"
fi


#
### POST CONFIGURATION
#
# Final message
echo ""
echo " $( tput setaf 1 )This server is now SECURE$( tput sgr0 )"
echo ""
echo " REBOOTING "
echo ""
echo " Please wait... "
echo ""

echo "" >> ${LOG_FILE}
echo "This server is now SECURE" >> ${LOG_FILE}
echo "" >> ${LOG_FILE}
echo " REBOOTING... " >> ${LOG_FILE}
echo "" >> ${LOG_FILE}


# send a recap email to the root email address
if [ ${ENABLE_MAIL_REPORTING} == "true" ]
then
#    echo "Subject: Install finished successfully" | /usr/lib/sendmail -v ${ROOT_EMAIL}

    PUBLIC_IP="$( dig +short myip.opendns.com @resolver1.opendns.com )"
    AUTHORIZED_KEYS_CONTENT="$( cat ${AUTHORIZED_KEYS_CONFIG_FILE} )"
    LOG_FILE_CONTENT="$( cat ${LOG_FILE} )"

# fill in the template email
SCRIPT_NAME="$0" \
ROOT_EMAIL="${ROOT_EMAIL}" \
HOST_NAME="$( hostname )" \
PUBLIC_IP="$( dig +short myip.opendns.com @resolver1.opendns.com )" \
INSTALL_DATE="$( date )" \
SSH_PORT="${SSH_PORT}" \
TZ_TO_USE="${TZ_TO_USE}" \
ROOT_PASSWORD="${ROOT_PASSWORD}" \
NEW_USER_NAME="${NEW_USER_NAME}" \
NEW_USER_PASSWORD="${NEW_USER_PASSWORD}" \
DEFAULT_USER_NAME="${DEFAULT_USER_NAME}" \
ENABLE_IPV6="${ENABLE_IPV6}" \
ENABLE_MAIL_REPORTING="${ENABLE_MAIL_REPORTING}" \
DEST_EMAIL="${DEST_EMAIL}" \
ENABLE_FAIL2BAN="${ENABLE_FAIL2BAN}" \
ENABLE_LOGWATCH="${ENABLE_LOGWATCH}" \
ENABLE_COCKPIT="${ENABLE_COCKPIT}" \
AUTHORIZED_KEYS_CONTENT="${AUTHORIZED_KEYS_CONTENT}" \
LOG_FILE_CONTENT="${LOG_FILE_CONTENT}" \
envsubst < ${EMAIL_TEMPLATE} > ./email.recap

# send the email
sendmail -vt < ./email.recap
fi


# Delete default user
if [ "$REMOVE_DEFAULT_USER" == "true" ]
then
    # copy the current folder to the new user's home folder
    cp $(dirname $(realpath $0 )) /home/${NEW_USER_NAME}/

    # remove the default user from the system
    userdel -r -f ${DEFAULT_USER_NAME}
fi

# reboot
reboot

exit 0
