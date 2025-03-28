{
  callPackage,
  makeSetupHook,
  stdenv,
}:

makeSetupHook {
  name = "garage-test-hook";
  passthru.tests = {
    simple = callPackage ./test.nix { };
  };
} ./garage-test-hook.sh
