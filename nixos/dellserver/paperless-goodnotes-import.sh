#!/usr/bin/env bash
# Import a GoodNotes export into paperless (see paperless.nix).
#
# GoodNotes exports <subject>/<topic>/.../<file>.pdf. Paperless turns consume
# subfolders into tags and the file name into the title. This sends every
# PDF of the export to
#
#   <consume>/<tag path>/<subject> ~ <topic> ~ ... ~ <file>.pdf
#
# so each document gets the tags of the tag path, and a name that still
# holds subject and topic. " ~ " is the separator because it does not occur
# in the folder and file names GoodNotes produces (the script refuses an
# export where it does), so the name can be split back into its parts.
# Paperless keeps it as the document's original file name, also when the
# title is changed later.
#
# The export is only read. Run it on the machine that has the export; it
# asks for the sudo password of the server once.
#
# Usage:
#   paperless-goodnotes-import.sh [options] <export folder> <tag path>
#
#   -n          dry run: show what would be sent, send nothing
#   -f FOLDER   only this top-level folder of the export (repeatable)
#   -m MB       leave out files larger than this (default 100, 0 = no limit)
#   -H HOST     server to send to (default dellserver)
#   -c DIR      paperless's consume folder there
#               (default /persist/data/paperless/consume)
#
# Example:
#   paperless-goodnotes-import.sh -n -f bio \
#     ~/neocortexshare/pdf/2026-11-17_GoodNotes evelyn/school/kanti/goodnotes
set -euo pipefail

SEP=" ~ "
dry=0
only=()
max_mb=100
host=dellserver
consume=/persist/data/paperless/consume

usage() { sed -n '/^# Usage:/,/^set -euo/p' "$0" | sed '$d; s/^# \{0,1\}//'; }

while getopts "nf:m:H:c:h" opt; do
  case $opt in
    n) dry=1 ;;
    f) only+=("$OPTARG") ;;
    m) max_mb=$OPTARG ;;
    H) host=$OPTARG ;;
    c) consume=$OPTARG ;;
    h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1))
if (( $# != 2 )); then usage >&2; exit 2; fi

src=${1%/}
tag_path=${2#/}; tag_path=${tag_path%/}
[[ -d "$src" ]] || { echo "Not a folder: $src" >&2; exit 1; }
[[ -n "$tag_path" ]] || { echo "The tag path is empty." >&2; exit 1; }

in_list() { local x=$1; shift; local e; for e in "$@"; do [[ "$e" == "$x" ]] && return 0; done; return 1; }

# A tree of links with the final layout; rsync follows them, so nothing is
# copied locally.
tree=$(mktemp -d)
trap 'rm -rf "$tree"' EXIT
mkdir -p "$tree/$tag_path"

sent=0; renamed=0; large=()
while IFS= read -r -d '' file; do
  rel=${file#"$src"/}
  IFS=/ read -r -a parts <<< "$rel"
  top=""
  (( ${#parts[@]} > 1 )) && top=${parts[0]}
  if (( ${#only[@]} )) && ! in_list "$top" "${only[@]}"; then continue; fi

  if [[ "$rel" == *"$SEP"* ]]; then
    echo "'$SEP' occurs in '$rel'; the name could not be split back. Nothing sent." >&2
    exit 1
  fi
  if (( max_mb > 0 )) && (( $(stat -c %s "$file") > max_mb * 1024 * 1024 )); then
    large+=("$rel"); continue
  fi

  # bio/Zoologie/Amphibien/Skript.pdf -> bio ~ Zoologie ~ Amphibien ~ Skript.pdf
  name=${parts[0]}
  for p in "${parts[@]:1}"; do name+="$SEP$p"; done

  # two files that end up with the same name: -2, -3, ...
  target="$tree/$tag_path/$name"; n=2
  while [[ -e "$target" || -L "$target" ]]; do
    target="$tree/$tag_path/${name%.*}-$n.${name##*.}"; n=$((n + 1))
  done
  [[ "$target" != "$tree/$tag_path/$name" ]] && renamed=$((renamed + 1))

  ln -s "$(realpath "$file")" "$target"
  sent=$((sent + 1))
done < <(find "$src" -type f -iname '*.pdf' ! -name '.*' -print0 | sort -z)

echo "to $host:$consume/$tag_path/"
echo "files:                $sent"
echo "renamed (same name):  $renamed"
if (( max_mb > 0 )); then
  echo "left out (> $max_mb MB): ${#large[@]}"
  for f in "${large[@]}"; do echo "    $f"; done
fi

if (( sent == 0 )); then echo "Nothing to send."; exit 0; fi
if (( dry )); then echo "Dry run, nothing sent."; exit 0; fi

# First into the home folder on the server, then into the consume folder as
# root: the consume folder belongs to paperless, and paperless must own what
# is in it to be able to delete it after the import.
stage="paperless-import-$(date +%Y%m%d-%H%M%S)"
rsync -rtL --info=progress2 "$tree/" "$host:$stage/"
ssh -t "$host" "sudo sh -c 'cp -r --no-preserve=mode,ownership \"$stage\"/. \"$consume\"/ && chown -R paperless:paperless \"$consume\"' && rm -r \"$stage\""

echo "Sent. Progress: the tasks page in paperless."
