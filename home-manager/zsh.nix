{ config, lib, pkgs, ... }: {
  home.packages = with pkgs; [
    zsh-powerlevel10k
  ];
  programs.zsh = let
    c0 = config.colorScheme.palette.base00;
    c1 = config.colorScheme.palette.base08;
    c2 = config.colorScheme.palette.base0B;
    c3 = config.colorScheme.palette.base0C;
    c4 = config.colorScheme.palette.base07;
    c5 = config.colorScheme.palette.base04;
    c6 = config.colorScheme.palette.base06;
    c7 = config.colorScheme.palette.base0D;
    c8 = config.colorScheme.palette.base02;
    c9 = config.colorScheme.palette.base09;
    cA = config.colorScheme.palette.base0A;
    cB = config.colorScheme.palette.base01;
    cC = config.colorScheme.palette.base03;
    cD = config.colorScheme.palette.base0F;
    cE = config.colorScheme.palette.base0E;
    cF = config.colorScheme.palette.base05;
    # c0 = config.colorScheme.palette.base00;
    # c1 = config.colorScheme.palette.base01;
    # c2 = config.colorScheme.palette.base02;
    # c3 = config.colorScheme.palette.base03;
    # c4 = config.colorScheme.palette.base04;
    # c5 = config.colorScheme.palette.base05;
    # c6 = config.colorScheme.palette.base06;
    # c7 = config.colorScheme.palette.base07;
    # c8 = config.colorScheme.palette.base08;
    # c9 = config.colorScheme.palette.base09;
    # cA = config.colorScheme.palette.base0A;
    # cB = config.colorScheme.palette.base0B;
    # cC = config.colorScheme.palette.base0C;
    # cD = config.colorScheme.palette.base0D;
    # cE = config.colorScheme.palette.base0E;
    # cF = config.colorScheme.palette.base0F;
  in {
    enable = true;
    enableAutosuggestions = true;
    enableCompletion = true;
    historySubstringSearch = {
      enable = true;
      searchUpKey = [ "^[[A" "$terminfo[kcuu1]" ];
      searchDownKey = [ "^[[B" "$terminfo[kcud1]" ];
    };
    syntaxHighlighting.enable = true;
    autocd = true;
    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
      {
        name = "powerlevel10k-config";
        src = ./p10k-config;
        file = "p10k.zsh";
      }
    ];
    oh-my-zsh = {
      enable = true;
      theme = "";
      plugins = [
        "git"
        "zoxide"
        "rbw"
        "emacs"
        "fzf"
      ];
    };
    initExtraFirst = ''
[ $TERM = "dumb" ] && unsetopt zle && PS1='$ ' && exec sh

printf "\033]4;0;#${c0}\033"
printf "\033]4;1;#${c1}\033"
printf "\033]4;2;#${c2}\033"
printf "\033]4;3;#${c3}\033"
printf "\033]4;4;#${c4}\033"
printf "\033]4;5;#${c5}\033"
printf "\033]4;6;#${c6}\033"
printf "\033]4;7;#${c7}\033"
printf "\033]4;8;#${c8}\033"
printf "\033]4;9;#${c9}\033"
printf "\033]4;10;#${cA}\033"
printf "\033]4;11;#${cB}\033"
printf "\033]4;12;#${cC}\033"
printf "\033]4;13;#${cD}\033"
printf "\033]4;14;#${cE}\033"
printf "\033]4;15;#${cF}\033"
printf "\033]10;${cF}\033\\"
printf "\033]11;${c0}\033\\"
printf "\033]12;${cF}\033\\"
printf "\033]13;${cF}\033\\"
printf "\033]17;${cF}\033\\"
printf "\033]19;${c0}\033\\"
printf "\033]232;${c0}\033\\"
printf "\033]256;${cF}\033\\"
printf "\033]257;${c0}\033\\"
printf "\033]708;${c0}\033\\"

setopt extendedglob        # Extended globbing. Allows using regular expressions with *
setopt rcexpandparam       # Array expension with parameters
setopt nocheckjobs         # Don't warn about running processes when exiting
setopt numericglobsort     # Sort filenames numerically when it makes sense
setopt nobeep              # No beep
setopt appendhistory       # Immediately append history instead of overwriting
setopt histignorealldups   # If a new command is a duplicate, remove the older one
setopt inc_append_history  # save commands are added to the history immediately, otherwise only when shell exits.

zstyle ':completion:*' matcher-list 'm:{[:lower:][:upper:]}={[:upper:][:lower:]}' # Case insensitive tab completion
zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"         # Colored completion (different colors for dirs/files/etc)
zstyle ':completion:*' rehash true                              # automatically find new executables in path
zstyle ':completion:*' menu select                              # Highlight menu selection
# Speed up completions
zstyle ':completion:*' accept-exact '*(N)'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.zsh-cache
    '';
    initExtra = ''
# Set terminal window and tab/icon title
#
# usage: title short_tab_title [long_window_title]
#
# See: http://www.faqs.org/docs/Linux-mini/Xterm-Title.html#ss3.1
# Fully supports screen and probably most modern xterm and rxvt
# (In screen, only short_tab_title is used)
function title {
  emulate -L zsh
  setopt prompt_subst

  [[ "$EMACS" == *term* ]] && return

  # if $2 is unset use $1 as default
  # if it is set and empty, leave it as is
  : ''${2=$1}

  case "$TERM" in
    xterm*|putty*|rxvt*|konsole*|ansi|mlterm*|alacritty|kitty|wezterm|st*)
      print -Pn "\e]2;''${2:q}\a" # set window name
      print -Pn "\e]1;''${1:q}\a" # set tab name
      ;;
    screen*|tmux*)
      print -Pn "\ek''${1:q}\e\\" # set screen hardstatus
      ;;
    *)
    # Try to use terminfo to set the title
    # If the feature is available set title
    if [[ -n "$terminfo[fsl]" ]] && [[ -n "$terminfo[tsl]" ]]; then
      echoti tsl
      print -Pn "$1"
      echoti fsl
    fi
      ;;
  esac
}

