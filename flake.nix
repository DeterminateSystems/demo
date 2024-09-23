{
    inputs.nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/*.tar.gz";
    inputs.determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/0.1.95.tar.gz";
    inputs.fh.url = "https://flakehub.com/f/DeterminateSystems/fh/0.1.16.tar.gz";

    outputs = { self, nixpkgs, determinate, fh, ... }: let
          supportedSystems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];

            forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: (forSystem system f));

            forSystem = system: f: f rec {
                inherit system;
                pkgs = nixpkgs.legacyPackages.${system};
                lib = pkgs.lib;
            };


        in {
        nixosConfigurations.ethercalc-demo = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
                "${nixpkgs}/nixos/maintainers/scripts/ec2/amazon-image.nix"
                determinate.nixosModules.default
                ({ pkgs, ... }: {
                    environment.systemPackages = [
                        fh.packages."${pkgs.stdenv.system}".default
                    ];

                    services.amazon-ssm-agent.enable = true;
                    systemd.services.amazon-ssm-agent.path = [
                        "/run/wrappers"
                        "/run/current-system/sw"
                     ];
                })
                ({ pkgs, ... }: {
                    networking.firewall.allowedTCPPorts = [ 80 ];
                    systemd.services.ethercalc.serviceConfig.AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
                    services.ethercalc = {
                        enable = false;
                        port = 80;
                    };
                    services.webhook = {
                      enabled = true;
                      port = 80;
                      hooks = {
                        echo = {
                          execute-command = "echo";
                          response-message = "Webhook is reachable!";
                        };
                      };
                    };
                })
            ];
        };

        devShells = forAllSystems ({ system, pkgs, ... }:
        {
          default = pkgs.mkShell {
            name = "demo-shell";
            buildInputs = with pkgs; [
              opentofu
              awscli2
            ];
          };
        });
    };
}
