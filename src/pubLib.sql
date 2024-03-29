/**
 * Public library for dl03t_main and other databases.
 */

CREATE extension IF NOT EXISTS adminpack;

-- -- -- -- -- -- -- -- -- -- --
-- Helper functions: avoid.

CREATE or replace FUNCTION iIF(
    condition boolean,       -- IF condition
    true_result anyelement,  -- THEN
    false_result anyelement  -- ELSE
    -- See https://stackoverflow.com/a/53750984/287948
) RETURNS anyelement AS $f$
  SELECT CASE WHEN condition THEN true_result ELSE false_result END
$f$  LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION iif
  IS 'Immediate IF. Sintax sugar for the most frequent CASE-WHEN. Avoid with text, need explicit cast.'
;

CREATE or replace FUNCTION array_length(a anyarray) RETURNS integer AS $wrap$
   SELECT array_length(a,1)
$wrap$  LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION array_length(anyarray)
  IS 'Wrap for array_length(A,1).'
;

-- -- -- -- -- -- -- -- -- -- --
-- Complementar CAST functions:

CREATE or replace FUNCTION ROUND(float,int) RETURNS NUMERIC AS $wrap$
   SELECT ROUND($1::numeric,$2)
$wrap$ language SQL IMMUTABLE;
COMMENT ON FUNCTION ROUND(float,int)
  IS 'Cast for ROUND(float,x). Useful for SUM, AVG, etc. See also https://stackoverflow.com/a/20934099/287948.'
;

CREATE or replace FUNCTION round_minutes(TIMESTAMP WITHOUT TIME ZONE, integer)
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
  IS 'Adaptation for ROUND(time) in minutes. Example: round_minutes(t,5). See also https://stackoverflow.com/a/8963684/287948.'
;
CREATE or replace FUNCTION round_minutes(TIMESTAMP WITHOUT TIME ZONE, integer,text) RETURNS text AS $wrap$
  SELECT to_char(round_minutes($1,$2),$3)
$wrap$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION round_minutes(TIMESTAMP WITHOUT TIME ZONE, integer, text)
  IS E'Wrap function for to_char( round_minutes() ). Example round_minutes(t,15,\'HH12:MI\').'
;

CREATE or replace FUNCTION text_to_boolean(x text, as_null boolean DEFAULT NULL) RETURNS boolean AS $f$
  SELECT CASE
    WHEN s IS NULL OR s IN ('','null','empty') THEN as_null -- NULL or false
    WHEN s IN ('0','false','no','not') THEN false
    ELSE true
  END
  FROM (SELECT lower(x)) t(s)
$f$ language SQL immutable;


/*
CREATE or replace FUNCTION array_to_formated_pairs(x text[]) RETURNS text AS $f$
  -- for dynamic query using jsonb_build_object(pairs)
  SELECT array_to_string( array_agg(format('%L,%s',i,i)), ',' )
  FROM unnest(x) t(i)
$f$ language SQL immutable;
see
select a, b, to_jsonb(subq) as info
  from t, lateral (select c, d, e) subq;
*/


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

CREATE or replace FUNCTION  jsonb_object_length(j jsonb) RETURNS int AS $f$
  SELECT COUNT(*)::int FROM jsonb_object_keys(j);
$f$ LANGUAGE SQL IMMUTABLE;

CREATE or replace FUNCTION  jsonb_object_keys_maxlength(j jsonb) RETURNS int AS $f$
  SELECT MAX(length(x))::int FROM jsonb_object_keys(j) t(x)
$f$ LANGUAGE SQL IMMUTABLE;



-- -- -- -- -- -- -- -- -- -- --
-- Extends native functions:

CREATE or replace FUNCTION jsonb_strip_nulls(
  p_input jsonb,      -- any input
  p_ret_empty boolean -- true for normal, false for ret null on empty
) RETURNS jsonb AS $f$
  SELECT CASE
     WHEN p_ret_empty THEN x
     WHEN x='{}'::JSONb THEN NULL
     ELSE x END
  FROM ( SELECT jsonb_strip_nulls(p_input) ) t(x)
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION jsonb_strip_nulls(jsonb,boolean)
  IS 'Extends jsonb_strip_nulls to return NULL instead empty';

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

CREATE or replace FUNCTION jsonb_pg_stat_file(
  f text,   -- filename with absolute path
  add_md5 boolean DEFAULT false,
  -- add_filename  boolean DEFAULT true,
  missing_ok boolean DEFAULT false
) RETURNS JSONb AS $f$
  -- = indest.get_file_meta(). Falta emitir erro quando file not found!
  -- usar (j->'size')::bigint+1 como pg_read(size)!  para poder usar missing nele.
  SELECT j
         || jsonb_build_object( 'file',f )
         || CASE WHEN add_md5 THEN jsonb_build_object( 'hash_md5', md5(pg_read_binary_file(f)) ) ELSE '{}'::jsonb END
  FROM to_jsonb( pg_stat_file(f,missing_ok) ) t(j)
  WHERE j IS NOT NULL
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION jsonb_pg_stat_file
  IS 'Convert pg_stat_file() information in JSONb, adding option to include MD5 digest and filename.'
