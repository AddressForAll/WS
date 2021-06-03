-- INGEST STEP1
-- Inicialização do Módulo Ingest dos prjetos AddressForAll.
--

CREATE extension IF NOT EXISTS postgis;
CREATE extension IF NOT EXISTS adminpack;

CREATE EXTENSION IF NOT EXISTS file_fdw;
CREATE SERVER    IF NOT EXISTS files FOREIGN DATA WRAPPER file_fdw;

CREATE schema    IF NOT EXISTS ingest;
CREATE schema    IF NOT EXISTS tmp_orig;

-- float is float4=real: review definitions? real  is indexable, use it at tables.

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
/* !REVISAR CONTROLE DE IDs!
CREATE TABLE ingest.addr_point(
  ?file_id,
  pack_id int, -- each donated package have only 1 set of points. E.g. pk012 of BR_MG_BHO.
  vianame text, -- official name in the origin
  housenum text, -- supply by origin
  -- is_informal boolean default false, -- non-official. E.g. closed condominim.
  geom geometry(Point,4326) NOT NULL,

  UNIQUE(pack_id,vianame,housenum),
  UNIQUE(pack_id,geom)
);
COMMENT ON TABLE ingest.addr_point
  IS 'Ingested address points of one or more packages, temporary data (not need package-version).'
;
*/
CREATE TABLE ingest.via_line(
  pck_id float NOT NULL, -- REFERENCES optim.donatedPack(pck_id),
  vianame text,
  is_informal boolean default false, -- non-official name (loteametos com ruas ainda sem nome)
  geom geometry,
  info JSONb,
  UNIQUE(pck_id,geom)
);
COMMENT ON TABLE ingest.via_line
  IS 'Ingested via lines (street axis) of one or more packages, temporary data (not need package-version).'
;

---------
CREATE TABLE ingest.feature_type (  -- replacing old optim.origin_content_type
  ftid smallint PRIMARY KEY NOT NULL,
  ftname text NOT NULL CHECK(lower(ftname)=ftname), -- ftlabel
  geomtype text NOT NULL CHECK(lower(geomtype)=geomtype), -- old model_geo
  need_join boolean, -- false=não, true=sim, null=both (at class).
  description text NOT NULL,
  info jsonb, -- is_useful, score, model_septable, description_pt, description_es, synonymous_pt, synonymous_es
  UNIQUE (ftname)
);
-- DELETE FROM ingest.feature_type;
INSERT INTO ingest.feature_type VALUES
  (0,'address',       'class', null,  'Cadastral address.','{"description_pt":"Endereço cadastral, representação por nome de via e numeração predial.","synonymous_pt":["endereço postal","endereço","planilha dos endereços","cadastro de endereços"]}'::jsonb),
  (1,'address_full',  'none', true,   'Cadastral address (gid,via_id,via_name,number,postal_code,etc), joining with geoaddress_ext by a gid.', NULL),
  (2,'address_cmpl',  'none', true,   'Cadastral address, like address_full with only partial core metadata.', NULL),
  (3,'address_noid',  'none', false,  'Cadastral address with some basic metadata but no standard gid for join with geo).', NULL),

  (10,'cadvia',           'class', null,  'Cadastral via (name of via).', '{"description_pt":"Via cadastral (nome de via), complemento da geográfica. Logradouro representado por dados cadastrais apenas.","synonymous_pt":["nomes de logradouro","nomes de rua"]}'::jsonb),
  (11,'cadvia_cmpl',      'none', true,   'Cadastral via with metadata complementing via_ext (via_cod,via_name).', NULL),
  (12,'cadvia_noid',      'none', false,   'Via name (and optional metadata) with no ID for join with via_ext.', NULL),

  (20,'geoaddress',         'class', null,  'Geo-address point.', '{"description_pt":"Geo-endereço. Representação geográfica do endereço, como ponto.","synonymous_pt":["geo-endereço","ponto de endereço","endereço georreferenciado","ponto de endereçamento postal"]}'::jsonb),
  (21,'geoaddress_full',    'point', false, 'Geo-address point with all attributes, via_name and number.', NULL),
  (22,'geoaddress_ext',     'point', true,  'Geo-address point with no (or some) metadata, external metadata at address_cmpl or address_full.', NULL),
  (23,'geoaddress_none',    'point', false, 'Geo-address point-only, no metadata (or no core metadata).', NULL),

  (30,'via',           'class', null,  'Via line.', '{"description_pt":"Eixo de via. Logradouro representado por linha central, com nome oficial e codlog opcional.","synonymous_pt":["eixo de logradouro","ruas"]}'::jsonb),
  (31,'via_full',       'line', false, 'Via line, with all metadata (official name, optional code and others)', NULL),
  (32,'via_ext',        'line', true,  'Via line, with external metadata at cadvia_cmpl', NULL),
  (33,'via_none',       'line', false, 'Via line with no metadata', NULL),

  (40,'genericvia',           'class', null,  'Generic-via line. Complementar parcel and block divider: railroad, waterway or other.', '{"description_pt":"Via complementar generalizada. Qualquer linha divisora de lotes e quadras: rios, ferrovias, etc. Permite gerar a quadra generalizada.","synonymous_pt":["hidrovia","ferrovia","limite de município"]}'::jsonb),
  (41,'genericvia_full',       'line', false, 'Generic-via line, with all metadata (type, official name, optional code and others)', NULL),
  (42,'genericvia_ext',        'line', true,  'Generic-via line, with external metadata', NULL),
  (43,'genericvia_none',       'line', false, 'Generic-via line with no metadata', NULL),

  (50,'building',        'class', null, 'Building polygon.', '{"description_pt":"Polígono de edificação.","synonymous_pt":["construções","construção"]}'::jsonb),
  (51,'building_full',   'poly', false, 'Building polygon with all attributes, via_name and number.', NULL),
  (52,'building_ext',    'poly', true,  'Building polygon with no (or some) metadata, external metadata at address_cmpl or address_full.', NULL),
  (53,'building_none',   'poly', false, 'Building polygon-only, no metadata (or no core metadata).', NULL),

  (60,'parcel',        'class', null, 'Parcel polygon (land lot).', '{"description_pt":"Polígono de lote.","synonymous_pt":["lote","parcela","terreno"]}'::jsonb),
  (61,'parcel_full',   'poly', false, 'Parcel polygon with all attributes, its main via_name and number.', NULL),
  (62,'parcel_ext',    'poly', true,  'Parcel polygon-only, all metadata external.', NULL),
  (63,'parcel_none',   'poly', false, 'Parcel polygon-only, no metadata.', NULL),

  (70,'nsvia',        'class', null, 'Namespace of vias, a name delimited by a polygon.', '{"description_pt":"Espaço-de-nomes para vias, um nome delimitado por polígono. Tipicamente nome de bairro ou de loteamento. Complementa o nome de via em nomes duplicados (repetidos dentro do mesmo município mas não dentro do mesmo nsvia).","synonymous_pt":["bairro","loteamento"]}'::jsonb),
  (71,'nsvia_full',   'poly', false, 'Namespace of vias polygon with name and optional metadata', NULL),
  (72,'nsvia_ext',    'poly', true,  'Namespace of vias polygon with external metadata', NULL)
