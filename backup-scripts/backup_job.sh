#!/bin/bash

[ ! -f .env ] && {
  cp .env.example .env
  touch log.out
  touch db.list
  touch sites.list

  exit 1
}

source .env

DATA=`date +%Y-%m-%d_%H%M`

echo "$DATA <<< start backup" >> ${SCRIPT_DIR}/log.out

${SCRIPT_DIR}/backup_nginx_conf.sh
${SCRIPT_DIR}/backup_db.sh
${SCRIPT_DIR}/backup_web.sh
${SCRIPT_DIR}/backup_upload.sh


[[ $DELETE_OLD == true ]] && {
  echo "$DATA >>> clear old"
  find ${BACKUP_DIR}/ -type f -mtime +${DELETE_DAYS} -delete
}

[ ! -z ${ALARM_KEY} ] && curl -fsS -m 10 --retry 5 -o /dev/null https://hc-ping.com/${ALARM_KEY}

DATA=`date +%Y-%m-%d_%H%M`
echo "$DATA <<< done backup" >> ${SCRIPT_DIR}/log.out
