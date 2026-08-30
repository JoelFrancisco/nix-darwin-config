{
  lib,
  stdenvNoCC,
  fetchurl,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "executor";
  version = "1.6.7";

  src = fetchurl {
    url = "https://registry.npmjs.org/executor/-/executor-${finalAttrs.version}-darwin-arm64.tgz";
    hash = "sha256-pek71JyMKm8pmAiKLuief1sFwni/1xpHvqkARxD/vKs=";
  };

  sourceRoot = "package";
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/lib/executor"
    cp -R bin/. "$out/lib/executor/"
    ln -s ../lib/executor/executor "$out/bin/executor"

    runHook postInstall
  '';

  meta = {
    description = "Local AI executor with a CLI, local API server, and web UI";
    homepage = "https://github.com/UsefulSoftwareCo/executor";
    license = lib.licenses.mit;
    platforms = [ "aarch64-darwin" ];
    mainProgram = "executor";
  };
})
