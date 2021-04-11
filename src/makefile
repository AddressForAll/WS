##
## Instalador Geral (make all) e instrucoes específicas (make x).
##

## -- -- VARS -- --

pg_io   =/tmp/pg_io
pg_uri  =postgres://postgres@localhost
iniExts ="CREATE EXTENSION IF NOT EXISTS hstore; CREATE EXTENSION IF NOT EXISTS postgis;"

## -- -- RULES -- --

ini_all: ini_database_list_tmp ini_step1 ini_step2 ini_step3_api ini_step4_optim optim_step1 clean

ini_tmprefresh:
	whoami
	@echo "Run with sudo! (idempotent)"
	mkdir -p $(pg_io)
	mkdir -p $(pg_io)/digital-preservartion-XX
	chmod -R 776  $(pg_io)
	chown -R postgres:postgres $(pg_io)/
	touch /opt/lock-mkStatus/tmp-makeStep00.~feito

ini_database_list_tmp: /opt/lock-mkStatus/tmp-makeStep00.~feito  # not sudor
	psql -lqt | cut -d \| -f 1 > $(pg_io)/database_list_tmp.txt

ini_step1: ini_database_list_tmp
	rm /opt/lock-mkStatus/*~feito
	bash mk-ini_step1.sh
	touch /opt/lock-mkStatus/WS-makeStep01.~feito

ini_step2: ini_step1 /opt/lock-mkStatus/WS-makeStep01.~feito
	psql $(pg_uri)/dl03t_main -c "CREATE SCHEMA IF NOT EXISTS Optim"
	psql $(pg_uri)/dl03t_main -c $(iniExts)
	psql $(pg_uri)/ingest1    -c $(iniExts)
	psql $(pg_uri)/ingest2    -c $(iniExts)
	touch /opt/lock-mkStatus/WS-makeStep02.~feito

ini_step3_api: /opt/lock-mkStatus/WS-makeStep02.~feito
	psql $(pg_uri)/dl03t_main < step01-iniApi.sql

ini_step4_optim: ini_step4_terms /opt/lock-mkStatus/WS-makeStep02.~feito
	@echo "Creating optim schema and its libs at DL03t_main database"
	#psql dl03t_main < ./optim-step1-ini.sql

ini_step5_terms: /opt/gits/sql-term/makefile
	@echo "se nao tem /opt/gits/sql-term precisa criar, senao git pull do sql-term. Execute o make."

ini_step6_pgrestUp: dkr_03t_main dkr_04s_main
	@echo "PostgREST Dockers up"

## Optim core:

optim_step1: optim-step1-ini.sql /opt/lock-mkStatus/WS-makeStep02.~feito
	@echo "Schema optim, core initialization (só roda com usuário sudo -u postgres)"
	psql dl03t_main < pubLib.sql
	psql dl03t_main < ingest-step1-ini.sql
	psql dl03t_main < optim-step1-ini.sql
	# bug pois só roda via "sudo su postgres"
	sh $(pg_io)/run_wgets-all.sh
	psql dl03t_main < optim-step2-ins.sql

## DOCKER RULES:

dkr_03t_main: docker-compose.yml
	docker-compose  up -d  pgrestDL03

dkr_04s_main: docker-compose.yml
	docker-compose  up -d  pgrestDL04

dkr_refresh: dkr_refresh_dl03 dkr_refresh_dl04
	@echo "PostgREST functio-return structures refreshed"

dkr_refresh_dl03: /opt/gits/WS/src/docker-compose.yml
	docker-compose -f /opt/gits/WS/src/docker-compose.yml kill -s SIGUSR1 pgrestDL03

dkr_refresh_dl04: /opt/gits/WS/src/docker-compose.yml
	docker-compose -f /opt/gits/WS/src/docker-compose.yml kill -s SIGUSR1 pgrestDL04

## clean all? or by prefix ini_clean, etc.?
clean:
	@echo "Cleaning up..."
	rm $(pg_io)/database_list_tmp.txt

## -- -- AFTER ALL -- --

# incluir aqui chamadas aos shels interativos para inclusão de datasets

status: status_base status_schEtc status_schProd status_disk_abuse

status_docker:
	@echo "run as super-user:"
	whoami
	docker ps -f "status=exited"
	@echo "restart with 'sudo docker container restart (name)'"

status_base:
	psql -c "\l"

status_schEtc:
	@echo "-- database ingest1:"
	psql ingest1    -c "\dn"
	@echo "-- OSM testing database DL01t_osm:"
	psql dl01t_osm  -c "\dn"
	@echo "-- MAIN testing database DL03t_main:"
	psql dl03t_main -c "\dn"

status_schProd:
	@echo "-- -- -- ON-PRODUCTION SCHEMAS -- -- --"
	@echo "-- OSM stable database DL02s_osm:"
	psql dl02s_osm  -c "\dn"
	@echo "-- MAIN stable database DL04s_main:"
	psql dl04s_main -c "\dn"

status_disk_abuse:
	@echo "-- -- -- CHECK disk abuse -- -- --"
	du -h /opt/gits  | grep -v M  | grep -v K
	du -h /var/www   | grep -v M  | grep -v K
	du -h /tmp   | grep -v M  | grep -v K

# # #
dir_ini:
	whoami
	@echo "Run with sudo! (idempotent)"
	mkdir -p /opt/BKPS
	mkdir -p /opt/gits
	mkdir -p /opt/lock-mkStatus

dir_refresh:
	whoami
	@echo "Run with sudo! (idempotent)"
	# opcional seria www-data:www-data
	chown -R postgres:www-data /var/www
	chown -R postgres:www-data /opt/BKPS
	chown -R postgres:www-data /opt/gits
	chown -R postgres:www-data /opt/lock-mkStatus
	# etc
	chmod 774 /opt/BKPS # ou 755
	find /opt/BKPS/* -type d -exec chmod 755 {} \+
	find /opt/BKPS/* -type f -exec chmod 664 {} \+  # ou 674 ou 655
	# etc
	chmod 774 /opt/gits # ou 755
	find /opt/gits/* -type d -exec chmod 774 {} \+
	find /opt/gits/* -type f -exec chmod 664 {} \+  # ou 674 ou 655
	#chmod 755 /opt/gits
	#chmod -R a-x,a=rX,u+w /opt/gits/*
	chmod 755 /opt/lock-mkStatus
	chmod -R a-x,a=rX,u+w /opt/lock-mkStatus/*

## DOC AND HELP
#
#  For chmod help see:
#    https://chmod-calculator.com/
#    https://www.pluralsight.com/blog/it-ops/linux-file-permissions
# ...
# How to commands
#  * avoid find by `chmod -R a-x,a=rX,u+w /var/www/html/*`, need to test.
#  * list all groups by `compgen -g` and all users by `compgen -u`.
#  * check user`s groups by `groups user_name` (or empty for self).
#
