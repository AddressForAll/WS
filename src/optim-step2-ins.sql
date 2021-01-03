-- OPTIM INSERTS
--
INSERT INTO optim.auth_user(username) VALUES ('enio'),('igor'),('peter'); -- minimal one Linux's /home/username

SELECT optim.fdw_wgets_refresh();


--- POSTGIS: SRID on demand, see Eclusa and Digital Preservation project demands.
-- ver https://wiki.openstreetmap.org/wiki/Brazil/Oficial/Carga#Adaptando_SRID
-- after max(srid)=900913
INSERT into spatial_ref_sys (srid, auth_name, auth_srid, proj4text, srtext)
values ( 952013, 'BR-RS-POA', null,
 '+proj=tmerc +lat_0=0 +lon_0=-51 +k=0.999995 +x_0=300000 +y_0=5000000 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs',
 null
); -- on conflick check and update.

INSERT into spatial_ref_sys (srid, auth_name, auth_srid, proj4text, srtext)
values ( 952019, 'BR:IBGE', 52019,
 '+proj=aea +lat_0=-12 +lon_0=-54 +lat_1=-2 +lat_2=-22 +x_0=5000000 +y_0=10000000 +ellps=WGS84 +units=m +no_defs',
 'PROJCS["Conica_Equivalente_de_Albers_Brasil",      GEOGCS["GCS_SIRGAS2000",          DATUM["D_SIRGAS2000",              SPHEROID["Geodetic_Reference_System_of_1980",6378137,298.2572221009113]],          PRIMEM["Greenwich",0],          UNIT["Degree",0.017453292519943295]],      PROJECTION["Albers"],      PARAMETER["standard_parallel_1",-2],      PARAMETER["standard_parallel_2",-22],      PARAMETER["latitude_of_origin",-12],      PARAMETER["central_meridian",-54],      PARAMETER["false_easting",5000000],      PARAMETER["false_northing",10000000],      UNIT["Meter",1]]'
); -- on conflick check and update.

--------------

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