;
-- Para a iconografia do site:
-- SELECT f.ftname as "feature type", t.geomtype as "geometry type", f.description from ingest.feature_type f inner JOIN (select  substring(ftname from '^[^_]+') as ftgroup, geomtype  from ingest.feature_type where geomtype!='class' group by 1,2) t ON t.ftgroup=f.ftname ;--where t.geomtype='class';
-- Para gerar backup CSV:
-- copy ( select lpad(ftid::text,2,'0') ftid, ftname, description, info->>'description_pt' as description_pt, array_to_string(jsonb_array_totext(info->'synonymous_pt'),'; ') as synonymous_pt from ingest.feature_type where geomtype='class' ) to '/tmp/pg_io/featur_type_classes.csv' CSV HEADER;
-- copy ( select lpad(ftid::text,2,'0') ftid, ftname,geomtype, iif(need_join,'yes'::text,'no') as need_join, description  from ingest.feature_type where geomtype!='class' ) to '/tmp/pg_io/featur_types.csv' CSV HEADER;

CREATE VIEW ingest.vw01info_feature_type AS
  SELECT ftid, ftname, geomtype, need_join, description,
       COALESCE(f.info,'{}'::jsonb) || (
         SELECT to_jsonb(t2) FROM (
           SELECT c.ftid as class_ftid, c.ftname as class_ftname,
                  c.description as class_description,
                  c.info as class_info
           FROM ingest.feature_type c
           WHERE c.geomtype='class' AND c.ftid = 10*round(f.ftid/10)
         ) t2
       ) AS info
  FROM ingest.feature_type f
  WHERE f.geomtype!='class'
;
-------

