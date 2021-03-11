#!/bin/bash

source .env

# Set env
DATE=`date +%Y-%m-%d_%H%M`

IFS=$'\r\n' command eval "DBS=($(cat ${SCRIPT_DIR}/db.list))"

echo ">>> [ DB ]" >> ${SCRIPT_DIR}/log.out

for SITE in ${DBS[*]}
  do
    if [ ! -d ${BACKUP_DIR}/site/${SITE} ]; then
      mkdir -p ${BACKUP_DIR}/site/${SITE}
    fi
    DBASE=$(grep dbase ${WWW_FOLDER}/${SITE}/backup.env | cut -f 2 -d '=')
    DBASEUSER=$(grep database_user ${WWW_FOLDER}/${SITE}/backup.env | cut -f 2 -d '=')
    DBASEPASS=$(grep database_password ${WWW_FOLDER}/${SITE}/backup.env | cut -f 2 -d '=')

    FILE=${BACKUP_DIR}/site/${SITE}/${SITE}_dump_${DATE}.sql.gz

    echo ">>> mysqlmump $FILE" >> ${SCRIPT_DIR}/log.out

    mysqldump --user=${DBASEUSER} --password=${DBASEPASS} --host=localhost --routines ${DBASE} | gzip -c > $FILE
  done

echo "<<< [ DB ]" >> ${SCRIPT_DIR}/log.out

exit 0
