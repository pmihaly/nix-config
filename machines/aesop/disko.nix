{
  fileSystems."/nix".neededForBoot = true;
  fileSystems."/persist".neededForBoot = true;

  disko.devices = {
    nodev = {
      "/" = {
        fsType = "tmpfs";
        mountOptions = [ "defaults" "size=25%" "mode=755" ];
      };
    };
    disk = {
      main = {
        type = "disk";
        device = "/dev/nvme0n1";
        content = {
          type = "gpt";
          partitions = {
            esp = {
              priority = 1;
              name = "ESP";
              start = "1M";
              end = "500M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            root = {
              size = "100%";
              content = {
                type = "btrfs";

                subvolumes = {
                  "nix" = {
                    mountOptions = [ "compress-force=zstd:1" "noatime" ];
                    mountpoint = "/nix";
                  };

                  "persist" = {
                    mountOptions = [ "compress-force=zstd:1" "noatime" ];
                    mountpoint = "/persist";
                  };

                  "persist/.snapshots" = { };

                };
              };
            };
          };
        };
      };
    };
  };
}
