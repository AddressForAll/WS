# Tradução 

- colocar no inicio da página: {{idiomas}}
- Template:Idiomas
```
<div id="idioma-menu" style="background:#f0f4fa; border:1px solid #c2d10; padding:0.5em; border-radius:6px; font-size:95%; margin-bottom:1em;">
  <div id="idioma-label" style="font-weight:bold; margin-bottom:0.3em;">🌐 Idioma / Language:</div>
  <div style="display: flex; gap: 1em;">
    <div id="link-pt"></div>
    <div id="link-en"></div>
    <div id="link-es"></div>
  </div>
</div>
```
- MediaWiki:Common.js
```

mw.hook('wikipage.content').add(function () {
    console.log("[Language Menu] Script started");

    var path = mw.config.get("wgPageName");
    var scriptPath = mw.config.get("wgArticlePath").replace('$1', ''); // Geralmente '/doc/'
    
    var currentLang = '';
    var base = path;
    var langs = ['pt', 'en', 'es'];

    // 1. Detecta idioma pelo sufixo no wgPageName
    langs.forEach(function (lang) {
        var suffix = '/' + lang;
        if (path.toLowerCase().endsWith(suffix)) {
            currentLang = lang;
            base = path.slice(0, -suffix.length);
        }
    });

    if (!currentLang) currentLang = 'en';
    console.log("[Language Menu] Lang:", currentLang, "Base:", base);

    // 2. Labels e links do Menu
    var labels = { 'pt': 'Português', 'en': 'English', 'es': 'Español' };
    var links = {
        'pt': (base === 'Main_Page' || base === 'Página_principal') ? 'Página_principal/pt' : base + '/pt',
        'en': (base === 'Main_Page' || base === 'Página_principal') ? 'Main_Page' : base,
        'es': (base === 'Main_Page' || base === 'Página_principal') ? 'Main_Page/es' : base + '/es'
    };

    function insertContent(id, lang) {
        var el = document.getElementById(id);
        if (!el) return;
        if (lang === currentLang) {
            el.textContent = labels[lang];
        } else {
            el.innerHTML = '<a class="lang-menu-link" href="' + mw.util.getUrl(links[lang]) + '">' + labels[lang] + '</a>';
        }
    }

    ['pt', 'en', 'es'].forEach(function(l) { insertContent("link-" + l, l); });

    // 3. 🌀 Reescreve links do conteúdo (Correção do duplo /doc/)
    if (currentLang !== 'en') {
        // Seleciona links que começam com o caminho do artigo (ex: /doc/)
        document.querySelectorAll('a[href^="' + scriptPath + '"]').forEach(function (link) {
            if (link.classList.contains('lang-menu-link')) return;

            var href = link.getAttribute('href');
            if (!href || href.includes('?') || href.includes('#')) return;

            // Decodifica e remove barras extras no final
            var hrefNormalized = decodeURIComponent(href).replace(/\/$/, '');

            // Ignora namespaces do MediaWiki
            if (hrefNormalized.match(/\/(Special:|File:|Category:|Help:|MediaWiki:)/i)) return;

            // Se o link já termina com um idioma conhecido, não mexe
            var alreadyHasLang = langs.some(function(l) { 
                return hrefNormalized.endsWith('/' + l); 
            });
            if (alreadyHasLang) return;

            // EXTRAÇÃO SEGURA: Remove o prefixo /doc/ para não duplicar na reconstrução
            // Se o href é "/doc/PAGINA", o pagePart vira "PAGINA"
            var pagePart = hrefNormalized.startsWith(scriptPath) ? hrefNormalized.slice(scriptPath.length) : hrefNormalized;
            
            // Reconstroi usando mw.util.getUrl para garantir que o caminho do wiki seja respeitado
            var newHref = mw.util.getUrl(pagePart + '/' + currentLang);
            
            link.setAttribute('href', newHref);
        });
    }
});

```

- LocalSettings.php

```
// Pega a URL e remove parâmetros após a '?'
$requestUri = explode('?', $_SERVER['REQUEST_URI'])[0];

if (preg_match('#/(pt|pt-br)$#i', $requestUri) || strpos($requestUri, '/pt/') !== false) {
    $wgLanguageCode = "pt-br";
} elseif (preg_match('#/es$#i', $requestUri) || strpos($requestUri, '/es/') !== false) {
    $wgLanguageCode = "es";
} else {
    $wgLanguageCode = "en";
}

// Força a interface a seguir o código acima, ignorando o cache de idioma do navegadorr
$wgHiddenPrefs[] = 'language';
```

