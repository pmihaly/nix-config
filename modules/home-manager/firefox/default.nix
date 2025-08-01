{
  pkgs,
  lib,
  config,
  ...
}:

with lib;
let
  cfg = config.modules.firefox;
in
{
  options.modules.firefox = {
    enable = mkEnableOption "firefox";
    hintchars = mkOption {
      type = types.str;
    };
    binary = mkOption {
      type = types.str;
      default =
        if pkgs.stdenv.isLinux then
          getExe pkgs.firefox
        else
          "${pkgs.firefox}/Applications/Firefox.app/Contents/MacOS/firefox";
    };
    extraProfiles = mkOption {
      type = types.anything;
      default = { };
    };

  };
  config = mkIf cfg.enable {

    modules.persistence.directories = [ ".mozilla" ];

    home.packages = with pkgs; if stdenv.isLinux then [ widevine-cdm ] else [ ];

    programs.nushell.shellAliases = {
      misi = "${cfg.binary} -new-instance -P misi >/dev/null & disown";
    } // mapAttrs (name: profile: "${cfg.binary} -new-instance -P ${name} & disown") cfg.extraProfiles;

    xdg.configFile."tridactyl/tridactylrc".text = ''
      bind gd tabdetach
      bind f hint -J

      set modeindicator false

      set searchurls.nps   https://search.nixos.org/packages?channel=unstable&sort=relevance&type=packages&query=
      set searchurls.nos   https://search.nixos.org/options?channel=unstable&sort=relevance&type=packages&query=
      set searchurls.hos   https://home-manager-options.extranix.com/?release=master&query=
      set searchurls.nog   https://noogle.dev/q?term=

      set searchurls.ys    https://youtube.com/results?search_query=
      set searchurls.y     https://youtube.com/feed/subscriptions

      set searchurls.g     https://google.com/search?q=
      set searchurls.ddg   https://duckduckgo.com/?q=
      set searchurls.r     https://old.reddit.com/r/
      set searchurls.dh    https://hub.docker.com/search?q=
      set searchurls.map   https://google.com/maps/search/
      set searchurls.maps  https://google.com/maps/search/
      set searchurls.route https://google.com/maps/dir/?api=1&travelmode=transit&destination=
      set searchurls.route https://google.com/maps/dir/?api=1&travelmode=transit&destination=
      set searchurls.brew  https://formulae.brew.sh/cask/

      blacklistadd excalidraw.com
      blacklistadd hackerrank.com
      blacklistadd console.hetzner.cloud/console

      setnull searchurls.amazon
      setnull searchurls.amazonuk
      setnull searchurls.bing
      setnull searchurls.cnrtl
      setnull searchurls.duckduckgo
      setnull searchurls.gentoo_wiki
      setnull searchurls.github
      setnull searchurls.google
      setnull searchurls.googlelucky
      setnull searchurls.googleuk
      setnull searchurls.mdn
      setnull searchurls.osm
      setnull searchurls.qwant
      setnull searchurls.scholar
      setnull searchurls.searx
      setnull searchurls.startpage
      setnull searchurls.twitter
      setnull searchurls.wikipedia
      setnull searchurls.yahoo
      setnull searchurls.youtube

      set hintchars ${cfg.hintchars}
      set hintnames uniform

      set markjumpnoisy false
      set editorcmd ${config.modules.terminal-emulator.binary} nvim

      colours shydactyl
    '';

    programs.firefox = {
      enable = true;
      nativeMessagingHosts = [
        pkgs.tridactyl-native
        pkgs.keepassxc
      ];
      policies = {
        DisableAppUpdate = true;
      };
      profiles =
        let
          defaults = {
            search = {
              force = true;
              default = "Brave search";
              engines = {
                "Brave search" = {
                  urls = [
                    {
                      template = "https://search.brave.com/search";
                      params = [
                        {
                          name = "q";
                          value = "{searchTerms}";
                        }
                      ];
                    }
                  ];
                  iconUpdateURL = "https://cdn.search.brave.com/serp/v2/_app/immutable/assets/favicon-32x32.86083f5b.png";
                };
              };
            };
            settings =
              let
                tinkeringWithUserChrome = {
                  # open with opt+shift+cmd+i
                  "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
                  "devtools.debugger.remote-enabled" = true;
                  "devtools.chrome.enabled" = true;
                };
              in
              tinkeringWithUserChrome
              // {
                "general.smoothScroll" = true;
                "browser.tabs.warnOnClose" = false;
                "browser.tabs.warnOnCloseOtherTabs" = false;
                "browser.toolbars.bookmarks.visibility" = "newtab";
                "browser.chrome.toolbar_tips" = false;
                "media.videocontrols.picture-in-picture.enabled" = false;
                "browser.newtabpage.pinned" = [ ];
                "browser.startup.homepage" = "https://search.brave.com/search";
              };
            extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
              ublock-origin
              localcdn
              clearurls
              tridactyl
              istilldontcareaboutcookies
            ];
            userChrome = ''
              #tracking-protection-icon-container,
              .urlbar-page-action,
              #fxa-toolbar-menu-button
              {
                visibility: collapse;
              }

                              /* Source file https://github.com/MrOtherGuy/firefox-csshacks/tree/master/chrome/hide_tabs_toolbar_v2.css made available under Mozilla Public License v. 2.0
                See the above repository for updates as well as full license text. */

                /* This requires Firefox 133+ to work */

                @media (-moz-bool-pref: "sidebar.verticalTabs"),
                       -moz-pref("sidebar.verticalTabs"){
                  #sidebar-main{
                    visibility: collapse;
                  }
                }
                @media (-moz-bool-pref: "userchrome.force-window-controls-on-left.enabled"),
                       -moz-pref("userchrome.force-window-controls-on-left.enabled"){
                  #nav-bar > .titlebar-buttonbox-container{
                    order: -1 !important;
                    > .titlebar-buttonbox{
                      flex-direction: row-reverse;
                    }
                  }
                }
                @media not (-moz-bool-pref: "sidebar.verticalTabs"),
                       not -moz-pref("sidebar.verticalTabs"){
                  #TabsToolbar:not([customizing]){
                    visibility: collapse;
                  }
                  :root[sizemode="fullscreen"] #nav-bar > .titlebar-buttonbox-container{
                    display: flex !important;
                  }
                  :root:is([tabsintitlebar],[customtitlebar]) #toolbar-menubar:not([autohide="false"]) ~ #nav-bar{
                    > .titlebar-buttonbox-container{
                      display: flex !important;
                    }
                    :root[sizemode="normal"] & {
                      > .titlebar-spacer{
                        display: flex !important;
                      }
                    }
                    :root[sizemode="maximized"] & {
                      > .titlebar-spacer[type="post-tabs"]{
                        display: flex !important;
                      }
                      @media (-moz-bool-pref: "userchrome.force-window-controls-on-left.enabled"),
                        -moz-pref("userchrome.force-window-controls-on-left.enabled"),
                        (-moz-gtk-csd-reversed-placement),
                        (-moz-platform: macos){
                        > .titlebar-spacer[type="post-tabs"]{
                          display: none !important;
                        }
                        > .titlebar-spacer[type="pre-tabs"]{
                          display: flex !important;
                        }
                      }
                    }
                  }
                }
            '';
            extraConfig = ''
              user_pref("browser.translation.enable", "false");
              user_pref("signon.rememberSignons", "false");
              user_pref("app.update.checkInstallTime", "false");

              user_pref("app.normandy.api_url", "");
              user_pref("app.normandy.enabled", false);
              user_pref("app.shield.optoutstudies.enabled", false);
              user_pref("app.update.auto", false);
              // user_pref("beacon.enabled", false); // breaks leetcode
              user_pref("breakpad.reportURL", "");
              user_pref("browser.aboutConfig.showWarning", false);
              user_pref("browser.cache.offline.enable", false);
              user_pref("browser.crashReports.unsubmittedCheck.autoSubmit", false);
              user_pref("browser.crashReports.unsubmittedCheck.autoSubmit2", false);
              user_pref("browser.crashReports.unsubmittedCheck.enabled", false);
              user_pref("browser.disableResetPrompt", true);
              user_pref("browser.newtab.preload", false);
              user_pref("browser.newtabpage.activity-stream.section.highlights.includePocket", false);
              user_pref("browser.newtabpage.enabled", false);
              user_pref("browser.newtabpage.enhanced", false);
              user_pref("browser.newtabpage.introShown", true);
              user_pref("browser.safebrowsing.appRepURL", "");
              user_pref("browser.safebrowsing.blockedURIs.enabled", false);
              user_pref("browser.safebrowsing.downloads.enabled", false);
              user_pref("browser.safebrowsing.downloads.remote.enabled", false);
              user_pref("browser.safebrowsing.downloads.remote.url", "");
              user_pref("browser.safebrowsing.enabled", false);
              user_pref("browser.safebrowsing.malware.enabled", false);
              user_pref("browser.safebrowsing.phishing.enabled", false);
              user_pref("browser.search.suggest.enabled", false);
              user_pref("browser.selfsupport.url", "");
              user_pref("browser.send_pings", false);
              user_pref("browser.sessionstore.privacy_level", 0);
              user_pref("browser.sessionstore.resume_from_crash", false);
              user_pref("browser.shell.checkDefaultBrowser", false);
              user_pref("browser.startup.homepage_override.mstone", "ignore");
              user_pref("browser.tabs.crashReporting.sendReport", false);
              user_pref("browser.tabs.firefox-view", false);
              user_pref("browser.urlbar.groupLabels.enabled", false);
              user_pref("browser.urlbar.quicksuggest.enabled", false);
              user_pref("browser.urlbar.speculativeConnect.enabled", false);
              user_pref("browser.urlbar.trimURLs", false);
              user_pref("datareporting.healthreport.service.enabled", false);
              user_pref("datareporting.healthreport.uploadEnabled", false);
              user_pref("datareporting.policy.dataSubmissionEnabled", false);
              user_pref("device.sensors.ambientLight.enabled", false);
              user_pref("device.sensors.enabled", false);
              user_pref("device.sensors.motion.enabled", false);
              user_pref("device.sensors.orientation.enabled", false);
              user_pref("device.sensors.proximity.enabled", false);
              user_pref("dom.battery.enabled", false);
              user_pref("dom.event.clipboardevents.enabled", false);
              user_pref("dom.webaudio.enabled", false);
              user_pref("experiments.activeExperiment", false);
              user_pref("experiments.enabled", false);
              user_pref("experiments.manifest.uri", "");
              user_pref("experiments.supported", false);
              user_pref("extensions.getAddons.cache.enabled", false);
              user_pref("extensions.getAddons.showPane", false);
              user_pref("extensions.pocket.enabled", false);
              user_pref("extensions.shield-recipe-client.api_url", "");
              user_pref("extensions.shield-recipe-client.enabled", false);
              user_pref("extensions.webservice.discoverURL", "");
              user_pref("media.autoplay.default", 1);
              user_pref("media.autoplay.enabled", false);
              user_pref("media.eme.enabled", false);
              user_pref("media.gmp-widevinecdm.enabled", false);
              user_pref("media.navigator.enabled", false);
              user_pref("media.peerconnection.enabled", false);
              user_pref("media.video_stats.enabled", false);
              user_pref("network.IDN_show_punycode", true);
              user_pref("network.allow-experiments", false);
              user_pref("network.captive-portal-service.enabled", false);
              user_pref("network.cookie.cookieBehavior", 1);
              user_pref("network.dns.disablePrefetch", true);
              user_pref("network.dns.disablePrefetchFromHTTPS", true);
              user_pref("network.http.referer.spoofSource", true);
              user_pref("network.http.speculative-parallel-limit", 0);
              user_pref("network.predictor.enable-prefetch", false);
              user_pref("network.predictor.enabled", false);
              user_pref("network.prefetch-next", false);
              user_pref("network.trr.mode", 5);
              user_pref("privacy.donottrackheader.enabled", true);
              user_pref("privacy.donottrackheader.value", 1);
              user_pref("privacy.query_stripping", true);
              user_pref("privacy.trackingprotection.cryptomining.enabled", true);
              user_pref("privacy.trackingprotn.enabled", true);
              user_pref("privacy.trackingprotection.fingerprinting.enabled", true);
              user_pref("privacy.trackingprotection.pbmode.enabled", true);
              user_pref("privacy.usercontext.about_newtab_segregation.enabled", true);
              user_pref("security.ssl.disable_session_identifiers", true);
              user_pref("services.sync.prefs.sync.browser.newtabpage.activity-stream.showSponsoredTopSite", false);
              user_pref("signon.autofillForms", false);
              user_pref("toolkit.telemetry.archive.enabled", false);
              user_pref("toolkit.telemetry.bhrPing.enabled", false);
              user_pref("toolkit.telemetry.cachedClientID", "");
              user_pref("toolkit.telemetry.enabled", false);
              user_pref("toolkit.telemetry.firstShutdownPing.enabled", false);
              user_pref("toolkit.telemetry.hybridContent.enabled", false);
              user_pref("toolkit.telemetry.newProfilePing.enabled", false);
              user_pref("toolkit.telemetry.prompted", 2);
              user_pref("toolkit.telemetry.rejected", true);
              user_pref("toolkit.telemetry.reportingpolicy.firstRun", false);
              user_pref("toolkit.telemetry.server", "");
              user_pref("toolkit.telemetry.shutdownPingSender.enabled", false);
              user_pref("toolkit.telemetry.unified", false);
              user_pref("toolkit.telemetry.unifiedIsOptIn", false);
              user_pref("toolkit.telemetry.updatePing.enabled", false);
              user_pref("webgl.disabled", true);
              user_pref("webgl.renderer-string-override", " ");
              user_pref("webgl.vendor-string-override", " ");
            '';
          };
        in
        {
          misi = mkMerge [
            defaults
            {
              id = 0;
              name = "misi";
              extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
                sponsorblock
                old-reddit-redirect
                youtube-nonstop
                reddit-enhancement-suite
                keepassxc-browser
              ];
              bookmarks = {
                force = true;
                settings = [
                  {
                    name = "nixing";
                    toolbar = true;
                    bookmarks = [
                      {
                        name = "darwin options";
                        url = "https://daiderd.com/nix-darwin/manual/index.html";
                      }
                    ];
                  }
                  {
                    name = "selfhosting";
                    toolbar = true;
                    bookmarks = [
                      {
                        name = "skylake";
                        url = "http://skylake";
                      }
                      {
                        name = "local syncthing";
                        url = "http://127.0.0.1:8384";
                      }
                    ];
                  }
                  {
                    name = "munsik";
                    toolbar = true;
                    bookmarks = [
                      {
                        name = "skeler I";
                        url = "https://youtube.com/watch?v=J0y6wM0aAgE";
                      }
                      {
                        name = "skeler II";
                        url = "https://youtube.com/watch?v=J4t4pMZBXZg";
                      }
                      {
                        name = "skeler III";
                        url = "https://youtube.com/watch?v=P4ALDytLAXQ";
                      }
                      {
                        name = "skeler IV";
                        url = "https://youtube.com/watch?v=HUUy3mnAhCE";
                      }
                      {
                        name = "breakcore to dissociate to";
                        url = "https://youtube.com/watch?v=BhZ0Ky9uqts";
                      }
                      {
                        name = "breakcore to feel to";
                        url = "https://youtube.com/watch?v=0KaBYaQGwbs";
                      }
                      {
                        name = "dnb";
                        url = "https://youtube.com/watch?v=qNaCzmbaYWI";
                      }
                      {
                        name = "ethereal breaks *:･ﾟ✧";
                        url = "https://youtube.com/watch?v=tdceTb3vsmk";
                      }
                      {
                        name = "cartoon tripping minimal techo";
                        url = "https://youtube.com/watch?v=WddpRmmAYkg";
                      }
                      {
                        name = "heaven.exe breakcore";
                        url = "https://youtube.com/watch?v=z9e8CPULjW4";
                      }
                      {
                        name = "abyss darksynth";
                        url = "https://youtube.com/watch?v=aA9GhsYt2O0";
                      }
                      {
                        name = "smooooth sonic dj";
                        url = "https://youtube.com/watch?v=PYfhbYIxBxE";
                      }
                      {
                        name = "smooooth disco mix I";
                        url = "https://youtube.com/watch?v=4nvewes8Inc";
                      }
                      {
                        name = "smooooth ukg cat fight";
                        url = "https://youtube.com/watch?v=DjDWKh2bBzs";
                      }
                      {
                        name = "smooooth disco mix II";
                        url = "https://youtube.com/watch?v=kTWLNco__OU";
                      }
                      {
                        name = "smooooth disco mix III";
                        url = "https://www.youtube.com/watch?v=f18xfDO10UI";
                      }
                      {
                        name = "german underground techno";
                        url = "https://youtube.com/watch?v=M26nbsaIG7k";
                      }
                      {
                        name = "german underground techno II";
                        url = "https://youtube.com/watch?v=1R8V0zWP9js";
                      }
                      {
                        name = "german underground techno III";
                        url = "https://www.youtube.com/watch?v=eWU6v4EtKk0";
                      }
                      {
                        name = "dub techno";
                        url = "https://youtube.com/watch?v=NAiBeZdGIQ8";
                      }
                      {
                        name = "dub techno II";
                        url = "https://youtube.com/watch?v=OnYKl4KKMWY";
                      }
                      {
                        name = "dub techno III";
                        url = "https://www.youtube.com/watch?v=80VIQIAtOnQ";
                      }
                      {
                        name = "german hard techno";
                        url = "https://youtube.com/watch?v=FdOfhuYW_OI";
                      }
                      {
                        name = "german hard techno II";
                        url = "https://youtube.com/watch?v=6FJAWPuD4s8";
                      }
                      {
                        name = "argent metal k1lled I";
                        url = "https://youtube.com/watch?v=bgu94ChWTCA";
                      }
                      {
                        name = "argent metal k1lled II";
                        url = "https://www.youtube.com/watch?v=HIekm-GR14M";
                      }
                      {
                        name = "argent metal aim to head";
                        url = "https://www.youtube.com/watch?v=e0odt0EIdrE";
                      }
                      {
                        name = "argent metal underground";
                        url = "https://www.youtube.com/watch?v=znqWSaqW9n8";
                      }
                      {
                        name = "ultrakill workout mix";
                        url = "https://www.youtube.com/watch?v=WAEvqMB4ytU";
                      }
                      {
                        name = "old+new school doom";
                        url = "https://www.youtube.com/watch?v=k8aPouLFoZw";
                      }
                    ];
                  }
                ];
              };
            }
          ];
        }
        // mapAttrs (
          name: profile:
          mkMerge [
            defaults
            profile
          ]
        ) cfg.extraProfiles;
    };
  };
}
