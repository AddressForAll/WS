# -*- coding: utf-8 -*-
import os
import requests
import urllib3
import time
from google import genai
from datetime import datetime

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# ==============================================================================
# CONFIGURACOES
# ==============================================================================
GEMINI_API_KEY = "AIzaSyDo7PJkbKBMWkFMRgDPZw0UDdR17jTKUv0"
client = genai.Client(api_key=GEMINI_API_KEY)

# MODELO QUE FUNCIONA NO SEU AMBIENTE:
MODELO = 'gemini-flash-latest' 

TARGETS = {
    'DOCS': {
        'url': 'https://docs.afa.codes/w/api.php', 
        'user': 'Admin', 'pass': 'rep@h9glrk5gf9fh0qgp78gmqkqabhpg5ldd',
        'perfil': 'Documentacao Tecnica e Governanca do ITGS/AddressForAll.'
    },
    'USR':  {
        'url': 'https://docs-usr.afa.codes/w/api.php', 
        'user': 'Admin', 'pass': 'rep@1k882n0s0hcgnkar31t78lsrls8726ve',
        'perfil': 'Manuais para Usuarios, Geografos e Gestores.'
    },
    'DEV':  {
        'url': 'https://docs-dev.afa.codes/w/api.php', 
        'user': 'Admin', 'pass': 'rep@ltderna54q1l5gj1tq7h2tcoqhdisdnu',
        'perfil': 'Documentacao para Desenvolvedores e Integracoes AFA Codes.'
    }
}

OUTPUT_DIR = "homes_geradas"
if not os.path.exists(OUTPUT_DIR): os.makedirs(OUTPUT_DIR)

# ==============================================================================
# COLETA DE PAGINAS (NAMESPACES 0 E 3014)
# ==============================================================================

def get_wiki_pages(config):
    session = requests.Session()
    url = config['url']
    found = []
    try:
        # Login
        r_tok = session.get(url, params={"action": "query", "meta": "tokens", "type": "login", "format": "json"}, verify=False)
        token = r_tok.json()['query']['tokens']['logintoken']
        session.post(url, data={"action": "login", "lgname": config['user'], "lgpassword": config['pass'], "lgtoken": token, "format": "json"}, verify=False)

        # Busca em Namespace 0 (Principal) e 3014 (Custom)
        for ns in ["0", "3014"]:
            r = session.get(url, params={
                "action": "query", "list": "allpages", "apnamespace": ns, "aplimit": "500", "format": "json"
            }, verify=False).json()
            pages = r.get('query', {}).get('allpages', [])
            found.extend([p['title'] for p in pages])
        
        return list(set(found))
    except:
        return []

# ==============================================================================
# GERACAO DE CONTEUDO
# ==============================================================================

print(f">>> Wiki Curator AddressForAll - Modelo: {MODELO} <<<")

for name, config in TARGETS.items():
    print(f"[*] Wiki: {name}")
    paginas = get_wiki_pages(config)
    
    if not paginas:
        print(f"    [!] Nenhuma pagina detectada.")
        continue

    print(f"    {len(paginas)} paginas encontradas. Gerando Home...")
    
    prompt = f"""
    CONTEXTO: Instituto AddressForAll / ITGS. Projeto AFA Codes (DNGS).
    FOCO: Geocodificacao amigavel e sistemas de grade.
    REGRAS: Use Wikitext, links [[Pagina]]. EVITE termos tecnicos de programacao.
    DESTAQUE: A Extension 'Novo CEP' deve ser a primeira secao e a mais importante.
    PERFIL: {config['perfil']}
    PAGINAS: {', '.join(paginas)}
    TAREFA: Crie a Home Page em Wikitext puro. NAO use blocos de codigo ```.
    """

    try:
        response = client.models.generate_content(model=MODELO, contents=prompt)
        text = response.text.strip()
        
        # Remove eventuais marcas de markdown que a IA possa incluir
        clean_text = text.replace('```mediawiki', '').replace('```', '').strip()

        filepath = os.path.join(OUTPUT_DIR, f"home_{name}.txt")
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(clean_text)
        print(f"    [OK] Home salva em {filepath}")
        time.sleep(1)
    except Exception as e:
        print(f"    [!] Erro na IA: {e}")

print("\n>>> Processo concluido com sucesso.")
