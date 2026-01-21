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
  console.log("[Language Menu] Current path:", path);

  var currentLang = '';
  var base = path;
  var langs = ['pt', 'en', 'es'];

  // Detecta idioma pelo sufixo
  langs.forEach(function (lang) {
    var suffix = '/' + lang;
    if (path.toLowerCase().endsWith(suffix)) {
      currentLang = lang;
      base = path.slice(0, -suffix.length);
      console.log("[Language Menu] Detected language:", lang, "Base:", base);
    }
  });

  // Se não detectou idioma → assume inglês (default)
  if (!currentLang) currentLang = 'en';

  // Labels e links
  var labels = {
    'pt': 'Português',
    'en': 'English',
    'es': 'Español'
  };

  var links = {};
  if (base === 'Main_Page' || base === 'Página_principal') {
    links = {
      'pt': 'Página_principal/pt',
      'en': 'Main_Page',     // inglês é base
      'es': 'Main_Page/es'
    };
  } else {
    links = {
      'pt': base + '/pt',
      'en': base,            // inglês é sem sufixo
      'es': base + '/es'
    };
  }

  // Monta menu de idiomas
  function insertContent(id, lang) {
    var el = document.getElementById(id);
    if (!el) return;

    if (lang === currentLang) {
      el.textContent = labels[lang];
    } else {
      el.innerHTML = '<a class="lang-menu-link" href="' + mw.util.getUrl(links[lang]) + '">' + labels[lang] + '</a>';
    }
  }

  insertContent("link-pt", "pt");
  insertContent("link-en", "en");
  insertContent("link-es", "es");

  // 🌀 Reescreve links do conteúdo
  console.log("[Language Menu] Rewriting content links for:", currentLang);

  //document.querySelectorAll('#mw-content-text a[href^="/"]').forEach(function (link) {
  document.querySelectorAll('a[href^="/doc/"]').forEach(function (link) {
    if (link.classList.contains('lang-menu-link')) return; // ignora menu de idiomas

    var href = link.getAttribute('href');
    if (!href) return;

    var hrefNormalized = decodeURIComponent(href.replace(/\/$/, ''));

    // Ignora âncoras e parâmetros
    if (href.includes('?') || href.includes('#')) return;

    // Ignora namespaces especiais
    if (hrefNormalized.match(/\/(Special:|File:|Category:|Help:|MediaWiki:)/)) return;

    // Ignora se já tem idioma
    if (hrefNormalized.match(/\/(pt|en|es)$/)) return;

    // Adiciona idioma se não for inglês
    if (currentLang !== 'en') {
      var newHref = hrefNormalized + '/' + currentLang;
      link.setAttribute('href', newHref);
      console.log("[Language Menu] Link modificado:", href, "→", newHref);
    }
  });
});
```
- LocalSettings.php
```

# End of automatically generated settings.
# Add more configuration options below.
$path = $_SERVER['REQUEST_URI'];

if (preg_match('#/en$#', $path)) {
    $wgLanguageCode = 'en';
} elseif (preg_match('#/es$#', $path)) {
    $wgLanguageCode = 'es';
} elseif (preg_match('#/pt$#', $path)) {
    $wgLanguageCode = 'pt';
}
```
