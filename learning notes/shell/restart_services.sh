#!/usr/bin/env bash
cd /u/username/src/ec
    (node bin/api_server.js >/g/local/devdata/username/log/ec-api.log 2>&1)&
    (node bin/cache_server.js >/g/local/devdata/username/log/ec-cache.log 2>&1)&
    (node bin/sexio.js >/g/local/devdata/username/log/ec-sexio.log 2>&1)&
    (grunt >>/g/local/devdata/username/log/grunt.log 2>&1)&
    sleep 5
    ps -e -o user:30=UID -o pid,ppid,pgid,c,stime,tty=TTY -o time,cmd -H|grep ^$USER|egrep -e "grunt|redis|mongo|node|elastic"|egrep -v -e "grep|tail|emacs|vim" >> ~/ecstatus.log
fi

ps -ef | grep guzzler | grep node

if [ $? -ne 0 ]; then
        (node bin/guzzler.js >/g/local/devdata/username/log/guzzler.log 2>&1)&
fi

ps -ef | grep stats | grep node

if [ $? -ne 0 ];then
        (node bin/stats-server.js > /g/local/devdata/username/log/ec-stats.log 2>&1)&
fi

ps -ef | grep rc-provisioner.js | grep node

if [ $? -ne 0 ]; then
        /g/mnt/devdata/username/ec-node/bin/node /g/mnt/devdata/username/src/ec/bin/rc-provisioner.js &
fi
