
-- OPTIM STEP1
-- Inicialização do Módulo principal de dados AddressForAll.
--

CREATE extension IF NOT EXISTS postgis;
CREATE extension IF NOT EXISTS adminpack;

CREATE EXTENSION IF NOT EXISTS file_fdw;
CREATE SERVER    IF NOT EXISTS files FOREIGN DATA WRAPPER file_fdw;

CREATE schema    IF NOT EXISTS api;
CREATE schema    IF NOT EXISTS ingest;
CREATE schema    IF NOT EXISTS optim;
CREATE schema    IF NOT EXISTS tmp_orig;

-- -- -- -- -- -- -- -- --
-- inicializações OPTIM:

CREATE TABLE IF NOT EXISTS optim.jurisdiction ( -- only current
  -- need a view vw01current_jurisdiction to avoid the lost of non-current.
  -- https://schema.org/AdministrativeArea or https://schema.org/jurisdiction ?
  -- OSM use AdminLevel, etc. but LexML uses Jurisdiction.
  osm_id bigint PRIMARY KEY,    -- official or adapted geometry. AdministrativeArea.
  jurisd_base_id int NOT NULL,  -- ISO3166-1-numeric COUNTRY ID (e.g. Brazil is 76) or negative for non-iso (ex. oceans)
  jurisd_local_id int   NOT NULL, -- numeric official ID like IBGE_ID of BR jurisdiction.
  -- for example BR's ACRE is 12 and its cities are {1200013, 1200054,etc}.
  name    text  NOT NULL CHECK(length(name)<60), -- city name for admin-level3 (OSM level=?)
  parent_abbrev   text  NOT NULL CHECK(length(parent_abbrev)=2), -- state is admin-level2, country level1
  abbrev text  CHECK(length(abbrev)>=2 AND length(abbrev)<=5), -- ISO and other abbreviations
  wikidata_id  bigint,  --  from '^Q\d+'
  lexlabel     text NOT NULL,  -- cache from name; e.g. 'sao.paulo'.
  isolabel_ext text NOT NULL,  -- cache from parent_abbrev (ISO) and name (camel case); e.g. 'BR-SP-SaoPaulo'.
  ddd          integer, -- Direct distance dialing
  info JSONb -- postalCode_ranges, notes,   creation, extinction, etc.
  ,UNIQUE(jurisd_base_id,jurisd_local_id)
  ,UNIQUE(jurisd_base_id,parent_abbrev,name)
  ,UNIQUE(jurisd_base_id,parent_abbrev,lexlabel)
  ,UNIQUE(jurisd_base_id,parent_abbrev,isolabel_ext)
  ,UNIQUE(jurisd_base_id,parent_abbrev,abbrev)
);
CREATE TABLE optim.donor (
  id serial NOT NULL primary key,
  scope text, -- city code or country code
  vat_id text,
  shortname text,
  legalName text NOT NULL,
  wikidata_id bigint,
  url text,
  info JSONb,
  UNIQUE(vat_id),
  UNIQUE(scope,legalName)
);
CREATE TABLE optim.donatedPack(
  pack_id int NOT NULL PRIMARY KEY,
  donor_id int NOT NULL REFERENCES optim.donor(id),
  accepted_date date,
  about text,
  config_commom jsonb, -- parte da config de ingestão comum a todos os arquivos (ver caso Sampa)
  info jsonb,
  UNIQUE(pack_id)
); -- pack é só intermediário de agregação

