# `ob` — Obsidian's official headless Sync client (npm: obsidian-headless).
#
# The npm tarball ships without a lockfile, so package-lock.json next to this
# file was generated with `npm install --package-lock-only` from the tarball's
# package.json. On a version bump: update version + hash, regenerate the
# lockfile, then fix npmDepsHash from the build error.
{ lib
, buildNpmPackage
, fetchurl
, nodejs_22
, python3
}:

buildNpmPackage rec {
  pname = "obsidian-headless";
  version = "0.0.14";

  src = fetchurl {
    url = "https://registry.npmjs.org/obsidian-headless/-/obsidian-headless-${version}.tgz";
    hash = "sha256-73UpjtOjVtyypN6Yxu/hCyrGSwBVYAcRi2rHBTXnMVY=";
  };

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-eneAi7PQtum5ADpxM6bMKtPECqHN5STRpGlVYYaQ/Ks=";

  nodejs = nodejs_22;
  # better-sqlite3 is built from source with node-gyp
  nativeBuildInputs = [ python3 ];
  dontNpmBuild = true;

  meta = {
    description = "Headless client for Obsidian Sync";
    homepage = "https://obsidian.md/help/sync/headless";
    license = lib.licenses.unfree;
    mainProgram = "ob";
    platforms = lib.platforms.linux;
  };
}
