/**
 * Public library for dl03t_main and other databases.
 */

CREATE extension IF NOT EXISTS adminpack;


CREATE or replace FUNCTION iIF(
    condition boolean,       -- IF condition
    true_result anyelement,  -- THEN
    false_result anyelement  -- ELSE
    -- See https://stackoverflow.com/a/53750984/287948
) RETURNS anyelement AS $f$
  SELECT CASE WHEN condition THEN true_result ELSE false_result END
$f$  LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION iif
  IS 'Immediate IF. Sintax sugar for the most frequent CASE WHEN THEN ELSE END.'
;


-- -- -- -- -- -- -- -- -- -- --
-- Complementar CAST functions:

CREATE FUNCTION ROUND(float,int) RETURNS NUMERIC AS $wrap$
   SELECT ROUND($1::numeric,$2)
$wrap$ language SQL IMMUTABLE;
COMMENT ON FUNCTION ROUND(float,int)
  IS 'Cast for ROUND(float,x). Useful for SUM, AVG, etc. See also https://stackoverflow.com/a/20934099/287948.'
;

CREATE FUNCTION round_minutes(TIMESTAMP WITHOUT TIME ZONE, integer)
RETURNS TIMESTAMP WITHOUT TIME ZONE AS $f$
  SELECT
     date_trunc('hour', $1)
     +  cast(($2::varchar||' min') as interval)
     * round(
         (date_part('minute',$1)::float + date_part('second',$1)/ 60.)::float
         / $2::float
      )
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION round_minutes(TIMESTAMP WITHOUT TIME ZONE, integer)
  IS 'Adaptation for ROUND(time) in minutes. See also https://stackoverflow.com/a/8963684/287948.'
;
CREATE FUNCTION round_minutes(TIMESTAMP WITHOUT TIME ZONE, integer,text) RETURNS text AS $wrap$
  SELECT to_char(round_minutes($1,$2),$3)
$wrap$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION round_minutes(TIMESTAMP WITHOUT TIME ZONE, integer, text)
  IS 'Wrap function for to_char( round_minutes() ).'
;

CREATE or replace FUNCTION text_to_boolean(x text, as_null boolean DEFAULT NULL) RETURNS boolean AS $f$
  SELECT CASE
    WHEN s IS NULL OR s IN ('','null','empty') THEN as_null -- NULL or false
    WHEN s IN ('0','false','no','not') THEN false
    ELSE true
  END
  FROM (SELECT lower(x)) t(s)
$f$ language SQL immutable;

CREATE or replace FUNCTION json_array_totext(json) RETURNS text[] AS $f$
  SELECT COALESCE(
    array_agg(x),
    CASE WHEN $1 is null THEN null ELSE ARRAY[]::text[] END
    )
  FROM json_array_elements_text($1) t(x);
$f$ LANGUAGE sql IMMUTABLE;
COMMENT ON FUNCTION json_array_totext(json)
  IS 'Cast JSON-array to text-array. See https://stackoverflow.com/q/45243186/287948'
;
CREATE or replace FUNCTION jsonb_array_totext(jsonb) RETURNS text[] AS $f$
  SELECT COALESCE(
    array_agg(x),
    CASE WHEN $1 is null THEN null ELSE ARRAY[]::text[] END
    )
  FROM jsonb_array_elements_text($1) t(x);
$f$ LANGUAGE sql IMMUTABLE;
COMMENT ON FUNCTION json_array_totext(json)
  IS 'Cast JSONb-array to text-array. See https://stackoverflow.com/q/45243186/287948'
;

CREATE or replace FUNCTION  jsonb_keys_to_vals(
  j jsonb, keys text[]
) RETURNS jsonb AS $f$
  SELECT jsonb_agg(j->x) FROM unnest(keys) t(x)
$f$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION  jsonb_objslice(
    key text, j jsonb, rename text default null
) RETURNS jsonb AS $f$
    SELECT COALESCE( jsonb_build_object( COALESCE(rename,key) , j->key ), '{}'::jsonb ) 
