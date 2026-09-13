{ pkgs ? import <nixpkgs> { }, lib, ... }: pkgs.stdenv.mkDerivation rec {
  pname = "hyprquickframe";
  version = "0.2.0";

  nativeBuildInputs = with pkgs; [
    cmake
    pkg-config
    makeWrapper
  ];

  buildInputs = with pkgs; [
    qt6.qtbase
    qt6.qtdeclarative
    kdePackages.layer-shell-qt
    grim
    imagemagick
    wl-clipboard
  ];

  src = pkgs.lib.cleanSource ./.;

  installPhase = ''
    mkdir -p $out/bin $out/share/hyprquickframe
    cp hyprquickframe $out/bin/
    cp src/detect_boxes.py $out/share/hyprquickframe/

    wrapProgram $out/bin/hyprquickframe \
      --set PATH "$PATH:${lib.makeBinPath [
        pkgs.grim
        pkgs.imagemagick
        pkgs.wl-clipboard
        pkgs.tesseract
        (pkgs.python3.withPackages (ps: with ps; [ opencv4 numpy ]))
      ]}"
  '';
}
