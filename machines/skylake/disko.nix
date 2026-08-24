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
      boot = {
        type = "disk";
        device = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_125861345";
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
                };
              };
            };
          };
        };
      };
      main = {
        type = "disk";
        device = "/dev/disk/by-id/scsi-0HC_Volume_106683582";
        content = {
          type = "gpt";
          partitions = {
            root = {
              size = "100%";
              content = {
                type = "btrfs";

                subvolumes = {
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
