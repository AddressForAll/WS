#!/bin/bash

export PATH=/usr/local/bin/:$PATH

for l in $(seq 15 20) ; do
        dia=$(date -d "-$l days" '+%Y%m%d')
        rclone ls operacao:/wiki/backup-$dia.tar.gz > /dev/null 2>&1
        if [ $? -eq 0 ] ; then
                echo Apagar operacao:/wiki/backup-$dia.tar.gz
                rclone delete operacao:/wiki/backup-$dia.tar.gz
        fi
	ssh carlos@pk21 " if [[ -f /mnt/dados/BACKUP/WIKI/backup-$dia.tar.gz ]] ; then rm /mnt/dados/BACKUP/WIKI/backup-$dia.tar.gz ; fi"
	ssh carlos@www.addressforall.org " if [[ -f ~/WIKI/backup-$dia.tar.gz ]] ; then rm ~/WIKI/backup-$dia.tar.gz ; fi"
done
dia=$(date '+%Y%m%d')

#pg_dump -U postgres -Fc wiki > /tmp/wiki-$dia.dump
mysqldump --host database -u root --password="baEdejELp5ozg" wikidb > /tmp/wikidb-$dia.sql

rm -rf /tmp/workingBackupMediaFiles
mkdir /tmp/workingBackupMediaFiles
php /var/www/html/w/maintenance/dumpBackup.php --full --uploads --include-files  > /tmp/dumpContent.xml
( cd /var/www/html/w/ ; php maintenance/dumpUploads.php  | sed 's~mwstore://local-backend/local-public~./images~'  | xargs cp -t /tmp/workingBackupMediaFiles )
zip -r /tmp/Mediafiles.zip /tmp/workingBackupMediaFiles


tar czf /tmp/backup-$dia.tar.gz /var/www/html/w/ /tmp/wikidb-$dia.sql /tmp/Mediafiles.zip /tmp/dumpContent.xml

rclone copy /tmp/backup-$dia.tar.gz operacao:/wiki
scp /tmp/backup-$dia.tar.gz carlos@pk21:/mnt/dados/BACKUP/WIKI/
scp /tmp/backup-$dia.tar.gz carlos@www.addressforall.org:~/WIKI/

rm -rf /tmp/wikidb-$dia.sql /tmp/backup-$dia.tar.gz /tmp/Mediafiles.zip /tmp/workingBackupMediaFiles /tmp/dumpContent.xml
#rm -rf /tmp/wikidb-$dia.sql /tmp/Mediafiles.zip /tmp/workingBackupMediaFiles /tmp/dumpContent.xml
