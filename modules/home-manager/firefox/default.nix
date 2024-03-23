{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.firefox;

in {
  options.modules.firefox = { enable = mkEnableOption "firefox"; };
  config = mkIf cfg.enable {

    modules.persistence.directories = [ ".mozilla" ];

    xdg.configFile."tridactyl/tridactylrc".text = ''
      bind gd tabdetach

      set modeindicator false

      set searchurls.nps https://search.nixos.org/packages?channel=unstable&sort=relevance&type=packages&query=
      set searchurls.nos https://search.nixos.org/options?channel=unstable&sort=relevance&type=packages&query=
      set searchurls.hos https://mipmip.github.io/home-manager-option-search/?query=
      set searchurls.nog https://noogle.dev/q?term=

      set searchurls.ys  https://youtube.com/results?search_query=
      set searchurls.y   https://youtube.com/feed/subscriptions

      set searchurls.g   https://google.com/search?q=
      set searchurls.ddg https://duckduckgo.com/?q=
      set searchurls.r   https://old.reddit.com/r/
      set searchurls.r   https://old.reddit.com/r/
      set searchurls.dh  https://hub.docker.com/search?q=

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
    '';

    programs.firefox = {
      enable = true;
      package = pkgs.firefox-bin;
      nativeMessagingHosts = [ pkgs.tridactyl-native pkgs.keepassxc ];
      policies = { DisableAppUpdate = true; };
      profiles = {
        misi = {
          id = 0;
          name = "misi";
          bookmarks = [{
            name = "munsik";
            toolbar = true;
            bookmarks = [
              {
                name = "skeler I";
                url = "https://www.youtube.com/watch?v=J0y6wM0aAgE";
              }
              {
                name = "skeler II";
                url = "https://www.youtube.com/watch?v=J4t4pMZBXZg";
              }
              {
                name = "skeler III";
                url = "https://www.youtube.com/watch?v=P4ALDytLAXQ";
              }
              {
                name = "garage";
                url = "https://www.youtube.com/watch?v=e1w7R1hEvCs";
              }
              {
                name = "breakcore to dissociate to";
                url = "https://www.youtube.com/watch?v=BhZ0Ky9uqts";
              }
              {
                name = "breakcore to feel to";
                url = "https://www.youtube.com/watch?v=0KaBYaQGwbs";
              }
              {
                name = "dnb";
                url = "https://www.youtube.com/watch?v=qNaCzmbaYWI";
              }
              {
                name = "focus lofi🍯";
                url = "https://www.youtube.com/watch?v=Xf3-4A-uEc8";
              }
              {
                name = "ethereal breaks *:･ﾟ✧";
                url = "https://www.youtube.com/watch?v=tdceTb3vsmk";
              }
              {
                name = "cartoon tripping minimal techo";
                url = "https://www.youtube.com/watch?v=WddpRmmAYkg";
              }
              {
                name = "breakcore to vibe to";
                url = "https://www.youtube.com/watch?v=5nVLLll-CKs";
              }
              {
                name = "heaven.exe breakcore";
                url = "https://www.youtube.com/watch?v=z9e8CPULjW4";
              }
              {
                name = "abyss darksynth";
                url = "https://www.youtube.com/watch?v=aA9GhsYt2O0";
              }
            ];
          }];
          search = {
            force = true;
            default = "Brave search";
            engines = {
              "Brave search" = {
                urls = [{
                  template = "https://search.brave.com/search";
                  params = [{
                    name = "q";
                    value = "{searchTerms}";
                  }];
                }];
                iconUpdateURL =
                  "https://cdn.search.brave.com/serp/v2/_app/immutable/assets/favicon-32x32.86083f5b.png";
              };
            };
          };
          settings = let
            tinkeringWithUserChrome = {
              "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
              "devtools.debugger.remote-enabled" = true;
              "devtools.chrome.enabled" = true;
            };
          in tinkeringWithUserChrome // {
            "general.smoothScroll" = true;
            "browser.tabs.warnOnClose" = false;
            "browser.tabs.warnOnCloseOtherTabs" = false;
            "browser.toolbars.bookmarks.visibility" = "newtab";
            "browser.chrome.toolbar_tips" = false;
            "media.videocontrols.picture-in-picture.enabled" = false;
            "browser.newtabpage.pinned" = [ ];
            "browser.startup.homepage" = "https://search.brave.com/search";
          };
          extensions = with pkgs.nur.repos.rycee.firefox-addons; [
            ublock-origin
            localcdn
            clearurls
            tridactyl
            sponsorblock
            istilldontcareaboutcookies
            old-reddit-redirect
            keepassxc-browser
            youtube-nonstop
            reddit-enhancement-suite
          ];
          userChrome = ''
            .tabbrowser-tab .tab-close-button,
            #firefox-view-button,
            #alltabs-button,
            #tracking-protection-icon-container,
            #reader-mode-button,
            #star-button-box,
            #unified-extensions-button,
            .unified-extensions-item,
            #tabs-newtab-button,
            #idbar,
            #appMenu-update-available-notification
            {
              display: none !important;
            }

            #titlebar,
            #PersonalToolbar
            {
              visibility: collapse !important;
            }
            #nav-bar {
              min-height: 0px !important;
              max-height: 0px !important;
            }
            toolbar {
              height: 0px !important;
            }

            #tabbrowser-tabs {
              border-inline-start: 1px solid transparent !important;
            }
          '';
          extraConfig = ''
            user_pref("app.normandy.api_url", "");
            user_pref("app.normandy.enabled", false);
            user_pref("app.shield.optoutstudies.enabled", false);
            user_pref("app.update.auto", false);
            user_pref("beacon.enabled", false);
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
      };
    };
  };
}
