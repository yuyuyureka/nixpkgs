{
  rustPlatform,
  fetchFromGitHub,
  warpgate-web,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "warpgate";
  version = "0.11.0";

  src = fetchFromGitHub {
    owner = "warp-tech";
    repo = "warpgate";
    rev = "v${finalAttrs.version}";
    hash = "sha256-GiTM/oqA6vut5LbYKYzcHfT4rJD7ccJgDIB/HbQ58fk=";
  };

  useFetchCargoVendor = true;

  RUSTC_BOOTSTRAP = 1;

  # Allow config to be world-readable
  postPatch = ''
    substituteInPlace warpgate/src/config.rs --replace-fail "if secure {" "if false {"
  '';

  cargoHash = "sha256-pwYpxA1Y3l/UiXnaguBQtE2Yd7Xf2iAfnSPUAxWqXe4=";

  cargoBuildFlags = [ "--all-features" ];

  doCheck = true; # requires multiple dbs to be installed

  preBuild = ''
    cp -R ${warpgate-web}/dist warpgate-web/
  '';
})
