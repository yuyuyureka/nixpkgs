import ./make-test-python.nix (
  { pkgs, lib, ... }:
  {
    name = "numerique-docs";

    meta = with lib.maintainers; {
      maintainers = [ ];
    };

    nodes = {
      docs =
        { ... }:
        {
          services.numerique-docs.enable = true;
          services.numerique-docs.domain = "docs";
        };
    };

    testScript = ''
      start_all()

      with subtest("HedgeDoc sqlite"):
          docs.wait_for_unit("numerique-docs.service")
          docs.wait_for_open_port(8001)
          docs.wait_until_succeeds('curl -sSf -H "Host: docs" http://[::1]:8001')
    '';
  }
)
