
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
  parent_abbrev   text  NOT NULL, -- state is admin-level2, country level1
  abbrev text  CHECK(length(abbrev)>=2 AND length(abbrev)<=5), -- ISO and other abbreviations
  wikidata_id  bigint,  --  from '^Q\d+'
  lexlabel     text NOT NULL,  -- cache from name; e.g. 'sao.paulo'.
  isolabel_ext text NOT NULL,  -- cache from parent_abbrev (ISO) and name (camel case); e.g. 'BR-SP-SaoPaulo'.
  ddd          integer, -- Direct distance dialing
  info JSONb -- admin_level, creation, extinction, postalCode_ranges, notes, etc.
  ,UNIQUE(jurisd_base_id,jurisd_local_id)
  ,UNIQUE(jurisd_base_id,parent_abbrev,name) -- parent-abbrev é null ou cumulativo
  ,UNIQUE(jurisd_base_id,parent_abbrev,lexlabel)
  ,UNIQUE(jurisd_base_id,parent_abbrev,isolabel_ext)
  ,UNIQUE(jurisd_base_id,parent_abbrev,abbrev)
);

CREATE TABLE optim.donor (
  id serial NOT NULL primary key,
  scope text, -- city code or country code
  shortname text, -- abreviation or acronym
  vat_id text,    -- in the Brazilian case is "CNPJ:number"
  legalName text NOT NULL, -- in the Brazilian case is Razao Social
  wikidata_id bigint,  -- without "Q" prefix
  url text,     -- official home page of the organization
  info JSONb,   -- all other information using controlled keys
  UNIQUE(vat_id),
  UNIQUE(scope,legalName)
);

CREATE TABLE optim.auth_user (
  -- authorized users to be a datapack responsible and eclusa-FTP manager
  username text NOT NULL PRIMARY KEY,
  info jsonb
);

CREATE TABLE optim.donatedPack(
  pack_id int NOT NULL PRIMARY KEY,
  donor_id int NOT NULL REFERENCES optim.donor(id),
  user_resp text NOT NULL REFERENCES optim.auth_user(username),
  accepted_date date NOT NULL,
  escopo text NOT NULL, -- bbox or minimum bounding AdministrativeArea
  about text,
  config_commom jsonb, -- parte da config de ingestão comum a todos os arquivos (ver caso Sampa)
  info jsonb
  ,UNIQUE(pack_id)
  ,UNIQUE(donor_id,accepted_date,escopo) -- revisar se precisa.
); -- pack é intermediário de agregação

CREATE TABLE optim.origin_content_type(
  id int PRIMARY KEY,
  label text,
  model_geo text,      -- tipo de geometria e seus atributos
  model_septable text, -- atributos da geometria em tabela separada
  is_useful boolean,      -- valido se true
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
  (15,'V1s','Via id','id name',TRUE,'good'),
  (101,'edificacoes','?','?',null,'bad'),
  (102,'lotes','?','?',null,'bad'),
  (103,'ruas','?','?',null,'bad'),
  (104,'eixos','?','?',null,'bad')
;
/*
INSERT INTO optim.origin_content_type VALUES
  (131,'transporte_publico','Rotas do transporte publico','?',FALSE,'bad'),
  (132,'license','Declaracao de licenca de uso do dado','?',FALSE,'bad'),
  (133,'edificacoes_lotes_quadras','?','?',FALSE,'bad');

-- id=100 em diante, ver select distinct ctype from eclusa.cityfolder_input('igor') order by 1;
cad
 data
 dwg
 edificacoes
 eixos
 enderecos
 equipamentos
 equipamentos_ponto
 gdb
 hidrografia
 lotes
 lotes_ponto
 meio_fio
 patrimonio
 pdf
 posteacao
 quadras
 std
 territorios
 vegetacao
*/

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
   is_open boolean    NOT NULL DEFAULT true, -- confere se finalizado ou "em aberto"
   fmeta jsonb,  -- file metadata
   config jsonb, -- complementado por pack com (config||config_commom) AS config
   ingest_instant timestamp DEFAULT now()
   ,UNIQUE(fhash)
   ,UNIQUE(jurisd_osm_id,fname,fversion,ctype) -- ,kx_ingest_date=ingest_instant::date
);
CREATE VIEW optim.vw01_origin AS
  SELECT o.*,
         j.name as jurisd_name,         j.parent_abbrev as jurisd_state,
         j.abbrev AS jurisd_abbrev3,    j.isolabel_ext AS jurisd_isolabel_ext,
         p.donor_id, p.user_resp,
         d.vat_id AS donor_vat_id,     d.shortname AS donor_shortname,
         d.legalName AS donor_legalName, d.url AS donor_url,
         p.accepted_date,              p.config_commom,
         ct.id AS ctype_id, ct.model_geo AS ctype_model_geo
  FROM (optim.origin o
       INNER JOIN optim.jurisdiction j         ON o.jurisd_osm_id=j.osm_id
       INNER JOIN optim.origin_content_type ct ON o.ctype=ct.label
       INNER JOIN optim.donatedPack p          ON o.pack_id=p.pack_id
     ) INNER JOIN optim.donor d ON p.donor_id = d.id
