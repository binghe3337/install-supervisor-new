#!/bin/bash
checkRoot()
{
    if [ $UID -ne 0 ]; then
        echo 'Error: Please run as root user.'
        exit 1
    fi
}
checkSupervisor()
{
    supervisorctl --help > /dev/null 2>&1 && { echo 'Error: You have installed supervisor.';exit 1; }
}
checkPython()
{
    python -V > /dev/null 2>&1 || { echo 'Error: dont find python';exit 1; }
    V1=2
    V2=4

    echo need python version is : $V1.$V2 - 2.x
    
    U_V1=`python -V 2>&1|awk '{print $2}'|awk -F '.' '{print $1}'`
    U_V2=`python -V 2>&1|awk '{print $2}'|awk -F '.' '{print $2}'`
    
    echo your python version is : $U_V1.$U_V2
    
    if [ $U_V1 -ne $V1 ];then
        echo 'Error: Your python version is not OK!(1)'
        exit 1
    elif [ $U_V1 -eq $V1 ];then     
        if [ $U_V2 -lt $V2 ];then 
            echo 'Error: Your python version is not OK!(2)'
            exit 1
        fi    
    fi

    echo 'Your python version is OK!'
}
checkPip()
{
    pip -V > /dev/null 2>&1 || { echo 'Error: dont find pip';exit 1; }
}
fileInit()
{
    pip install supervisor
    supervisorctl --help > /dev/null 2>&1 || { echo 'Error: Supervisor installation failed.';exit 1; }
    mkdir -p /etc/supervisor/relative/directory
    echo_supervisord_conf > /etc/supervisor/supervisord.conf
    echo '[include]' >> /etc/supervisor/supervisord.conf
    echo 'files = relative/directory/*.ini' >> /etc/supervisor/supervisord.conf

    echo '[program:sleep]' > /etc/supervisor/relative/directory/sleep.ini
    echo 'command=/bin/sleep 2500' >> /etc/supervisor/relative/directory/sleep.ini
    echo 'autostart=true' >> /etc/supervisor/relative/directory/sleep.ini
    echo 'user=root' >> /etc/supervisor/relative/directory/sleep.ini

    echo '[program:theprogramname]' > /etc/supervisor/relative/directory/templet.ini.bak
    echo 'command=/bin/cat' >> /etc/supervisor/relative/directory/templet.ini.bak
    echo 'startsecs=1' >> /etc/supervisor/relative/directory/templet.ini.bak
    echo 'autostart=true' >> /etc/supervisor/relative/directory/templet.ini.bak
    echo 'user=root' >> /etc/supervisor/relative/directory/templet.ini.bak
    echo ';directory=/tmp' >> /etc/supervisor/relative/directory/templet.ini.bak
    echo ';environment=A="1",B="2"' >> /etc/supervisor/relative/directory/templet.ini.bak
    echo ';redirect_stderr=true' >> /etc/supervisor/relative/directory/templet.ini.bak
    echo ';stdout_logfile=/var/log/theprogramname.log' >> /etc/supervisor/relative/directory/templet.ini.bak
}
command_exists() {
	command -v "$@" >/dev/null 2>&1
}
get_os_info() {
	lsb_dist=''
	dist_version=''
	if command_exists lsb_release; then
		lsb_dist="$(lsb_release -si)"
	fi

	if [ -z "$lsb_dist" ] && [ -r /etc/lsb-release ]; then
		lsb_dist="$(. /etc/lsb-release && echo "$DISTRIB_ID")"
	fi
	if [ -z "$lsb_dist" ] && [ -r /etc/debian_version ]; then
		lsb_dist='debian'
	fi
	if [ -z "$lsb_dist" ] && [ -r /etc/fedora-release ]; then
		lsb_dist='fedora'
	fi
	if [ -z "$lsb_dist" ] && [ -r /etc/oracle-release ]; then
		lsb_dist='oracleserver'
	fi
	if [ -z "$lsb_dist" ] && [ -r /etc/centos-release ]; then
		lsb_dist='centos'
	fi
	if [ -z "$lsb_dist" ] && [ -r /etc/redhat-release ]; then
		lsb_dist='redhat'
	fi
	if [ -z "$lsb_dist" ] && [ -r /etc/photon-release ]; then
		lsb_dist='photon'
	fi
	if [ -z "$lsb_dist" ] && [ -r /etc/os-release ]; then
		lsb_dist="$(. /etc/os-release && echo "$ID")"
	fi

	lsb_dist="$(echo "$lsb_dist" | tr '[:upper:]' '[:lower:]')"

	if [ "${lsb_dist}" = "redhatenterpriseserver" ]; then
		lsb_dist='redhat'
	fi

	case "$lsb_dist" in
		ubuntu)
			if command_exists lsb_release; then
				dist_version="$(lsb_release --codename | cut -f2)"
			fi
			if [ -z "$dist_version" ] && [ -r /etc/lsb-release ]; then
				dist_version="$(. /etc/lsb-release && echo "$DISTRIB_CODENAME")"
			fi
			;;

		debian|raspbian)
			dist_version="$(cat /etc/debian_version | sed 's/\/.*//' | sed 's/\..*//')"
			case "$dist_version" in
				9)
					dist_version="stretch"
					;;
				8)
					dist_version="jessie"
					;;
				7)
					dist_version="wheezy"
					;;
			esac
			;;

		oracleserver)
			lsb_dist="oraclelinux"
			dist_version="$(rpm -q --whatprovides redhat-release --queryformat "%{VERSION}\n" | sed 's/\/.*//' | sed 's/\..*//' | sed 's/Server*//')"
			;;

		fedora|centos|redhat)
			dist_version="$(rpm -q --whatprovides ${lsb_dist}-release --queryformat "%{VERSION}\n" | sed 's/\/.*//' | sed 's/\..*//' | sed 's/Server*//' | sort | tail -1)"
			;;

		"vmware photon")
			lsb_dist="photon"
			dist_version="$(. /etc/os-release && echo "$VERSION_ID")"
			;;

		*)
			if command_exists lsb_release; then
				dist_version="$(lsb_release --codename | cut -f2)"
			fi
			if [ -z "$dist_version" ] && [ -r /etc/os-release ]; then
				dist_version="$(. /etc/os-release && echo "$VERSION_ID")"
			fi
			;;
	esac

	if [ -z "$lsb_dist" ] || [ -z "$dist_version" ]; then
		cat >&2 <<-EOF
		无法确定服务器系统版本信息。
		请联系脚本作者。
		EOF
		exit 1
	fi
}
download_file() {
	local url="$1"
	local file="$2"
	local verify="$3"
	local retry=0
	local verify_cmd=

	verify_file() {
		if [ -z "$verify_cmd" ] && [ -n "$verify" ]; then
			if [ "${#verify}" = "32" ]; then
				verify_cmd="md5sum"
			elif [ "${#verify}" = "40" ]; then
				verify_cmd="sha1sum"
			elif [ "${#verify}" = "64" ]; then
				verify_cmd="sha256sum"
			elif [ "${#verify}" = "128" ]; then
				verify_cmd="sha512sum"
			fi

			if [ -n "$verify_cmd" ] && ! command_exists "$verify_cmd"; then
				verify_cmd=
			fi
		fi

		if [ -s "$file" ] && [ -n "$verify_cmd" ]; then
			(
				set -x
				echo "${verify}  ${file}" | $verify_cmd -c
			)
			return $?
		fi

		return 1
	}

	download_file_to_path() {
		if verify_file; then
			return 0
		fi

		if [ $retry -ge 3 ]; then
			rm -f "$file"
			cat >&2 <<-EOF
			文件下载或校验失败! 请重试。
			URL: ${url}
			EOF

			if [ -n "$verify_cmd" ]; then
				cat >&2 <<-EOF
				如果下载多次失败，你可以手动下载文件:
				1. 下载文件 ${url}
				2. 将文件重命名为 $(basename "$file")
				3. 上传文件至目录 $(dirname "$file")
				4. 重新运行安装脚本

				注: 文件目录 . 表示当前目录，.. 表示当前目录的上级目录
				EOF
			fi
			exit 1
		fi

		( set -x; wget -O "$file" --no-check-certificate "$url" )
		if [ "$?" != "0" ] || [ -n "$verify_cmd" ] && ! verify_file; then
			retry=$(expr $retry + 1)
			download_file_to_path
		fi
	}

	download_file_to_path
}
download_startup_file() {
	local supervisor_startup_file=
	local supervisor_startup_file_url=

	if command_exists systemctl; then

		cat >&2 <<-'EOF'
		Oh! systemctl
		EOF

		supervisor_startup_file='/lib/systemd/system/supervisord.service'
		supervisor_startup_file_url="https://raw.githubusercontent.com/binghe3337/install-supervisor/master/startup/supervisord.systemd"

		download_file "$supervisor_startup_file_url" "$supervisor_startup_file"
		(
			set -x
			systemctl daemon-reload >/dev/null 2>&1
		)
	elif command_exists service; then

		cat >&2 <<-'EOF'
		Oh! service
		EOF

		supervisor_startup_file='/etc/init.d/supervisord'

		get_os_info

		case "$lsb_dist" in
			ubuntu|debian|raspbian)
				supervisor_startup_file_url="https://raw.githubusercontent.com/binghe3337/install-supervisor/master/startup/supervisord.init.debain"
				;;
			fedora|centos|redhat|oraclelinux|photon)
				supervisor_startup_file_url="https://raw.githubusercontent.com/binghe3337/install-supervisor/master/startup/supervisord.init.redhat"
				;;
			*)
				echo "没有适合当前系统的服务启动脚本文件。"
				exit 1
				;;
		esac

		download_file "$supervisor_startup_file_url" "$supervisor_startup_file"
		(
			set -x
			chmod a+x "$supervisor_startup_file"
		)
	else
		cat >&2 <<-'EOF'
		当前服务器未安装 systemctl 或者 service 命令，无法配置服务。
		请先手动安装 systemd 或者 service 之后再运行脚本。
		EOF

		exit 1
	fi
}
start_supervisor() {
	( set -x; sleep 3 )
	if command_exists systemctl; then
		if systemctl status supervisord.service >/dev/null 2>&1; then
			systemctl restart supervisord.service
		else
			systemctl start supervisord.service
		fi
	elif command_exists service; then
		if service supervisord status >/dev/null 2>&1; then
			service supervisord restart
		else
			service supervisord start
		fi
	fi

	if [ "$?" != "0" ]; then
		cat >&2 <<-'EOF'
		启动 Supervisor 失败!
		请反馈给脚本作者。
		EOF
		exit 1
	fi
}

enable_supervisor() {
	if command_exists systemctl; then
		(
			set -x
			systemctl enable "supervisord.service"
		)
	elif command_exists service; then
		if [ -z "$lsb_dist" ]; then
			get_os_info
		fi

		case "$lsb_dist" in
			ubuntu|debian|raspbian)
				(
					set -x
					update-rc.d -f supervisord defaults
				)
				;;
			fedora|centos|redhat|oraclelinux|photon)
				(
					set -x
					chkconfig --add supervisord
					chkconfig supervisord on
				)
				;;
			esac
	fi
}
checkRoot
checkSupervisor
checkPython
checkPip
fileInit
download_startup_file
start_supervisor
enable_supervisor
