/**
 * System's Public library (commom for WS and others)
 * PREFIXES: digpreserv_, geojson_
 * Extra: PostGIS's Brazilian SRID inserts. Can be encapsulated into a digpreserv_ function that selects country or all.
 */

CREATE extension IF NOT EXISTS postgis;

-------------------------------
-- system Digital Preservation

-- rename *_to_real to *_to_real!

CREATE or replace FUNCTION digpreserv_packid_to_real(pkid int, version int) RETURNS real AS $f$
  SELECT pkid::real + (CASE WHEN version IS NULL or version<=0 THEN 1 ELSE version END)::real/1000.0::real
  -- Estimativa de versões: 1 por semana ao longo de 15 anos. 15*12*4.3=780. Ainda sobram 320 por segurança.
$f$ language SQL IMMUTABLE;
COMMENT ON FUNCTION digpreserv_packid_to_real(int,int)
 IS 'Encodes integer pkid and version into real pck_id, convention of the one new version a week for 15 years.'
;
CREATE or replace FUNCTION digpreserv_packid_to_real(pck_id int[]) RETURNS real AS $wrap$
  SELECT digpreserv_packid_to_real(pck_id[1],pck_id[2])
$wrap$ language SQL IMMUTABLE;
COMMENT ON FUNCTION digpreserv_packid_to_real(int[])
 IS 'Encodes integer array[pkid,version] into real pck_id, convention of the 20 years with 40 versions/year.'
;
CREATE or replace FUNCTION digpreserv_packid_to_real(str_pkid text) RETURNS real AS $f$
  SELECT replace(str_pkid,'_','.')::real
$f$ language SQL IMMUTABLE;
COMMENT ON FUNCTION digpreserv_packid_to_real(text)
 IS 'Converts pck_id format, text into real.'
;

CREATE or replace FUNCTION digpreserv_packid_to_ints(pck_id real) RETURNS int[] AS $f$
  SELECT array[k::int,round((pck_id-k)*1000)::int]
  FROM ( SELECT trunc(pck_id) k) t
$f$ language SQL IMMUTABLE;
COMMENT ON FUNCTION digpreserv_packid_to_ints(real)
 IS 'Decodes real pck_id into integer array[pkid,version], convention of the 20 years with 40 versions/year.'
;

CREATE or replace FUNCTION digpreserv_packid_to_str(pck_id real, sep boolean default false) RETURNS text AS $f$
 SELECT CASE WHEN sep IS NULL THEN replace(s,'.000','') WHEN sep THEN replace(s,'.','_') ELSE s END
 FROM ( SELECT to_char(CASE WHEN sep IS NULL THEN floor($1) ELSE $1 END,'FM999999000.000') s ) t
$f$ language SQL IMMUTABLE;

CREATE or replace FUNCTION digpreserv_packid_to_str(pck_id int[], sep boolean default false) RETURNS text AS $wrap$
  select  digpreserv_packid_to_str( digpreserv_packid_to_real($1), $2 )
$wrap$ language SQL IMMUTABLE;
CREATE or replace FUNCTION digpreserv_packid_to_str(pkid int, version int, sep boolean default false) RETURNS text AS $wrap$
 select  digpreserv_packid_to_str( digpreserv_packid_to_real($1,$2), $3 )
$wrap$ language SQL IMMUTABLE;

CREATE or replace FUNCTION digpreserv_packid_plusone(pck_id real) RETURNS real AS $f$
  SELECT digpreserv_packid_to_real(p[1],p[2]+1) -- +1?
  FROM (SELECT digpreserv_packid_to_ints(pck_id) p) t
$f$ language SQL IMMUTABLE;


CREATE or replace FUNCTION digpreserv_packid_isvalid(pck_id real) RETURNS boolean AS $f$
  SELECT CASE
    WHEN p IS NULL OR p[1] IS NULL OR p[1]=0 OR p[2]=0 OR digpreserv_packid_to_real(p)!=pck_id::real THEN false
    ELSE true
    END
  FROM (SELECT digpreserv_packid_to_ints(pck_id) p) t
