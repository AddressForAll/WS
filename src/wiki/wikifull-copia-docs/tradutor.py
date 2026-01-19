import mwclient
import google.generativeai as genai
import time

# 1. Configuração do Gemini
genai.configure(api_key="SUA_CHAVE_AQUI")
model = genai.GenerativeModel('gemini-1.5-flash')

def translate_with_gemini(text, target_lang):
    prompt = f"Traduza o seguinte conteúdo de Wiki para {target_lang}, mantendo estritamente a formatação original (links, tabelas, negritos):\n\n{text}"
    response = model.generate_content(prompt)
    return response.text

# 2. Conexão com as Wikis
# Substitua pelos seus domínios e credenciais
site_full = mwclient.Site('wikifull.seudominio.com', path='/')
site_public = mwclient.Site('wiki.seudominio.com', path='/')

# Se precisar de login:
# site_full.login('usuario', 'senha')
# site_public.login('usuario', 'senha')

def process_wiki_sync():
    # 1. Selecionar somente os Category:Public
    category = site_full.categories['Public']
    
    for page in category:
        print(f"Processando página: {page.name}")
        content_pt = page.text()
        
        # 2. Traduzir o título para inglês (usando Gemini para precisão)
        title_prompt = f"Traduza apenas o título desta página para inglês (seja conciso): {page.name}"
        title_en = model.generate_content(title_prompt).text.strip()
        
        # 3. Traduzir conteúdo para Inglês
        content_en = translate_with_gemini(content_pt, "English")
        
        # 4. Traduzir conteúdo para Espanhol
        content_es = translate_with_gemini(content_pt, "Spanish")
        
        # 5. Salvar na Wiki Pública
        print(f"Salvando versões para: {title_en}")
        
        # Salva a versão principal (EN)
        site_public.pages[title_en].save(content_en, summary="Tradução automática EN")
        
        # Salva a versão PT (subpágina)
        site_public.pages[f"{title_en}/pt"].save(content_pt, summary="Cópia original PT")
        
        # Salva a versão ES (subpágina)
        site_public.pages[f"{title_en}/es"].save(content_es, summary="Tradução automática ES")
        
        print(f"Página {title_en} finalizada com sucesso!")
        time.sleep(2) # Pausa para evitar limites de taxa (rate limiting)

if __name__ == "__main__":
    process_wiki_sync()
