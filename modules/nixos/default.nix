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
  ];
}
