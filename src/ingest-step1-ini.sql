-- INGEST STEP1
-- Inicialização do Módulo Ingest dos prjetos AddressForAll.
--

CREATE extension IF NOT EXISTS postgis;
CREATE extension IF NOT EXISTS adminpack;

CREATE EXTENSION IF NOT EXISTS file_fdw;
CREATE SERVER    IF NOT EXISTS files FOREIGN DATA WRAPPER file_fdw;

CREATE schema    IF NOT EXISTS ingest;
CREATE schema    IF NOT EXISTS tmp_orig;

-- -- --
-- SQL and bash generators (optim-ingest submodule)

CREATE or replace FUNCTION ingest.fdw_csv_paths(
  p_name text, p_context text DEFAULT 'br', p_path text DEFAULT NULL
) RETURNS text[] AS $f$
  SELECT  array[
    fpath, -- /tmp/pg_io/digital-preservation-XX
    concat(fpath,'/', iIF(p_context IS NULL,''::text,p_context||'-'), p_name, '.csv')
  ]
  FROM COALESCE(p_path,'/tmp/pg_io') t(fpath)
$f$ language SQL;

CREATE or replace FUNCTION ingest.fdw_generate(
  p_name text,  -- table name and CSV input filename
  p_context text DEFAULT 'br',  -- or null
  p_schemaname text DEFAULT 'optim',
  p_columns text[] DEFAULT NULL, -- mais importante! nao poderia ser null
  p_addtxtype boolean DEFAULT false,  -- add " text"
  p_path text DEFAULT NULL,  -- default based on ids
  p_delimiter text DEFAULT ',',
  p_header boolean DEFAULT true
) RETURNS text  AS $f$
DECLARE
 fdwname text;
 fpath text;
 f text;
 sepcols text;
BEGIN
  -- usar ingest.fdw_csv_paths!
 fpath := COALESCE(p_path,'/tmp/pg_io'); -- /tmp/pg_io/digital-preservation-XX
 f := concat(fpath,'/', iIF(p_context IS NULL,''::text,p_context||'-'), p_name, '.csv');
 p_context := iIF(p_context IS NULL, ''::text, '_'|| p_context);
 fdwname := 'tmp_orig.fdw_'|| iIF(p_schemaname='optim', ''::text, p_schemaname||'_') || p_name || p_context;
 -- poderia otimizar por chamada (alter table option filename), porém não é paralelizável.
 sepcols := iIF(p_addtxtype, '" text,"'::text, '","'::text);
 -- if delimiter = tab, format = tsv
 EXECUTE
    format(
      'DROP FOREIGN TABLE IF EXISTS %s; CREATE FOREIGN TABLE %s    (%s%s%s)',
       fdwname, fdwname,   '"', array_to_string(p_columns,sepcols), iIF(p_addtxtype, '" text'::text, '"')
     ) || format(
       'SERVER files OPTIONS (filename %L, format %L, header %L, delimiter %L)',
       f, 'csv', p_header::text, p_delimiter
    );
    return ' '|| fdwname || E' was created!\n source: '||f|| ' ';
END;
$f$ language PLpgSQL;
COMMENT ON FUNCTION ingest.fdw_generate
  IS 'Generates a structure FOREIGN TABLE for ingestion.'
;

CREATE or replace FUNCTION ingest.fdw_generate_getCSV(
  p_name text,  -- table name and CSV input filename
  p_context text DEFAULT 'br',  -- or null
  p_path text DEFAULT NULL,     -- default based on ids
  p_delimiter text DEFAULT ','
) RETURNS text  AS $f$
  SELECT ingest.fdw_generate(p_name, p_context, 'optim', pg_csv_head(p[2],p_delimiter), true, p_path, p_delimiter)
  FROM ingest.fdw_csv_paths(p_name,p_context,p_path) t(p)
$f$ language SQL;

-- select ingest.fdw_generate_getCSV('enderecos','br_mg_bho');
-- creates tmp_orig.fdw_enderecos_br_mg_bho by source: /tmp/pg_io/br_mg_bho-enderecos.csv


