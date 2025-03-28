{ buildPythonPackage
, fetchPypi
}:

buildPythonPackage rec {
  pname = "nested-multipart-parser";
  version = "1.5.0";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-KAObbIrNPTqhd5H1B3PyO34oYEUD7sYo6OCJMnaPc6k=";
  };
}