-- DROP TABLE ingest.layer_file;
CREATE TABLE ingest.layer_file (
  pck_id float4 NOT NULL CHECK( digpreserv_packid_isvalid(pck_id) ), -- package file ID, not controled here. Talvez seja packVers (package and version) ou pck_id com float
  file_id serial NOT NULL PRIMARY KEY,
  ftid smallint NOT NULL REFERENCES ingest.feature_type(ftid),
  file_type text,  -- csv, geojson, shapefile, etc.
  proc_step int DEFAULT 1,  -- current status of the "processing steps", 1=started, 2=loaded, ...=finished
  hash_md5 text NOT NULL, -- or "size-md5" as really unique string
  file_meta jsonb,
  UNIQUE(hash_md5) -- or size-MD5 or (ftid,hash_md5)?  não faz sentido usar duas vezes se existe _full.
);

CREATE TABLE ingest.feature_asis_report (
  file_id int NOT NULL REFERENCES ingest.layer_file(file_id),
  feature_id int NOT NULL,
  info jsonb,
  UNIQUE(file_id,feature_id)
);

CREATE TABLE ingest.tmp_geojson_feature (
  file_id int NOT NULL REFERENCES ingest.layer_file(file_id),
  feature_id int,
  feature_type text,
  properties jsonb,
  jgeom jsonb,
  UNIQUE(file_id,feature_id)
);

CREATE TABLE ingest.feature_asis (
  file_id int NOT NULL REFERENCES ingest.layer_file(file_id),
  feature_id int NOT NULL,
  properties jsonb,
  geom geometry,
  UNIQUE(file_id,feature_id)
);
CREATE TABLE ingest.feature_asis_summary (
  file_id int NOT NULL PRIMARY KEY REFERENCES ingest.layer_file(file_id),
  summary jsonb
);

----------------
----------------
-- Ingest AS-IS


CREATE or replace FUNCTION ingest.feature_asis_geohashes(
    p_file_id integer,  -- ID at ingest.layer_file
    ghs_size integer DEFAULT 5
) RETURNS jsonb AS $f$
  WITH scan AS (
   SELECT  ghs, COUNT(*) n
   FROM (
  	SELECT
  	  ST_Geohash(
  	    CASE WHEN t1a.gtype='point' THEN geom ELSE ST_PointOnSurface(geom) END
  	    ,ghs_size
  	  ) as ghs
  	FROM ingest.feature_asis,
  	 (SELECT ingest.layer_file_geomtype(p_file_id) AS gtype) t1a
  	WHERE file_id=p_file_id
   ) t2
   GROUP BY 1
   ORDER BY 1
  )
   SELECT jsonb_object_agg( ghs,n )
   FROM scan
$f$ LANGUAGE SQL;

CREATE or replace FUNCTION ingest.feature_asis_assign_volume(
    p_file_id integer  -- ID at ingest.layer_file
) RETURNS jsonb AS $f$
  SELECT to_jsonb(t3)
  FROM (
      SELECT n, CASE gtype
          WHEN 'poly'  THEN 'polygons'
          WHEN 'line'  THEN 'segments'
          WHEN 'point'  THEN 'points'
        END n_unit,
      size, CASE gtype
          WHEN 'poly'  THEN 'km2'
          WHEN 'line'  THEN 'km'
          ELSE  ''
        END size_unit,
        bbox_km2
      FROM (
        SELECT gtype, n, CASE gtype
            WHEN 'poly'  THEN round( ST_Area(geom,true)/1000000, 1)::int
            WHEN 'line'  THEN round( ST_Length(geom,true)/1000, 1)::int
            ELSE  null::int
          END size,
          round( ST_Area(ST_OrientedEnvelope(geom),true)/1000000, 1)::int AS bbox_km2
        FROM (
            SELECT count(*) n, st_collect(geom) as geom
            FROM ingest.feature_asis WHERE file_id=p_file_id
        ) t1a, (
          SELECT ingest.layer_file_geomtype(p_file_id) AS gtype
        ) t1b
      ) t2
  ) t3
$f$ LANGUAGE SQL;

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

  INSERT INTO ingest.layer_file(ftid,file_type,file_meta)
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
    INSERT INTO ingest.feature_asis
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


