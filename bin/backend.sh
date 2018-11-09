#!/usr/bin/env bash
#设置当前工作目录
if [ "${APP_ENV}" = 'dev' ];then
    workDir='/var/www/html/file.microservice.com'
else
    workDir='/mnt/www/file.microservice.com'
fi

start(){
    pid=$(ps aux|grep "openresty.*${workDir}"|grep -v grep|awk '{print $2}')
    if [ "${pid}" ]; then
        echo $"openresty is already start "
        reload
        exit 0
    fi
    openresty  -p ${workDir} -c ${workDir}/conf/nginx.conf
    echo $"openresty is start"

}

reload(){
    openresty  -p ${workDir} -c ${workDir}/conf/nginx.conf -s reload
    echo $"openresty is reload ok"
}

stop(){
    openresty  -p ${workDir} -c ${workDir}/conf/nginx.conf -s stop
    echo $"openresty is stop"
}

case $1 in
    start)
        start
        ;;
    restart|reload)
        reload
        ;;
    stop)
        stop
        ;;
    *)
    echo $"Usage: $0 {start|stop|restart|reload}"
    exit 1
esac
exit $?
