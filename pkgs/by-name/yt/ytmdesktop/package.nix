{
  lib,
  cacert,
  commandLineArgs ? "",
  copyDesktopItems,
  electron,
  fetchFromGitHub,
  yarn-berry,
  makeDesktopItem,
  makeWrapper,
  stdenv,
  stdenvNoCC,
  writableTmpDirAsHomeHook,
  writeShellScriptBin,
  zip,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "ytmdesktop";
  version = "2.0.8";

  src = fetchFromGitHub {
    owner = "ytmdesktop";
    repo = "ytmdesktop";
    tag = "v${finalAttrs.version}";
    hash = "sha256-WJuT+TnpqjGgzoUVFvMHknkrba1mca5LcNMKoSkDxJQ=";
  };

  desktopItems = [
    (makeDesktopItem {
      desktopName = "YouTube Music Desktop App";
      exec = "ytmdesktop";
      icon = "ytmdesktop";
      name = "ytmdesktop";
      genericName = finalAttrs.meta.description;
      mimeTypes = [ "x-scheme-handler/ytmd" ];
      categories = [
        "AudioVideo"
        "Audio"
      ];
      startupNotify = true;
      startupWMClass = "YouTube Music Desktop App";
    })
  ];

  yarnOfflineCache = stdenvNoCC.mkDerivation {
    name = "${finalAttrs.pname}-${finalAttrs.version}-offline-cache";
    inherit (finalAttrs) src;

    nativeBuildInputs = [
      cacert
      yarn-berry
      writableTmpDirAsHomeHook
    ];

    postConfigure = ''
      yarn config set enableTelemetry false
      yarn config set enableGlobalCache false
      yarn config set --json supportedArchitectures.os '[ "linux", "darwin" ]'
      yarn config set --json supportedArchitectures.cpu '["arm", "arm64", "ia32", "x64"]'
      yarn config set cacheFolder "$out"
    '';

    buildPhase = ''
      runHook preBuild

      yarn install --mode=skip-build

      runHook postBuild
    '';

    outputHashAlgo = "sha256";
    outputHashMode = "recursive";

    # TODO: figure out why the two are different
    outputHash =
      if stdenv.hostPlatform.isDarwin then
        "sha256-Dc2uK0HXUgKfvHKkeIHSjjCCP6hnk52oqYn6qd/aOYM="
      else
        "sha256-gkMc3wVKe22/2DI49JCsVKCOHfw77lphQZX6/3wOO/o=";
  };

  nativeBuildInputs =
    let
      # the build process runs `git rev-parse --abbrev-ref HEAD`
      fakeGit = writeShellScriptBin "git" ''
        echo "v${finalAttrs.version}"
      '';
    in
    [
      copyDesktopItems
      fakeGit
      makeWrapper
      yarn-berry
      writableTmpDirAsHomeHook
      zip
    ];

  postPatch = lib.optionalString stdenv.hostPlatform.isLinux ''
    # workaround for https://github.com/electron/electron/issues/31121
    substituteInPlace src/main/index.ts \
      --replace-fail "process.resourcesPath" "'$out/share/ytmdesktop/resources'"
  '';

  postConfigure = ''
    yarn config set enableTelemetry false
    yarn config set enableGlobalCache false
    export cachePath=$(mktemp -d)
    cp -r $yarnOfflineCache/* $cachePath
    yarn config set cacheFolder $cachePath
    yarn install --mode=skip-build
  '';

  buildPhase = ''
    runHook preBuild

    cp -r ${electron.dist} electron-dist
    chmod -R u+w electron-dist

    pushd electron-dist
    zip -0Xqr ../electron.zip .
    popd

    rm -r electron-dist

    # force @electron/packager to use our electron instead of downloading it
    substituteInPlace node_modules/@electron/packager/dist/packager.js \
        --replace-fail 'await this.getElectronZipPath(downloadOpts)' '"electron.zip"'

    yarn run package

    runHook postBuild
  '';

  installPhase =
    ''
      runHook preInstall
    ''
    + lib.optionalString stdenv.hostPlatform.isLinux ''

      mkdir -p "$out"/share/ytmdesktop
      cp -r out/*/{locales,resources{,.pak}} "$out"/share/ytmdesktop

      install -Dm644 src/assets/icons/ytmd.png "$out"/share/pixmaps/ytmdesktop.png

      makeWrapper ${lib.getExe electron} "$out"/bin/ytmdesktop \
        --add-flags "$out"/share/ytmdesktop/resources/app.asar \
        --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}" \
        --add-flags ${lib.escapeShellArg commandLineArgs}
    ''
    + lib.optionalString stdenv.hostPlatform.isDarwin ''
      mkdir -p $out/Applications
      cp -r out/*/"YouTube Music Desktop App".app "$out"/Applications

      wrapProgram "$out"/Applications/"YouTube Music Desktop App".app/Contents/MacOS/youtube-music-desktop-app \
        --add-flags ${lib.escapeShellArg commandLineArgs}

      makeWrapper "$out"/Applications/"YouTube Music Desktop App".app/Contents/MacOS/youtube-music-desktop-app "$out"/bin/ytmdesktop
    ''
    + ''
      runHook postInstall
    '';

  meta = {
    changelog = "https://github.com/ytmdesktop/ytmdesktop/tag/v${finalAttrs.version}";
    description = "A Desktop App for YouTube Music";
    downloadPage = "https://github.com/ytmdesktop/ytmdesktop/releases";
    homepage = "https://ytmdesktop.app/";
    license = lib.licenses.gpl3Only;
    mainProgram = "ytmdesktop";
    maintainers = [ lib.maintainers.cjshearer ];
    inherit (electron.meta) platforms;
  };
})
