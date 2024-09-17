{
    inputs.nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/*.tar.gz";
    inputs.determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/0.1.95.tar.gz";
    inputs.fh.url = "https://flakehub.com/f/DeterminateSystems/determinate/0.1.16.tar.gz";

    outputs = { self, nixpkgs, determinate, fh, ... }: {
        nixosConfigurations.ethercalc-demo = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
                "${nixpkgs}/nixos/maintainers/scripts/ec2/amazon-image.nix"
                determinate.nixosModules.default
                ({ pkgs, ... }: {
                    environment.systemPackages = [
                        fh.packages."${pkgs.stdenv.system}".default
                    ];
                })
                ({ pkgs, ... }: {
                    networking.firewall.allowedTCPPorts = [ 8080 ];
                    services.ethercalc = {
                        enable = true;
                        port = 8080;
                    };
                })
            ];
        };
    };
}