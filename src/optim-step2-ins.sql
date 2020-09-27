-- OPTIM INSERTS
--
INSERT INTO optim.auth_user(username) VALUES ('enio'),('igor'),('peter'); -- minimal one Linux's /home/username

INSERT INTO optim.jurisdiction
  SELECT * FROM tmp_orig.fdw_jurisdiction_br
  ON CONFLICT DO NOTHING
; -- ok
INSERT INTO optim.donor
  SELECT * FROM tmp_orig.fdw_donor_br
  ON CONFLICT DO NOTHING
; -- ok
INSERT INTO optim.donatedPack
  SELECT pack_id,donor_id,user_resp,accepted_date,escopo,about, null,
         jsonb_build_object(
           'author',author,      'contentReferenceTime',contentReferenceTime,
           'license_is_explicit',text_to_boolean(license_is_explicit),
           'license',license,   'uri_objType',uri_objType,
           'uri',uri,           'isAt_UrbiGIS',text_to_boolean(isAt_UrbiGIS)
         )
  FROM tmp_orig.fdw_donatedPack_br
  ON CONFLICT DO NOTHING
;-- ok



/*
INSERT INTO optim.donor (scope,vat_ID,shortName,legalName,wikidata_ID,url)
  SELECT scope, "vatID", "shortName", "legalName",
         substr("wikidataQID",2)::bigint,
         url
  FROM tmp_orig.fdw_br_donor
  ON CONFLICT DO NOTHING
;
INSERT INTO optim.jurisdiction(local_jurisd_id,name,state,abbrev3,wikidata_id,lexlabel,isolabel_ext,ddd,info)
  -- osm_id,jurisd_base_id,jurisd_local_id,name,parent_abbrev,abbrev,wikidata_id,lexlabel,isolabel_ext,ddd,info

  SELECT   "idIBGE"::int, name,
            state, abbrev3, -- upper
            substr("wdId",2)::bigint,
            "lexLabel",
            'BR-'||state||'-'||lexname_to_unix("lexLabel"),
            ddd,
            jsonb_build_object(
              'postalCode_ranges',"postalCode_ranges",
              'notes',notes,
              'creation',creation,
              'extinction',extinction
            ) AS  info
  FROM tmp_orig.fdw_br_city_codes
ON CONFLICT DO NOTHING
; --
CREATE FOREIGN TABLE tmp_orig.fdw_br_donatedPack (
  donor_id int,
  pack_id int,
  accepted_date text,
  label_ref text,
  about text,
  contentReferenceTime text,
  creator text,
  licensedExp text,
  license_main text,
  url_objType text,
  uri text
) SERVER files OPTIONS (
   filename '/tmp/pg_io/donatedPack.csv'
   ,format 'csv'
   ,delimiter ','
   ,header 'true'
);
INSERT INTO optim.donatedPack (pack_id,donor_id,accepted_date,about,info)
  SELECT pack_id,donor_id,accepted_date::date,about,
         jsonb_build_object(
             'label_ref',label_ref,'creator',creator,
             'licensedExp',licensedExp,'license_main',license_main,
             'url_objType',url_objType, 'uri',uri
         )
  FROM tmp_orig.fdw_br_donatedPack
  WHERE length(accepted_date)>=4 AND donor_id IN (select id from optim.donor)
ON CONFLICT DO NOTHING
;

*/

-- verifica por hora com: select scope,vat_ID,shortName,legalName, p.pack_id, p.donor_id from optim.donor d inner join (select pack_id, donor_id, info->>'label_ref' labref from optim.donatedPack) p ON p.labref=d.shortname;
-- assim podemos trocaar o antigo
