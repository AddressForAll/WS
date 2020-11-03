CREATE SCHEMA IF NOT EXISTS api;

-- NOTE. Don`t use "vw" prefix on API.viewName because all are VIEWS.

-- -- -- -- -- -- -- -- -- -- --
-- DIRECT clones of core tables.


CREATE or replace VIEW api.jurisdiction AS SELECT * FROM optim.jurisdiction
; COMMENT ON VIEW api.jurisdiction
  IS 'An optim core table.'
;
CREATE or replace VIEW api.donor AS        SELECT * FROM optim.donor
; COMMENT ON VIEW api.donor
  IS 'Donor View. An optim table and Digital Preservation core.'
;
CREATE or replace VIEW api.donatedPack AS  SELECT * FROM optim.donatedPack
; COMMENT ON VIEW api.donatedPack
  IS 'DonatedPack View. An optim table and Digital Preservation core.'
;
CREATE or replace VIEW api.origin AS       SELECT * FROM optim.origin
; COMMENT ON VIEW api.origin
  IS 'Origin View. An optim table and Digital Preservation core.'
;
CREATE or replace VIEW api.origin_content_type AS SELECT * FROM optim.origin_content_type
; COMMENT ON VIEW api.origin_content_type
  IS 'Content type valid in Origin. An optim table and Digital Preservation core.'
;

CREATE or replace VIEW api.auth_user AS SELECT * FROM optim.auth_user
; COMMENT ON VIEW api.auth_user
  IS 'Authorized user. An optim table and Digital Preservation core.'
;

----
CREATE VIEW api.origin_agg1 AS
  SELECT jurisd_base_id, substr(jurisd_isolabel_ext, 1, 2) AS country,
   count(*) AS orig_n_files,
   count(DISTINCT vw01_origin.pack_id) AS orig_n_packs,
   COUNT(*)                 n_files,
   COUNT(DISTINCT pack_id)  n_packs,
   COUNT(DISTINCT jurisd_osm_id)        n_jurisds,
   round(sum((vw01_origin.fmeta -> 'size'::text)::bigint) / 1000000::numeric) AS orig_mb
  FROM optim.vw01_origin
  GROUP BY 1,2
  ORDER BY 2
; COMMENT ON VIEW api.origin_agg1
  IS '(temporary, rename to agg1country_origin) Aggregating Origin by country-code.'
;
---

CREATE VIEW api.vw_jurisd_origin AS
  SELECT jurisd_base_id, jurisd_state,jurisd_admin_level,
    COUNT(*)                 n_files,
    COUNT(DISTINCT pack_id)  n_packs,
    COUNT(DISTINCT donor_id) n_donors,
    COUNT(DISTINCT jurisd_osm_id)        n_jurisds,
    SUM((fmeta->'size')::int)::bigint as bytes
   FROM optim.vw01_origin
   -- WHERE =8
  GROUP BY 1,2,3
  ORDER BY 1,3,2
; COMMENT ON VIEW api.vw_jurisd_origin
  IS 'Temporaria, renomear para agg2jurisd_origin.'
;

CREATE VIEW api.vw_donors_origin AS
  SELECT donor_id, donor_shortname, donor_legalname,
     COUNT(*)                 n_files,
     COUNT(DISTINCT pack_id)  n_packs,
     COUNT(DISTINCT jurisd_osm_id)        n_jurisds,
     SUM((fmeta->'size')::int)::bigint as bytes
    FROM optim.vw01_origin
   GROUP BY 1,2,3
   ORDER BY donor_shortname
; COMMENT ON VIEW api.vw_donors_origin
  IS 'Temporaria, renomear para agg3donors_origin.'
;

-- -- -- -- -- -- -- --
-- API TABLE TEMPLATEs. Definições globais, com origem em diversos projetos.

CREATE TABLE api.ttpl_general01_namecheck(
  is_valid boolean,     name text,      invalid_explain text
  ,UNIQUE(name)
); COMMENT ON TABLE api.ttpl_general01_namecheck
  IS 'Standard check-names structure. Ref. eclusa.cityfolder_validUsers().'
;

CREATE TABLE api.ttpl_core01_jurisdiction(LIKE optim.jurisdiction  -- revisar??
); COMMENT ON TABLE api.ttpl_core01_jurisdiction
  IS 'Standard Jurisdiction view, core data model.'
;
CREATE TABLE api.ttpl_core02_donor(
  --LIKE optim.donor -kx_vat_id
  id serial NOT NULL primary key,
  scope text, -- city code or country code
  shortname text, -- abreviation or acronym
  vat_id text,    -- in the Brazilian case is "CNPJ:number"
  legalName text NOT NULL, -- in the Brazilian case is Razao Social
  wikidata_id bigint,  -- without "Q" prefix
  url text,     -- official home page of the organization
  info JSONb,   -- all other information using controlled keys
  kx JSONb  -- cache to transport JOINED coluns
); COMMENT ON TABLE api.ttpl_core02_donor
  IS 'Standard Donor view, core data model.'
;

CREATE TABLE api.ttpl_core03_origin(
  -- LIKE optim.origin + kx
  id int, jurisd_osm_id bigint, ctype text, pack_id int, fhash text,
  fname text, fversion smallint, kx_cmds text[], is_valid boolean, is_open boolean,
  fmeta jsonb, config jsonb, ingest_instant timestamp, kx jsonb
); COMMENT ON TABLE api.ttpl_core03_origin
  IS 'Standard Origin view, core data model.'
;

CREATE TABLE api.ttpl_eclusa01_packdir(
  username text, jurisdiction_label text,
  jurisdiction_osmid bigint, pack_path text, pack_id int, packinfo JSONb
  ,UNIQUE(pack_id)
  ,UNIQUE(pack_path)
); COMMENT ON TABLE api.ttpl_general01_namecheck
  IS 'Standard pack path structure. Ref. eclusa.cityfolder_input_packdir().'
;

CREATE TABLE api.ttpl_eclusa02_cityfile1 (
  pack_id int,        ctype text,          fid int,
  fname text,         is_valid boolean,    fmeta JSONb
  ,UNIQUE(fid)
  ,UNIQUE(pack_id,ctype,fname)
); COMMENT ON TABLE api.ttpl_eclusa02_cityfile1
  IS 'List filenames. Ref. eclusa.cityfolder_input_files_user().'
;
INSERT INTO  api.ttpl_eclusa02_cityfile1 VALUES
  (NULL, NULL, NULL, NULL, NULL,
   '{"dispatching_errcod":-1,"dispatching_errmsg":"empty endpoint, use e.g. /eclusa/$other_eclusa_parts"}'::jsonb
  ),
  (NULL, NULL, NULL, NULL, NULL,
   '{"dispatching_errcod":-2,"dispatching_errmsg":"incomplete endpoint, try something as /eclusa/checkUserFiles-step1/$user"}'::jsonb
  ),
  (NULL, NULL, NULL, NULL, NULL,
   '{"dispatching_errcod":-3,"dispatching_errmsg":"endpoint not found, try something as /eclusa/checkUserFiles-step1/$user/$is_valid"}'::jsonb
  )
;
-- ttpl_eclusa02_cityfile2 in use?
CREATE TABLE api.ttpl_eclusa03_cityfile2 (LIKE api.ttpl_eclusa02_cityfile1 INCLUDING ALL);
ALTER TABLE api.ttpl_eclusa03_cityfile2 ADD  hash text, ADD err_msg text;
COMMENT ON TABLE api.ttpl_eclusa03_cityfile2
  IS 'List filenames and its hashes. Ref. eclusa.??().'
;

CREATE TABLE api.ttpl_eclusa04_hash ( -- IN USE??
  hash text, hashtype text, fname text, refpath text
);

-- -- -- -- -- -- -- --
-- API.uri_dispatchers:
-- note: after changes, $make dkr_refresh

CREATE or replace FUNCTION API.apiroot() RETURNS jsonb AS $f$
   SELECT '{"error_cod":1,"error_msg":"API LIST UNDER CONSTRUCTION"}'::jsonb
$f$ language SQL immutable;
COMMENT ON FUNCTION API.apiroot
  IS 'Lists all current API functions.'
;

CREATE or replace FUNCTION API.uri_dispatch_parser(
    uri text,        -- e.g. /eclusa/checkUserFiles_step1/igor/0
    uri_prefix text[] DEFAULT NULL,  -- e.g. '{eclusa,checkuserfiles-step1}'
    args text DEFAULT NULL
) RETURNS text[] AS $f$
  WITH topt AS (
    SELECT p, p_len, COALESCE(prefix_len,0) prefix_len,
    (uri_prefix IS NULL OR uri_prefix=p[1:prefix_len]) AS valid_prefix
    FROM (
      SELECT regexp_split_to_array(trim(lower(uri),'/'), '/'),
             array_upper(uri_prefix,1)
      ) t1(p,prefix_len),
         LATERAL (select array_upper(p,1) as p_len) t2
  )
  SELECT CASE WHEN valid_prefix AND p_len>=prefix_len THEN p[prefix_len+1:] ELSE NULL END
  FROM topt
$f$ language SQL immutable;
COMMENT ON FUNCTION API.uri_dispatch_parser
  IS 'A uri_dispatcher_x() parser, returning NULL or standard strings of the endpont call.'
; -- e.g. select API.uri_dispatch_parser('/eclusa/checkUserFiles-step1/igor/0', '{eclusa,checkuserfiles-step1}');

/*
CREATE or replace FUNCTION API.uri_dispatcher_scalar(
    uri text DEFAULT '',
    args text DEFAULT NULL
) RETURNS JSONb AS $f$
  WITH topt AS (
    SELECT p, p_len, CASE WHEN p_len<3 THEN NULL ELSE p[3] END AS p3 -- frequent use
    FROM (SELECT regexp_split_to_array(trim(lower(uri),'/'), '/')) t1(p),
         LATERAL (select array_upper(p,1) as p_len) t2
  )
  SELECT CASE
    WHEN p_len=1 AND p[1]='xxx' THEN  f1()
    WHEN p_len<=1 THEN f_err(-1)
    WHEN p[2]='yyyy-step1' THEN f1(p[3])
    WHEN p[2]='yyyy-step2' THEN f2(p[3],p[4])
    ELSE f_err(-2)
    END
  FROM topt -- WHERE p is not NULL
$f$ language SQL immutable;
COMMENT ON FUNCTION API.uri_dispatcher_scalar
  IS 'Main uri_dispatcher, for pure-JSON return. No automatic CSV conversion at PostgREST.'
;
*/

----------------------

-- -- -- -- -- -- -- -- --
-- API ENDPOINT FUNCTIONS:


CREATE or replace FUNCTION API.uridisp_vw_core_jurisdiction(
    p_uri text DEFAULT '', -- e.g. /vw_core/vw_core/jurisdiction/{isolabel_ext}
    p_args text DEFAULT NULL
) RETURNS TABLE (LIKE api.ttpl_core01_jurisdiction) AS $f$
        SELECT t2.*
        FROM API.uri_dispatch_parser(p_uri) t1(p) -- rev ,'{eclusa,checkuserfiles_step2}'
        INNER JOIN optim.jurisdiction  t2 -- or api.jurisdiction?
        ON t1.p[1] IS NOT NULL
        WHERE CASE
          -- retorna listagem:
          WHEN t1.p[1] IS NULL OR  t1.p[1]='' THEN true
          WHEN t1.p[1]~'^isolabel_ext\.lk\..+$'  THEN upper(t2.isolabel_ext) LIKE (upper(substr(t1.p[1],17))||'%')
          WHEN t1.p[1]~'^parent_abbrev\.lk\..+$' THEN
            t2.isolabel_ext LIKE (upper(substr(t1.p[1],18))||'%') and t2.parent_abbrev=upper(substr(t1.p[1],18))
            -- AND admin_level=8?
          WHEN t1.p[1]~'^parent_abbrev\.eq\..+$' THEN t2.parent_abbrev = upper(substr(t1.p[1],18)) -- AND admin_level=8?
          -- retorna item exato:
          WHEN t1.p[1] LIKE 'br-__-___' THEN
               t2.abbrev=upper(substr(t1.p[1],7))
               AND substr(t2.isolabel_ext,1,6)=upper(substr(t1.p[1],1,6))
          WHEN t1.p[1] iLIKE 'br;__;%' THEN
               t2.lexlabel=lower(substr(t1.p[1],7))
               AND substr(t2.isolabel_ext,1,6)=replace(upper(substr(t1.p[1],1,6)),';','-')
           WHEN t1.p[1]~'^q\d+$' THEN t2.wikidata_id=substr(t1.p[1],2)::bigint
           WHEN t1.p[1]~'^\d+$'  THEN CASE   -- ID numerico?
               WHEN t1.p[2] IS NOT NULL THEN -- com segundo parametro?
                t1.p[2]~'^\d+$' AND t2.jurisd_local_id=(t1.p[2])::int AND t2.jurisd_base_id=(t1.p[1])::int
               ELSE t2.osm_id=(t1.p[1])::bigint -- OSM relation
               END
           ELSE CASE   -- codigo nao-numerico no primeiro parametro.
               WHEN t1.p[2] IS NULL THEN upper(t2.isolabel_ext)=upper(t1.p[1])
               ELSE -- dois parametros
                  t2.jurisd_base_id=(SELECT jurisd_base_id FROM optim.jurisdiction WHERE isolabel_ext=upper(t1.p[1]))
                  AND
                  t1.p[2]~'^\d+$' AND t2.jurisd_local_id=(t1.p[2])::int -- por ex. IBGE_ID
               END
           END
$f$ language SQL immutable;
COMMENT ON FUNCTION API.uridisp_vw_core_jurisdiction
  IS 'Jurisdiction basic properties, from many alternatives to express its identification.'
;
-- CREATE or replace FUNCTION API.uridisp_vw_core_jurisdiction_geojson() ...
-- vai devolver o mapa com atributos basicos retornados da funcao. Decidir se havera NGINX detectando extensao.

CREATE or replace FUNCTION API.uridisp_vw_core_donor(
    p_uri text DEFAULT '', -- /vw_core/jurisdiction/{param}
    p_args text DEFAULT NULL
    -- e.g. http://api-test.addressforall.org/v1/vw_core/donor/3
) RETURNS TABLE (LIKE api.ttpl_core02_donor) AS $f$
        SELECT t2.id, scope, shortname, vat_id, legalName, wikidata_id, url, info,
             CASE
               WHEN j1.n_packs IS NULL THEN NULL::jsonb
               ELSE jsonb_build_object(
                 'n_packs',j1.n_packs,
                 'n_files',j1.n_files,
                 'tot_bytes',j1.tot_bytes
               )
             END as kx
        FROM API.uri_dispatch_parser(p_uri) t1(p) -- rev ,'{eclusa,checkuserfiles_step2}'
        INNER JOIN optim.donor t2 ON true
        LEFT JOIN (
          SELECT donor_id,
                 count(distinct pack_id) AS n_packs,
                 count(*) AS n_files,
                 sum((fmeta->'size')::int) as tot_bytes
          FROM optim.vw01_origin
          GROUP BY donor_id
        ) j1 ON j1.donor_id = t2.id
        WHERE CASE
          WHEN t1.p[1] IS NULL OR  t1.p[1]='' THEN true
          WHEN t1.p[1]~'^\d+$'  THEN t2.id=(t1.p[1])::int
          WHEN t1.p[1]~'^q\d+$' THEN t2.wikidata_id=(substr(t1.p[1],2)::bigint)
          WHEN t1.p[1]~'^scope\.lk\..+$'     THEN t2.scope LIKE (upper(substr(t1.p[1],10))||'%')
          WHEN t1.p[1]~'^legalname\.lk\..+$' THEN upper(t2.legalName) LIKE ('%'||upper(substr(t1.p[1],14))||'%')
          WHEN t1.p[1]~'^url\.lk\..+$'       THEN t2.url LIKE ('%'||lower(substr(t1.p[1],8))||'%')
          WHEN t1.p[1]~'^shortname\.lk\..+$' THEN t2.shortname LIKE (upper(substr(t1.p[1],14))||'%')
          WHEN t1.p[1]~'^[a-z]+:.+$'    THEN t2.kx_vat_id=optim.vat_id_normalize(t1.p[1])
          ELSE t2.shortname=upper(t1.p[1])
          END
$f$ language SQL immutable;
COMMENT ON FUNCTION API.uridisp_vw_core_donor
  IS 'Donor basic properties, from many alternatives to express its identification or lists.'
;

-- CREATE or replace FUNCTION API.uridisp_vw_core_pack(

CREATE or replace FUNCTION API.uridisp_vw_core_origin(
    p_uri text DEFAULT '', -- /vw_core/origin/{id|hashFile|hash|partialHash} ou pack_id/partialHash
    p_args text DEFAULT NULL
) RETURNS TABLE (LIKE api.ttpl_core03_origin) AS $f$
        SELECT t2.id, jurisd_osm_id, ctype, pack_id, fhash,
               fname, fversion, kx_cmds, is_valid, is_open,
               fmeta, config, ingest_instant, jsonb_build_object(
                 'donor',jsonb_build_object('id',donor_id, 'vat_id',donor_vat_id, 'shortname',donor_shortname, 'legalname',donor_legalname, 'url',donor_url),
                 'jurisd',jsonb_build_object('name',jurisd_name, 'state',jurisd_state, 'abbrev3',jurisd_abbrev3, 'isolabel_ext',jurisd_isolabel_ext),
                 'pack',jsonb_build_object('user_resp',user_resp, 'accepted_date',accepted_date, 'config_commom',config_commom, 'ctype_id',ctype_id, 'ctype_model_geo',ctype_model_geo)
               ) as kx
        FROM API.uri_dispatch_parser(p_uri) t1(p) -- rev ,'{eclusa,checkuserfiles_step2}'
        INNER JOIN optim.vw01_origin t2 ON t1.p[1] IS NOT NULL
        WHERE CASE
          -- LIST:
          WHEN t1.p[1] LIKE 'jurisd_osm_id.eq._%'       THEN t2.jurisd_osm_id=substr(t1.p[1],18)::bigint
          WHEN t1.p[1] LIKE 'jurisd_isolabel_ext.eq._%' THEN upper(t2.jurisd_isolabel_ext)=upper(substr(t1.p[1],24))
          WHEN t1.p[1] LIKE 'donor_id.eq._%'            THEN t2.donor_id=substr(t1.p[1],13)::int
          WHEN t1.p[1] LIKE 'donor_shortname.eq._%'     THEN t2.donor_shortname=upper(substr(t1.p[1],20))
          WHEN t1.p[1] LIKE 'jurisd_state.eq._%' THEN
            -- AND admin_level=8?
            t2.jurisd_isolabel_ext LIKE ('__-'||upper(substr(t1.p[1],17))||'%') and t2.jurisd_state=upper(substr(t1.p[1],17))
          -- one ITEM:
          WHEN t1.p[1]~'^\d+$'  THEN t2.id=(t1.p[1])::int
          WHEN t1.p[1]~'^sha256:[0-9a-fA-F]{4}' THEN t2.fhash ~ ('^'||lower(substr(t1.p[1],8)))
          END
$f$ language SQL immutable;
COMMENT ON FUNCTION API.uridisp_vw_core_origin
  IS 'Origin properties, from ID or hash as identificators.'
;

-- REVISAR views pendentes!
--Atributos: Há no antigo banco old_dl03t_main a view: api.origin que retorna uma série de atributos ao juntar: origin, city, donatedpack e donor, do schema ingest e precisa ser replicado para manter a visualização. Provavelmente será usada então dl03t_main.ingest.vw01_origin.
--Filtros: Adicionado api.vw_states_origin ao bd dl03t_main que será utilizado para filtrar origens por estado.


-- CREATE or replace FUNCTION API.uridisp_vw_core_origins
-- by ctype, pack or jurisd

---------------------------------

CREATE schema crm; -- Customer Relationship Management
-- gerenciar newsletter e contato/followup com funcionarios, fornecedores e associados do instituto.

CREATE TABLE crm.newsletter_cust (
  cust_id serial NOT NULL, -- future REFERENCES crm.customer(id)
  email  text NOT NULL PRIMARY KEY  CHECK(email=trim(lower(email)) AND length(email)>3 AND position('@' in email)>1),
  signature_date timestamp not NULL DEFAULT now(),
  is_valid boolean default false, -- valid string email and domain exists
  confirmed boolean default false -- acceptd by email-response of email-owner
);

CREATE or replace FUNCTION API.newsletter_email_ins(p_email text) RETURNS int AS $f$
  INSERT INTO crm.newsletter_cust(email) VALUES(trim(lower(p_email)))
  ON CONFLICT DO NOTHING
  RETURNING cust_id
$f$ language SQL;
COMMENT ON FUNCTION API.apiroot
 IS 'Insere email na tabela crm.newsletter_cust.'
;
