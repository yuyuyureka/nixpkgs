{ lib, pkgs, config, ... }:

let
  cfg = config.services.numerique-docs;
in {

  options = {

    services.numerique-docs = {

      enable = lib.mkEnableOption "suitenumerique docs";

      domain = lib.mkOption {
        type = lib.types.str;
      };

      listenAddress = lib.mkOption {
        type = lib.types.str;
        default = "[::1]";
        description = ''
          Address the server will listen on.
        '';
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 8001;
        description = ''
          Port the server will listen on.
        '';
      };

    };

  };

  config = lib.mkIf cfg.enable {

    systemd.targets.numerique-docs = {
      description = "Common target for all suitenumerique docs services.";
      wantedBy = [ "multi-user.target" ];
    };

    systemd.services.numerique-docs = let
      inherit (pkgs.numerique-docs) backend;
      inherit (backend) python gunicorn;
    in {
      wantedBy = ["numerique-docs.target"];
      environment = {
        PYTHONPATH = python.pkgs.makePythonPath backend.propagatedBuildInputs;
        DJANGO_SETTINGS_MODULE = "impress.settings";
        DJANGO_CONFIGURATION = "Production";
        DJANGO_ALLOWED_HOSTS = cfg.domain;
      };
      serviceConfig = {
        DynamicUser = true;
        ExecStart = "${lib.getExe gunicorn} impress.wsgi --bind ${cfg.listenAddress}:${toString cfg.port} --pythonpath ${backend}/${python.sitePackages}";
      };
    };

    systemd.services.numerique-docs-y-provider = {
      wantedBy = ["numerique-docs.target"];
      serviceConfig = {
        DynamicUser = true;
        ExecStart = "${pkgs.numerique-docs.y-provider.nodejs}/bin/node ${pkgs.numerique-docs.y-provider}/start-server.js";
      };
    };

    #systemd.services.numerique-docs-nginx = {
    #  wantedBy = ["numerique-docs.target"];
    #  serviceConfig = {
    #    DynamicUser = true;
    #    ExecStart = "";
    #  };
    #};
  };

}