;
CREATE VIEW optim.vwdump_origin AS  -- for digital-preservation-XX/out need a function!
  SELECT  id,jurisd_osm_id,ctype,pack_id,fhash,fname,fversion,is_valid,
          fmeta -'fpath' -'creation' -'modification' AS fmeta,
          config,ingest_instant
  FROM optim.origin
  -- where jurisd_osm_id in country and year(accepted_date) is current
  ORDER BY id
;

CREATE VIEW optim.vw_source AS -- ORIGIN+donatedPack
  SELECT id, pack_id, donor_id, user_resp, accepted_date, jurisd_isolabel_ext
  FROM optim.vw01_origin
  UNION
  SELECT -pack_id, pack_id, donor_id,user_resp, accepted_date, escopo
  FROM optim.donatedPack
  -- WHERE pack_id IN (select pack_id, count(*) from optim.origin group by 1 having count(*)>1)
;

/*
CREATE VIEW optim.vw01_origin AS
  -- REVISAR com novos campos jurisdiction
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
*/

-- -- --
-- SQL and bash generators (optim-ingest submodule)

CREATE or replace FUNCTION optim.fdw_generate(
  p_name text,  -- name or target-table name
  p_jurisd_abbrev text DEFAULT 'br',  -- or null
  p_schemaname text DEFAULT 'optim',
  p_columns text[] DEFAULT NULL,
  p_path text DEFAULT NULL  -- default based on ids
) RETURNS text  AS $f$
DECLARE
 fdwname text;
 fpath text;
 f text;
BEGIN
 fpath := COALESCE(p_path,'/tmp/pg_io'); -- /tmp/pg_io/digital-preservation-XX
 f := concat(fpath,'/', iIF(p_jurisd_abbrev IS NULL,'',p_jurisd_abbrev||'-'), p_name, '.csv');
 p_jurisd_abbrev := iIF(p_jurisd_abbrev IS NULL, '', '_'|| p_jurisd_abbrev);
 fdwname := 'tmp_orig.fdw_'|| iIF(p_schemaname='optim', '', p_schemaname||'_') || p_name || p_jurisd_abbrev;
 -- poderia otimizar por chamada (alter table option filename), porém não é paralelizável.
 EXECUTE
    format(
      'DROP FOREIGN TABLE IF EXISTS %s; CREATE FOREIGN TABLE %s (%s)',
       fdwname, fdwname, array_to_string(p_columns,',')
     ) || format(
       'SERVER files OPTIONS (filename %L, format %L, header %L, delimiter %L)',
       f, 'csv', 'true', ','
    );
    return ' '|| fdwname || E' was created!\n source: '||f|| ' ';
