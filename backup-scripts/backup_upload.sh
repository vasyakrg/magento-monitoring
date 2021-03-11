#!/bin/bash

source .env
# Set env

IFS=$'\r\n' command eval "DBS=($(cat ${SCRIPT_DIR}/sites.list))"

echo ">>> upload configs nginx"
/usr/bin/b2 sync --keepDays ${B2_KEEP} ${BACKUP_DIR}/configs/ b2://${B2_BACKET}/configs/ >> ${SCRIPT_DIR}/log.b2.out

for SITE in ${SITES[*]}
  do
    echo ">>> upload files from $SITE"
    /usr/bin/b2 sync --keepDays ${B2_KEEP} ${BACKUP_DIR}/site/${SITE}/ b2://${B2_BACKET}/site/${SITE}/ >> ${SCRIPT_DIR}/log.b2.out
  done

IFS=$'\r\n' command eval "DBS=($(cat ${SCRIPT_DIR}/db.list))"

for DB in ${DBS[*]}
  do
    echo ">>> upload db from $DB"
    /usr/bin/b2 sync --keepDays ${B2_KEEP} ${BACKUP_DIR}/site/${DB}/ b2://${B2_BACKET}/site/${DB}/ >> ${SCRIPT_DIR}/log.b2.out
  done

exit 0