CREATE TABLE optim.origin_content_type(
  id int PRIMARY KEY,
  label text,
  model_geo text,      -- tipo de geometria e seus atributos
  model_septable text, -- atributos da geometria em tabela separada
  is_useful text,      -- valido se true
  score text           -- avaliação de preferência
  ,UNIQUE(label)
);
INSERT INTO optim.origin_content_type VALUES
  (1,'PL1','Point Lot via_name housenumber','',TRUE,'perfect'),
  (2,'PL1s','Point Lot id','id via_name housenumber',TRUE,'perfect'), -- separated
  (3,'P1','Point via_name housenumber','',TRUE,'perfect'),
  (4,'P2','Point housenumber','',TRUE,'good'),
  (5,'P1s','Point id ','id via_name housenumber',TRUE,'perfect'),    -- separated
  (6,'P2s','Point id','id housenumber',TRUE,'good'),
  (7,'P3e','Point','',FALSE,'bad'),                                  -- empty
  (8,'L1','Lot via_name housenumber','',TRUE,'perfect'),
  (9,'L2','Lot housenumber','',TRUE,'good'),
  (10,'L2s','Lot id','id housenumber',TRUE,'good'),
  (11,'L1s','Lot id','id via_name housenumber',TRUE,'perfect'),
  (12,'L3','Lot','',FALSE,'bad'),
  (13,'N1s','(null)','via_name housenumber region',FALSE,'bad'),
  (14,'V1','Via name','',TRUE,'perfect'),
  (15,'V1s','Via id','id name',TRUE,'good')
;

CREATE TABLE IF NOT EXISTS optim.origin(
   id serial           NOT NULL PRIMARY KEY,
   jurisd_osm_id int   NOT NULL REFERENCES optim.jurisdiction(osm_id), -- scope of data, desmembrando arquivos se possível.
   ctype text          NOT NULL REFERENCES optim.origin_content_type(label),  -- .. tipo de entrada que amarra com config!
   pack_id int         NOT NULL REFERENCES optim.donatedPack(pack_id), -- um ou mais origins no mesmo paxck.
   fhash text          NOT NULL, -- sha256 is a finger print
   fname text          NOT NULL,  -- filename
   fversion smallint   NOT NULL DEFAULT 1, -- fname version (counter for same old filename+ctype).
   -- PS: pack version or file intention version? Or only control over changes?...  ou versão relativa às conig.
   kx_cmds text[],  -- conforme config; uso posterior para guardar sequencia de comandos.
   is_valid boolean   NOT NULL DEFAULT false,
   is_open boolean    NOT NULL DEFAULT true,
   fmeta jsonb,  -- file metadata
   config jsonb, -- complementado por pack com (config||config_commom) AS config
   ingest_instant timestamp DEFAULT now()
   ,UNIQUE(fhash)
   ,UNIQUE(jurisd_osm_id,fname,fversion,ctype) -- ,kx_ingest_date=ingest_instant::date
);

CREATE VIEW optim.vw01_origin AS
  SELECT o.*,
         c.name as city_name,          c.parent_abbrev as city_state,
         c.abbrev AS city_abbrev3,    c.isolabel_ext AS city_isolabel_ext,
         d.vat_id AS donor_vat_id,     d.shortname AS donor_shortname,
         d.legalName AS donor_legalName, d.url AS donor_url,
         p.accepted_date,              p.config_commom
  FROM (optim.origin o
       INNER JOIN optim.jurisdiction c ON o.jurisd_osm_id=c.osm_id
       LEFT JOIN optim.donatedPack p ON o.pack_id=p.pack_id
     ) LEFT JOIN optim.donor d ON p.donor_id = d.id
;

-- -- --
-- SQL and bash generators (optim-ingest submodule)

CREATE or replace FUNCTION optim.fdw_generate_getclone(
  -- foreign-data wrapper generator
  p_tablename text,
  p_jurisd_abbrev text DEFAULT 'br',  -- or null
  p_schemaname text DEFAULT 'optim',
  p_path text DEFAULT NULL  -- default based on ids
) RETURNS text  AS $f$
DECLARE
 fdwname text;
 fpath text;
 f text;
BEGIN
 fpath := COALESCE(p_path,'/tmp/pg_io');
 f := concat(fpath,'/', iIF(p_jurisd_abbrev IS NULL,'',p_jurisd_abbrev||'-'), p_tablename, '.csv');
 p_jurisd_abbrev := iIF(p_jurisd_abbrev IS NULL, '', '_'|| p_jurisd_abbrev);
 fdwname := 'tmp_orig.fdw_'|| iIF(p_schemaname='optim', '', p_schemaname||'_') || p_tablename || p_jurisd_abbrev;
 -- poderia otimizar por chamada (alter table option filename), porém não é paralelizável.
 EXECUTE
    format(
      'DROP FOREIGN TABLE IF EXISTS %s; CREATE FOREIGN TABLE %s (%s)',
       fdwname, fdwname, array_to_string(pg_tablestruct_dump_totext(p_schemaname||'.'||p_tablename),',')
     ) || format(
       'SERVER files OPTIONS (filename %L, format %L, header %L, delimiter %L)',
       f, 'csv', 'true', ','
    );
    return ' '|| fdwname || E' was created!\n source: '||f|| ' ';
