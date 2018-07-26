# install-supervisor-new
Install and configure the supervisor.


一键安装脚本：<br>
wget https://raw.githubusercontent.com/binghe3337/install-supervisor-new/master/setup_sv.sh<br>
chmod +x setup_sv.sh<br>
./setup_sv.sh<br>

Supervisor 相关命令：<br>
1、service supervisord {start|stop|restart|status}<br>
例如：service supervisord status<br>
2、supervisorctl {start|stop|restart|status} [项目名称]<br>
例如：supervisorctl status sleep<br>
