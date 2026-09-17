{
  pkgs,
  config,
  lib,
  vars,
  ...
}:

with lib;

let
  cfg = config.modules.matrix-vision-bot;

  # Runtime-only identification of this bot device on the homeserver.
  # A stable device id avoids a fresh device (and a full sync state) on
  # every restart.
  defaultDeviceId = "matrix-vision-bot";

  # The env's `openai` chain pulls in `inline-snapshot` purely as a
  # TEST dep, but in this nixpkgs rev (56c02bc) that package's own test
  # suite is flaky inside the Nix sandbox (3 failed / 1402 passed, repeated),
  # so it never builds and blocks the whole env. It's a dev-only test helper
  # — never present at runtime for the bot — so disable its doCheck through a
  # pythonOverrides on the interpreter: this rebuilds the package-set fixed
  # point, so every consumer (openai etc.) resolves the patched instance.
  # Scoped here; no other python user on the system is affected.
  botPython = pkgs.python312.override {
    packageOverrides = self: super: {
      inline-snapshot = super.inline-snapshot.overridePythonAttrs (o: {
        doCheck = false;
      });
    };
  };

  # Python interpreter with exactly the bot's runtime deps, built from the
  # repo's LOCKED nixpkgs (flake.lock). This is the reproducibility anchor:
  # `nix flake lock` pins nixpkgs to one commit, so dev and skylake always
  # resolve the same package versions.
  botEnv = botPython.withPackages (ps: [
    ps.matrix-nio # async Matrix client (module: nio)
    ps.aiohttp # matrix-nio transport
    ps.pillow # image decode/normalize (PIL)
    ps.requests # image download from m.image mxc URIs
    ps.numpy # image array ops in image_analysis
    ps.openai # OpenAI-compatible vision endpoints (OpenAI/OpenRouter)
  ]);

  # System-level deps exposed on the service PATH (ffmpeg provides the
  # codecs Pillow needs for HEIC/HEIF etc). Inherited verbatim from the
  # upstream `matrix-vision-bot-env` flake (t_84e3691e).
  systemDeps = [ pkgs.ffmpeg ];

  # The vended bot source (modules/nixos/matrix-vision-bot/src). Built in
  # the same shape as the reference flake: the source copied to $out/src and
  # a launcher `matrix-vision-bot` that runs `python -m matrix_bot` with
  # PYTHONPATH=$out/src and ffmpeg on PATH.
  package = pkgs.stdenv.mkDerivation {
    pname = "matrix-vision-bot";
    version = "0.1.0";
    src = ./src;

    nativeBuildInputs = [ pkgs.makeWrapper ];
    buildInputs = [ botEnv ] ++ systemDeps;

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin $out/src
      cp -r $src/* $out/src/
      makeWrapper ${botEnv}/bin/python $out/bin/matrix-vision-bot \
        --add-flags "-m matrix_bot" \
        --set PYTHONPATH "$out/src" \
        --prefix PATH : ${pkgs.lib.makeBinPath systemDeps}
      chmod +x $out/bin/matrix-vision-bot
      runHook postInstall
    '';
  };

  # Map the secret's MATRIX_BOT_USER name to the bot's MATRIX_USER_ID
  # (they are the same value — matrix-bot.age names it BOT_USER because
  # the hermes module consumed it first; the vision bot config reads
  # MATRIX_USER_ID). Done in the ExecStart wrapper so it happens at
  # runtime, after systemd has loaded EnvironmentFile.
  execStart = pkgs.writeShellScript "matrix-vision-bot-run" ''
    export MATRIX_USER_ID="''${MATRIX_USER_ID:-$MATRIX_BOT_USER}"
    exec ${package}/bin/matrix-vision-bot
  '';
in
{
  options.modules.matrix-vision-bot = {
    enable = mkEnableOption "Matrix vision bot (image analysis on m.image)";

    allowedUsers = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        List of full Matrix user ids (e.g. "@misi:matrix.skylake.mihaly.codes")
        allowed to trigger image analysis. Empty = any user in any room the
        bot can see.
      '';
    };

    maxImageRate = mkOption {
      type = types.int;
      default = 6;
      description = "Max images analysed per room per minute.";
    };

    maxConcurrent = mkOption {
      type = types.int;
      default = 2;
      description = "Max simultaneous vision API calls bot-wide.";
    };

    analysisPrompt = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Prompt override passed to the vision model.";
    };
  };

  config = mkIf cfg.enable {
    # The bot is an outbound-only Matrix client (federates over the
    # homeserver's own nginx front), so it exposes no local port and needs no
    # mkService/nginx wiring.

    users.groups.matrix-vision-bot = { };
    users.users.matrix-vision-bot = {
      description = "Matrix vision bot service user";
      isSystemUser = true;
      group = "matrix-vision-bot";
    };

    # agenix secrets. OWN entries pointing at the same committed .age files
    # the hermes module uses (encrypted for misi + skylake host key), so the
    # bot is self-contained and decrypts on skylake. Owner/group = the bot
    # user so its systemd unit can read them. Rendered into the unit via
    # EnvironmentFile, never the store.
    #
    #   matrix-bot.age     -> MATRIX_HOMESERVER, MATRIX_BOT_USER,
    #                         MATRIX_ACCESS_TOKEN, MATRIX_HOME_ROOM
    #   openrouter-api-key -> OPENROUTER_API_KEY (vision provider cred)
    age.secrets."matrix-vision-bot/matrix" = {
      file = ../../../secrets/matrix-bot.age;
      owner = "matrix-vision-bot";
      group = "matrix-vision-bot";
      mode = "400";
    };
    age.secrets."matrix-vision-bot/openrouter" = {
      file = ../../../secrets/openrouter-api-key.age;
      owner = "matrix-vision-bot";
      group = "matrix-vision-bot";
      mode = "400";
    };

    systemd.services.matrix-vision-bot = {
      description = "Matrix vision bot (image/vision analysis)";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      # Secret values are read from these materialized agenix files at unit
      # start (KEY=VALUE env-file format). No secret ever lands in the Nix
      # store — only the committed .age files in secrets/.
      serviceConfig.EnvironmentFile = [
        config.age.secrets."matrix-vision-bot/matrix".path
        config.age.secrets."matrix-vision-bot/openrouter".path
      ];

      environment = {
        # Stable device identity (avoids a fresh sync state per restart).
        MATRIX_DEVICE_ID = defaultDeviceId;
        MATRIX_MAX_IMAGE_RATE = toString cfg.maxImageRate;
        MATRIX_MAX_CONCURRENT = toString cfg.maxConcurrent;
      }
      // optionalAttrs (cfg.allowedUsers != [ ]) {
        MATRIX_ALLOWED_USERS = concatStringsSep "," cfg.allowedUsers;
      }
      // optionalAttrs (cfg.analysisPrompt != null) {
        MATRIX_ANALYSIS_PROMPT = cfg.analysisPrompt;
      };

      serviceConfig = {
        ExecStart = execStart;
        User = "matrix-vision-bot";
        Group = "matrix-vision-bot";
        Restart = "on-failure";
        RestartSec = "5s";
        # Stateless client — durable state (if any) belongs on /persist via
        # vars.serviceConfig, so give it a tmpfs RuntimeDirectory only.
        RuntimeDirectory = "matrix-vision-bot";
        RuntimeDirectoryMode = "0750";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
      };
    };
  };
}
