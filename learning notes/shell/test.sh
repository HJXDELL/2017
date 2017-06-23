#!/usr/bin/env bash
grep 'VALIDATION FAILED' $EC_LOGTOP/api-`date +%Y%m%d --date="yesterday"`.log | cut -d '=' -f2 | cut -d ':' -f1| sort | uniq > accountid.list

OFFLINE_TIMEOUT=$((`date +%s --date="tomorrow"` * 1000))

for aid in `cat accountid.list`;do
mongo localhost:23308/ec -u web -p dev_web <<EOF
db.people.update({"_id" : $aid},{\$set: {"offline_timeout_id_expiration": $OFFLINE_TIMEOUT}});
exit;
EOF
sleep 1
done
~
