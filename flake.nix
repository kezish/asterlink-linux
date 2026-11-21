{
  description = "Trackable Linux/NixOS port of AsterLink (upstream source preserved)";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      runtimeLibs = with pkgs; [
        gtk3 webkitgtk_4_1 libsecret libappindicator-gtk3
        mpv libGL libepoxy glib pango cairo gdk-pixbuf
      ];
    in {
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = with pkgs; [
          flutter go cmake ninja pkg-config
          clang gcc python3 git
        ];
        buildInputs = runtimeLibs;
        shellHook = ''
          export GOTOOLCHAIN=local
          echo "AsterLink Linux dev shell ready: Flutter / Go / GTK / QuickJS"
        '';
      };
    };
}
