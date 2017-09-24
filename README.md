# Debian / Ubuntu secure_server script
Bash script to secure a server when it has just been installed.

### It will execute the following tasks : 
- Setup the timezone
- Update and fully upgrade the system
- Install and configure the Unattended-upgrades package (to ensure the security updates are automaticly installed)
- Disable IPV6  [Optionnal]
- Setup the /etc/hosts file properly
- Change the root password  [Optionnal]
- Create a new user [Optionnal]
- Remove the default user (ubuntu, pi ...)  [Optionnal]
- Configure ssh properly
- Install and configure fail2ban  [Optionnal]
- Install, configure and enable ufw to handle all the firewalling heavyduty
- Install and configure sendmail for email reporting  [Optionnal]
- Install and configure logwatch for log rotation and log email reporting  [Optionnal]
- Install and configure cockpit for easy monitoring / administration  [Optionnal]
- Send a final email with a resume of all that happened  [Optionnal]


### How to use this
- clone the repo
- edit the secure_server.sh script to set it up the way you want to 
(active/deactivate IPV6 support, enable logwatch, root password...)

- Add your public key to the authorized_keys.config_file to make sure you can connect to your server once it has been secured (password authentication is disabled by default unless you enable cockpit (passwd auth is required by cockpit))

- double check to make sure everything is the way want it
- run the secure_server.sh script
- get yourself a coffee (it can take from 3 to 15mn depending on the server config / internet connection)
- if you see that the server has rebooted, head up to the ssh port you specified in the settings section of the script
- enjoy ;)
