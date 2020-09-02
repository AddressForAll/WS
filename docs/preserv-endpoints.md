## Digital preservation endpoints

Official recording of [data provenance](https://en.wikipedia.org/wiki/Provenance#Data_provenance) and access to original donated files.

![](assets/umlClass-preserv1.png)

Below, the [*endpoints*](https://en.wikipedia.org/wiki/Endpoint_interface) expressed as [URI Templates](https://en.wikipedia.org/wiki/URI_Template).

_endpoint_ (URI template) |  Description
------------------------|-----------------
`api.addressforall.org/v1.json/donor` | synonymous with `api.addressforall.org/_sql/donor`, lists all dataset donors. Donors are [organizations](https://schema.org/Organization).
`api.addressforall.org/v1.json/donor/{vatID_type}:{vatID_val}` | returns only the donor determined by its [vatID](https://schema.org/vatID).
`api.addressforall.org/v1.json/donor/{id}` | retorna apenas  doador determinado pelo ID interno solicitado.
`api.addressforall.org/v1.json/origin` | synonymous with `api.addressforall.org/_sql/origin`, lista "origem dos *dataset*", no sentido de .
`api.addressforall.org/v1.json/origin/{hash}` | synonymous with `api.addressforall.org/_sql/origin?fhash={hash}`
`api.addressforall.org/v1.json/origin/{adminCode}` | filter Origin  by administrative hierarchy, for example `BR-SP`. Count origins.
`api.addressforall.org/v1.json/origin/{donorId}` |  filter Origin  by Donor. Count origins.
`api.addressforall.org/v1.json/origin/hashes/{hash_prefix}` |  filter Origin  by hash prefix.
`preserv.addressforall.org/download/{hash}` | downloads a original source file by it's hexadecinal SHA256 hash.