ZSH_THEME_TERM_TAB_TITLE_IDLE="%15<..<%~%<<" #15 char left truncated PWD
ZSH_THEME_TERM_TITLE_IDLE="%n@%m:%~"

# Runs before showing the prompt
function mzc_termsupport_precmd {
  [[ "''${DISABLE_AUTO_TITLE:-}" == true ]] && return
  title $ZSH_THEME_TERM_TAB_TITLE_IDLE $ZSH_THEME_TERM_TITLE_IDLE
}

# Runs before executing the command
function mzc_termsupport_preexec {
  [[ "''${DISABLE_AUTO_TITLE:-}" == true ]] && return

  emulate -L zsh

  # split command into array of arguments
  local -a cmdargs
  cmdargs=("''${(z)2}")
  # if running fg, extract the command from the job description
  if [[ "''${cmdargs[1]}" = fg ]]; then
    # get the job id from the first argument passed to the fg command
    local job_id jobspec="''${cmdargs[2]#%}"
    # logic based on jobs arguments:
    # http://zsh.sourceforge.net/Doc/Release/Jobs-_0026-Signals.html#Jobs
    # https://www.zsh.org/mla/users/2007/msg00704.html
    case "$jobspec" in
      <->) # %number argument:
        # use the same <number> passed as an argument
        job_id=''${jobspec} ;;
      ""|%|+) # empty, %% or %+ argument:
        # use the current job, which appears with a + in $jobstates:
        # suspended:+:5071=suspended (tty output)
        job_id=''${(k)jobstates[(r)*:+:*]} ;;
      -) # %- argument:
        # use the previous job, which appears with a - in $jobstates:
        # suspended:-:6493=suspended (signal)
        job_id=''${(k)jobstates[(r)*:-:*]} ;;
      [?]*) # %?string argument:
        # use $jobtexts to match for a job whose command *contains* <string>
        job_id=''${(k)jobtexts[(r)*''${(Q)jobspec}*]} ;;
      *) # %string argument:
        # use $jobtexts to match for a job whose command *starts with* <string>
        job_id=''${(k)jobtexts[(r)''${(Q)jobspec}*]} ;;
    esac

    # override preexec function arguments with job command
    if [[ -n "''${jobtexts[$job_id]}" ]]; then
      1="''${jobtexts[$job_id]}"
      2="''${jobtexts[$job_id]}"
    fi
  fi

  # cmd name only, or if this is sudo or ssh, the next cmd
  local CMD=''${1[(wr)^(*=*|sudo|ssh|mosh|rake|-*)]:gs/%/%%}
  local LINE="''${2:gs/%/%%}"

  title '$CMD' '%100>...>$LINE%<<'
}

autoload -U add-zsh-hook
add-zsh-hook precmd mzc_termsupport_precmd
add-zsh-hook preexec mzc_termsupport_preexec


# Required for $langinfo
zmodload zsh/langinfo

