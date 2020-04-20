#!/bin/bash
set -e

echo "Prepare configuration for script"
TIMESTAMP=$(date +%F_%R)
BACKUP_FILE=${DB_NAME}-${TIMESTAMP}.sql
BACKUP_FILE_LATEST=${DB_NAME}-latest.sql.gz
DB_HOST=${DB_HOST:-localhost}
DB_PASSWORD=$(cat ${DB_PASSWORD_FILE})
CREDENTIALFILE=${CREDENTIALFILE:-/srv/gcloud/credentials.json}

if [ -z ${GCS_BUCKET} ]; then
	echo "GCS_BUCKET undefied"
	exit 1
fi

if [ ! -f ${CREDENTIALFILE} ]
then
	echo "Could not find GCloud Service Account credential file under '${CREDENTIALFILE}'"
	echo "Your can set the location by define env['CREDENTIALFILE']"
	exit 1
fi

echo "login to gcloud with SA"
gcloud auth activate-service-account --key-file=/srv/gcloud/credentials.json

# create login credential file
echo "[mysqldump]
password=${DB_PASSWORD}" > ~/.my.cnf
chmod 0600 ~/.my.cnf

echo "Start create backup"
mysqldump -h ${DB_HOST} -u ${DB_USER} -P ${DB_PORT} --single-transaction --dump-date ${DB_NAME} > ${BACKUP_FILE}
if [[ $? -eq 0 ]]; then
    gzip ${BACKUP_FILE}
else 
    echo >&2 "DB backup failed" 
    exit 1
fi

echo "End backup"

## copy to destination
echo "Copy to gcs"
BACKUP_FILE_ARCHIVED=${BACKUP_FILE}.gz
gsutil cp ${BACKUP_FILE_ARCHIVED} gs://${GCS_BUCKET}/${DB_NAME}/${BACKUP_FILE_ARCHIVED} && gsutil cp ${BACKUP_FILE_ARCHIVED} gs://${GCS_BUCKET}/${DB_NAME}/${BACKUP_FILE_LATEST}

if test $? -ne 0 
then
	exit 1;
fi