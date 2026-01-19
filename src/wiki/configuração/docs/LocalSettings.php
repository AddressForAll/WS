<?php
# ========================================================================
# PARTE 1: CONFIGURAÇÕES ORIGINAIS DO AMBIENTE (docs.php)
# ========================================================================
# Estas configurações definem onde o site está e qual banco de dados usar.
# Não altere estas linhas com dados do site antigo.

# Protect against web entry
if ( !defined( 'MEDIAWIKI' ) ) {
	exit;
}

## Uncomment this to disable output compression
# $wgDisableOutputCompression = true;

$wgSitename = "SITENAME_PLACEHOLDER";
$wgMetaNamespace = "METANAMESPACE_PLACEHOLDER";

## The URL base path to the directory containing the wiki;
#$wgScriptPath = "";
$wgScriptPath = "/w";
$wgArticlePath = "/doc/$1";

## The protocol and server name to use in fully-qualified URLs
$wgServer = "https://wiki.example.org";

## The URL path to static resources (images, scripts, etc.)
$wgResourceBasePath = $wgScriptPath;

## The URL paths to the logo.
$wgLogos = [
	'1x' => "$wgResourceBasePath/resources/assets/logo_custom.png",
	'icon' => "$wgResourceBasePath/resources/assets/logo_custom.png",
];

## UPO means: this is also a user preference option
$wgEnableEmail = true;
$wgEnableUserEmail = true; # UPO

$wgEmergencyContact = "admin@example.org";
$wgPasswordSender = "admin@example.org";

$wgEnotifUserTalk = false; # UPO
$wgEnotifWatchlist = false; # UPO
$wgEmailAuthentication = true;

## Database settings (DO NOVO SITE)
$wgDBtype = "mysql";
$wgDBserver = "database_host";
$wgDBname = "database_name";
$wgDBuser = "database_user";
$wgDBpassword = "DB_PASSWORD_PLACEHOLDER";

# MySQL specific settings
$wgDBprefix = "";
$wgDBssl = false;

# MySQL table options to use during installation or update
$wgDBTableOptions = "ENGINE=InnoDB, DEFAULT CHARSET=binary";

# Shared database table
$wgSharedTables[] = "actor";

## Shared memory settings
$wgMainCacheType = CACHE_ACCEL;
$wgMemCachedServers = [];

## Configuração inicial de uploads
$wgEnableUploads = true;
$wgUseImageMagick = true;
$wgImageMagickConvertCommand = "/usr/bin/convert";

# InstantCommons allows wiki to use images from https://commons.wikimedia.org
$wgUseInstantCommons = true;

$wgPingback = true;

# Time zone
$wgLocaltimezone = "America/Sao_Paulo";

$wgSecretKey = "SECRET_KEY_PLACEHOLDER_64_CHARS";

# Changing this will log out all existing sessions.
$wgAuthenticationTokenVersion = "1";

# Site upgrade key.
$wgUpgradeKey = "UPGRADE_KEY_PLACEHOLDER";

# Path to the GNU diff3 utility.
$wgDiff3 = "/usr/bin/diff3";

## Default skin
$wgDefaultSkin = "vector";

# Skins carregadas
wfLoadSkin( 'MinervaNeue' );
wfLoadSkin( 'MonoBook' );
wfLoadSkin( 'Timeless' );
wfLoadSkin( 'Vector' );

# Extensões padrão
wfLoadExtension( 'CodeEditor' );
wfLoadExtension( 'VisualEditor' );
wfLoadExtension( 'WikiEditor' );

# ========================================================================
# ⬇️ PARTE 2: IMPORTADO DO SITE COMPLETO (pub.php) ⬇️
# ========================================================================

# Notificações
$wgEnotifUserTalk = true;
$wgEnotifWatchlist = true;

# Extensões e Skins Adicionais
wfLoadExtension( 'Bootstrap' );
wfLoadSkin( 'chameleon' );
$wgDefaultSkin = "chameleon";

wfLoadExtension( 'CategoryTree' );
wfLoadExtension( 'Cite' );
wfLoadExtension( 'CiteThisPage' );
wfLoadExtension( 'Scribunto' );
wfLoadExtension( 'Kartographer' );
wfLoadExtension( 'LookupUser' );

# Configurações de Mapa
$wgKartographerMapServer = 'https://a.tile.openstreetmap.org/';

# DEFINIÇÃO DE NAMESPACES
define("NS_CUSTOM_1", 3000);
define("NS_CUSTOM_2", 3004);
# ... (demais definições mantidas conforme original)

$wgExtraNamespaces[NS_CUSTOM_1] = "namespace_1";
$wgExtraNamespaces[NS_CUSTOM_2] = "namespace_2";

# PERMISSÕES DE SEGURANÇA
$wgGroupPermissions['*']['createaccount'] = false;
$wgGroupPermissions['*']['edit'] = false;
$wgGroupPermissions['*']['read'] = true;

# LISTA BRANCA
$wgWhitelistRead = [
    "Special:UserLogin",
    "Special:UserLogout",
    "Special:PasswordReset",
    "MediaWiki:Common.css",
    "MediaWiki:Common.js"
];

# COOKIES E SESSÃO
$wgSessionName = 'session_placeholder';
$wgCookiePrefix = "wiki_custom";
$wgCookieDomain = "wiki.example.org";

# DEBUG LOGS
$wgDebugLogFile = "/var/www/html/debug_anon.log";