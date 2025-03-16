{
  fileSystems."/nix".neededForBoot = true;
  fileSystems."/boot".neededForBoot = true;
  fileSystems."/persist".neededForBoot = true;

  disko.devices = {
    nodev = {
      "/" = {
        fsType = "tmpfs";
        mountOptions = [
          "defaults"
          "size=50%"
          "mode=755"
        ];
      };
    };
    disk = {
      main = {
        type = "disk";
        device = "/dev/sda";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              priority = 1;
              size = "1M";
              type = "EF02";
            };
            root = {
              size = "100%";
              content = {
                type = "btrfs";

                subvolumes = {
                  "boot" = {
                    mountOptions = [
                      "compress-force=zstd:1"
                      "noatime"
                    ];
                    mountpoint = "/boot";
                  };

                  "nix" = {
                    mountOptions = [
                      "compress-force=zstd:1"
                      "noatime"
                    ];
                    mountpoint = "/nix";
                  };

                  "persist" = {
                    mountOptions = [
                      "compress-force=zstd:1"
                      "noatime"
                    ];
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
