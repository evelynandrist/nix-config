{ config, ... }:
let
  home = "/Users/${config.userConfig.username}";
in {
  # Homebrew's ollama, not nixpkgs': the nixpkgs build sets
  # OLLAMA_MLX_BACKENDS="" so only the llama.cpp/Metal engine is available,
  # while the bottle links mlx-c and can also run the faster `-mlx` model tags.
  homebrew.brews = [ "ollama" ];

  # A daemon rather than a user agent so the API is up at boot, before (or
  # without) a GUI login. Runs as the user so models live in ~/.ollama.
  launchd.daemons.ollama.serviceConfig = {
    UserName = config.userConfig.username;
    ProgramArguments = [ "/opt/homebrew/opt/ollama/bin/ollama" "serve" ];
    EnvironmentVariables = {
      HOME = home;
      # reachable from home assistant on the LAN
      OLLAMA_HOST = "0.0.0.0:11434";
      OLLAMA_FLASH_ATTENTION = "1";
      # halves KV cache memory at negligible quality loss
      OLLAMA_KV_CACHE_TYPE = "q8_0";
      # never unload: a cold load costs seconds on every voice request
      OLLAMA_KEEP_ALIVE = "-1";
      # matches home assistant's default num_ctx; a request with a different
      # num_ctx than the loaded model forces a full reload
      OLLAMA_CONTEXT_LENGTH = "8192";
      # one model, one request at a time: each parallel slot reserves its own
      # context, which 16GB of unified memory can't spare
      OLLAMA_MAX_LOADED_MODELS = "1";
      OLLAMA_NUM_PARALLEL = "1";
    };
    RunAtLoad = true;
    KeepAlive = true;
    # launchd's default for daemons is "Standard", but "Background" (what the
    # home-manager module uses) clamps CPU/IO priority; be explicit.
    ProcessType = "Interactive";
    StandardOutPath = "${home}/Library/Logs/ollama.log";
    StandardErrorPath = "${home}/Library/Logs/ollama.log";
  };

  # macOS caps GPU-wired memory at ~2/3 of RAM (~10.9GB here). Headless, the
  # rest of the system needs far less than the remaining 5GB, so let the model
  # plus KV cache stay fully on the GPU. Not persistent across reboots by
  # itself, hence the RunAtLoad daemon.
  launchd.daemons.iogpu-wired-limit.serviceConfig = {
    ProgramArguments = [ "/usr/sbin/sysctl" "iogpu.wired_limit_mb=12288" ];
    RunAtLoad = true;
  };
}
