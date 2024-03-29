# run for makefile the ini_step1. CREATE all official databases.
# Template para a criação de bases em Portugues do Brasil:
psql postgres://postgres@localhost -c "\
ALTER database template1 is_template=false;\
DROP database template1;\
CREATE DATABASE template1\
WITH OWNER = postgres\
   ENCODING = 'UTF8'\
   TABLESPACE = pg_default\
   LC_COLLATE = 'pt_BR.UTF-8'\
   LC_CTYPE = 'pt_BR.UTF-8'\
   CONNECTION LIMIT = -1\
   TEMPLATE template0;\
ALTER database template1 is_template=true;\
"
# -- ERROR:  DROP DATABASE cannot run inside a transaction block

arr=("DL03t_main" "DL04s_main" "DL01t_osm" "DL02s_osm" "ingest1" "ingest2" "sandbox")
for db in "${arr[@]}"
do
  echo
  echo "-------------- $db: -------------"
  if  grep -iqw "$db" /tmp/pg_io/database_list_tmp.txt ; then
      echo " (base já existe)"
  else
      psql postgres://postgres@localhost -c "CREATE DATABASE $db"
  fi
done
