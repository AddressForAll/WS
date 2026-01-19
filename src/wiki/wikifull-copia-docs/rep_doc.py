import mysql.connector
import requests
import json
import sys
import zlib
import re
import hashlib
import os
import urllib3

# ==============================================================================
# CONFIGURAÇÕES TÉCNICAS ANONIMIZADAS
# ==============================================================================

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# Caminho genérico para o diretório de imagens do MediaWiki
LOCAL_IMG_PATH = "/var/www/html/w/images"

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
        'user': 'Bot_User', 
        'pass': 'BOT_PASSWORD_PLACEHOLDER'
    },
    'USR':  {
        'url': 'https://wiki-user.example.org/w/api.php', 
        'user': 'Bot_User', 
        'pass': 'BOT_PASSWORD_PLACEHOLDER'
    },
    'DEV':  {
        'url': 'https://wiki-dev.example.org/w/api.php', 
        'user': 'Bot_User', 
        'pass': 'BOT_PASSWORD_PLACEHOLDER'
    }
}

NS_CUSTOM = 3014

# ==============================================================================
# 1. TRATAMENTO DE IMAGENS
# ==============================================================================

def get_local_file_info(filename_raw):
    """Calcula o caminho MD5 padrão do MediaWiki para arquivos locais."""
    name_only = re.sub(r'^(File|Arquivo|Image|Imagem):', '', filename_raw, flags=re.IGNORECASE).strip()
    clean_name = name_only.replace(' ', '_')
    m = hashlib.md5()
    m.update(clean_name.encode('utf-8'))
    md5 = m.hexdigest()
    # Estrutura /a/ab/arquivo.png
    full_path = os.path.join(LOCAL_IMG_PATH, md5[:1], md5[:2], clean_name)
    return full_path, clean_name

def upload_image_checked(site_name, config, filename_raw):
    path_disco, clean_name_dest = get_local_file_info(filename_raw)
    if not os.path.exists(path_disco): return

    try:
        session = requests.Session()
        session.verify = False
        
        # Obter Login Token
        r = session.get(config['url'], params={'action': 'query', 'meta': 'tokens', 'type': 'login', 'format': 'json'})
        lt = r.json()['query']['tokens']['logintoken']
        
        # Login
        session.post(config['url'], data={'action': 'login', 'lgname': config['user'], 'lgpassword': config['pass'], 'lgtoken': lt, 'format': 'json'})
        
        # Obter CSRF Token
        r = session.get(config['url'], params={'action': 'query', 'meta': 'tokens', 'format': 'json'})
        ct = r.json()['query']['tokens']['csrftoken']

        with open(path_disco, 'rb') as f:
            files = {'file': (clean_name_dest, f)}
            data = {'action': 'upload', 'filename': clean_name_dest, 'token': ct, 'ignorewarnings': 1, 'format': 'json'}
            res = session.post(config['url'], data=data, files=files).json()

            if 'upload' in res and res['upload']['result'] == 'Success':
                print(f"      [IMG UP] {clean_name_dest} ({site_name} OK)")
    except Exception as e: pass

# ==============================================================================
# 2. PROCESSAMENTO E NORMALIZAÇÃO
# ==============================================================================

def traduzir_e_corrigir_texto(text):
    if not text: return "", []
    unique_imgs = set()
    
    # Coleta de imagens originais para upload posterior
    pattern_std = r'\[\[(?:Arquivo|File|Image|Imagem):\s*([^|\]\n]+?)\s*(?:\||\]\])'
    for m in re.findall(pattern_std, text, re.IGNORECASE): 
        unique_imgs.add(m.strip())

    # Normalização de sintaxe para compatibilidade entre instâncias
    text = re.sub(r'(?i)\[\[Predefinição:', '[[Template:', text)
    text = re.sub(r'(?i)\{\{\s*Predefinição:', '{{Template:', text)
    text = re.sub(r'(?i)\[\[Categoria:', '[[Category:', text)
    text = re.sub(r'(?i)\[\[(Arquivo|Imagem):', '[[File:', text)

    # Correção em blocos de galeria
    def fix_gallery_content(match):
        return re.sub(r'(?i)(Arquivo|Imagem|Image):', 'File:', match.group(0))
    
    text = re.sub(r'(<gallery[^>]*>)(.*?)(</gallery>)', fix_gallery_content, text, flags=re.DOTALL | re.IGNORECASE)

    return text, list(unique_imgs)

# ==============================================================================
# 3. EXECUÇÃO DO SYNC
# ==============================================================================

def main():
    print(">>> INICIANDO SINCRONIZAÇÃO ENTRE AMBIENTES <<<")
    conn = mysql.connector.connect(**DB_
