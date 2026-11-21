{
  description = "Trackable Linux/NixOS port of AsterLink (upstream source preserved)";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      core = pkgs.mkShell {
        packages = with pkgs; [
          flutter341 go cmake ninja pkg-config clang gcc python3 git
        ];
        buildInputs = with pkgs; [ gtk3 libsecret libappindicator-gtk3 ];
        shellHook = ''
          export GOTOOLCHAIN=local
          echo "AsterLink Linux core shell: Flutter / Go / GTK / QuickJS"
        '';
      };
    in {
      devShells.x86_64-linux.default = core;
      devShells.x86_64-linux.full = pkgs.mkShell {
        inputsFrom = [ core ];
        buildInputs = with pkgs; [
          webkitgtk_4_1 mpv-unwrapped libass libGL libepoxy glib pango cairo gdk-pixbuf
          glib-networking gst_all_1.gstreamer gst_all_1.gst-plugins-base
        ];
        shellHook = ''
          export GOTOOLCHAIN=local
          # GIO discovers its TLS backend dynamically rather than via ELF linking.
          export GIO_EXTRA_MODULES="${pkgs.glib-networking}/lib/gio/modules''${GIO_EXTRA_MODULES:+:$GIO_EXTRA_MODULES}"
          export GST_PLUGIN_PATH_1_0="${pkgs.gst_all_1.gst-plugins-base}/lib/gstreamer-1.0''${GST_PLUGIN_PATH_1_0:+:$GST_PLUGIN_PATH_1_0}"
          echo "AsterLink Linux full shell: WebKitGTK / libmpv / GIO TLS"
        '';
      };
    };
}
