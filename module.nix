# Generic work configuration module for SSH jump host and SOCKS5 proxy
{ pkgs, config, lib, ... }:
let
  cfg = config.programs.jumphost;
in
{
  options.programs.jumphost = {
    enable = lib.mkEnableOption "work jump host configuration";

    host = lib.mkOption {
      type = lib.types.str;
      description = ''
        Jump host used to access work services without VPN.
        Used as SSH proxy jump and as SOCKS5 tunnel endpoint.
      '';
    };

    sshHosts = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          user = lib.mkOption {
            type = lib.types.str;
            default = "git";
            description = "SSH user for this host";
          };

          identityFile = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Optional SSH identity file";
          };
        };
      });
      default = { };
      description = ''
        SSH hosts to configure with jump host proxy.
        Keys are hostnames, values are SSH configuration options.
      '';
      example = lib.literalExpression ''
        {
          "ssh.bitbucket.example.com" = {
            user = "git";
            identityFile = "~/.ssh/work.pub";
          };
          "gitlab.example.com" = { };
        }
      '';
    };

    git = {
      baseCodeDir = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Optional base directory containing work code repositories.
          If set, git commits in subdirectories will use the configured email.
        '';
      };

      email = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Optional email address to use for git commits within baseCodeDir.
          Only used if baseCodeDir is set.
        '';
      };
    };

    socks5Proxy = {
      enable = lib.mkEnableOption "SOCKS5 proxy via SSH tunnel" // {
        default = true;
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 1080;
        description = ''
          Local port to bind the SOCKS5 proxy server (tunneled through jump host)
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    programs.ssh = {
      enable = true;
      matchBlocks =
        (lib.mapAttrs
          (hostname: hostCfg: {
            user = hostCfg.user;
            proxyJump = cfg.host;
            identityFile = lib.mkIf (hostCfg.identityFile != null) hostCfg.identityFile;
          })
          cfg.sshHosts)
        // {
          "${cfg.host}" = {
            forwardAgent = true;
          };
        };
    };

    programs.git = lib.mkIf (cfg.git.baseCodeDir != null && cfg.git.email != null) {
      includes = [
        {
          condition = "gitdir:${cfg.git.baseCodeDir}/**";
          contents = {
            user.email = cfg.git.email;
          };
        }
      ];
    };

    # SOCKS5 proxy via SSH tunnel to jump host (macOS)
    launchd.agents.jumphost-socks5-proxy = lib.mkIf (cfg.socks5Proxy.enable && pkgs.stdenv.isDarwin) {
      enable = true;
      config = {
        ProgramArguments = [
          "${pkgs.openssh}/bin/ssh"
          "-D" # Dynamic port forwarding (SOCKS proxy)
          (toString cfg.socks5Proxy.port)
          "-N" # Don't execute remote command
          # "-q" # Quiet mode (suppress warnings)
          "-C" # Enable compression
          cfg.host
        ];
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/jumphost-socks5-proxy.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/jumphost-socks5-proxy.err";
      };
    };

    # SOCKS5 proxy via SSH tunnel to jump host (Linux)
    systemd.user.services.jumphost-socks5-proxy = lib.mkIf (cfg.socks5Proxy.enable && pkgs.stdenv.isLinux) {
      Unit = {
        Description = "SOCKS5 proxy via SSH tunnel to work jump host";
        After = [ "network.target" ];
      };

      Service = {
        ExecStart = "${pkgs.openssh}/bin/ssh -D ${toString cfg.socks5Proxy.port} -N -C ${cfg.host}";
        Restart = "always";
        RestartSec = "10s";
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
