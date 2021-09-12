##
## Instalador Geral (make all) e instrucoes específicas (make x).
##

## -- -- VARS -- --

opt_lock =/opt/lock-mkStatus
gits     =/opt/gits
pg_io    =/tmp/pg_io
pg_uri   =postgres://postgres@localhost
iniExts  ="CREATE EXTENSION IF NOT EXISTS hstore; CREATE EXTENSION IF NOT EXISTS postgis;"

sites_domains = addressforall.org addressforall.com www.addressforall.org git-raw.addressforall.org api-htm.addressforall.org \
		osms.addressforall.org api.addressforall.org docs.addressforall.org \
		git-raw.osm.codes olc.osm.codes osm.codes www.osm.codes \
		digital-guard.org www.digital-guard.org docs.digital-guard.org \
		docs.itgs.org.br itgs.org.br www.itgs.org.br
sites_protocols =  https http
sites_return_code = 200

## -- -- Functions a revisar -- --
## pode ser INCLUDE!

define ITERATE_DATABASES
# revisar conforme mk-ini_step1.sh que precisaria ser função de array.
arr_databases=("DL03t_main" "DL04s_main" "DL01t_osm" "DL02s_osm" "ingest1" "ingest2" "sandbox") \
for db in "${arr_databases[@]}" \
do \
  echo "-- $db:" \
  if  grep -iqw "$db" /tmp/pg_io/database_list_tmp.txt ; then \
      echo " (base já existe)" \
  else \
      psql postgres://postgres@localhost -c "CREATE DATABASE $db" \
  fi \
done
endef


## -- -- RULES -- --

all:
	@echo "Use primeiro   sudo make ini_basics"
	@echo "Use depois     make ini_all"
	@echo "!Importante para master users:"
	@echo "   sudo usermod -a -G postgres masterUser"
	@echo "   sudo usermod -a -G www-data masterUser"

#ini_all: ini_database_list_tmp ini_step1 ini_step2 ini_step3_api ini_step4_optim optim_step1 clean
ini_all: ini_database_list_tmp ini_step1 ini_step2 ini_step2b_ins clean


ini_basics: dir_refresh ini_tmprefresh
		@echo "-- ok ini basics --"