$f$ language SQL IMMUTABLE;

-- falta dinâmico de MAX de real da tabela. Use digpreserv_packid_plusone(x) para o próximo.

CREATE or replace FUNCTION digpreserv_packid_getmax(
  p_tablename  text,
  p_plusone boolean DEFAULT false
) RETURNS real AS $f$
DECLARE
  r real;
BEGIN
  EXECUTE format(
    CASE
      WHEN p_plusone THEN 'SELECT MAX(pck_id) INTO r FROM %s'
      ELSE  'SELECT digpreserv_packid_plusone(MAX(pck_id)) INTO r FROM %s'
    END, p_tablename
  );
  RETURN r;
END
$f$ LANGUAGE PLpgSQL;
COMMENT ON FUNCTION digpreserv_packid_getmax
 IS 'Obtais the current (or the next when p_plusOne) pck_id of a table.'
;

-------------------------------
-- system -generic

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
   SELECT fname, (ROW_NUMBER() OVER())::int, -- feature_id,
          geojson_type, feature->>'type',    -- feature_type,
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

--------

CREATE or replace FUNCTION sql_parse_selectcols_simple(s text) RETURNS text AS $f$
   SELECT CASE
       WHEN $1 IS NULL OR p[1]='' OR array_length(p,1)>2 THEN NULL
       WHEN array_length(p,1)=1 THEN p[1]
       ELSE p[1] ||' AS '||p[2]
       END
   FROM (SELECT regexp_split_to_array(trim($1),'\s+') p) t
$f$ LANGUAGE SQL;

CREATE or replace FUNCTION sql_parse_selectcols(selcols text[]) RETURNS text[] AS $f$
   SELECT array_agg( CASE
      WHEN $1 IS NULL OR p_as IS NULL OR array_length(p_as,1)=0 OR array_length(p_as,1)>2 THEN NULL
      WHEN array_length(p_as,1)=2 THEN p_as[1] ||' AS '||p_as[2]
      ELSE sql_parse_selectcols_simple(p_as[1])
      END )
   FROM (
     SELECT i,regexp_split_to_array(x, '\s+as\s+','i') p_as
     FROM UNNEST($1) WITH ORDINALITY t1(x,i)
   ) t2
$f$ LANGUAGE SQL;

-- SELECT sql_parse_selectcols(array['row_number() OVER () as gid','x','y as z']);

--CREATE or replace FUNCTION ST_cast_to_simple(p_geom geometry) RETURNS geometry AS $f$
--$f$ LANGUAGE SQL;


