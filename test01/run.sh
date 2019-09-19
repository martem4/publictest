
#!/bin/bash

export TZ=Europe/Moscow

function change_timezone {
	timedatectl set-timezone $TZ
}

function change_locale {
	locale-gen fr_FR.UTF-8
}

function change_sshd_port {
	sed -i -e 's/.*Port.*22.*/Port 2498/g' /etc/ssh/ssh_config
	systemctl restart ssh
}

function deny_remote_root {
	root_permit=`cat /etc/ssh/ssh_config | grep PermitRootLogin | wc -l`
	if [ $root_permit -gt 0 ]; then
		sed -i -e 's/.*PermitRootLogin.*/PermitRootLogin No/g' /etc/ssh/ssh_config
	else
		echo "PermitRootLogin No" >> /etc/ssh/ssh_config
	fi
        systemctl restart ssh
}

function add_service_user {
	su -c "useradd serviceuser -s /bin/bash -m -g sudo"
}

function deny_service_run_for_user {
	echo -e $'\n'"serviceuser ALL=!/usr/sbin/service" >> /etc/sudoers
}

function deploy_nginx {
	deb http://nginx.org/packages/ubuntu/ $release nginx
	deb-src http://nginx.org/packages/ubuntu/ $release nginx
	apt-get update
	apt-get --assume-yes install nginx
	systemctl enable nginx
	systemctl start nginx
}

function deploy_monit {
	export MMONIT_VERSION=3.7.3
	export MMONIT_DIR=/tmp/mmonit
	export MMONIT_URL=https://mmonit.com/dist/mmonit-$MMONIT_VERSION-linux-x64.tar.gz
	export MMONIT_ARC_NAME=mmonit-$MMONIT_VERSION-linux-x64.tar.gz
	export MMONIT_APP_DIR=$MMONIT_DIR/mmonit-$MMONIT_VERSION

	mkdir -p $MMONIT_DIR
	wget $MMONIT_URL -P $MMONIT_DIR
	cd $MMONIT_DIR
	tar -xvzf $MMONIT_ARC_NAME
	cd $MMONIT_APP_DIR/bin; ./mmonit
}

function nginx_proxy_auth_to_monit {
	apt-get update
        apt-get --assume-yes install apache2-utils
	htpasswd -b -c /etc/nginx/.htpasswd monit tinom
	sed -i -e '/listen 80 default_server;/a location /mmonit {proxy_pass http://localhost:8080; auth_basic "Restricted"; auth_basic_user_file /etc/nginx/.htpasswd;}' /etc/nginx/sites-available/default
	systemctl nginx reload
}


change_timezone
change_locale
change_sshd_port
deny_remote_root
add_service_user
deny_service_run_for_user
deploy_nginx
deploy_monit
nginx_proxy_auth_to_monit