;

CREATE or replace FUNCTION jsonb_read_stat_file(
  f text,   -- filename with absolute path
  missing_ok boolean DEFAULT false, -- an error is raised, else (if true), the function returns NULL when file not found.
  add_md5 boolean DEFAULT false
) RETURNS JSONb AS $f$
  SELECT j
         || jsonb_build_object( 'file',f,  'content',pg_read_file(f)::JSONB )
         || CASE WHEN add_md5 THEN jsonb_build_object( 'hash_md5', md5(pg_read_binary_file(f)) ) ELSE '{}'::jsonb END
  FROM to_jsonb( pg_stat_file(f,missing_ok) ) t(j)
  WHERE j IS NOT NULL
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION jsonb_read_stat_file(text,boolean,boolean)
  IS 'Read content and metadata by pg_stat_file(). Like a pg_read_file() augmented with JSONb parse and file information.'
;

CREATE or replace FUNCTION volat_file_write(
  file text,
  fcontent text,
  msg text DEFAULT 'Ok',
  append boolean DEFAULT false
) RETURNS text AS $f$
  -- solves de PostgreSQL problem of the "LAZY COALESCE", as https://stackoverflow.com/a/42405837/287948
  SELECT msg ||'. Content bytes '|| iif(append,'appended:'::text,'writed:')
         ||  pg_catalog.pg_file_write(file,fcontent,append)::text
         || E'\nSee '|| file
$f$ language SQL volatile;
COMMENT ON FUNCTION volat_file_write
  IS 'Do lazy coalesce. To use in a "only write when null" condiction of COALESCE(x,volat_file_write()).'
;

-- -- CSV
CREATE or replace FUNCTION copy_csv(
  p_filename  text,
  p_query     text = NULL,
  p_etc       text = 'HEADER',
  p_root      text = '/tmp/pg_io/'
) RETURNS text AS $f$
DECLARE
  f text;
BEGIN
  IF p_query IS NULL THEN
      p_query := 'SELECT * FROM '||p_filename;
  END IF;
  IF p_filename !~ '\.[a-zA-Z0-9]+$' THEN
      p_filename := p_filename||'.csv';
  END IF;
  f := CASE WHEN substr(p_filename,1,1)='/' THEN p_filename ELSE p_root||p_filename END;
  EXECUTE format(
    'COPY (%s)      TO %L CSV   %s'
    ,      p_query,    f     ,  p_etc
  );
  RETURN f;
END
$f$ LANGUAGE PLpgSQL;
COMMENT ON FUNCTION copy_csv
 IS 'Easy transform query or view-name to COPY-to-CSV, with optional header. Example: copy_csv(tableName).';


-- handling of CSV files and its heders:

CREATE or replace FUNCTION pg_csv_head(
  filename text,                 -- the CSV file
  separator text default ',',    -- the CSV separator
  linesize bigint default 9000   -- header maximum size in UTF8 characteres.
) RETURNS text[] AS $f$
  SELECT regexp_split_to_array(replace(s,'"',''), separator)
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

----------------
-- Other system's helper functions

CREATE or replace FUNCTION col_description(
 p_relname text,  -- table name or schema.table
 p_colname text,   -- table's column name
 p_database text DEFAULT NULL -- NULL for current
) RETURNS text AS $f$
 WITH r AS (
   SELECT CASE WHEN array_length(x,1)=1 THEN array['public',x[1]] ELSE x END
   FROM regexp_split_to_array(p_relname,'\.') t(x)
  )
 SELECT col_description(p_relname::regClass, ordinal_position)
 FROM r, information_schema.columns i
 WHERE i.table_catalog = CASE
     WHEN $3 IS NULL THEN current_database() ELSE $3
   END and i.table_schema  = r.x[1]
   and i.table_name    = r.x[2]
   and i.column_name = p_colname
$f$ LANGUAGE SQL;
COMMENT ON FUNCTION col_description(text,text,text)
 IS E'Complement for col_description(text,oid). \nSee https://stackoverflow.com/a/12736192/287948';

CREATE or replace FUNCTION rel_description(
  p_relname text, p_schemaname text DEFAULT NULL
) RETURNS text AS $f$
SELECT obj_description((CASE
  WHEN strpos($1, '.')>0 THEN $1
  WHEN $2 IS NULL THEN 'public.'||$1
  ELSE $2||'.'||$1
       END)::regclass, 'pg_class');
$f$ LANGUAGE SQL;
COMMENT ON FUNCTION rel_description(text,text)
 IS E'Alternative shortcut to obj_description(). \nSee https://stackoverflow.com/a/12736192/287948';


CREATE or replace FUNCTION rel_columns(
 p_relname text, p_schemaname text DEFAULT NULL
) RETURNS text[] AS $f$
   SELECT --attrelid::regclass AS tbl,  atttypid::regtype  AS datatype
        array_agg(attname::text ORDER  BY attnum)
   FROM   pg_attribute
   WHERE  attrelid = (CASE
             WHEN strpos($1, '.')>0 THEN $1
             WHEN $2 IS NULL THEN 'public.'||$1
             ELSE $2||'.'||$1
          END)::regclass
   AND    attnum > 0
   AND    NOT attisdropped
