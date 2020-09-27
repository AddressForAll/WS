##
## Instalador Geral (make all) e instrucoes específicas (make x).
##

## -- -- VARS -- --

iniExts  = "CREATE EXTENSION IF NOT EXISTS hstore; CREATE EXTENSION IF NOT EXISTS postgis;"

## -- -- RULES -- --

ini_all: ini_database_list_tmp ini_step1 ini_step2 ini_step3_api ini_step4_optim optim_step1 clean

ini_database_list_tmp:
	mkdir -p /tmp/pg_io
	psql -lqt | cut -d \| -f 1 > /tmp/pg_io/database_list_tmp.txt

ini_step1: ini_database_list_tmp
	rm /opt/lock-mkStatus/*~feito
	bash mk-ini_step1.sh
	touch /opt/lock-mkStatus/WS-makeStep01.~feito

ini_step2: ini_step1 /opt/lock-mkStatus/WS-makeStep01.~feito
	psql dl03t_main -c "CREATE SCHEMA IF NOT EXISTS Optim"
	psql dl03t_main -c $(iniExts)
	psql ingest1    -c $(iniExts)
	psql ingest2    -c $(iniExts)
	touch /opt/lock-mkStatus/WS-makeStep02.~feito

ini_step3_api: /opt/lock-mkStatus/WS-makeStep02.~feito
	psql dl03t_main < step01-iniApi.sql

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
	psql dl03t_main < optim-step1-ini.sql
	sh /tmp/pg_io/run_wgets.sh
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
	rm /tmp/pg_io/database_list_tmp.txt

## -- -- AFTER ALL -- --

# incluir aqui chamadas aos shels interativos para inclusão de datasets

status: status_base status_schEtc status_schProd

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
