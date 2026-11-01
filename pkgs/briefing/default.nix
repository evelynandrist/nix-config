# `briefing` — collects calendar, journal and mail, has ollama summarise them
# and writes the result for Home Assistant. See briefing.py for the design and
# nixos/packardserver/home-assistant/briefing.nix for the service.
{ writers }:

writers.writePython3Bin "briefing" {
  flakeIgnore = [ "E501" ];
} (builtins.readFile ./briefing.py)