$f$ LANGUAGE SQL;

------

CREATE or replace FUNCTION geohash_checkprefix(
  p_check text, p_prefixes text[]
) RETURNS text AS $f$
  SELECT x
  FROM unnest(p_prefixes) t(x)
  WHERE p_check like (x||'%')
  ORDER BY length(x) desc, x
  LIMIT 1
$f$ LANGUAGE SQL;

CREATE or replace FUNCTION geohash_distribution_tots(p_j jsonb) RETURNS jsonb AS $f$
  SELECT jsonb_build_object(
    'keys',  MAX( jsonb_object_length(p_j) ), --constant
    'n_tot', SUM(n::int)::int,
    'n_avg', ROUND(AVG(n::int))::int,
    'n_dev', ROUND(STDDEV_POP(n::int))::int,
    'n_median', percentile_disc(0.5) WITHIN GROUP (ORDER BY n::int),
    'n_min', MIN(n::int),
    'n_max', MAX(n::int)
    )
  FROM  jsonb_each(p_j) t(ghs,n)
$f$ LANGUAGE SQL;

CREATE or replace FUNCTION geohash_distribution_format(
  p_j jsonb,
  p_perc boolean DEFAULT true,
  p_glink text DEFAULT '', -- ex. http://git.AddressForAll.org/out-BR2021-A4A/blob/main/data/SP/RibeiraoPreto/_pk058/via_
  p_sep text DEFAULT ', '
) RETURNS text AS $f$
  WITH scan AS (SELECT ghs,n::int as n FROM jsonb_each(p_j) t1(ghs,n) ORDER BY ghs)
  SELECT string_agg(
          CASE
            WHEN p_glink>'' THEN  '<a href="'||p_glink||ghs||'.geojson"><code>'||ghs||'</code></a>: '
            ELSE  '<code>'||ghs||'</code>: '
          END || CASE WHEN p_perc THEN round(100.0*n/tot)::int::text ELSE n::text END || '%'
         , p_sep )
  FROM  scan , (SELECT SUM(n::int) tot FROM scan) t2
$f$ LANGUAGE SQL;

CREATE or replace FUNCTION geohash_distribution_summary(
  p_j jsonb,
  p_ghs_size int DEFAULT 6, -- 5 para áreas
  p_len_max int DEFAULT 10,
  p_percentile real DEFAULT 0.75,
  p_limite_n int DEFAULT NULL
) RETURNS jsonb AS $f$
  DECLARE
    len int;
    ghs_len int;
    newdistrib jsonb;
  BEGIN
  ghs_len := jsonb_object_keys_maxlength(p_j);
  IF p_ghs_size >= ghs_len THEN
    p_ghs_size := p_ghs_size-1;
  END IF;
  len := jsonb_object_length(p_j);

  IF p_ghs_size<1 OR p_len_max<2 OR len<=p_len_max THEN
    RETURN p_j;
  END IF;

  IF p_limite_n IS NULL THEN
    WITH
    j_each AS (
        SELECT ghs, n::int n
        FROM  jsonb_each(p_j) t(ghs,n) ORDER BY n
    ),
    perc AS (
        SELECT percentile_disc(p_percentile) WITHIN GROUP (ORDER BY n) as pct
        FROM j_each
    )
    SELECT  jsonb_object_agg( ghs,n ) INTO newdistrib
    FROM (
            SELECT ghs, n
            FROM j_each, perc
            WHERE n>=pct

            UNION

            SELECT substr(ghs,1,p_ghs_size), SUM(n) as n
            FROM j_each, perc
            WHERE n<pct
            GROUP BY 1
    ) t;

   ELSE

    WITH
    j_each AS (
        SELECT ghs, n::int n
        FROM  jsonb_each(p_j) t(ghs,n) ORDER BY n
    ),
    perc AS (
        SELECT percentile_disc(p_percentile) WITHIN GROUP (ORDER BY n) as pct
        FROM j_each
    )
    SELECT  jsonb_object_agg( ghs,n ) INTO newdistrib
    FROM (
            SELECT ghs, n
            FROM j_each, perc
            WHERE n>=pct 
                OR ghs = ANY((
                    SELECT array_agg(ghs)
                    FROM j_each, perc
                    WHERE n<pct
                    GROUP BY substr(ghs,1,p_ghs_size)
                    HAVING SUM(n) >= p_limite_n
                )::text[])

            UNION

            SELECT substr(ghs,1,p_ghs_size), SUM(n) as n
            FROM j_each, perc
            WHERE n<pct
            GROUP BY 1
            HAVING SUM(n) < p_limite_n
    ) t;
    END IF;

  RETURN geohash_distribution_summary(newdistrib, p_ghs_size-1, p_len_max, p_percentile,p_limite_n);
  END;
$f$ LANGUAGE PLpgSQL;
