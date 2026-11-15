// HashCode Meet: the name, HashCode's mark and the welcome page.
// docker-jitsi-meet appends this file to interface_config.js at start;
// docker-compose.yml mounts it at /config/custom-interface_config.js.
// The welcome page's look is in config/web/ (plugin.head.html and friends).
interfaceConfig.APP_NAME = 'HashCode Meet';
interfaceConfig.NATIVE_APP_NAME = 'HashCode Meet';
interfaceConfig.PROVIDER_NAME = 'HashCode';

// HashCode's mark, served by this server (config/web/hashcode-logo.png), in
// the corner of the call and on the welcome page, linking to hashcode.digital.
interfaceConfig.SHOW_JITSI_WATERMARK = true;
interfaceConfig.DEFAULT_LOGO_URL = 'images/hashcode-logo.png';
interfaceConfig.DEFAULT_WELCOME_PAGE_LOGO_URL = 'images/hashcode-logo.png';
interfaceConfig.JITSI_WATERMARK_LINK = 'https://hashcode.digital';

// The welcome page: our three points and footer (welcomePageAdditionalContent),
// no app-store footer, no mobile app promotion.
interfaceConfig.DISPLAY_WELCOME_PAGE_CONTENT = true;
interfaceConfig.DISPLAY_WELCOME_FOOTER = false;
interfaceConfig.MOBILE_APP_PROMO = false;