END;
$f$ language PLpgSQL;
COMMENT ON FUNCTION optim.fdw_generate_getclone
  IS 'Generates a same-structure FOREIGN TABLE for ingestion.'
;

CREATE or replace FUNCTION optim.fdw_wgets_script(
  p_output_shfile text DEFAULT '/tmp/pg_io/run_wgets.sh'
) RETURNS text AS $f$
 -- gambiarra temporária, depois que tomar forma criar tabelas e gerador automatico;
 SELECT pg_catalog.pg_file_unlink(p_output_shfile);
 WITH t AS (
    SELECT $$
    mkdir -p /tmp/pg_io/digital-preservation-XX
    rm -f "/tmp/pg_io/digital-preservation-XX/"*.csv
    wget -P /tmp/pg_io/digital-preservation-XX/  https://raw.githubusercontent.com/datasets-br/state-codes/master/data/br-region-codes.csv
    wget -P /tmp/pg_io/digital-preservation-XX/  http://git-raw.addressforall.org/digital-preservartion-BR/master/data/br-jurisdiction.csv
    wget -P /tmp/pg_io/digital-preservation-XX/  http://git-raw.addressforall.org/digital-preservartion-BR/master/data/br-donatedPack.csv
    wget -P /tmp/pg_io/digital-preservation-XX/  http://git-raw.addressforall.org/digital-preservartion-BR/master/data/br-donor.csv
    wget -P /tmp/pg_io/digital-preservation-XX/  http://git-raw.addressforall.org/digital-preservartion-BR/master/data/br-origin.csv
    $$ as cmds
 )
 SELECT 'Gravados '
        || pg_catalog.pg_file_write(p_output_shfile,cmds,false)::text
        ||' bytes em '|| p_output_shfile ||E' \n' as fim
 FROM t;
$f$ language SQL immutable;

-- -- --
-- API

CREATE VIEW api.jurisdiction AS SELECT * FROM optim.jurisdiction
; COMMENT ON VIEW api.jurisdiction
  IS 'An optim core table.'
;
CREATE VIEW api.donor AS        SELECT * FROM optim.donor
; COMMENT ON VIEW api.donor
  IS 'An optim table and Digital Preservation core.'
;
CREATE VIEW api.donatedPack AS  SELECT * FROM optim.donatedPack
; COMMENT ON VIEW api.donatedPack
  IS 'An optim table and Digital Preservation core.'
;
CREATE VIEW api.origin AS       SELECT * FROM optim.origin
; COMMENT ON VIEW api.origin
  IS 'An optim table and Digital Preservation core.'
;
CREATE VIEW api.origin_content_type AS SELECT * FROM optim.origin_content_type
; COMMENT ON VIEW api.origin_content_type
  IS 'An optim table and Digital Preservation core.'
;



-- -- --
-- Pre-insert (generating FDWs)

\echo E'\n --- FDW para ingestão de dados do git ---'
PREPARE fdw_gen(text) AS SELECT optim.fdw_generate_getclone($1, 'br', 'optim');
  EXECUTE fdw_gen('jurisdiction');  -- creates tmp_orig.fdw_jurisdiction_br
  EXECUTE fdw_gen('donor');         -- creates tmp_orig.fdw_donor_br
  EXECUTE fdw_gen('donatedPack');   -- creates  tmp_orig.fdw_donatedPack_br
  EXECUTE fdw_gen('origin');        -- creates tmp_orig.fdw_origin_br

SELECT optim.fdw_wgets_script('/tmp/pg_io/run_wgets.sh');

-- falta   SELECT optim.fdw_generate_getclone('origin_content_type', NULL, 'optim');
