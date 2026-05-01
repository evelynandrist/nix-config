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
    rev = "153498f9d8c98a229a2638a367a9a768dcf99c4b";
    hash = "sha256-JjkP1gfPTukAnYNeepwA/iVIbOqp57jLdAK9M2JoOCo=";
  };

  cargoHash = "sha256-B/zzhgARdHZx+3w6JHh8+3HaOKmMcVcQRcLR5/rUQUc=";

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [ openssl ];

  meta = {
    description = "Package to organize shell extensions andd scripts";
    homepage = "https://github.com/UbiqueInnovation/terminal-magic-cli";
    license = lib.licenses.asl20;
    maintainers = [];
  };
}
