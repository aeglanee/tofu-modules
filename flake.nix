{
  description = "tofu-modules — repo toolchain (OpenTofu, pre-commit)";

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
          nodejs # the markdownlint hook uses it instead of downloading a non-NixOS build
        ];
      };
    };
}
