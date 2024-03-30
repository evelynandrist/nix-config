{ config, lib, pkgs, ... }: {
  systemd.services.fakeroute = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    description = "Start the fakeroute python script.";
    serviceConfig = {
      Type = "simple";
      User = "root";
      ExecStart = let
	python = pkgs.python3.withPackages (ps: with ps; [ pyroute2 scapy ]);
      in
	"${python.interpreter} ${./fakeroute.py}";
      Restart = "always";
      RestartSec = "10"; # restart after 10s if service crashes
      KillSignal = "SIGINT";
    };
  };
}
