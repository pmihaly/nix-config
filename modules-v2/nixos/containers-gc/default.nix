{
  config,
  lib,
  vars,
  ...
}:

with lib;
let
  cfg = config.modules.containers-gc;
in
{
  options.modules.containers-gc = {
    enable = mkEnableOption "periodic garbage collection of unused container (podman) images";
    timer = mkOption {
      type = types.str;
      default = "daily";
      description = "systemd OnCalendar expression for the GC run.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.virtualisation.podman.enable;
        message = "modules.containers-gc: virtualisation.podman must be enabled";
      }
    ];

    systemd.services.containers-gc = {
      description = "Prune unused podman images";
      wantedBy = [ "timers.target" ];
      # Order after multi-user.target so the boot catch-up run (Persistent=true)
      # happens after the ${vars.persistDir} mount and the quadlet containers are
      # up — never against the pre-mount tmpfs storage.
      after = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        Environment = [ "HOME=/root" ];
      };
      script = ''
        # Prune images not referenced by any container (running or stopped), so old
        # image versions left behind by upgrades don't fill up ${vars.persistDir}
        # (this is what caused the 2026-08 ENOSPC corruption on skylake).
        # Quadlet containers use Pull=missing, so a container always re-pulls its
        # image on (re)start — pruning can't break container startup.
        echo "containers-gc: ${vars.persistDir} before prune:"
        df -h ${vars.persistDir}
        ${config.virtualisation.podman.package}/bin/podman image prune --force
        echo "containers-gc: ${vars.persistDir} after prune:"
        df -h ${vars.persistDir}
      '';
    };

    systemd.timers.containers-gc = {
      description = "Timer: prune unused podman images";
      wantedBy = [ "timers.target" ];
      unit = "containers-gc.service";
      timerConfig = {
        OnCalendar = cfg.timer;
        Persistent = true;
      };
    };
  };
}
