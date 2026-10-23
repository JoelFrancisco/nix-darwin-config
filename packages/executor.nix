{
  lib,
  stdenvNoCC,
  fetchurl,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "executor";
  version = "1.6.11";

  src = fetchurl {
    url = "https://registry.npmjs.org/executor/-/executor-${finalAttrs.version}-darwin-arm64.tgz";
    hash = "sha256-l4tsfzaI/2k2j2gg3QOzRnTCpDwA8OlO4L/H7kNXZkI=";
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