$f$ LANGUAGE SQL IMMUTABLE;  -- complement is f(key text[], j jsonb, rename text[])
COMMENT ON FUNCTION jsonb_objslice(text,jsonb,text)
  IS 'Get the key as encapsulated object, with same or changing name.'
;
 
-- -- -- -- -- -- -- -- -- -- --
-- FILE SYSTEM helper functions:

CREATE or replace FUNCTION pg_read_file(f text, missing_ok boolean) RETURNS text AS $$
  SELECT pg_read_file(f,0,922337203,missing_ok) -- max. of ~800 Mb or 880 MiB = 0.86 GiB
   -- missing_ok: if true, the function returns NULL; if false, an error is raised.
   -- GAMBI, ver https://stackoverflow.com/q/63299550/287948
   -- ou usar jsonb_read_stat_file()
$$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION pg_read_file(text,boolean)
  IS 'Simplified pg_read_file(). For GeoJSON preffer jsonb_read_stat_file(). DANGER FOR BIG FILES, please review it.'
;

CREATE or replace FUNCTION jsonb_read_stat_file(
  f text,   -- absolute path and filename
  missing_ok boolean DEFAULT false -- an error is raised, else (if true), the function returns NULL when file not found.
) RETURNS JSONb AS $f$
  SELECT j || jsonb_build_object( 'file',f,  'content',pg_read_file(f)::JSONB )
  FROM to_jsonb( pg_stat_file(f,missing_ok) ) t(j)
  WHERE j IS NOT NULL
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION jsonb_read_stat_file(text,boolean)
  IS 'Same as pg_read_file() but augmented with JSONb parse and pg_stat_file() metadata.'
;

CREATE or replace FUNCTION geojson_readfile_headers(
    f text,   -- absolute path and filename
    missing_ok boolean DEFAULT false -- an error is raised, else (if true), the function returns NULL when file not found.
) RETURNS JSONb AS $f$
  SELECT j || jsonb_build_object( 'file',f,  'content_header', pg_read_file(f)::JSONB - 'features' )
  FROM to_jsonb( pg_stat_file(f,missing_ok) ) t(j)
  WHERE j IS NOT NULL
$f$ LANGUAGE SQL;

-- drop  FUNCTION geojson_readfile_features;
CREATE or replace FUNCTION geojson_readfile_features(f text) RETURNS TABLE (
  fname text, feature_id int, geojson_type text,
  feature_type text, properties jsonb, geom geometry
) AS $f$
   SELECT fname, (ROW_NUMBER() OVER())::int -- feature_id,
          geojson_type, feature->>'type'    -- feature_type,
          jsonb_objslice('name',feature) || feature->'properties', -- properties and name. 
          -- see CRS problems at https://gis.stackexchange.com/questions/60928/
          ST_GeomFromGeoJSON(  crs || (feature->'geometry')  ) AS geom
   FROM (
      SELECT j->>'file' AS fname,
             jsonb_objslice('crs',j) AS crs,
             j->>'type' AS geojson_type,
             jsonb_array_elements(j->'features') AS feature
      FROM ( SELECT pg_read_file(f)::JSONb AS j ) jfile
   ) t2
$f$ LANGUAGE SQL;
COMMENT ON FUNCTION geojson_readfile_features(text)
  IS 'Reads a small GeoJSON file and transforms it into a table with a geometry column.'
;

CREATE or replace FUNCTION geojson_readfile_features_jgeom(file text, file_id int default null) RETURNS TABLE (
  file_id int, feature_id int, feature_type text, properties jsonb, jgeom jsonb
) AS $f$
   SELECT file_id, (ROW_NUMBER() OVER())::int AS subfeature_id,
          subfeature->>'type' AS subfeature_type,
          subfeature->'properties' AS properties,
          crs || subfeature->'geometry' AS jgeom
   FROM (
      SELECT j->>'type' AS geojson_type,
             jsonb_objslice('crs',j) AS crs,
             jsonb_array_elements(j->'features') AS subfeature
      FROM ( SELECT pg_read_file(file)::JSONb AS j ) jfile
   ) t2
