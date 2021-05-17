## Subindo serviços back-end do WS

Os códigos-fonte desta pasta são relativos ao `makefile` de gestão dos "serviços gerais" da **Plataforma de Projetos AddressForAll**.
Para a gestão de módulos específicos, por exemplo *Projeto de Preservação Digital*, rodar o respectivo `makefile`.

Alguns serviços, como o Docker, requerem usuário *root* (ex. `sudo make` ou `sudo docker-compose up dkname`).

## Make geral

Usar `cd src; make`. O comando apenas indicará no terminal como rodar os principais *targets*. No jardão *make* cada *target* (alvo) é um comando `make _target_`. Sugere-se primeiro rodar aqueles que demandam `sudo` depois os demais.

* `sudo make ini_basics`: cria pastas de trabalho e uniformiza permissões. Use antes apenas `make` para conferir incluir seu usuário nos grupos.
* `make ini_all`: inicializa de fato todas as bases de dados no PostreSQL, se estiver devidamente instalado.
* `sudo make ini_step6_pgrestUp`: inicialização dos Dockers.

Apesar de desenvolvido para não destruir bases e serviços, **CUIDADO**, não realizar *makes* sem garantia prévia de *backup*.

Outros *targets* úteis:
* `make status | more` lista status das bases de dados, todas elas.
* ...

## Dockers

Apesar de definidos no _makefile_, pode-se realizar o "make" do docker diretamente. Por exemplo `sudo docker-compose start db`.
Ideal, antes de rodar, é verificar se a imagem PostgREST foi instalada...

O comando mais simples para inicializar tudo é `sudo docker-compose up --detach`.
Seu equivalente no _makefile_ é `sudo make ini_step6_pgrestUp`, que resulta nas mensagens:
```
docker-compose  up -d  pgrestDL03
Creating src_pgrestDL03_1 ... done
docker-compose  up -d  pgrestDL04
Creating src_pgrestDL04_1 ... done
PostgREST Dockers up
```

Para editar `docker-compose.yml` confira https://docs.docker.com/compose/compose-file/

Para gerenciar, comandos mais frequentes neste projeto:

* `sudo docker ps` lista todos os processos de docker rodando.
* `sudo image ls` lista todas as imagens disponíveis para se instanciar (conferir versão e manter atualizado com ??).
* `sudo docker-compose down` ["mata"](https://stackoverflow.com/a/51517764/287948) todos os dockers.
* `sudo docker-compose down` "mata" só o
* `docker-compose pull` ...
* `docker-compose create` ...
* `docker-compose start` ...

Para debug do que está rodando:
* `sudo docker ps` (localize o ID por ex. "9bb").
* `sudo docker inspect 9bb`

Um comando de uso frequente para caso de reestruturacao de tabelas e funcoes, usar direto `make dkr_refresh` ou:
```sh
sudo make -C /opt/gits/WS/src dkr_refresh
```
## permissoes online no WS

Urgente: mudar permissao `PGRST_DB_ANON_ROLE` no docker-composer.

Ver como rodar com senhas e limitações em
http://postgrest.org/en/v7.0.0/tutorials/tut0.html#step-4-create-database-for-api
