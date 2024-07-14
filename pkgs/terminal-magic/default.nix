{ lib
, fetchFromGitHub
, rustPlatform
, openssl
, pkg-config
}:

rustPlatform.buildRustPackage rec {
  pname = "terminal-magic";
  version = "0.5.6";

  src = fetchFromGitHub {
    owner = "UbiqueInnovation";
    repo = "terminal-magic-cli";
    rev = "d61486a55cc7bc21110984dd0ee4d2b5dd82b6d3";
    hash = "sha256-szI8GB6oREqqGsdi1QzeyypDNiHtOWgWBbXBhlACDaM=";
  };

  cargoHash = "sha256-TrJjqTZMkVag2am/24zWnMy8mBXgN2je7vucMkfe0Hw=";

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [ openssl ];

  meta = {
    description = "Package to organize shell extensions andd scripts";
    homepage = "https://github.com/UbiqueInnovation/terminal-magic-cli";
    license = lib.licenses.asl20;
    maintainers = [];
  };
}
