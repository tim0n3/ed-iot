#!/bin/bash

set -e

function getCurrentDir() {
    local current_dir="${BASH_SOURCE%/*}"
    if [[ ! -d "${current_dir}" ]]; then current_dir="$PWD"; fi
    echo "${current_dir}"
}

function includeDependencies() {
    # shellcheck source=./setupLibrary.sh
    source "${current_dir}/setupLibrary.sh"
}

current_dir=$(getCurrentDir)
includeDependencies
output_file="output.log"

function main() {
    read -rp "Enter the username of the new user account:" username

    promptForPassword

    # Run setup functions
    trap cleanup EXIT SIGHUP SIGINT SIGTERM

    addUserAccount "${username}" "${password}"

    read -rp $'Paste in the public SSH key for the new user:\n' sshKey
    echo 'Running setup script...'
    logTimestamp "${output_file}"

    exec 3>&1 >>"${output_file}" 2>&1
    disableSudoPassword "${username}"
    addSSHKey "${username}" "${sshKey}"
    changeSSHConfig
    setupUfw

    if ! hasSwap; then
        setupSwap
    fi

    setupTimezone

    echo "Installing Network Time Protocol... " >&3
    configureNTP

    sudo service ssh restart

    cleanup

    echo "Setup Done! Log file is located at ${output_file}" >&3
}

function setupSwap() {
    createSwap
    mountSwap
    tweakSwapSettings "10" "50"
    saveSwapSettings "10" "50"
}

function hasSwap() {
    [[ "$(sudo swapon -s)" == *"/swapfile"* ]]
}

function cleanup() {
    if [[ -f "/etc/sudoers.bak" ]]; then
        revertSudoers
    fi
}

function logTimestamp() {
    local filename=${1}
    {
        echo "===================" 
        echo "Log generated on $(date)"
        echo "==================="
    } >>"${filename}" 2>&1
}

function setupTimezone() {
    echo -ne "Enter the timezone for the server (Default is 'Africa/Johannesburg'):\n" >&3
    read -r timezone
    if [ -z "${timezone}" ]; then
        timezone="Africa/Johannesburg"
    fi
    setTimezone "${timezone}"
    echo "Timezone is set to $(cat /etc/timezone)" >&3
}

# Keep prompting for the password and password confirmation
function promptForPassword() {
   PASSWORDS_MATCH=0
   while [ "${PASSWORDS_MATCH}" -eq "0" ]; do
       read -s -rp "Enter new UNIX password:" password
       printf "\n"
       read -s -rp "Retype new UNIX password:" password_confirmation
       printf "\n"

       if [[ "${password}" != "${password_confirmation}" ]]; then
           echo "Passwords do not match! Please try again."
       else
           PASSWORDS_MATCH=1
       fi
   done 
}

function _is_mik() {
	echo -e "Configuring network settings:\n"
	read -n1 -p "Are you using a MikroTik LTE device (y/n):" networksettings
	case ${networksettings:0:1} in
	y|Y )
		echo "Configuring MikroTik static network client on iface eth0"
		cat <<EOF >> /etc/dhcpcd.conf
		# define static profile\n
		interface eth0\n
		# MikroTik eth0 configuration\n
		static ip_address=192.168.88.200/24\n
		static routers=192.168.88.1\n
		static domain_name_servers=192.168.88.1\n
		static domain_name_servers=8.8.8.8\n
EOF
		;;
		n|N )
		echo "configuring eth0 iface for Modbus TCP with ip 192.168.0.200\n"
		cat <<EOF >> /etc/dhcpcd.conf
			# define static profile
			interface eth1
			static ip_address=192.168.0.200/24
EOF
		;;
		* )
			echo Answer Y | y || N | n only ;
			_is_mik
		;;
	esac
}

_modem_service_install() {
	read -n1 -p "Install modem & watchdog service? (y/n):" serviceinstall
	case ${serviceinstall:0:1} in
	y|Y )
		echo "--------------------------------------"
		echo "--   SystemV service install        --"
		echo "--------------------------------------"
		cp /home/pi/app/energydrive.service /etc/systemd/system/energydrive.service ;
		cp /home/pi/app/watchdog.service /etc/systemd/system/watchdog.service ;
		systemctl enable energydrive.service ;
		systemctl stop energydrive.service ;
		systemctl enable watchdog.service ;
		systemctl stop watchdog.service ;
