{
  platform,
  pkgs,
  lib,
  vars,
  config,
  ...
}:

with lib;
let
  cfg = config.modules.altserver;
  netmuxd-src = pkgs.fetchFromGitHub {
    owner = "jkcoxson";
    repo = "netmuxd";
    rev = "7e6c520975e8d34045e36f9d58f9f529285337f5";
    hash = "sha256-NLWo+cAW8oBDaX+YjVb/gOgL/vw7P5ys3kMEX00OI/A=";
  };
  netmuxd = pkgs.rustPlatform.buildRustPackage {
    pname = "netmuxd";
    version = "0.1";
    cargoLock = {
      lockFile = netmuxd-src + /Cargo.lock;
      allowBuiltinFetchGit = true;
    };
    src = netmuxd-src;
    buildNoDefaultFeatures = true;
    buildFeatures = [ "usb" ];

    buildInputs = with pkgs; [
      openssl
      libimobiledevice
    ];

    nativeBuildInputs = with pkgs; [
      perl
      pkg-config
    ];
  };
in
{
  options.modules.altserver = {
    enable = mkEnableOption "altserver";
  };
  config = mkIf cfg.enable (
    optionalAttrs platform.isLinux {

      systemd.tmpfiles.rules =
        let
          directories = [
            "${vars.storage}/Services/anisette"
          ];
        in
        (map (directory: "d ${directory} 0750 misi backup -") directories);

      services.usbmuxd = {
        enable = true;
      };

      home-manager.users.${vars.username} = {
        home.packages = with pkgs; [
          libimobiledevice
          altserver-linux
        ];
      };

      programs.zsh.shellAliases = {
        netmuxd = "${netmuxd}/bin/netmuxd --disable-unix --host 127.0.0.1";
        altserver = "USBMUXD_SOCKET_ADDRESS='127.0.0.1:27015' ALTSERVER_ANISETTE_SERVER='http://127.0.0.1:6969' ${getExe pkgs.altserver-linux} -a '***@icloud.com' -p '***'";
      };

      systemd.services = {
        netmuxd = {
          wantedBy = [ "multi-user.target" ];
          requires = [ "usbmuxd.service" ];
          after = [ "network.target" ];
          description = "";

          serviceConfig = {
            Restart = "always";
            ExecStart = config.programs.zsh.shellAliases.netmuxd;
          };
        };

        altserver-server = {
          wantedBy = [ "multi-user.target" ];
          requires = [ "netmuxd.service" "usbmuxd.service" ];
          after = [ "network.target" ];
          description = "";

          serviceConfig = {
            Restart = "always";
            ExecStart = config.programs.zsh.shellAliases.altserver;
          };
        };
      };

      services.avahi = {
        enable = true;
        nssmdns4 = true;
        nssmdns6 = true;
        publish = {
          enable = true;
          userServices = true;
        };
      };

      virtualisation.oci-containers.containers.alt_anisette_server = {
        image = "dadoum/anisette-v3-server";
        ports = [
          "6969:6969"
        ];
        volumes = [
          "${vars.storage}/Services/anisette:/home/Alcoholic/.config/anisette-v3/lib/"
        ];
      };
    }
  );
}
