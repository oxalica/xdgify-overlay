{ pkgs ? import <nixpkgs> {} }:
with pkgs;
runCommandCC "preload_redirect" {} ''
  cp ${./lib.c} lib.c
  chmod +w lib.c
  substituteInPlace lib.c \
    --replace '@libc@' '${glibc}/lib/libc.so.6'
  mkdir -p $out/lib
  $CC lib.c -o $out/lib/libpreload_redirect.so \
    -O2 -ldl -shared -fPIC -Wl,-soname=libpreload_redirect.so
  $STRIP $out/lib/libpreload_redirect.so
''

