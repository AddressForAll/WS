
-- -- -- -- -- -- -- --
-- API TABLE TEMPLATEs. Definições globais, com origem em diversos projetos.

CREATE TABLE api.ttpl_general01_namecheck(
  is_valid boolean,     name text,      invalid_explain text
  ,UNIQUE(name)
); COMMENT ON TABLE api.ttpl_general01_namecheck
  IS 'Standard check-names structure. Ref. eclusa.cityfolder_validUsers().'
;

CREATE TABLE api.ttpl_eclusa01_cityfile1 (
  cityname text,      ctype text,          fid int,
  fname text,         is_valid boolean,    fmeta JSONb
  ,UNIQUE(fid)
  ,UNIQUE(cityname,ctype,fname)
); COMMENT ON TABLE api.ttpl_eclusa01_cityfile1
  IS 'List filenames. Ref. eclusa.cityfolder_input_files_user().'
;
INSERT INTO  api.ttpl_eclusa01_cityfile1 VALUES
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
CREATE TABLE api.ttpl_eclusa02_cityfile2 (LIKE api.ttpl_eclusa01_cityfile1 INCLUDING ALL);
ALTER TABLE api.ttpl_eclusa02_cityfile2 ADD  hash text, ADD err_msg text;
COMMENT ON TABLE api.ttpl_eclusa02_cityfile2
  IS 'List filenames and its hashes. Ref. eclusa.??().'
;

CREATE TABLE api.ttpl_eclusa03_hash ( -- IN USE??
  hash text, hashtype text, fname text, refpath text
);

-- -- -- -- -- -- -- --
-- API.uri_dispatchers:
-- note: after changes, $make dkr_refresh

CREATE or replace FUNCTION API.uri_dispatch_parser(
    uri text,        -- e.g. /eclusa/checkUserFiles-step1/igor/0
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
COMMENT ON FUNCTION API.uri_dispatch_tab_eclusa1
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


-- -- -- -- -- -- -- --
-- API etc dispatchers:


/* OLD, lixo.
CREATE or replace FUNCTION API.uri_dispatch_tab_eclusa1(
    uri text DEFAULT '', -- /eclusa/checkUserFiles-step1/{user}/{is_valid}?
    args text DEFAULT NULL
) RETURNS TABLE (LIKE api.ttpl_eclusa01_cityfile1) AS $f$
  WITH topt AS (
    SELECT CASE
      WHEN p_len=1 AND p[1]='eclusa' THEN -2 -- incomplete
      WHEN p_len<=1 THEN -1 -- empty
      WHEN p[2]='checkuserfiles-step1' THEN 1
      WHEN p[2]='checkuserfiles-step2' THEN 2
      ELSE -3  -- not found
      END opt,
      CASE WHEN p_len<3 THEN NULL ELSE p[3] END AS p_user,
      CASE WHEN p_len<4 THEN NULL ELSE text_to_boolean(p[4]) END AS p_is_valid
    FROM (SELECT regexp_split_to_array(trim(lower(uri),'/'), '/')) t1(p),
         LATERAL (select array_upper(p,1) as p_len) t2
  )
      ( -- OPT1:
        SELECT cityname, ctype, fid, fname, is_valid, fmeta
             -- err_msg=fmeta->>'is_valid_err'
        FROM topt, eclusa.cityfolder_input_files('/home/'||p_user)
        WHERE topt.opt = 1
             AND COALESCE( is_valid=p_is_valid, true)
        ORDER BY 1,2
      ) UNION ALL
      ( -- OPT2:
        SELECT cityname, ctype, fid, fname, is_valid, fmeta
               -- see fmeta->>'hash' and  fmeta->>'is_valid_err'
        FROM topt, eclusa.cityfolder_input('/home/'||p_user)
        WHERE topt.opt = 2
              AND COALESCE( is_valid=p_is_valid, true)
        ORDER BY 1,2
      ) UNION ALL -- OPT<0, error message:
        SELECT a.* from topt, api.ttpl_eclusa01_cityfile1 a
        WHERE topt.opt < 0 AND fmeta->'dispatching_errcod' = to_jsonb(topt.opt)
$f$ language SQL immutable;
COMMENT ON FUNCTION API.uri_dispatch_tab_eclusa1
  IS 'A uri_dispatcher() returning a table, for Eclusa-step1 datatype.'
;

---  mais lixo ainda:
CREATE or replace FUNCTION API.uri_dispatch_tab_eclusa2(
    uri text DEFAULT '',
    args text DEFAULT NULL
) RETURNS api.ttpl_eclusa02_cityfile2 AS $f$
  -- etc
$f$ language SQL immutable;
COMMENT ON FUNCTION API.uri_dispatch_tab_eclusa2
  IS 'A uri_dispatcher() returning a table, for Eclusa-step2 datatype.'
;
*/
