{
  inputs.nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/*";
  inputs.determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
  inputs.fh.url = "https://flakehub.com/f/DeterminateSystems/fh/*";

  outputs =
    inputs:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      forAllSystems = f: inputs.nixpkgs.lib.genAttrs supportedSystems (system: (forSystem system f));

      forSystem =
        system: f:
        f rec {
          inherit system;
          pkgs = import inputs.nixpkgs {
            inherit system;
          };
          lib = pkgs.lib;
        };

      ethercalcModule = {
        systemd.services.ethercalc.serviceConfig.AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
        services.ethercalc = {
          enable = true;
          port = 80;
        };
      };

      giteaModule = {
        services.gitea = {
          enable = true;
          settings.server = {
            HTTP_ADDR = "0.0.0.0";
            HTTP_PORT = 8080;
          };
        };

        networking.firewall = {
          extraCommands = ''
            iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
            iptables -t nat -A OUTPUT -p tcp --dport 80 -j REDIRECT --to-port 8080
          '';
        };
      };

      nixos =
        modules:
        inputs.nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            "${inputs.nixpkgs}/nixos/maintainers/scripts/ec2/amazon-image.nix"
            inputs.determinate.nixosModules.default
            (
              { pkgs, ... }:
              {
                environment.systemPackages = [
                  inputs.fh.packages."${pkgs.stdenv.system}".default
                ];

                services.amazon-ssm-agent.enable = true;
                systemd.services.amazon-ssm-agent.path = [
                  "/run/wrappers"
                  "/run/current-system/sw"
                ];
              }
            )
            {
              networking.firewall.allowedTCPPorts = [
                80
                8080
              ];
            }
          ]
          ++ modules;
        };
    in
    {
      nixosConfigurations.base = nixos [ ];
      nixosConfigurations.ethercalc = nixos [ ethercalcModule ];
      nixosConfigurations.gitea = nixos [ giteaModule ];

      devShells = forAllSystems (
        { system, pkgs, ... }:
        {
          default = pkgs.mkShell {
            name = "demo-shell";
            buildInputs = with pkgs; [
              opentofu
              awscli2
              jq
            ];
          };
        }
      );
    };
}