CREATE or replace FUNCTION ingest.fdw_generate_getclone(
  -- foreign-data wrapper generator
  p_tablename text,  -- cloned-table name
  p_context text DEFAULT 'br',  -- or null
  p_schemaname text DEFAULT 'optim',
  p_ignore text[] DEFAULT NULL, -- colunms to be ignored.
  p_add text[] DEFAULT NULL, -- colunms to be added.
  p_path text DEFAULT NULL  -- default based on ids
) RETURNS text  AS $wrap$
  SELECT ingest.fdw_generate(
    $1,$2,$3,
    pg_tablestruct_dump_totext(p_schemaname||'.'||p_tablename,p_ignore,p_add),
    true, -- p_addtxtype
    p_path
  )
$wrap$ language SQL;
COMMENT ON FUNCTION ingest.fdw_generate_getclone
  IS 'Generates a clone-structure FOREIGN TABLE for ingestion. Wrap for fdw_generate().'
;

------------
-- GEOMETRIAS

CREATE TABLE ingest.addr_point(
  pack_id int, -- each donated package have only 1 set of points. E.g. pk012 of BR_MG_BHO.
  vianame text, -- official name in the origin
  housenum text, -- supply by origin
  -- is_informal boolean default false, -- non-official. E.g. closed condominim.
  geom geometry,
  UNIQUE(pack_id,vianame,housenum),
  UNIQUE(pack_id,geom)
);
COMMENT ON TABLE ingest.addr_point
  IS 'Ingested address points of one or more packages, temporary data (not need package-version).'
;

CREATE TABLE ingest.via_line(
  pack_id int NOT NULL, -- REFERENCES optim.donatedPack(pack_id),
  vianame text,
  is_informal boolean default false, -- non-official name (loteametos com ruas ainda sem nome)
  geom geometry,
  info JSONb,
  UNIQUE(pack_id,geom)
);
COMMENT ON TABLE ingest.via_line
  IS 'Ingested via lines (street axis) of one or more packages, temporary data (not need package-version).'
;

---------
CREATE TABLE ingest.feature_type (  -- replacing old optim.origin_content_type
  ftid smallint PRIMARY KEY NOT NULL,
  ftname text NOT NULL CHECK(lower(ftname)=ftname), -- ftlabel
  geomtype text NOT NULL CHECK(lower(geomtype)=geomtype), -- old model_geo
  need_complement boolean, -- false=não, true=sim.
  description text NOT NULL, 
  info jsonb, -- is_useful, score, model_septable
  UNIQUE (ftname)
);
INSERT INTO ingest.feature_type VALUES
  (0,'address',       'class', null,  'Cadastral address (gid,via_id,via_name,number,postal_code,etc).', NULL),
  (1,'address_full',  'none', true,   'Cadastral address (gid,via_id,via_name,number,postal_code,etc), joining with geoaddress_ext by a gid.', NULL),
  (2,'address_noid',  'none', true,   'Cadastral address with some basic metadata but no standard gid for join with geo).', NULL),
  (3,'address_cmpl',  'none', true,   'Cadastral address, like address_full but .', NULL),
  (4,'via_cmpl',      'none', true,   'Via line with no metadata', NULL),
  
  (10,'geoaddress',         'class', null,  'Geo-address point.', NULL),
  (11,'geoaddress_full',    'point', false, 'Geo-address point with all attributes, via_name and number.', NULL),
  (12,'geoaddress_ext',     'point', true,  'Geo-address point with no (or some) metadata, external metadata at address_cmpl or address_full.', NULL),
  (13,'geoaddress_none',    'point', false, 'Geo-address point-only, no metadata (or no core metadata).', NULL),

  (20,'via',           'class', null,  'Via line.', NULL),
  (21,'via_full',       'line', false, 'Via line with official name and optional code, as attributes', NULL),
  (22,'via_ext',        'line', true,  'Via line with external metadata', NULL),
  (23,'via_none',       'line', false, 'Via line with no metadata', NULL),

  (30,'building',        'class', null, 'Building polygon.', NULL),
  (31,'building_full',   'poly', false, 'Building polygon with all attributes, via_name and number.', NULL),
  (32,'building_ext',    'poly', true,  'Building polygon with no (or some) metadata, external metadata at address_cmpl or address_full.', NULL),
  (33,'building_none',   'poly', false, 'Building polygon-only, no metadata (or no core metadata).', NULL),

  (40,'parcel',        'class', null, 'Land lot (parcel).', NULL),
  (41,'parcel_full',   'poly', false, 'Land lot (parcel) polygon with all attributes, main via_name and number.', NULL),
  (42,'parcel_ext',    'poly', true,  'Land lot (parcel) polygon-only, all metadata external.', NULL),
  (43,'parcel_none',   'poly', false, 'Land lot (parcel) polygon-only, no metadata.', NULL),

  (50,'nsvia',        'class', null, 'Namespace of vias (bairro), a name delimited by a polygon.', NULL),
  (51,'nsvia_full',   'poly', false, 'Namespace of vias (bairro) polygon with name and optional metadata', NULL),
  (52,'nsvia_ext',    'poly', true,  'Namespace of vias (bairro) polygon with external metadata', NULL)
