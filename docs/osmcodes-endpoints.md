## OSMcodes endpoints

Below, the [*endpoints*](https://en.wikipedia.org/wiki/Endpoint_interface) expressed as [URI Templates](https://en.wikipedia.org/wiki/URI_Template).

_endpoint_ (URI template) |  Descrição
------------------------|-----------------
`api.osm.codes/{geocode}` | returns JSON of jurisdictional geocodes, such as countries, states, and country-state-municipality hierarchy (when exists). In case of official resolution, redirects to it (see cases of Cape Verde and Ireland).
`olc.osm.codes/{olc_complete}` |  resolves OLC code and resends it to `OSM.org` with a point, or to `map.osm.codes` with a polygon.
`ghs.osm.codes/{geohash_complete}`  | resolves Geohash code and resends it to `OSM.org` with the point, or to `map.osm.codes` with the polygon
`postal.osm.codes/{country_postal_code}`  | resolves the jurisdiction's ISO code (country code) and resends it to the country's official postal code resolver.
`postal.osm.codes/{country}/{postal_code}`  | resolve código ISO da jurisdição (country code) e resolve localmente o postalcode (por exemplo no Brasil com a base do CEP). Alternativamente `country~x`  resolve código publico alternativo, tal como [CRP](https://github.com/AddressForAll/CRP).

<!--
resolves the jurisdiction's ISO code (country code) and resolves the postalcode locally (for example in Brazil with the CEP base). Alternatively country ~ x resolves alternative public code, such as CRP.
-->
