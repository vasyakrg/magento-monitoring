#!/bin/bash

source .env

# Set env
DATE=`date +%Y-%m-%d_%H%M`

FILE=${BACKUP_DIR}/configs/configs_${DATE}.tar.gz

[ ! -d ${BACKUP_DIR}/configs ] && mkdir -p ${BACKUP_DIR}/configs

echo ">>> [ CONFIG ]" >> ${SCRIPT_DIR}/log.out
echo ">>> backup $FILE" >> ${SCRIPT_DIR}/log.out

tar -czf $FILE ${NGINX_CONF} > /dev/null

echo "<<< [ CONFIG ]" >> ${SCRIPT_DIR}/log.out
exit 0
