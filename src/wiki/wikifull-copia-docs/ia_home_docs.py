# -*- coding: utf-8 -*-
import os
import requests
import urllib3
import time
from google import genai
from datetime import datetime

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# ==============================================================================
# CONFIGURAÇÕES ANONIMIZADAS
# ==============================================================================
GEMINI_API_KEY = "AIzaSy_SUA_CHAVE_AQUI_PLACEHOLDER"
client = genai.Client(api_key=GEMINI_API_KEY)

# Modelo selecionado para o ambiente
MODELO = 'gemini-1.5-flash' 

TARGETS = {
    'DOCS': {
        'url': 'https://wiki-public.example.org/w/api.php', 
        'user': 'Bot_Curator', 
        'pass': 'BOT_PASSWORD_PLACEHOLDER',
        'perfil': 'Documentação Técnica e Governança.'
    },
    'USR':  {
        'url': 'https://wiki-user.example.org/w/api.php', 
        'user': 'Bot_Curator', 
        'pass': 'BOT_PASSWORD_PLACEHOLDER',
        'perfil': 'Manuais para Usuários e Gestores.'
    },
    'DEV':  {
        'url': 'https://wiki-dev.example.org/w/api.php', 
        'user': 'Bot_Curator', 
        'pass': 'BOT_PASSWORD_PLACEHOLDER',
        'perfil': 'Documentação para Desenvolvedores e APIs.'
    }
}

OUTPUT_DIR = "generated_homes"
if not os.path.exists(OUTPUT_DIR): os.makedirs(OUTPUT_DIR)

# ==============================================================================
# COLETA DE PÁGINAS (NAMESPACES 0 E 3014)
# ==============================================================================

def get_wiki_pages(config):
    """Recupera lista de títulos de páginas para alimentar o contexto da IA."""
    session = requests.Session()
    url = config['url']
    found = []
    try:
        # Obter Login Token
        r_tok = session.get(url, params={"action": "query", "meta": "tokens", "type": "login", "format": "json"}, verify=False)
        token = r_tok.json()['query']['tokens']['logintoken']
        
        # Login
        session.post(url, data={"action": "login", "lgname": config['user'], "lgpassword": config['pass'], "lgtoken": token, "format": "json"}, verify=False)

        # Busca em Namespaces específicos (Ex: 0=Principal, 3014=Custom)
        for ns in ["0", "3014"]:
            r = session.get(url, params={
                "action": "query", "list": "allpages", "apnamespace": ns, "aplimit": "500", "format": "json"
            }, verify=False).json()
            pages = r.get('query', {}).get('allpages', [])
            found.extend([p['title'] for p in pages])
        
        return list(set(found))
    except Exception as e:
        print(f"    [!] Erro ao listar páginas: {e}")
        return []

# ==============================================================================
# GERAÇÃO DE CONTEÚDO COM IA
# ==============================================================================



print(f">>> Wiki Curator - Modelo: {MODELO} <<<")

for name, config in TARGETS.items():
    print(f"[*] Processando Wiki: {name}")
    paginas = get_wiki_pages(config)
    
    if not paginas:
        print(f"    [!] Nenhuma página detectada ou erro de autenticação.")
        continue

    print(f"    {len(paginas)} páginas encontradas. Gerando Home Page...")
    
    # Prompt estruturado para garantir que a IA gere Wikitext válido
    prompt = f"""
    CONTEXTO: Organização de Tecnologia Geográfica.
    FOCO: Geocodificação e sistemas de grade.
    REGRAS: Use estritamente Wikitext, links internos no formato [[Pagina]]. 
    PERFIL DO PÚBLICO: {config['perfil']}
    LISTA DE PÁGINAS DISPONÍVEIS: {', '.join(paginas)}
    TAREFA: Crie uma Home Page organizada. NÃO use blocos de código Markdown (```).
    """

    try:
        response = client.models.generate_content(model=MODELO, contents=prompt)
        text = response.text.strip()
        
        # Limpeza de possíveis artefatos de Markdown da resposta
        clean_text = text.replace('```mediawiki', '').replace('```', '').strip()

        filepath = os.path.join(OUTPUT_DIR, f"home_{name.lower()}.txt")
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(clean_text)
        print(f"    [OK] Home salva em {filepath}")
        
        # Delay para respeitar limites de taxa da API (Rate Limiting)
        time.sleep(1)
    except Exception as e:
        print(f"    [!] Erro na chamada da API Gemini: {e}")

print("\n>>> Processo concluído.")