END;
$f$ language PLpgSQL;
COMMENT ON FUNCTION optim.fdw_generate
  IS 'Generates a structure FOREIGN TABLE for ingestion.'
;

CREATE or replace FUNCTION optim.fdw_generate_getclone(
  -- foreign-data wrapper generator
  p_tablename text,  -- cloned-table name
  p_jurisd_abbrev text DEFAULT 'br',  -- or null
  p_schemaname text DEFAULT 'optim',
  p_ignore text[] DEFAULT NULL, -- colunms to be ignored.
  p_add text[] DEFAULT NULL, -- colunms to be added.
  p_path text DEFAULT NULL  -- default based on ids
) RETURNS text  AS $wrap$
  SELECT optim.fdw_generate(
    $1,$2,$3,
    pg_tablestruct_dump_totext(p_schemaname||'.'||p_tablename,p_ignore,p_add),
    p_path
  )
$wrap$ language SQL;
COMMENT ON FUNCTION optim.fdw_generate_getclone
  IS 'Generates a clone-structure FOREIGN TABLE for ingestion.'
;

CREATE or replace FUNCTION optim.fdw_wgets_script(
   -- first step is to wget
   p_subset text DEFAULT '', -- ''='all' and 'refresh'.
   p_output_shfile text DEFAULT '/tmp/pg_io/run_wgets'
   -- p_remove_all_csv true.
) RETURNS text AS $f$
  -- gambiarra temporária, depois que tomar forma criar tabelas e gerador automatico;
  WITH
   t0 AS (SELECT CASE WHEN p_subset='' OR p_subset is null THEN 'all' ELSE lower(p_subset) END as s)
   ,t1 AS (
     SELECT '001' as g,'mkdir -p /tmp/pg_io/digital-preservation-XX' as cmd
     UNION ALL
     SELECT '002', 'rm -f "/tmp/pg_io/digital-preservation-XX/"*'|| iIF(s='all','','-'||s) ||'.csv' FROM t0
     UNION ALL
     SELECT 'all', 'wget -P /tmp/pg_io/digital-preservation-XX/ -N https://raw.githubusercontent.com/datasets-br/state-codes/master/data/br-region-codes.csv'
     UNION ALL
     SELECT 'refresh', 'wget -P /tmp/pg_io/digital-preservation-XX/ -N http://git-raw.addressforall.org/digital-preservation-BR/master/data/in/br-jurisdiction.csv'
     UNION ALL
     SELECT 'refresh', 'wget -P /tmp/pg_io/digital-preservation-XX/ -N http://git-raw.addressforall.org/digital-preservation-BR/master/data/in/br-donatedPack.csv'
     UNION ALL
     SELECT 'refresh', 'wget -P /tmp/pg_io/digital-preservation-XX/ -N http://git-raw.addressforall.org/digital-preservation-BR/master/data/in/br-donor.csv'
   )
   ,t2 as (
     SELECT string_agg(cmd,E'\n') as cmds
     FROM ( -- t3:
      SELECT cmd FROM t0, t1
      WHERE (t0.s='all' AND t1.g<'999') OR iif(t0.s='all', true, p_subset=t1.g) --  OR p_subset='002'
      ORDER BY g
     ) t3
   ) -- \t2
   SELECT COALESCE(
          'Anterior deletado: '||pg_catalog.pg_file_unlink((SELECT p_output_shfile||'-'||s||'.sh' FROM t0))::text
          ||E'\nGravados '
          || pg_catalog.pg_file_write(output_shfile,t2.cmds,false)::text
          ||' bytes em '|| output_shfile ||E' \n'
          ,E'ERRO, algo NULL em optim.fdw_wgets_script() \n'
          ||concat('output_shfile=',output_shfile IS NULL,' t2.cmds=',t2.cmds IS NULL)
        ) as fim
   FROM t2, (SELECT p_output_shfile||'-'||s||'.sh' FROM t0) t4(output_shfile);
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
SELECT optim.fdw_generate_getclone('jurisdiction', 'br', 'optim', null,null, '/tmp/pg_io/digital-preservation-XX');
SELECT optim.fdw_generate(
  'donatedPack',  'br', 'optim',
  array[
    'pack_id int',        'donor_id int',         'donor_label text',
    'user_resp text',     'accepted_date date',   'escopo text',
    'about text',         'author text',          'contentReferenceTime text',
    'license_is_explicit text', 'license text',   'uri_objType text',
    'uri text',           'isAt_UrbiGIS text'
  ],
  '/tmp/pg_io/digital-preservation-XX'
);

