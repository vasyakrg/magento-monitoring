#!/bin/bash

source .env

# Set env
DATE=`date +%Y-%m-%d_%H%M`

IFS=$'\r\n' command eval "SITES=($(cat ${SCRIPT_DIR}/sites.list))"

for SITE in ${SITES[*]}
  do
    if [ ! -d ${BACKUP_DIR}/site/${SITE} ]; then
      mkdir -p ${BACKUP_DIR}/site/${SITE}
    fi

    FILE=${BACKUP_DIR}/site/${SITE}/${SITE}_files_${DATE}.tar.gz
    echo ">>> [ SITES ]" >> ${SCRIPT_DIR}/log.out
    echo ">>> backup $FILE" >> ${SCRIPT_DIR}/log.out

    echo "tar -czf $FILE ${WWW_FOLDER}/${SITE}"
    tar -czf $FILE ${WWW_FOLDER}/${SITE} > /dev/null
  done

echo ">>> [ SITES ]" >> ${SCRIPT_DIR}/log.out
exit 0
