[
  (final: prev: {
    nerdfonts-fira-code = prev.nerdfonts.override {
      fonts = [ "FiraCode" ];
    };
  })
  (final: prev: {
    iosevka-custom = prev.iosevka.override {
      privateBuildPlan = ''
        [buildPlans.iosevka-custom]
        family = "Iosevka Custom"
        spacing = "fontconfig-mono"
        serifs = "slab"
        no-cv-ss = true
        export-glyph-names = true

          [buildPlans.iosevka-custom.ligations]
          inherits = "dlig"

        [buildPlans.iosevka-custom.weights.regular]
        shape = 400
        menu = 400
        css = 400

        [buildPlans.iosevka-custom.weights.bold]
        shape = 700
        menu = 700
        css = 700

        [buildPlans.iosevka-custom.weights.extrabold]
        shape = 800
        menu = 800
        css = 800

        [buildPlans.iosevka-custom.slopes.upright]
        angle = 0
        shape = "upright"
        menu = "upright"
        css = "normal"

        [buildPlans.iosevka-custom.slopes.italic]
        angle = 9.4
        shape = "italic"
        menu = "italic"
        css = "italic"
      '';
      set = "custom";
    };
  })
  (final: prev: {
    custom-firefox = prev.wrapFirefox prev.firefox-esr-unwrapped {
      nixExtensions = [
        (prev.fetchFirefoxAddon {
          name = "ublock";
          url = "https://addons.mozilla.org/firefox/downloads/file/4121906/ublock_origin-1.50.0.xpi";
          sha256 = "1cx5nzyjznhlyahlrb3pywanp7nk8qqkfvlr2wzqqlhbww1q0q8h";
        })
        (prev.fetchFirefoxAddon {
          name = "old-reddit-redirect";
          url = "https://addons.mozilla.org/firefox/downloads/file/4126417/old_reddit_redirect-1.7.0.xpi";
          sha256 = "0pyyj6zr48rhdnvs6ygh6ww1wsyka7vvbs3kkz2chjm1nlvbaw3b";
        })
        (prev.fetchFirefoxAddon {
          name = "decentraleyes";
          url = "https://addons.mozilla.org/firefox/downloads/file/3902154/decentraleyes-2.0.17.xpi";
          sha256 = "1wdgxlh9cpbxs3qvcr957jjzqlsmi42j70vmx9dvrclf8pf6vwg7";
        })
        (prev.fetchFirefoxAddon {
          name = "sponsorblock";
          url = "https://addons.mozilla.org/firefox/downloads/file/4117298/sponsorblock-5.4.8.xpi";
          sha256 = "0g04vqh8fjp96f646pracaz8cmwlddp811dd7j66h1gafx8q3jby";
        })
        (prev.fetchFirefoxAddon {
          name = "vimium";
          url = "https://addons.mozilla.org/firefox/downloads/file/4046008/vimium_ff-1.67.6.xpi";
          sha256 = "0mylnyyw7d8wsxnk24jlrb2j039y7qay8y8h5pb22wmx8a4ckmp8";
        })
      ];

      extraPolicies = {
        CaptivePortal = false;
        DisableFirefoxStudies = true;
        DisablePocket = true;
        DisableTelemetry = true;
        DisableFirefoxAccounts = true;
        FirefoxHome = {
          Pocket = false;
          Snippets = false;
        };
        UserMessaging = {
          ExtensionRecommendations = false;
          SkipOnboarding = true;
        };
        SecurityDevices = {
          "PKCS#11 Proxy Module" = "${prev.p11-kit}/lib/p11-kit-proxy.so";
        } // builtins.fromJSON ''
    {
    "NewTabPage": false,
    "DisplayMenuBar": true,
    "DisableFirefoxAccounts": true,
    "NetworkPrediction": false,
    "CaptivePortal": false,
    "DisableFirefoxStudies": true,
    "DisableTelemetry": true,
    "DisablePocket": true,
    "DisableFormHistory": true,
    "DNSOverHTTPS": {
      "Enabled": false
    },
    "DisableBuiltinPDFViewer": true,
    "DisableAppUpdate": true
    }

        '';
      };

      extraPrefs = ''
        // Show more ssl cert infos
        lockPref("security.identityblock.show_extended_validation", true);

        // Generated using ffprofile.com
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
        user_pref("general.useragent.override", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36");
        user_pref("keyword.enabled", false);
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
        user_pref("privacy.trackingprotection.enabled", true);
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
  })
]