SELECT optim.fdw_generate(
  -- usando ordem dos campos confirme git
  'donor',  'br', 'optim',
  array[
    'id int',          'escopo text',      'shortName text',
    'vat_id text',     'legalName text',   'wikidata_id bigint',
    'url text'
  ],
  '/tmp/pg_io/digital-preservation-XX'
);

-----

CREATE or replace FUNCTION optim.fdw_wgets_refresh(
  -- second step (after wget) is to insert the "refresh group".
  p_do_update boolean DEFAULT false
) RETURNS text AS $f$
  -- falta UPDATE jurisdiction e retornarc COUNTs! https://stackoverflow.com/a/25941849/287948
  -- mudar para PLpgSQL e usar `GET DIAGNOSTICS my_var_tab = ROW_COUNT` a cada upsert.
  INSERT INTO optim.jurisdiction
    SELECT * FROM tmp_orig.fdw_jurisdiction_br
    ON CONFLICT DO NOTHING
  ; -- ok
  INSERT INTO optim.donor
    SELECT * FROM tmp_orig.fdw_donor_br
    ON CONFLICT (id)
    DO UPDATE
       SET  id=EXCLUDED.id, scope=EXCLUDED.scope, shortName=EXCLUDED.shortName,
            vat_id=EXCLUDED.vat_id, legalName=EXCLUDED.legalName,
            wikidata_id=EXCLUDED.wikidata_id, url=EXCLUDED.url
       WHERE p_do_update
  ;
  INSERT INTO optim.donatedPack
    SELECT pack_id,donor_id,user_resp,accepted_date,escopo,about, null,
           jsonb_build_object(
             'author',author,      'contentReferenceTime',contentReferenceTime,
             'license_is_explicit',text_to_boolean(license_is_explicit),
             'license',license,   'uri_objType',uri_objType,
             'uri',uri,           'isAt_UrbiGIS',text_to_boolean(isAt_UrbiGIS)
           )
    FROM tmp_orig.fdw_donatedPack_br
    ON CONFLICT (pack_id)
    DO UPDATE
    SET  pack_id=EXCLUDED.pack_id,      donor_id=EXCLUDED.donor_id,
         user_resp=EXCLUDED.user_resp,  accepted_date=EXCLUDED.accepted_date,
         escopo=EXCLUDED.escopo,        about=EXCLUDED.about,
         config_commom=EXCLUDED.config_commom, info=EXCLUDED.info
    WHERE p_do_update
  ;-- ok
  -- usar ROW_COUNT a cada caso!
  SELECT 'OK, inserted new itens at jurisdiction, donor and donatedPack. ';
$f$ language SQL;

-- falta   SELECT optim.fdw_generate_getclone('origin_content_type', NULL, 'optim');
/* deu pau pois inverte ordem do CSV
PREPARE fdw_gen(text) AS SELECT optim.fdw_generate_getclone($1, 'br', 'optim', array['info'],null, '/tmp/pg_io/digital-preservation-XX');
  EXECUTE fdw_gen('donor');         -- creates tmp_orig.fdw_donor_br
  -- (só publica nao ingere) EXECUTE fdw_gen('origin');        -- creates tmp_orig.fdw_origin_br
-- gera script de download dos dados:
SELECT optim.fdw_wgets_script('/tmp/pg_io/run_wgets.sh');
-- por fim rodar inserts no STEP2