ini_tmprefresh:  # sudor
	@echo "-- ini_tmprefresh --"
	@echo "Sou root? sou sudo? entre meus grupos tenho postgres?"
	whoami
	groups
	@echo "Run with sudo! (idempotent)"
	mkdir -p $(pg_io)
	mkdir -p $(pg_io)/digital-preservartion-XX
	chmod 777  $(pg_io)
	chmod -f 744  $(pg_io)/*.* || true
	chown -R postgres:postgres $(pg_io)/
	mkdir -p $(opt_lock)
	chmod 777  $(opt_lock)
	@echo "Digite ^C para finalizar ou ENTER para apagar todas as locks *~feito"
	@read _ENTER_
	@# o certo seria rm condicional!
	rm -f $(opt_lock)/*~feito || true
	touch $(opt_lock)/tmp-makeStep00.~feito
	chown -R postgres:www-data $(opt_lock)/
	chmod -f 666  $(opt_lock)/*.* || true
	@echo "... feito o que era preciso como root."

ini_database_list_tmp: $(opt_lock)/tmp-makeStep00.~feito  # not sudor
	@echo "!run before:   sudo make ini_tmprefresh"
	psql $(pg_uri) -lqt | cut -d \| -f 1 > $(pg_io)/database_list_tmp.txt
	chmod 666  $(pg_io)/database_list_tmp.txt

ini_step1: ini_database_list_tmp
	bash mk-ini_step1.sh
	touch $(opt_lock)/WS-makeStep01.~feito
	chmod 666 $(opt_lock)/WS-makeStep01.~feito

ini_step2: ini_step1 $(opt_lock)/WS-makeStep01.~feito
	psql $(pg_uri)/dl03t_main -c "CREATE SCHEMA IF NOT EXISTS Optim"
	psql $(pg_uri)/dl03t_main -c $(iniExts)
	psql $(pg_uri)/ingest1    -c $(iniExts)
	psql $(pg_uri)/ingest2    -c $(iniExts)
	touch $(opt_lock)/WS-makeStep02.~feito
	chmod 666 $(opt_lock)/WS-makeStep02.~feito

ini_step2b_ins: # revisar conforme mk-ini_step1.sh que precisaria ser função de array.
	@echo "------- ingest1 REDO ---------"
	psql $(pg_uri)/ingest1    < pubLib.sql
	psql $(pg_uri)/ingest1    < sys_pubLib.sql
	psql $(pg_uri)/ingest1    < ingest-step1-ini.sql
	@echo "------- ingest2 REDO ---------"
	psql $(pg_uri)/ingest2    < pubLib.sql
	psql $(pg_uri)/ingest2    < sys_pubLib.sql
	psql $(pg_uri)/ingest2    < ingest-step1-ini.sql
	@echo "------- dl03t_main REDO ---------"
	psql $(pg_uri)/dl03t_main < pubLib.sql
	psql $(pg_uri)/dl03t_main < sys_pubLib.sql
	psql $(pg_uri)/dl03t_main < ingest-step1-ini.sql

ini_step3_api: $(opt_lock)/WS-makeStep02.~feito
	psql $(pg_uri)/dl03t_main < step01-iniApi.sql

ini_step4_optim: ini_step4_terms $(opt_lock)/WS-makeStep02.~feito
	@echo "Creating optim schema and its libs at DL03t_main database"
	psql $(pg_uri)/dl03t_main < ./optim-step1-ini.sql

ini_step5_terms: $(gits)/sql-term/makefile
	@echo "se nao tem $(gits)/sql-term precisa criar, senao git pull do sql-term. Execute o make."

ini_step6_pgrestUp: dkr_03t_main dkr_04s_main
	@echo "PostgREST Dockers up"

## Optim core:

optim_step1: optim-step1-ini.sql $(opt_lock)/WS-makeStep02.~feito
	@echo "-- Schema optim, core initialization --"
	@echo "Só roda com usuário 'sudo -u postgres', digite ENTER se ok"
	whoami
	@read _digite_enter_
	psql $(pg_uri)/dl03t_main < pubLib.sql
	psql $(pg_uri)/dl03t_main < ingest-step1-ini.sql
	psql $(pg_uri)/dl03t_main < optim-step1-ini.sql
	# conferir se bug pois só roda via "sudo su postgres"
	sh $(pg_io)/run_wgets-all.sh
	psql $(pg_uri)/dl03t_main < optim-step2-ins.sql

## DOCKER RULES:

dkr_03t_main: docker-compose.yml
	docker-compose  up -d  pgrestDL03

dkr_04s_main: docker-compose.yml
	docker-compose  up -d  pgrestDL04

dkr_refresh: dkr_refresh_dl03 dkr_refresh_dl04
	@echo "PostgREST functio-return structures refreshed"

dkr_refresh_dl03: $(gits)/WS/src/docker-compose.yml
	docker-compose -f $(gits)/WS/src/docker-compose.yml kill -s SIGUSR1 pgrestDL03

dkr_refresh_dl04: $(gits)/WS/src/docker-compose.yml
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
	psql $(pg_uri) -c "\l"

status_schEtc:
	@echo "-- database ingest1:"
	psql $(pg_uri)/ingest1    -c "\dn"
	@echo "-- OSM testing database DL01t_osm:"
	psql $(pg_uri)/dl01t_osm  -c "\dn"
	@echo "-- MAIN testing database DL03t_main:"
	psql $(pg_uri)/dl03t_main -c "\dn"

status_schProd:
	@echo "-- -- -- ON-PRODUCTION SCHEMAS -- -- --"
	@echo "-- OSM stable database DL02s_osm:"
	psql $(pg_uri)/dl02s_osm  -c "\dn"
	@echo "-- MAIN stable database DL04s_main:"
	psql $(pg_uri)/dl04s_main -c "\dn"

status_disk_abuse:
	@echo "-- -- -- CHECK disk usage ABUSE -- -- --"
	@(du -h $(gits)  | grep -v "^[0-9][0-9,\.]*[KM]") || true
	@(du -h /var/www | grep -v "^[0-9][0-9,\.]*[KM]") || true
	@(du -h /tmp     | grep -v "^[0-9][0-9,\.]*[KM]") || true
	@echo "... if no line, it is ok!"

status_sites:
	@for site in $(sites_domains); do \
		for protocol in $(sites_protocols) ; do \
			res=`curl -o /dev/null -s -w "%{http_code}\n" $$protocol://$$site `; \
			if [ "$$res" != "$(sites_return_code)" ] ; then \
				>&2 echo Erro $$res no site $$protocol://$$site; \
			fi ; \
		done ; \
	done

# # #
dir_ini:
	whoami
	@echo "Run with sudo! (idempotent)"
	#mkdir -p /opt/BKPS
	mkdir -p $(gits)
	mkdir -p $(opt_lock)

dir_refresh:
	whoami
	@echo "Run with sudo! (idempotent)"
	# opcional seria www-data:www-data
	chown -R postgres:www-data /var/www
	#chown -R postgres:www-data /opt/BKPS
	chown -R postgres:www-data $(gits)
	chown -R postgres:www-data $(opt_lock)
	# etc
	#chmod 774 /opt/BKPS # ou 755
	#find /opt/BKPS/* -type d -exec chmod 755 {} \+
	#find /opt/BKPS/* -type f -exec chmod 664 {} \+  # ou 674 ou 655
	# etc
	chmod 777 $(gits) # ou 774 ou 755...
	find $(gits)/* -type d -exec chmod 774 {} \+
	find $(gits)/* -type f -exec chmod 664 {} \+  # ou 674 ou 655
	#chmod -R a-x,a=rX,u+w $(gits)/*
	chmod 777 $(opt_lock)
	chmod -Rf a-x,a=rX,u+w $(opt_lock)/* || true

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
