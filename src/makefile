##
## Instalador Geral (make all) e instrucoes específicas (make x).
##

## -- -- VARS -- --

iniExts  = "CREATE EXTENSION IF NOT EXISTS hstore; CREATE EXTENSION IF NOT EXISTS postgis;"

## -- -- RULES -- --

ini_all: ini_database_list_tmp ini_step1 ini_step2 ini_step3_optim clean

ini_database_list_tmp:
	mkdir -p /tmp/pg_io
	psql -lqt | cut -d \| -f 1 > /tmp/pg_io/database_list_tmp.txt


ini_step1: ini_database_list_tmp  make-step1.~feito
	bash make-step1.sh
	touch make-step1.~feito

ini_step2: ini_step1
	psql dl03t_main -c "CREATE SCHEMA IF NOT EXISTS Optim"
	psql dl03t_main -c $(iniExts)
	psql ingest1    -c $(iniExts)
	psql ingest2    -c $(iniExts)

ini_step3_optim: ini_step4_terms
	@echo "Creating optim schema and its libs at DL03t_main database"
	psql dl03t_main < ./optim-step1-ini.sql

ini_step4_terms: /opt/gits/sql-term/makefile
	@echo "se nao tem /opt/gits/sql-term precisa criar, senao git pull do sql-term"

ini_step6_pgrestUp: dkr_03t_main dkr_04s_main
	@echo "PostgREST Dockers up"

## DOCKERS:

dkr_03t_main: docker-compose.yml
	docker-compose  up -d  pgrestDL03

dkr_04s_main: docker-compose.yml
	docker-compose  up -d  pgrestDL04


## ECLUSA do Igor, comandos usualmente executados pelo root no crontab:
ecl_igorFiles: ecl_igorFiles_step1_hashes ecl_igorFiles_step2_copy

ecl_igorFiles_step1_hashes:
  psql "postgres://postgres@localhost/dl03t_main" -c "select eclusa.cityfolder_runhashes('/home/igor')"
	sh /tmp/pg_io/runHashes.sh

ecl_igorFiles_step2_copy:
	psql "postgres://postgres@localhost/dl03t_main" -c "select eclusa.cityfolder_run_cpfiles('igor')"
	sh /tmp/pg_io/runCpFiles.sh

#falta ecl_enioFiles_step3_insert: conclue o proceso de insert dos casos válidos de pré-preservação

## ECLUSA do ENIO, comandos usualmente executados pelo root no crontab:
ecl_enioFiles: ecl_enioFiles_step1_hashes ecl_enioFiles_step2_copy

ecl_enioFiles_step1_hashes:
  psql "postgres://postgres@localhost/dl03t_main" -c "select eclusa.cityfolder_runhashes('/home/enio')"
	sh /tmp/pg_io/runHashes.sh

ecl_enioFiles_step2_copy:
	psql "postgres://postgres@localhost/dl03t_main" -c "select eclusa.cityfolder_run_cpfiles('enio')"
	sh /tmp/pg_io/runCpFiles.sh

#falta ecl_enioFiles_step3_insert: conclue o proceso de insert dos casos válidos de pré-preservação

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
	@echo "-- API database DL05_api:"
	psql dl05_api   -c "\dn"
