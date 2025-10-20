{
  stdenv,
  rustPlatform,
  bencher,
  fetchNpmDeps,
  nodejs,
  npmHooks,
  wasm-pack,
  wasm-bindgen-cli_0_2_100,
  binaryen,
  cargo,
  rustc,
  clang,
  lld,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "bencher-console";
  version = bencher.version;

  inherit (bencher) meta src;

  npmRoot = "services/console";
  npmDeps = fetchNpmDeps {
    name = "${finalAttrs.pname}-npm-deps";
    inherit (finalAttrs) version src;
    sourceRoot = "${finalAttrs.src.name}/${finalAttrs.npmRoot}";
    hash = "sha256-P/vAihZvioNHU3qgn+lG2Vlc1xDnO2JZhr51zNd3+wg=";
  };

  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit (finalAttrs) pname version src;
    hash = "sha256-9Uf2XvBjZUudrfrLQCu4lCsGLx1zUz95nkNrMHTekm8=";
  };

  nativeBuildInputs = [
    npmHooks.npmConfigHook
    rustPlatform.cargoSetupHook
    nodejs
    wasm-pack
    wasm-bindgen-cli_0_2_100
    binaryen
    cargo
    rustc
    clang
    lld
  ];
  buildPhase = ''
    runHook preBuild

    cd services/console

    substituteInPlace astro.config.mjs \
      --replace-fail '// import node from "@astrojs/node";' 'import node from "@astrojs/node";' \
      --replace-fail 'adapter: undefined' 'adapter: node({mode: "standalone"})'

    wasm-pack build ../../lib/bencher_valid --target web --release --no-default-features --features plus,wasm

    npm run build

    cp -r dist $out

    runHook postBuild
  '';
})