;
/* 
 Exemplos de sinônimos:
   building = edificacoes
   lot = lotes
   via = eixos, ruas, streets
   geoaddress_full = P1 (Point via_name housenumber)
   geoaddress_full + lot_full = PL1 (Point Lot via_name housenumber)
   ...
*/

CREATE TABLE ingest.file (
  file_id serial NOT NULL PRIMARY KEY,
  ftid smallint NOT NULL REFERENCES ingest.feature_type(ftid),
  file_type text,  -- csv, geojson, shapefile, etc.
  file_meta jsonb
);

CREATE TABLE ingest.tmp_geojson_feature (
  file_id int NOT NULL REFERENCES ingest.file(file_id),
  feature_id int,
  feature_type text,
  properties jsonb,
  jgeom jsonb,
  UNIQUE(file_id,feature_id)
);

CREATE TABLE ingest.feature (
  file_id int NOT NULL REFERENCES ingest.file(file_id),
  feature_id int NOT NULL,
  properties jsonb,
  geom geometry,
  UNIQUE(file_id,feature_id)
);

-----
CREATE or replace FUNCTION ingest.geojson_load(
    p_file text, -- absolute path and filename, test with '/tmp/pg_io/EXEMPLO3.geojson'
    p_ftid int,  -- REFERENCES ingest.feature_type(ftid)
    p_ftype text DEFAULT NULL,
    p_to4326 boolean DEFAULT true
) RETURNS text AS $f$

  DECLARE
    q_file_id integer;
    jins_count bigint;
    q_ret text;
  BEGIN
 
  INSERT INTO ingest.file(ftid,file_type,file_meta)
     SELECT p_ftid::smallint,
            COALESCE( p_ftype, substring(p_file from '[^\.]+$') ),
            geojson_readfile_headers(p_file)
     RETURNING file_id INTO q_file_id;
  
  WITH jins AS (
    INSERT INTO ingest.tmp_geojson_feature
     SELECT * 
     FROM geojson_readfile_features_jgeom(p_file, q_file_id )
    RETURNING 1
   ) 
   SELECT COUNT(*) FROM jins INTO jins_count;
   
  WITH ins2 AS (
    INSERT INTO ingest.feature
     SELECT file_id, feature_id, properties, 
            CASE WHEN p_to4326 AND ST_SRID(geom)!=4326 THEN ST_Transform(geom,4326) ELSE geom END
     FROM (
       SELECT file_id, feature_id, properties,
              ST_GeomFromGeoJSON(jgeom) geom
       FROM ingest.tmp_geojson_feature
       WHERE file_id = q_file_id
     ) t
    RETURNING 1
   )
   SELECT 'Inserted in tmp '|| jins_count ||' items from file_id '|| q_file_id
         ||E'.\nInserted in feature '|| (SELECT COUNT(*) FROM ins2) ||' items.'
         INTO q_ret;
         
  DELETE FROM ingest.tmp_geojson_feature WHERE file_id = q_file_id;
  RETURN q_ret;
 END;
$f$ LANGUAGE PLpgSQL;
