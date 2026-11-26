# The parser plugin, built against paperless's own Python packages:
#   services.paperless.extraPythonPackages = ps: [ (ps.callPackage ./paperless-llm-ocr { }) ];
# It can only be imported inside paperless, so there is no import check.
{ lib, buildPythonPackage, setuptools, poppler-utils }:

buildPythonPackage {
  pname = "paperless-llm-ocr";
  version = "1.0.0";
  pyproject = true;

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [ ./pyproject.toml ./paperless_llm_ocr.py ];
  };

  postPatch = ''
    substituteInPlace paperless_llm_ocr.py \
      --replace-fail '@pdftoppm@' '${poppler-utils}/bin/pdftoppm' \
      --replace-fail '@pdftotext@' '${poppler-utils}/bin/pdftotext'
  '';

  build-system = [ setuptools ];
}
