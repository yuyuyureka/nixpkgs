{ stdenv,
  fetchFromGitHub,
  nodejs,
  just,
  openapi-generator-cli,
  typescript,
  fetchYarnDeps,
  yarnConfigHook,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "warpgate-web";
  version = "0.11.0";

  src = fetchFromGitHub {
    owner = "warp-tech";
    repo = "warpgate";
    rev = "v${finalAttrs.version}";
    hash = "sha256-GiTM/oqA6vut5LbYKYzcHfT4rJD7ccJgDIB/HbQ58fk=";
  };
  sourceRoot = "${finalAttrs.src.name}/warpgate-web";

  offlineCache = fetchYarnDeps {
    yarnLock = finalAttrs.src + "/warpgate-web/yarn.lock";
    hash = "sha256-m2wQTgxnwcaTSfQ/pWOS3gzFRhpS/ZdTs+NG/OarYvQ=";
  };

  nativeBuildInputs = [
    nodejs
    openapi-generator-cli
    typescript
    yarnConfigHook
  ];

  postPatch = ''
    substituteInPlace package.json --replace-fail "npm i typescript@5 && npm i && yarn " ""
    substituteInPlace svelte.config.js --replace-fail "prebundleSvelteLibraries: true," ""
  '';

  buildPhase = ''
    rm node_modules/.bin/openapi-generator-cli
    yarn --offline openapi:client:admin
    yarn --offline openapi:client:gateway
    yarn --offline build
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -R dist $out/

    runHook postInstall
  '';
})
