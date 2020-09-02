# WS
Core infrastructure for AdressForAll Web Services

## ADDRESSFORALL.ORG and subdomains

Today hosted at IP `165.227.5.135`. Below, remember that domain and subdomain names are case-insensitive. The "type" column is about [type of resource record](https://en.wikipedia.org/wiki/Domain_Name_System#Resource_records).

Subdomain | type |  Description
---------|---------|--------
addressforall.org | (root)| the portal of Instituto AddressForAll.
W<span>WW.</span>addressforall.org |A| synonymous with  `addressforall.org`.
API.addressforall.org |A| All official APIs, including the standard `/_sql`. Retorns JSON.
DOCS.addressforall.org|A| API for information retrivieal of the  official (institute and donors) documents, like licenses, contracts, law, etc.
GIT.addressforall.org|A| redirects to [Institute's *gits*](https://github.com/addressforall), to to avoid being held hostage by the supplier.
OSMS.addressforall.org|A| hosting of documentation of [OSM-Stable](https://github.com/OSMBrasil/stable) "external project", by [mkdocs](https://www.mkdocs.org/).
PRESERV.addressforall.org|A| [Digital preservation project](https://github.com/AddressForAll/digital-preservartion-BR), including its `/download/` API and documentation (by [mkdocs](https://www.mkdocs.org/)).

Below, general [*endpoints*](https://en.wikipedia.org/wiki/Endpoint_interface), expressed by URL, with `x*` syntax indicating "any thing folowing `x`".

_endpoint_ (URI template) |  Description
------------------------|-----------------
`api.addressforall.org/_sql` | the [PostgREST](http://postgrest.org/)'s API. See also data model.
`api.addressforall.org/v1/*` | (any endpoint) synonymous with `api.addressforall.org/v1.json/*`.
`api.addressforall.org/v1/_man/*` | (any endpoint) mkdocs documentation of the API version 1
`api.addressforall.org/v1.csv/*` | (any endpoint) synonymous with `api.addressforall.org/v1.json/*` but returning CSV format.
`api.addressforall.org/v1.htm/*` | (any endpoint) synonymous with `api.addressforall.org/v1.json/*`, but  returning interactive HTML page.
`api.addressforall.org/v1.json` | API **version 1**. Lists all valid _endpoints_ of this API.

See also [Preserv endpoints](docs/preserv-endpoints.md), [Address endpoints](docs/address-endpoints.md), ...

## OSM.CODES and subdomains

Today hosted at IP `165.227.5.135`, so, separated from AddressForAll. Below, remember that domain and subdomain names are case-insensitive. The "type" column is about [type of resource record](https://en.wikipedia.org/wiki/Domain_Name_System#Resource_records).

Subdominio | type |  Descrição
---------|---------|--------
osm.codes | (root)| portal do Projeto OSM CODES.
W<span>WW.</span>osm.codes |CNAME| idem `osm.codes`.
MAP.osm.codes | CNAME| mostra map OSM com geometrias ou pontos solicitados por `?geo:latitudo,longitude;u=incerteza` ou por BBOX a ser apresentada, enviando por POST ou GET.
API.osm.codes | CNAME| todas as APIs JSON e/ou retorno CSV
OLC.osm.codes |  CNAME| opção ao PlusCodes para redirecionar "OLC completo" para o OSM
GHS.osm.codes  | CNAME | opção ao PlusCodes  para demonstrar o uso do "Geohash completo"

Below, general [*endpoints*](https://en.wikipedia.org/wiki/Endpoint_interface), expressed by URL, with `x*` syntax indicating "any thing folowing `x`".

_endpoint_ (URI template) |  Descrição
------------------------|-----------------
`api.osm.codes/{geocode}` | devolve JSON de geocódigos de jurisdição, tais como países, estados, e hierarquia pais-estado-municipio onde dispor. No caso particular de Cabo Verde e irlanda pode redirecionar para respectivo resolver.
`olc.osm.codes/{olc_complete}` |  resolve código OLC e reenvia para OSM.org com o ponto, ou para map.osm.codes com o polígono.
`ghs.osm.codes/{geohash_complete}`  | resolve código Geohash e reenvia para OSM.org com o ponto, ou para map.osm.codes com o polígono
`postal.osm.codes/{country_postal_code}`  | resolve código ISO da jurisdição (country code) e reenvia para resolvedor oficial de postal codes do país, quando existi serviço por GET, senão precisa usar endpoint complementar.
`postal.osm.codes/{country}/{postal_code}`  | resolve código ISO da jurisdição (country code) e resolve localmente o postalcode (por exemplo no Brasil com a base do CEP). Alternativamente `country~x`  resolve código publico alternativo, tal como [CRP](https://github.com/AddressForAll/CRP).

See also [OSMcodes endpoints](docs/osmcodes-endpoints.md).
