# ollama on the RTX 3060. Its model is pulled and checked by
# paperless-llm-ocr.nix, the only user so far.
#
# Listens on 127.0.0.1 only; no port is opened. Models and state live in
# /persist/data/ollama, in the nightly restic backup.
#
# The CUDA build of ollama is not on cache.nixos.org, only on the CUDA
# team's cache, added below. A system that does not have this cache yet
# in its nix.conf would compile ollama with CUDA on this laptop for hours,
# so the first time, fetch it before deploying:
#
#   sudo nix build --no-link \
#     --option extra-substituters https://cache.nixos-cuda.org \
#     --option extra-trusted-public-keys cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M= \
#     <the ollama store path of the new system>
#
# Check:  ollama list
#         journalctl -u ollama -b
{ pkgs, ... }:
let
  home = "/persist/data/ollama";
in {
  nix.settings = {
    substituters = [ "https://cache.nixos-cuda.org" ];
    trusted-public-keys = [ "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M=" ];
  };

  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
    # A fixed user, so the files in /persist keep their owner.
    user = "ollama";
    inherit home;
  };

  systemd.tmpfiles.rules = [ "d ${home} 0750 ollama ollama -" ];
  systemd.services.ollama.unitConfig.RequiresMountsFor = [ home ];
}