CREATE or replace FUNCTION ST_AsGeoJSONb( -- ST_AsGeoJSON_complete
  -- st_asgeojsonb(geometry, integer, integer, bigint, jsonb
  p_geom geometry,
  p_decimals int default 6,
  p_options int default 1,  -- 1=better (implicit WGS84) tham 5 (explicit)
  p_id text default null,
  p_properties jsonb default null,
  p_name text default null,
  p_title text default null,
  p_id_as_int boolean default false
) RETURNS JSONb AS $f$
-- Do ST_AsGeoJSON() adding id, crs, properties, name and title
  SELECT ST_AsGeoJSON(p_geom,p_decimals,p_options)::jsonb
       || CASE
          WHEN p_properties IS NULL OR jsonb_typeof(p_properties)!='object' THEN '{}'::jsonb
          ELSE jsonb_build_object('properties',p_properties)
          END
       || CASE
          WHEN p_id IS NULL THEN '{}'::jsonb
          WHEN p_id_as_int THEN jsonb_build_object('id',p_id::bigint)
          ELSE jsonb_build_object('id',p_id)
          END
       || CASE WHEN p_name IS NULL THEN '{}'::jsonb ELSE jsonb_build_object('name',p_name) END
       || CASE WHEN p_title IS NULL THEN '{}'::jsonb ELSE jsonb_build_object('title',p_title) END
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION ST_AsGeoJSONb IS $$
  Enhances ST_AsGeoJSON() PostGIS function.
  Use ST_AsGeoJSONb( geom, 6, 1, osm_id::text, stable.element_properties(osm_id) - 'name:' ).
$$;


/* LIXO, VERIFCAR SE PODE REMOVER DAQUI:
-- -- -- -- -- -- -- -- -- -- --
-- GeoJSON functions

CREATE or replace FUNCTION ST_GeomFromGeoJSON_sanitized(
  p_j  JSONb, p_srid int DEFAULT 4326
) RETURNS geometry AS $f$
  SELECT g FROM (
   SELECT  ST_GeomFromGeoJSON(g::text)
   FROM (
   SELECT CASE
    WHEN p_j IS NULL OR p_j='{}'::JSONb OR jsonb_typeof(p_j)!='object'
        OR NOT(p_j?'type')
        OR  (NOT(p_j?'crs') AND (p_srid<1 OR p_srid>998999) )
        OR p_j->>'type' NOT IN ('Feature', 'FeatureCollection', 'Position', 'Point', 'MultiPoint',
         'LineString', 'MultiLineString', 'Polygon', 'MultiPolygon', 'GeometryCollection')
        THEN NULL
    WHEN NOT(p_j?'crs')  OR 'EPSG0'=p_j->'crs'->'properties'->>'name'
        THEN p_j || ('{"crs":{"type":"name","properties":{"name":"EPSG:'|| p_srid::text ||'"}}}')::jsonb
    ELSE p_j
    END
   ) t2(g)
   WHERE g IS NOT NULL
  ) t(g)
  WHERE ST_IsValid(g)
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION file_get_contents
 IS $$ Do ST_GeomFromGeoJSON() with correct SRID. OLD geojson_sanitize(), as https://gis.stackexchange.com/a/60945/7505 $$;

CREATE OR REPLACE FUNCTION st_read_geojson(
  p_path text,
  p_ext text DEFAULT '.geojson',
  p_basepath text DEFAULT '/var/gits/city-codes/data/dump_osm/'::text,
  p_srid int DEFAULT 4326
) RETURNS geometry AS $f$
  SELECT CASE WHEN length(s)<30 THEN NULL ELSE ST_GeomFromGeoJSON_sanitized(s::jsonb) END
  FROM  ( SELECT file_get_contents(p_basepath||p_path||p_ext) ) t(s)
$f$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION file_get_contents
 IS 'Gambiarra para ler geojson, até testar a melhor opção com funções nativas pg'
;
*/

---------------------

-- -- -- -- --
-- PostGIS complements, !future PubLib-postgis

-- Project digital-preservation-BR:
INSERT into spatial_ref_sys (srid, auth_name, auth_srid, proj4text, srtext)
 -- POSTGIS: SRID on demand, see Eclusa and Digital Preservation project demands.
 -- see https://wiki.openstreetmap.org/wiki/Brazil/Oficial/Carga#Adaptando_SRID
 -- after max(srid)=900913
VALUES
  ( 952013, 'BR-RS-POA', null,
   '+proj=tmerc +lat_0=0 +lon_0=-51 +k=0.999995 +x_0=300000 +y_0=5000000 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs',
   null
  ),
  ( 952019, 'BR:IBGE', 52019,
   '+proj=aea +lat_0=-12 +lon_0=-54 +lat_1=-2 +lat_2=-22 +x_0=5000000 +y_0=10000000 +ellps=WGS84 +units=m +no_defs',
   'PROJCS["Conica_Equivalente_de_Albers_Brasil",      GEOGCS["GCS_SIRGAS2000",          DATUM["D_SIRGAS2000",              SPHEROID["Geodetic_Reference_System_of_1980",6378137,298.2572221009113]],          PRIMEM["Greenwich",0],          UNIT["Degree",0.017453292519943295]],      PROJECTION["Albers"],      PARAMETER["standard_parallel_1",-2],      PARAMETER["standard_parallel_2",-22],      PARAMETER["latitude_of_origin",-12],      PARAMETER["central_meridian",-54],      PARAMETER["false_easting",5000000],      PARAMETER["false_northing",10000000],      UNIT["Meter",1]]'
  )
ON CONFLICT DO NOTHING;
