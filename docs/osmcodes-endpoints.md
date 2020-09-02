## OSMcodes endpoints

Below, the [*endpoints*](https://en.wikipedia.org/wiki/Endpoint_interface) expressed as [URI Templates](https://en.wikipedia.org/wiki/URI_Template).

_endpoint_ (URI template) |  Descrição
------------------------|-----------------
`api.osm.codes/{geocode}` | devolve JSON de geocódigos de jurisdição, tais como países, estados, e hierarquia pais-estado-municipio onde dispor. No caso particular de Cabo Verde e irlanda pode redirecionar para respectivo resolver.
`olc.osm.codes/{olc_complete}` |  resolve código OLC e reenvia para OSM.org com o ponto, ou para map.osm.codes com o polígono.
`ghs.osm.codes/{geohash_complete}`  | resolve código Geohash e reenvia para OSM.org com o ponto, ou para map.osm.codes com o polígono
`postal.osm.codes/{country_postal_code}`  | resolve código ISO da jurisdição (country code) e reenvia para resolvedor oficial de postal codes do país, quando existi serviço por GET, senão precisa usar endpoint complementar.
`postal.osm.codes/{country}/{postal_code}`  | resolve código ISO da jurisdição (country code) e resolve localmente o postalcode (por exemplo no Brasil com a base do CEP). Alternativamente `country~x`  resolve código publico alternativo, tal como [CRP](https://github.com/AddressForAll/CRP).
