{ stdenv,
  python3,
  fetchFromGitHub,
  fetchYarnDeps,
  nodejs,
  yarnConfigHook,
  yarnBuildHook,
  postgresql,
  postgresqlTestHook,
  garage,
  garageTestHook,
  gettext,
}:

let
  src = fetchFromGitHub {
    owner = "suitenumerique";
    repo = "docs";
    tag = "v${version}";
    hash = "sha256-ISfdz71KrJ6hfs1HJKrTMXgcUPdegCwU/OM0r/yHXqs=";
  };
  version = "2.6.0";

in rec {

  mail-templates = stdenv.mkDerivation {
    pname = "numerique-docs-mail";
    inherit version src;

    sourceRoot = "${src.name}/src/mail";

    offlineCache = fetchYarnDeps {
      yarnLock = "${src}/src/mail/yarn.lock";
      hash = "sha256-ReCnbby6gU1FhSmzZqpp3GUYcnl2UOsot5U3Dhfc2Ak=";
    };

    preBuild = ''
      chmod u+w ../backend/core/templates
    '';
    installPhase = ''
      runHook preInstall
      cp -r ../backend/core/templates/mail $out
      runHook postInstall
    '';

    nativeBuildInputs = [ nodejs yarnConfigHook yarnBuildHook ];

  };

  backend = let
    python = python3.override {
      self = python;
      packageOverrides = final: prev: {
        django = final.django_5;
      };
    };
  in python.pkgs.buildPythonPackage {
    pname = "numerique-docs";
    inherit version src;
    
    sourceRoot = "${src.name}/src/backend";

    #build-system = [ python.pkgs.setuptools ];
    dependencies = with python.pkgs; [
      #python.pkgs.setuptools
      django
      requests
      sentry-sdk
      openai
      djangorestframework
      django-configurations
      mozilla-django-oidc
      faker
      responses
      factory-boy

      boto3
      brotli
      celery
      django-cors-headers
      django-countries
      django-filter
      django-parler
      redis
      django-redis
      django-storages
      django-timezone-field
      django-treebeard
      drf-spectacular
      easy-thumbnails
      jsonschema
      markdown
      psycopg
      pyjwt
      python-magic
      url-normalize
      whitenoise
      
      drf-spectacular-sidecar
      freezegun
      drf-nested-routers
      nested-multipart-parser
    ];
    postPatch = ''
      substituteInPlace pyproject.toml  \
        --replace-fail '"--cov-report",' "" \
        --replace-fail '"term-missing",' ""
      substituteInPlace impress/settings.py \
        --replace-fail '"dockerflow.django.middleware.DockerflowMiddleware",' "" \
        --replace-fail '"dockerflow.django",' "" \
        --replace-fail 'DATA_DIR = os.path.join("/", "data")' 'DATA_DIR = os.getenv("DATA_DIR", "/data")'
      cp -r ${mail-templates} core/templates/mail
    '';
    postBuild = ''
      export DATA_DIR=$PWD/data
      DJANGO_CONFIGURATION=Build python manage.py compilemessages
      DJANGO_CONFIGURATION=Build python manage.py collectstatic --noinput
    '';
    preCheck = ''
      export DJANGO_SETTINGS_MODULE=impress.settings
      export DJANGO_CONFIGURATION="Test"
      export DB_HOST="$PGHOST"
      export DB_USER="$PGUSER"
      export DJANGO_SECRET_KEY=ThisIsAnExampleKeyForTestPurposeOnly
      export OIDC_OP_JWKS_ENDPOINT=/endpoint-for-test-purpose-only
    '';
    garageTestBuckets = [ "impress-media-storage" ];
    postgresqlTestUserOptions = "LOGIN SUPERUSER";

    nativeBuildInputs = [
      gettext
    ];

    nativeCheckInputs = [
      python.pkgs.pytestCheckHook
      python.pkgs.pytest-django
      postgresql
      postgresqlTestHook
      garage
      garageTestHook
    ];

    disabledTestPaths = [
      # Garage: Not implemented
      "core/tests/documents/test_api_document_versions.py"
    ];
    disabledTests = [
      # Garage: Not implemented
      "test_models_documents_get_versions_slice_pagination"
      "test_models_documents_get_versions_slice_min_datetime"
      "test_models_documents_version_duplicate"

      # ???
      "test_update_blank_title_migration"
    ];

    passthru = {
      inherit (python.pkgs) gunicorn;
    };
  };

  y-provider = stdenv.mkDerivation {
    pname = "numerique-docs-y-provider";
    inherit version src;
    inherit (frontend) offlineCache;

    sourceRoot = "${src.name}/src/frontend";

    nativeBuildInputs = [ nodejs yarnConfigHook yarnBuildHook ];

    yarnBuildScript = "COLLABORATION_SERVER";
    yarnBuildFlags = [ "run" "build" ];
    installPhase = ''
      pushd servers/y-provider
      yarn install --frozen-lockfile --force --production=true --focused
      popd

      cp -r servers/y-provider/dist $out
      cp -rL node_modules $out/
    '';
  };
  frontend = stdenv.mkDerivation {
    pname = "numerique-docs-frontend";
    inherit version src;

    offlineCache = fetchYarnDeps {
      yarnLock = "${src}/src/frontend/yarn.lock";
      hash = "sha256-QgKIN8PIJ0QAB8i0NqcQrAq1gW8Rhndf4Z+5Dkxll+I=";
    };

    sourceRoot = "${src.name}/src/frontend";

    nativeBuildInputs = [ nodejs yarnConfigHook yarnBuildHook ];

    yarnBuildScript = "app:build";
    installPhase = ''
      cp -r apps/impress/out $out
    '';
  };
}
