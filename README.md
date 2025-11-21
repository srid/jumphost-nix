# jumphost-nix

Nix home-manager module for using [jump hosts](https://en.wikipedia.org/wiki/Jump_server), especially at workplaces with location-restricted services.

## Features

- **SSH Jump Host**: `git clone` repositories that are only accessible from the jump host (e.g., company Bitbucket/GitLab behind firewall)
- **SOCKS5 Proxy**: Access internal company websites/services through your browser without VPN (automatic background SSH tunnel)
- **Git Identity**: Automatically use your work email for commits in work repositories

## Usage

Real-world example => https://github.com/srid/nixos-config/blob/master/modules/home/work/juspay.nix

```nix
{
  imports = [ ./path/to/jumphost-nix/module.nix ];

  programs.jumphost = {
    enable = true;
    host = "office-machine.tail12345.ts.net";
    
    # Configure SSH hosts to use jump host
    sshHosts = {
      "git.company.com" = {
        user = "git";
        identityFile = "~/.ssh/work_key";  # optional
      };
    };

    # Optional: Configure git for work directory
    git = {
      baseCodeDir = "~/work";
      email = "you@company.com";
    };

    # SOCKS5 proxy (enabled by default)
    socks5Proxy = {
      enable = true;
      port = 1080;  # default
    };
  };
}
```

## Use Cases

- Work from home without company VPN
- Access location-restricted internal services (Jira, Confluence, internal dashboards)
- Clone and push to self-hosted git repositories behind corporate firewall
- Keep work and personal git identities separate automatically

## Using the SOCKS5 Proxy

Once configured, the SOCKS5 proxy runs automatically in the background on the specified port (default: 1080).

### Browser Configuration with ZeroOmega

To route browser traffic through the proxy, use [ZeroOmega](https://github.com/zero-peak/ZeroOmega) (a Chrome/Edge extension):

1. Install ZeroOmega from the Chrome Web Store
2. Create a new proxy profile:
   - Protocol: `SOCKS5`
   - Server: `127.0.0.1`
   - Port: `1080` (or your configured port)
3. Set up rules to automatically proxy specific domains (e.g., `*.company.com`)

This allows you to access internal company websites without a VPN.
