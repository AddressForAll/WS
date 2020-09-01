# WS
Core infrastructure for AdressForAll Web Services

## ADDRESSFORALL.ORG and subdomains

Today hosted at IP `165.227.5.135`.

Subdomain | mode |  Description
---------|---------|--------
addressforall.org | (root)| portal do Instituto AddressForAll.
WWW.addressforall.org |A| sinônimo de `addressforall.org`.
API.addressforall.org |A| Todas as APIs oficiais, incluindo a padronizada de `/_sql`. Retorno JSON.
api-CSV.addressforall.org|A| (? talvez descartada) Mesmo que API porém retornando CSV
api-HTM.addressforall.org|A| (? talvez descaratada) Mesmo que API porém retornando HTML com Javascript. Os elementos da solicitação (URL) podem ser interpretados direto da URL ou registrados como variável global na página.
DOCS.addressforall.org|A| API de busca e catalogação de documentos oficiais.
GIT.addressforall.org|A| redirecionador dos nossos gits (para não ficar refém do fornecedor, sempre citar endereço pelo nosso domínio).
OSMS.addressforall.org|A| documentação mkdocs de https://github.com/OSMBrasil/stable
PRESERV.addressforall.org|A| Projeto Preservação digital, incluindo retorno `/download/` com downloads.

A seguir os [*endpoints*](https://en.wikipedia.org/wiki/Endpoint_interface) implementados, expressos como [URI Templates](https://en.wikipedia.org/wiki/URI_Template).

_endpoint_ (URI template) |  Descrição
------------------------|-----------------
`api.addressforall.org/_sql` | API do [PostgREST](http://postgrest.org/).
`api.addressforall.org/v1` | sinônimo de `api.addressforall.org/v1.json`.
`api.addressforall.org/v1.json` | API **versão 1**. Listagem dos _endpoints _válidos desta API.
`api.addressforall.org/v1.csv` | idem  `api.addressforall.org/v1.json` mas retornando em CSV.
`api.addressforall.org/v1.htm` | (? em dúvida se melhor `api-HTM.addressforall.org/v1`) idem  `api.addressforall.org/v1.json` mas retornando em página interativa HTML.
`api.addressforall.org/v1.json/donor` | sinônimo de `api.addressforall.org/_sql/donor`, lista doadores de datasets.
`api.addressforall.org/v1.json/donor/{vatID_type}:{vatID_val}` | retorna apenas  doador determinado pelo VatID.
`api.addressforall.org/v1.json/donor/{id}` | retorna apenas  doador determinado pelo ID interno solicitado.
`api.addressforall.org/v1.json/origin` | sinônimo de `api.addressforall.org/_sql/origin`, lista "origem dos *dataset*", no sentido de [proveniência dos dados](https://en.wikipedia.org/wiki/Provenance#Data_provenance). 
`api.addressforall.org/v1.json/origin/{hash}` | sinônimo de `api.addressforall.org/_sql/origin?fhash={hash}`
`api.addressforall.org/v1.json/origin/{hash}` | sinônimo de `api.addressforall.org/_sql/origin?fhash={hash}`


`api.addressforall.org/v1/*` | (qualquer endpoint) sinônimo de `api.addressforall.org/v1.json/*`.
`api.addressforall.org/v1.csv/*` | (qualquer endpoint) sinônimo de `api.addressforall.org/v1.json/*` porém retornando CSV.
`api.addressforall.org/v1.htm/*` | (qualquer endpoint) sinônimo de `api.addressforall.org/v1.json/*` porém retornando HTML com Javascript.


## OSM.CODES and subdomains

Atualmente hospedado no IP `165.227.5.135`, ou seja, separado do AddressForAll. 

Subdominio | modo |  Descrição
---------|---------|--------
osm.codes | (root)| portal do Projeto OSM CODES.
WWW.osm.codes |CNAME| idem `osm.codes`.
MAP.osm.codes | CNAME| mostra map OSM com geometrias ou pontos solicitados por `?geo:latitudo,longitude;u=incerteza` ou por BBOX a ser apresentada, enviando por POST ou GET.
API.osm.codes | CNAME| todas as APIs JSON e/ou retorno CSV
OLC.osm.codes |  CNAME| opção ao PlusCodes para redirecionar "OLC completo" para o OSM
GHS.osm.codes  | CNAME | opção ao PlusCodes  para demonstrar o uso do "Geohash completo"

A seguir os [*endpoints*](https://en.wikipedia.org/wiki/Endpoint_interface) implementados, expressos como [URI Templates](https://en.wikipedia.org/wiki/URI_Template)


_endpoint_ (URI template) |  Descrição
------------------------|-----------------
`api.osm.codes/{geocode}` | devolve JSON de geocódigos de jurisdição, tais como países, estados, e hierarquia pais-estado-municipio onde dispor. No caso particular de Cabo Verde e irlanda pode redirecionar para respectivo resolver.
`olc.osm.codes/{olc_complete}` |  resolve código OLC e reenvia para OSM.org com o ponto, ou para map.osm.codes com o polígono.
`ghs.osm.codes/{geohash_complete}`  | resolve código Geohash e reenvia para OSM.org com o ponto, ou para map.osm.codes com o polígono
`postal.osm.codes/{country_postal_code}`  | resolve código ISO da jurisdição (country code) e reenvia para resolvedor oficial de postal codes do país, quando existi serviço por GET, senão precisa usar endpoint complementar.
`postal.osm.codes/{country}/{postal_code}`  | resolve código ISO da jurisdição (country code) e resolve localmente o postalcode (por exemplo no Brasil com a base do CEP). Alternativamente `country~x`  resolve código publico alternativo, tal como [CRP](https://github.com/AddressForAll/CRP).