##ubuntu
		#cp /home/ubuntu/app/energydrive.service /etc/systemd/system/energydrive.service ;
		#cp /home/ubuntu/app/watchdog.service /etc/systemd/system/watchdog.service ;
		#systemctl enable energydrive.service ;
		#systemctl stop energydrive.service ;
		#systemctl enable watchdog.service ;
		#systemctl stop watchdog.service ;

	;;
	n|N )
		echo "You've opted to install the services later"
	;;
	esac
}

_create_crontabs() {
	echo "--------------------------------------"
	echo "--        Creating crontabs:        --"
	echo "--------------------------------------"
	cat <<EOF | crontab -
	@daily  /sbin/shutdown -r +5
	@hourly /bin/bash /home/pi/AutoPai/check-internet.sh
EOF
	echo "--------------------------------------"
	echo "--        Crontabs created          --"
	echo "--------------------------------------"
}

_record_serialno() {
	echo "--------------------------------------"
	echo "--       Store serialnumber         --"
	echo "--------------------------------------"
	sudo bash ./rpi-serialno.sh
}

_iot_core_reminder() {
	echo "--------------------------------------"
	echo "-- Paste the RSA cert into IoT Core --"
	echo "--------------------------------------"
	echo -e "and remember to update the parameters of the config.json and iot-core-config.json files respectively!!!\n"
	cat /home/pi/app/rsa_cert.pem & sleep 10
	echo -e "\nDone!\n"
}

_controls_key() {
	echo "
	----------------------------------------------------------
	-- Some useful commands for the modem software:         --
	-- restart the main service:                            --
	-- sudo systemctl restart energydrive.service           --
	--                                                      --
	-- restart the watchdog service:                        --
	-- sudo systemctl restart watchdog.service              --
	--                                                      --
	-- view all the running services on the Pi:             --
	-- systemctl list-units --type service | grep running   --
	--                                                      --
	-- View journal output of the main modem service:       --
	-- sudo journalctl -f -u energydrive.service            --
	----------------------------------------------------------
"
}

function _post_install_reboot() {
	echo "Reboot the Pi now?" && sleep 2
	read -n1 -p "(y/n) :" reboot
	case ${reboot:0:1} in
		y|Y )
			echo "Rebooting the Pi now"
			echo "going down in 30..." && sleep 10
			echo "going down in 20..." && sleep 10
			echo "going down in 10..." && sleep 5
			echo "going down in 5..." && sleep 1
			echo "going down in 4..." && sleep 1
			echo "going down in 3..." && sleep 1
			echo "going down in 2..." && sleep 1
			echo "bye bye" && sleep 1
			sudo reboot now
		;;
		n|N )
			echo "Script Pi version is complete."
		;;
		* )
			echo Answer Y | y || N | n only ! ;
			_post_install_reboot
		;;
	esac
}

_dependancy_install() {
	echo "Installing git to clone the AutoPai repo"
	sudo apt update -yqq ;
	sudo apt install git -yqq ;
	git clone https://github.com/tim0n3/AutoPai.git ;
	cd AutoPai ;
	chmod +x *.sh ;
}

_is_pi() {
	echo "running AutoPi.sh and linked scripts"
	bash AutoPi.sh
}

_is_moxa() {
	echo "running AutoMoxa.sh and linked scripts"
	bash AutoMoxa.sh
}

function _start() {
	echo "Check if using Pi or moxa:"
	read -n1 -p "Is this a Pi or a Moxa? (y=Pi/n=moxa) (y/n) :" ispi
	case ${ispi:0:1} in
		y|Y )
			echo " Device is Raspberry Pi "
			echo " Using Pi-scripts "
			_is_pi
		;;
		n|N )
			echo " \n Device is Moxa \n"
			echo "Using Moxa-scripts \n"
			_is_moxa
		;;
		* )
			echo Answer Y | y || N | n only ;
			_start
		;;
	esac
}

main
_run_firewall_setup_script
_create_vdev_mapping
_is_mik
_modem_service_install
_create_crontabs
_record_serialno
_iot_core_reminder
_controls_key
_post_install_reboot
_dependancy_install
_start
