<?php
# ========================================================================
# PARTE 1: CONFIGURAÇÕES ORIGINAIS DO AMBIENTE (docs.php)
# ========================================================================
# Estas configurações definem onde o site está e qual banco de dados usar.

# Protect against web entry
if ( !defined( 'MEDIAWIKI' ) ) {
	exit;
}

$wgSitename = "SITENAME_PLACEHOLDER";
$wgMetaNamespace = "METANAMESPACE_PLACEHOLDER";

## The URL base path to the directory containing the wiki;
$wgScriptPath = "/w";
$wgArticlePath = "/doc/$1";

## The protocol and server name to use in fully-qualified URLs
$wgServer = "https://wiki-usr.example.org";

## The URL path to static resources (images, scripts, etc.)
$wgResourceBasePath = $wgScriptPath;

## The URL paths to the logo.
$wgLogos = [
	'1x' => "$wgResourceBasePath/resources/assets/logo_custom.png",
	'icon' => "$wgResourceBasePath/resources/assets/logo_custom.png",
];

$wgEnableEmail = true;
$wgEnableUserEmail = true;

$wgEmergencyContact = "admin@example.org";
$wgPasswordSender = "admin@example.org";

$wgEnotifUserTalk = false;
$wgEnotifWatchlist = false;
$wgEmailAuthentication = true;

## Database settings
$wgDBtype = "mysql";
$wgDBserver = "db_host";
$wgDBname = "db_name";
$wgDBuser = "db_user";
$wgDBpassword = "DB_PASSWORD_PLACEHOLDER";

# MySQL specific settings
$wgDBprefix = "";
$wgDBssl = false;
$wgDBTableOptions = "ENGINE=InnoDB, DEFAULT CHARSET=binary";
$wgSharedTables[] = "actor";

## Shared memory settings
$wgMainCacheType = CACHE_ACCEL;

$wgEnableUploads = true;
$wgUseImageMagick = true;
$wgImageMagickConvertCommand = "/usr/bin/convert";
$wgUseInstantCommons = true;
$wgPingback = true;

# Time zone
$wgLocaltimezone = "America/Sao_Paulo";

# Chaves de Segurança (Anonimizadas)
$wgSecretKey = "SECRET_KEY_PLACEHOLDER_64_CHARS";
$wgAuthenticationTokenVersion = "1";
$wgUpgradeKey = "UPGRADE_KEY_PLACEHOLDER";

$wgDiff3 = "/usr/bin/diff3";
$wgDefaultSkin = "vector";

# Skins e Extensões Base
wfLoadSkin( 'MinervaNeue' );
wfLoadSkin( 'MonoBook' );
wfLoadSkin( 'Timeless' );
wfLoadSkin( 'Vector' );
wfLoadExtension( 'CodeEditor' );
wfLoadExtension( 'VisualEditor' );
wfLoadExtension( 'WikiEditor' );

# ========================================================================
# ⬇️ PARTE 2: IMPORTADO DO SITE COMPLETO (pub.php) ⬇️
# ========================================================================

# Notificações e Uploads
$wgEnotifUserTalk = true; 
$wgEnotifWatchlist = true; 
$wgFileExtensions = array( 'png', 'gif', 'jpg', 'jpeg', 'webp' );
$wgGroupPermissions['user']['upload'] = true;

# Licenciamento
$wgRightsUrl = "https://creativecommons.org/licenses/by/4.0/";
$wgRightsText = "Creative Commons - Atribuição";
$wgRightsIcon = "$wgResourceBasePath/resources/assets/licenses/cc-by.png";

# Interface Chameleon (Bootstrap)
wfLoadExtension( 'Bootstrap' );
wfLoadSkin( 'chameleon' );
$wgDefaultSkin = "chameleon";

# Extensões Adicionais (Lista Resumida)
wfLoadExtension( 'CategoryTree' );
wfLoadExtension( 'Cite' );
wfLoadExtension( 'Scribunto' );
wfLoadExtension( 'Kartographer' );
wfLoadExtension( 'LookupUser' );

# Configurações Lua
$wgScribuntoDefaultEngine = 'luastandalone';
$wgScribuntoEngineConf['luastandalone']['luaPath'] = '/usr/bin/lua5.1';

# NAMESPACES CUSTOMIZADOS
define("NS_CUSTOM_1", 3000);
define("NS_CUSTOM_1_TALK", 3001);
# ... (outras definições mantidas conforme lógica original)

$wgExtraNamespaces[NS_CUSTOM_1] = "namespace_custom";

# --- POLÍTICA DE PRIVACIDADE (WIKI PRIVADA) ---
$wgGroupPermissions['*']['read'] = false; // Bloqueia leitura pública
$wgGroupPermissions['*']['edit'] = false;
$wgGroupPermissions['*']['createaccount'] = false;

$wgGroupPermissions['user']['read'] = true;
$wgGroupPermissions['user']['edit'] = true;

# Lista Branca para Login
$wgWhitelistRead = [
    "Special:UserLogin",
    "Special:UserLogout",
    "Special:PasswordReset",
    "Special:ChangePassword",
    "MediaWiki:Common.css",
    "MediaWiki:Common.js"
];

# Autenticação de Imagens
$wgUploadDirectory = "$IP/images";
$wgUploadPath = "/w/img_auth.php";
$wgUploadAuthScript = "$IP/img_auth.php";

$wgEnableAPI = true;
$wgEnableWriteAPI = true;

# Logs de Erro
$wgDebugLogFile = "/var/www/html/debug.log";
$wgShowExceptionDetails = true;

# SESSÃO E COOKIES
$wgSessionName = 'session_usr_placeholder';
$wgCookiePrefix = "usr_wiki_custom";
$wgCookieDomain = "wiki-usr.example.org";

$wgGroupPermissions['user']['apihighlimits'] = true;