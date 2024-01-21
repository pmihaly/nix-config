{ ... }: {
  imports = [
    ./nginx
    ./jellyfin
    ./homer
    ./authelia
    ./deluge
    ./arr
    ./endlessh
    ./monitoring
    ./hledger
    ./duckdns
    ./paperless
    ./syncthing
    ./qemu
  ];
}
