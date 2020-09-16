
## Subindo serviços
Os códigos-fonte desta pasta são relativos ao  `makefile` de gestão dos "serviços gerais" da Plataforma de Projetos AddressForAll.
Para a gestão de módulos específicos, por exemplo Projeto de Preservação Digital, rodar o respectivo `makefile`.

Alguns serviços, como o Docker, requerem sudor (ex. `sudo make` ou `sudo docker-compose up dkname`).

## Make geral
O comando `make all` vai iniciarlizar todas as basees de dados e todos os Dockers. 
**CUIDADO**, apesar de desenvolvido para não destruir bases e serviços, não realizar esse comando sem garantia prévia de backup.


## Makes específicos
Alguns exemplos:
* `make fulano` descrição ....
* `make status | more` lista status das bases de dados, todas elas.
* ...

## Dockers

Apesar de definidos no `makefile`, pode-se realizar o "make" do docker diretamente. Por exemplo `sudo docker-compose start db`.
Ideal, antes de rodar, é conferir se a imagem PostgREST foi instalada...  

O comando mais simples para inicializar tudo é `sudo docker-compose up --detach`.

Para editar docker-compose.yml confira https://docs.docker.com/compose/compose-file/

Para gerenciar, comandos mais frequentes neste projeto:
* `sudo docker ps` lista todos os processos de docker rodando.
* `sudo image ls` lista todas as imagens disponíveis para se instanciar (conferir versão e manter atualizado com ??).
* `sudo docker-compose down` ["mata"](https://stackoverflow.com/a/51517764/287948) todos os dockers.
* `sudo docker-compose down` "mata" só o 
* `docker-compose pull` ..
* `docker-compose create` ...
* `docker-compose start` ...

Para debug do que está rodando:
* `sudo docker ps` (localize o ID por ex. "9bb").
* `sudo docker inspect 9bb`
