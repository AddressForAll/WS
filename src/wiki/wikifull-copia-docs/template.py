import mysql.connector
import requests
import zlib
import re
import urllib3
import sys

# ==============================================================================
# CONFIGURAÇÕES ANONIMIZADAS
# ==============================================================================
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

DB_CONFIG = {
    'user': 'db_user',
    'password': 'DB_PASSWORD_PLACEHOLDER',
    'host': 'database_host',
    'database': 'database_name',
    'raise_on_warnings': True
}

TARGETS = {
    'DOCS': {
        'url': 'https://wiki-public.example.org/w/api.php', 
        'user': 'Bot_Sync', 
        'pass': 'BOT_PASSWORD_PLACEHOLDER'
    },
    'USR':  {
        'url': 'https://wiki-user.example.org/w/api.php', 
        'user': 'Bot_Sync', 
        'pass': 'BOT_PASSWORD_PLACEHOLDER'
    },
    'DEV':  {
        'url': 'https://wiki-dev.example.org/w/api.php', 
        'user': 'Bot_Sync', 
        'pass': 'BOT_PASSWORD_PLACEHOLDER'
    }
}

# Namespace 10 = Template (Predefinição)
NS_TEMPLATE = 10

# ==============================================================================
# TRADUTOR DE CONTEÚDO (PARA ÍCONES DENTRO DO TEMPLATE)
# ==============================================================================
def traduzir_tags(text):
    """
    Normaliza o Wikitext de Português para Inglês/Padrão 
    para garantir compatibilidade entre diferentes instâncias do MediaWiki.
    """
    if not text: return ""
    # Corrige referências a imagens dentro dos templates
    text = re.sub(r'(?i)\[\[(Arquivo|Imagem):', '[[File:', text)
    text = re.sub(r'(?i)\|\s*semmoldura', '|frameless', text)
    text = re.sub(r'(?i)\|\s*miniaturadaimagem', '|thumb', text)
    text = re.sub(r'(?i)\|\s*miniatura', '|thumb', text)
    return text

# ==============================================================================
# COMUNICAÇÃO COM A API DO MEDIAWIKI
# ==============================================================================


def enviar_template(site_name, conf, title, text):
    try:
        session = requests.Session()
        session.verify = False
        
        # 1. Obter Login Token
        r = session.get(conf['url'], params={'action': 'query', 'meta': 'tokens', 'type': 'login', 'format': 'json'})
        if 'error' in r.json(): return
        lt = r.json()['query']['tokens']['logintoken']
        
        # 2. Efetuar Login
        session.post(conf['url'], data={'action': 'login', 'lgname': conf['user'], 'lgpassword': conf['pass'], 'lgtoken': lt, 'format': 'json'})
        
        # 3. Obter Token CSRF para edição
        r = session.get(conf['url'], params={'action': 'query', 'meta': 'tokens', 'format': 'json'})
        ct = r.json()['query']['tokens']['csrftoken']
        
        # 4. Normalizar Título (Garante prefixo Template: e remove variações em PT)
        clean_title = title.replace('Predefinição:', '').replace('Template:', '').strip()
        final_title = f"Template:{clean_title}"
        
        # 5. Executar a Edição via API
        res = session.post(conf['url'], data={
            'action': 'edit', 
            'title': final_title, 
            'text': traduzir_tags(text), 
            'token': ct, 
            'bot': 'true', 
            'summary': 'Sync Templates V27 (Automatic)', 
            'format': 'json'
        }).json()
        
        if 'edit' in res and res['edit']['result'] == 'Success':
            print(f"   [OK] {site_name}: {final_title}")
        elif 'error' in res and 'nochange' in str(res['error']):
            pass # Ignora se não houve alteração no conteúdo
        else:
            print(f"   [ERRO] {site_name} -> {final_title}: {res}")

    except Exception as e:
        print(f"   [FALHA] {site_name}: {e}")

# ==============================================================================
# PROCESSO PRINCIPAL (EXTRAÇÃO DO BANCO DE DADOS LOCAL)
# ==============================================================================
def main():
    print(">>> SINCRONIZANDO TODOS OS TEMPLATES (NS 10) <<<")
    
    conn = mysql.connector.connect(**DB_CONFIG)
    cursor = conn.cursor(dictionary=True)

    # Query para extrair o texto bruto das páginas no Namespace de Templates
    query = """
        SELECT p.page_title, t.old_text, t.old_flags
        FROM page p
        JOIN revision r ON p.page_latest = r.rev_id
        JOIN slots s ON r.rev_id = s.slot_revision_id
        JOIN content c ON s.slot_content_id = c.content_id
        JOIN text t ON t.old_id = SUBSTRING_INDEX(c.content_address, ':', -1)
        WHERE p.page_namespace = 10
    """
    cursor.execute(query)
    
    count = 0
    for row in cursor:
        count += 1
        # Tratamento de codificação do título
        try: tit = row['page_title'].decode('utf-8').replace('_', ' ')
        except: tit = row['page_title'].decode('latin1').replace('_', ' ')
        
        # Tratamento de descompressão do texto (MediaWiki costuma usar gzip/zlib)
        raw = row['old_text']
        flags = row['old_flags'].decode('utf-8') if row['old_flags'] else ""
        
        if 'gzip' in flags:
            try: txt = zlib.decompress(raw, zlib.MAX_WBITS|16).decode('utf-8')
            except: 
                try: txt = zlib.decompress(raw).decode('
