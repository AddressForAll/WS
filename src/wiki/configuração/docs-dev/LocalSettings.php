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
$wgServer = "https://wiki.example.org";

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
$wgMemCachedServers = [];

$wgEnableUploads = true;
$wgUseImageMagick = true;
$wgImageMagickConvertCommand = "/usr/bin/convert";
$wgUseInstantCommons = true;
$wgPingback = true;

# Time zone
$wgLocaltimezone = "America/Sao_Paulo";

# Chave secreta (Anonimizada)
$wgSecretKey = "SECRET_KEY_PLACEHOLDER_64_CHARS";
$wgAuthenticationTokenVersion = "1";
$wgUpgradeKey = "UPGRADE_KEY_PLACEHOLDER";

$wgDiff3 = "/usr/bin/diff3";
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

# Configurações de Upload
$wgEnableUploads = true;
$wgFileExtensions = array( 'png', 'gif', 'jpg', 'jpeg', 'webp' );
$wgGroupPermissions['user']['upload'] = true;
$wgGroupPermissions