{
  description = "tofu-modules — repo toolchain (OpenTofu, pre-commit, tflint)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in
    {
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = with pkgs; [
          opentofu
          pre-commit
          tflint
          nodejs # the markdownlint hook uses it instead of downloading a non-NixOS build
        ];
        # The restapi provider marks its attributes sensitive only with this set; modules/gitea
        # refuses to run without it (its tests too).
        API_DATA_IS_SENSITIVE = "true";
      };
    };
}