CREATE or replace FUNCTION ingest.getmeta_to_file(
  p_file text,
  p_ftid int,
  p_pck_id float,
  p_ftype text DEFAULT NULL
  -- proc_step = 1
  -- ,p_size_min int DEFAULT 5
) RETURNS int AS $f$
-- with ... check
 WITH filedata AS (
   SELECT p_pck_id, p_ftid, ftype,
          CASE
            WHEN (fmeta->'size')::int<5 OR (fmeta->>'hash_md5')='' THEN NULL --guard
            ELSE fmeta->>'hash_md5'
          END AS hash_md5,
          (fmeta - 'hash_md5') AS fmeta
   FROM (
       SELECT COALESCE( p_ftype, substring(p_file from '[^\.]+$') ) as ftype,
          jsonb_pg_stat_file(p_file,true) as fmeta
   ) t
 ),
  file_exists AS (
    SELECT file_id,proc_step
    FROM ingest.layer_file
    WHERE pck_id=p_pck_id AND hash_md5=(SELECT hash_md5 FROM filedata)
  ), ins AS (
   INSERT INTO ingest.layer_file(pck_id,ftid,file_type,hash_md5,file_meta)
      SELECT * FROM filedata
   ON CONFLICT DO NOTHING
   RETURNING file_id
  )
  SELECT file_id FROM (
      SELECT file_id, 1 as proc_step FROM ins
      UNION ALL
      SELECT file_id, proc_step      FROM file_exists
  ) t WHERE proc_step=1
$f$ LANGUAGE SQL;
COMMENT ON FUNCTION ingest.getmeta_to_file(text,int,float,text)
  IS 'Reads file metadata and inserts it into ingest.layer_file. If proc_step=1 returns valid ID else NULL.'
;
CREATE or replace FUNCTION ingest.getmeta_to_file(
  p_file text,
  p_ftname text, -- define o layer... um file pode ter mais de um layer??
  p_pck_id float,
  p_ftype text DEFAULT NULL
) RETURNS int AS $wrap$
    SELECT ingest.getmeta_to_file(
      $1,
      (SELECT ftid::int FROM ingest.feature_type WHERE ftname=lower($2)),
      $3,
      $4
    );
$wrap$ LANGUAGE SQL;
COMMENT ON FUNCTION ingest.getmeta_to_file(text,text,float,text)
  IS 'Wrap para ingest.getmeta_to_file() usando ftName ao invés de ftID.'
;
-- ex. select ingest.getmeta_to_file('/tmp/a.csv',3,555);
-- ex. select ingest.getmeta_to_file('/tmp/b.shp','geoaddress_full',555);

/* ver VIEW
CREATE or replace FUNCTION ingest.feature_type_refclass_tab(
  p_ftid integer
) RETURNS TABLE (like ingest.feature_type) AS $f$
  SELECT *
  FROM ingest.feature_type
  WHERE ftid = 10*round(p_ftid/10)
$f$ LANGUAGE SQL;
COMMENT ON FUNCTION ingest.feature_type_refclass_tab(integer)
  IS 'Feature class of a feature_type, returing it as table.'
;
CREATE or replace FUNCTION ingest.feature_type_refclass_jsonb(
  p_ftid integer
) RETURNS JSONB AS $wrap$
  SELECT to_jsonb(t)
  FROM ingest.feature_type_refclass_tab($1) t
$wrap$ LANGUAGE SQL;
COMMENT ON FUNCTION ingest.feature_type_refclass_jsonb(integer)
  IS 'Feature class of a feature_type, returing it as JSONb.'
;
*/

CREATE or replace FUNCTION ingest.layer_file_geomtype(
  p_file_id integer
) RETURNS text AS $f$
  SELECT geomtype
  FROM ingest.feature_type
  WHERE ftid = (
    SELECT ftid
    FROM ingest.layer_file
    WHERE file_id = p_file_id
  )
$f$ LANGUAGE SQL;
COMMENT ON FUNCTION ingest.layer_file_geomtype(integer)
  IS 'Geomtype of a layer_file.'
;