# URL-encode a string
#
# Encodes a string using RFC 2396 URL-encoding (%-escaped).
# See: https://www.ietf.org/rfc/rfc2396.txt
#
# By default, reserved characters and unreserved "mark" characters are
# not escaped by this function. This allows the common usage of passing
# an entire URL in, and encoding just special characters in it, with
# the expectation that reserved and mark characters are used appropriately.
# The -r and -m options turn on escaping of the reserved and mark characters,
# respectively, which allows arbitrary strings to be fully escaped for
# embedding inside URLs, where reserved characters might be misinterpreted.
#
# Prints the encoded string on stdout.
# Returns nonzero if encoding failed.
#
# Usage:
#  zsh_urlencode [-r] [-m] [-P] <string> [<string> ...]
#
#    -r causes reserved characters (;/?:@&=+$,) to be escaped
#
#    -m causes "mark" characters (_.!~*'''()-) to be escaped
#
#    -P causes spaces to be encoded as '%20' instead of '+'
function zsh_urlencode() {
  emulate -L zsh
  local -a opts
  zparseopts -D -E -a opts r m P

  local in_str="$@"
  local url_str=""
  local spaces_as_plus
  if [[ -z $opts[(r)-P] ]]; then spaces_as_plus=1; fi
  local str="$in_str"

  # URLs must use UTF-8 encoding; convert str to UTF-8 if required
  local encoding=$langinfo[CODESET]
  local safe_encodings
  safe_encodings=(UTF-8 utf8 US-ASCII)
  if [[ -z ''${safe_encodings[(r)$encoding]} ]]; then
    str=$(echo -E "$str" | iconv -f $encoding -t UTF-8)
    if [[ $? != 0 ]]; then
      echo "Error converting string from $encoding to UTF-8" >&2
      return 1
    fi
  fi

  # Use LC_CTYPE=C to process text byte-by-byte
  local i byte ord LC_ALL=C
  export LC_ALL
  local reserved=';/?:@&=+$,'
  local mark='_.!~*'''()-'
  local dont_escape="[A-Za-z0-9"
  if [[ -z $opts[(r)-r] ]]; then
    dont_escape+=$reserved
  fi
  # $mark must be last because of the "-"
  if [[ -z $opts[(r)-m] ]]; then
    dont_escape+=$mark
  fi
  dont_escape+="]"

  # Implemented to use a single printf call and avoid subshells in the loop,
  # for performance
  local url_str=""
  for (( i = 1; i <= ''${#str}; ++i )); do
    byte="$str[i]"
    if [[ "$byte" =~ "$dont_escape" ]]; then
      url_str+="$byte"
    else
      if [[ "$byte" == " " && -n $spaces_as_plus ]]; then
        url_str+="+"
      else
        ord=$(( [##16] #byte ))
        url_str+="%$ord"
      fi
    fi
  done
  echo -E "$url_str"
}

# Emits the control sequence to notify many terminal emulators
# of the cwd
#
# Identifies the directory using a file: URI scheme, including
# the host name to disambiguate local vs. remote paths.
function mzc_termsupport_cwd {
  # Percent-encode the host and path names.
  local URL_HOST URL_PATH
  URL_HOST="$(zsh_urlencode -P $HOST)" || return 1
  URL_PATH="$(zsh_urlencode -P $PWD)" || return 1

  # common control sequence (OSC 7) to set current host and path
  printf "\e]7;%s\a" "file://''${URL_HOST}''${URL_PATH}"
}

# Use a precmd hook instead of a chpwd hook to avoid contaminating output
# i.e. when a script or function changes directory without `cd -q`, chpwd
# will be called the output may be swallowed by the script or function.
add-zsh-hook precmd mzc_termsupport_cwd

# File and Dir colors for ls and other outputs
export LS_OPTIONS='--color=auto'
eval "$(dircolors -b)"
alias ls='ls $LS_OPTIONS'

printf "\033]4;0;#${c0}\033\\"
printf "\033]4;1;#${c1}\033\\"
printf "\033]4;2;#${c2}\033\\"
printf "\033]4;3;#${c3}\033\\"
printf "\033]4;4;#${c4}\033\\"
printf "\033]4;5;#${c5}\033\\"
printf "\033]4;6;#${c6}\033\\"
printf "\033]4;7;#${c7}\033\\"
printf "\033]4;8;#${c8}\033\\"
printf "\033]4;9;#${c9}\033\\"
printf "\033]4;10;#${cA}\033\\"
printf "\033]4;11;#${cB}\033\\"
printf "\033]4;12;#${cC}\033\\"
printf "\033]4;13;#${cD}\033\\"
printf "\033]4;14;#${cE}\033\\"
printf "\033]4;15;#${cF}\033\\"
printf "\033]10;#${cF}\033\\"
printf "\033]11;#${c0}\033\\"
printf "\033]12;#${cF}\033\\"
printf "\033]13;#${cF}\033\\"
printf "\033]17;#${cF}\033\\"
printf "\033]19;#${c0}\033\\"
printf "\033]232;#${c0}\033\\"
printf "\033]256;#${cF}\033\\"
printf "\033]257;#${c0}\033\\"
printf "\033]708;#${c0}\033\\"

export EDITOR="emacsclient -c -a 'emacs'"

alias emacs="emacsclient -c -a 'emacs'"
function em() {
  exec >/dev/null
  setopt LOCAL_OPTIONS NO_NOTIFY NO_MONITOR
  hyprctl dispatch togglegroup
  e ''${*:-.} &
  sleep 0.5
  hyprctl dispatch lockactivegroup lock
  wait
  hyprctl dispatch togglegroup
  exec >/dev/tty
}

bindkey -v
    '';
  };
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };
  programs.hyfetch = {
    enable = true;
    settings = {
      preset = "transgender";
      mode = "rgb";
      light_dark = "dark";
      lightness = 0.53;
      color_align = {
        mode = "vertical";
      };
      backend = "neofetch";
    };
  };
}
