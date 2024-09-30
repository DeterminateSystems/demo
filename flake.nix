{
  inputs.nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/*";
  inputs.determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/=0.1.95";
  inputs.fh.url = "https://flakehub.com/f/DeterminateSystems/fh/=0.1.16";

  outputs = inputs:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];

      forAllSystems = f: inputs.nixpkgs.lib.genAttrs supportedSystems (system: (forSystem system f));

      forSystem = system: f: f rec {
        inherit system;
        pkgs = import inputs.nixpkgs {
          inherit system;
        };
        lib = pkgs.lib;
      };
    in
    {
      nixosConfigurations.ethercalc-demo = inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          "${inputs.nixpkgs}/nixos/maintainers/scripts/ec2/amazon-image.nix"
          inputs.determinate.nixosModules.default
          ({ pkgs, ... }: {
            environment.systemPackages = [
              inputs.fh.packages."${pkgs.stdenv.system}".default
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
              enable = true;
              port = 80;
            };

            services.writefreely = {
              enable = false;
              host = "0.0.0.0";
              settings.server.bind = "0.0.0.0";
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