$f$ LANGUAGE SQL;
COMMENT ON FUNCTION geojson_readfile_features_jgeom(text,int)
  IS 'Reads a big GeoJSON file and transforms it into a table with a json-geometry column.'
;

CREATE or replace FUNCTION volat_file_write(
  msg text, file text, fcontent text, fopt boolean
) RETURNS text AS $f$
  -- solves de PostgreSQL problem of the "LAZY COALESCE", as https://stackoverflow.com/a/42405837/287948
  SELECT msg||'. Content bytes: '|| pg_catalog.pg_file_write(file,fcontent,fopt)::text
$f$ language SQL volatile;
COMMENT ON FUNCTION volat_file_write
  IS 'Do lazy coalesce. To use in a "only write when null" condiction of COALESCE(x,volat_file_write()).'
;

-- handling of CSV files and its heders:

CREATE or replace FUNCTION pg_csv_head(
  filename text,                 -- the CSV file
  separator text default ',',    -- the CSV separator
  linesize bigint default 9000   -- header maximum size in UTF8 characteres.
) RETURNS text[] AS $f$
  SELECT regexp_split_to_array(s, separator)
  FROM regexp_split_to_table(  pg_read_file(filename,0,linesize,true),  E'\n') t(s)
  LIMIT 1
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION pg_csv_head(text,text,bigint)
  IS 'Devolve array do header de um arquivo CSV com separador estrito, lendo apenas primeiros bytes.'
;

CREATE or replace FUNCTION  pg_csv_head_tojsonb(
  filename text, tolower boolean = false,
  separator text = ',', linesize bigint = 9000,
  is_idx_json boolean = true
) RETURNS jsonb AS $f$
    SELECT  jsonb_object_agg(
      trim( CASE WHEN tolower THEN lower(x) ELSE x END, ' "' ),
      ordinality - CASE WHEN is_idx_json THEN 1 ELSE 0 END
    )
    FROM unnest( pg_csv_head($1,$3,$4) ) WITH ORDINALITY x
$f$ LANGUAGE SQL IMMUTABLE;
-- exemplo, select x from pg_csv_head_tojsonb('/tmp/pg_io/ENDERECO.csv') t(x);
-- ver /home/igor/BR-MG-BeloHorizonte/_pk012/_preservation/makefile
--
-- select jsonb_keys_to_vals(x,array['SIGLA_TIPO_LOGRADOURO','NOME_LOGRADOURO','NUMERO_IMOVEL','LETRA_IMOVEL','GEOMETRIA'])
-- from pg_csv_head_tojsonb('/tmp/pg_io/ENDERECO.csv') t(x);


-- -- -- -- -- -- -- -- -- -- -- -- --
-- Catalog's Regclass helper functions

CREATE or replace FUNCTION pg_tablestruct_dump_totext(
  p_tabname text, p_ignore text[] DEFAULT NULL, p_add text[] DEFAULT NULL
) RETURNS text[]  AS $f$
  SELECT array_agg(col||' '||datatype) || COALESCE(p_add,array[]::text[])
  FROM (
    SELECT -- attrelid::regclass AS tbl,
           attname            AS col
         , atttypid::regtype  AS datatype
    FROM   pg_attribute
    WHERE  attrelid = p_tabname::regclass  -- table name, optionally schema-qualified
    AND    attnum > 0
    AND    NOT attisdropped
    AND    ( p_ignore IS null OR NOT(attname=ANY(p_ignore)) )
    ORDER  BY attnum
  ) t
$f$ language SQL IMMUTABLE;
COMMENT ON FUNCTION pg_tablestruct_dump_totext
  IS 'Extraxcts column descriptors of a table. Used in ingest.fdw_generate_getclone() function. Optional adds to the end.'
;

CREATE or replace FUNCTION lexname_to_unix(p_lexname text) RETURNS text AS $$
  SELECT string_agg(initcap(p),'') FROM regexp_split_to_table($1,'\.') t(p)
$$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION lexname_to_unix(text)
  IS 'Convert URN LEX jurisdiction string to camel-case filename for Unix-like file systems.'
;