CREATE or replace FUNCTION ingest.any_load(
    p_fileref text,  -- apenas referencia para ingest.layer_file
    p_ftname text,   -- featureType of layer... um file pode ter mais de um layer??
    p_tabname text,  -- tabela temporária de ingestáo
    p_pck_id float,   -- id do package da Preservação.
    p_tabcols text[] DEFAULT NULL, -- array[]=tudo, senão lista de atributos de p_tabname, ou só geometria
    p_geom_name text DEFAULT 'geom',
    p_to4326 boolean DEFAULT true -- on true converts SRID to 4326 .
) RETURNS text AS $f$
  DECLARE
    q_file_id integer;
    q_query text;
     bigint;
    feature_id_col text;
    use_tabcols boolean;
    msg_ret text;
  BEGIN
  q_file_id := ingest.getmeta_to_file(p_fileref,p_ftname,p_pck_id); -- not null when proc_step=1. Ideal retornar array.
  IF q_file_id IS NULL THEN
    RETURN format('ERROR: file-read problem or data ingested before, see %s.',p_fileref);
  END IF;
  IF p_tabcols=array[]::text[] THEN  -- condição para solicitar todas as colunas
    p_tabcols = rel_columns(p_tabname);
  END IF;
  IF 'gid'=ANY(p_tabcols) THEN
    feature_id_col := 'gid';
    p_tabcols := array_remove(p_tabcols,'gid');
  ELSE
    feature_id_col := 'row_number() OVER () AS gid';
  END IF;
  IF p_tabcols is not NULL AND array_length(p_tabcols,1)>0 THEN
    p_tabcols   := sql_parse_selectcols(p_tabcols); -- clean p_tabcols
    use_tabcols := true;
  ELSE
    use_tabcols := false;
  END IF;
  IF 'geom'=ANY(p_tabcols) THEN
    p_tabcols := array_remove(p_tabcols,'geom');
  END IF;
  q_query := format(
      $$
      WITH
      scan AS (
        SELECT %s, gid, properties,
               CASE
                 WHEN ST_SRID(geom)=0 THEN ST_SetSRID(geom,4326)
                 WHEN %s AND ST_SRID(geom)!=4326 THEN ST_Transform(geom,4326)
                 ELSE geom
               END AS geom
        FROM (
            SELECT %s,  -- feature_id_col
                 %s as properties,
                 %s -- geom
            FROM %s %s
          ) t
      ),
      ins AS (
        INSERT INTO ingest.feature_asis
           SELECT *
           FROM scan WHERE geom IS NOT NULL AND ST_IsValid(geom)
        RETURNING 1
      )
      SELECT COUNT(*) FROM ins
    $$,
    q_file_id,
    iif(p_to4326,'true'::text,'false'),  -- decide ST_Transform
    feature_id_col,
    iIF( use_tabcols, 'to_jsonb(subq)'::text, E'\'{}\'::jsonb' ), -- properties
    CASE WHEN lower(p_geom_name)='geom' THEN 'geom' ELSE p_geom_name||' AS geom' END,
    p_tabname,
    iIF( use_tabcols, ', LATERAL (SELECT '|| array_to_string(p_tabcols,',') ||') subq',  ''::text )
  );
  EXECUTE q_query INTO num_items;
  msg_ret := format( E'From file_id=%s inserted type=%s\nin feature_asis %s items.',
    q_file_id,
    p_ftname, num_items
  );
  IF num_items>0 THEN
    UPDATE ingest.layer_file SET proc_step=2   -- if insert process occurs after q_query.
    WHERE file_id=q_file_id
    ;
    INSERT INTO ingest.feature_asis_summary (file_id,summary) VALUES (
      q_file_id,
      feature_asis_assign_volume(q_file_id)
      || jsonb_build_object(
          'distribution',
          geohash_distribution_summary( ingest.feature_asis_geohashes(q_file_id,5), 5, 10, 0.7)
        ) -- 6 para lines e pontos e 5 para areas
      );
  END IF;
  RETURN msg_ret;
  END;
$f$ LANGUAGE PLpgSQL;
COMMENT ON FUNCTION ingest.any_load(text,text,text,float,text[],text,boolean)
  IS 'Load (into ingest.feature_asis) shapefile or any other non-GeoJSON, of a separated table.'
;
-- ex. SELECT ingest.any_load('/tmp/pg_io/NRO_IMOVEL.shp','geoaddress_none','pk027_geoaddress1',27,array['gid','textstring']);


CREATE or replace FUNCTION ingest.any_load(
    p_fileref text,  -- 1. apenas referencia para ingest.layer_file
    p_ftname text,   -- 2. featureType of layer... um file pode ter mais de um layer??
    p_tabname text,  -- 3. tabela temporária de ingestáo
    p_pck_id text,   -- 4. id do package da Preservação no formato "a.b".
    p_tabcols text[] DEFAULT NULL,   -- 5. lista de atributos, ou só geometria
    p_geom_name text DEFAULT 'geom', -- 6
    p_to4326 boolean DEFAULT true    -- 7. on true converts SRID to 4326 .
) RETURNS text AS $wrap$
   SELECT ingest.any_load($1, $2, $3, digpreserv_packid_to_float($4), $5, $6, $7)
$wrap$ LANGUAGE SQL;
COMMENT ON FUNCTION ingest.any_load(text,text,text,text,text[],text,boolean)
  IS 'Wrap to ingest.any_load(1,2,3,4=float).'
;

/*
# falta
# função ingest.any_load deveria converter lista de cols conforme padrões geoaddress_none
*/


-- INSERT GEOMETRIA QQ com referencia a arquivo e layer
-- FILE não tem ftype!
-- ingest.layer_file tem muitos ingest.file_layer(ftype!)  que tem suas geometrias em ingest.layer_geom

-- SELECT ingest.geom_asis_filemeta('/tmp/bigbigfile.zip');
