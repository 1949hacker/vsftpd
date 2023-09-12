#!/bin/bash
set -x

if [ "$1" = "vsftpd" ]; then
	VSFTPDDIR="/etc"
	PIDDIR="/var/run/vsftpd"
	LOGDIR="/var/log/vsftpd"
	SECURECHROOTDIR="/var/run/vsftpd/empty"
	PRIVATEKEY_FILE="/etc/ssl/private/vsftpd.key"
	CERTIFICATE_FILE="/etc/ssl/certs/vsftpd.crt"
	CSR_FILE="/etc/ssl/certs/vsftpd.csr"

	if [ -z "$FTP_SERVER_NAME" ]; then
		export FTP_SERVER_NAME="Welcome to My FTP service"
	fi

	if [ -z "$FTP_REPOSITORY" ]; then
		export FTP_REPOSITORY="/srv_volume"
	fi

	if [ -z "$FTP_USER" ]; then
		export FTP_USER="admin"
	fi

	if [ -z "$FTP_PASSWORD" ]; then
		export FTP_PASSWORD="$(cat /dev/urandom | tr -dc A-Z-a-z-0-9 | head -c 18)"
	fi

	if [ -z "$PASV_ADDRESS" ]; then
		export PASV_ADDRESS="$(tail -n 1 /etc/hosts | awk '{print $1}')"
	fi

	if [ -z "$PASV_PROMISCUOUS" ]; then
		export PASV_PROMISCUOUS="false"
	fi

	if [ -z "$PASV_MIN_PORT" ]; then
		export PASV_MIN_PORT="4559"
	fi

	if [ -z "$PASV_MAX_PORT" ]; then
		export PASV_MAX_PORT="4564"
	fi

	if [ -z "$USESSL" ]; then
		export USESSL="false"
	fi

	if [ -z "$FORCESSL" ]; then
		export FORCESSL="false"
	fi

	EXIST=1
	grep -qw ^"$FTP_USER" /etc/passwd || EXIST=0

	if [ "$EXIST" -eq 0 ]; then
		# Neccesary directories creation
		mkdir -p "$LOGDIR" "$PIDDIR" "$SECURECHROOTDIR"

		# VSFTPd log file creation
		touch "${LOGDIR}"/vsftpd.log
		touch "${LOGDIR}"/xferlog.log

		# User creation / configuration
		useradd -c "User for send files using vSFTPD" -d "$FTP_REPOSITORY" -m "$FTP_USER" &> /dev/null && echo "FTP user creation [ OK ]" || exit 2
		chown "$FTP_USER". "$FTP_REPOSITORY" &> /dev/null && echo "FTP user directory configuration [ OK ]" || exit 2
		echo -e "$FTP_PASSWORD\\n$FTP_PASSWORD" | passwd "$FTP_USER" &> /dev/null && echo "FTP user password configuration [ OK ]" || exit 2

		sed -i "s/PASV_ADDRESS_CUSTOM/$PASV_ADDRESS/g" "${VSFTPDDIR}/vsftpd.conf"
		sed -i "s/FTP_SERVER_NAME_CUSTOM/$FTP_SERVER_NAME/g" "${VSFTPDDIR}/vsftpd.conf"

		if [ "$PASV_PROMISCUOUS" == "true" ]; then
			echo "pasv_promiscuous=YES" >> "${VSFTPDDIR}/vsftpd.conf"
		fi

		{
			echo "pasv_min_port=$PASV_MIN_PORT"
			echo "pasv_max_port=$PASV_MAX_PORT"
		} >> "${VSFTPDDIR}/vsftpd.conf"

		if [ "$USESSL" == "true" ]; then
			{
				echo "ssl_enable=YES"
				echo "allow_anon_ssl=NO"
				echo "ssl_tlsv1=NO"
				echo "ssl_sslv2=NO"
				echo "ssl_sslv3=NO"
				echo "rsa_cert_file=$CERTIFICATE_FILE"
				echo "rsa_private_key_file=$PRIVATEKEY_FILE"
			} >> "${VSFTPDDIR}/vsftpd.conf"

			if [ -z "$SSL_CERTIFICATE" ]; then
				openssl genrsa -out "$PRIVATEKEY_FILE" 4096 &> /dev/null && echo "Private key generate [ OK ]" || exit 2
				openssl req -subj "/CN=$HOSTNAME/C=ES/ST=Catalunya/L=Barcelona/O=Arroyof Solutions/OU=Sistemas/emailAddress=enzo@arroyof.com" -sha256 -new -key "$PRIVATEKEY_FILE" -out "$CSR_FILE" &> /dev/null && echo "CSR generate [ OK ]" || exit 2
				openssl x509 -req -days 365 -in "$CSR_FILE" -signkey "$PRIVATEKEY_FILE" -sha256 -out "$CERTIFICATE_FILE" &> /dev/null && echo "Self-signed certificate generate [ OK ]" || exit 2
			fi
		fi

		if [ "$FORCESSL" == "false" ]; then
			{
				echo "force_local_logins_ssl=NO"
				echo "force_local_data_ssl=NO"
			} >> "${VSFTPDDIR}/vsftpd.conf"
		fi

		touch "${VSFTPDDIR}/vsftpd.user_list"
	fi

	# VSFTPd standard log container redirection
	tail -f "${LOGDIR}"/vsftpd.log | tee /dev/stdout &
	tail -f "${LOGDIR}"/xferlog.log | tee /dev/stdout &

cat << EOB

****************************************************
*                                                  *
*    Docker image: oscarenzo/vsftpd                *
*    https://gitlab.com/docker-files1/vsftpd       *
*                                                  *
****************************************************

SERVER SETTINGS
---------------
· FTP host: $PASV_ADDRESS
· FTP user: $FTP_USER
· FTP password: $FTP_PASSWORD
· PATH: $FTP_REPOSITORY
· Promiscuous: $PASV_PROMISCUOUS
· SSL enabled: $USESSL
· SSL forced: $FORCESSL
---------------

EOB

"$@" "${VSFTPDDIR}/vsftpd.conf" &
pid="${!}"
wait "${pid}"
fi
