# Proxmox VE SDN DNS Plugin for AdGuard Home

Proxmox VE SDN (Software Defined Network) DNS plugin that integrates with AdGuard Home's DNS Rewrite feature for automatic DNS record management.

## Overview

This plugin allows Proxmox VE to automatically create and delete DNS records in AdGuard Home when VMs are created or removed in SDN-managed networks. It uses AdGuard Home's DNS Rewrite API as the backend.

## Features

- Automatic A/AAAA record creation when VMs start
- Automatic record deletion when VMs are removed
- PTR record support (via DNS Rewrite)
- Seamless integration with Proxmox VE SDN

## Requirements

- Proxmox VE 8.x or later
- AdGuard Home with API access enabled
- Network configured with Proxmox SDN

## Installation

### 1. Download the plugin

```bash
curl -o /usr/share/perl5/PVE/Network/SDN/Dns/AdguardPlugin.pm \
  https://raw.githubusercontent.com/YOUR_USERNAME/proxmox-sdn-adguard/main/AdguardPlugin.pm
```

### 2. Register the plugin

Edit `/usr/share/perl5/PVE/Network/SDN/Dns.pm` and add:

```perl
use PVE::Network::SDN::Dns::AdguardPlugin;
```

After the other `use` statements, and add:

```perl
PVE::Network::SDN::Dns::AdguardPlugin->register();
```

After the other `register()` calls.

### 3. Register with API

Edit `/usr/share/perl5/PVE/API2/Network/SDN/Dns.pm` and add:

```perl
use PVE::Network::SDN::Dns::AdguardPlugin;
```

### 4. Restart services

```bash
systemctl restart pvedaemon pveproxy
```

### 5. Repeat on all cluster nodes

The plugin must be installed on all Proxmox VE nodes in the cluster.

## Configuration

### Add AdGuard Home DNS

```bash
pvesh create /cluster/sdn/dns \
  --dns adguard \
  --type adguard \
  --url http://192.168.1.1:3000 \
  --apiuser admin \
  --apipass yourpassword
```

### Configure SDN to use AdGuard

```bash
pvesh set /cluster/sdn --dns adguard
```

## Configuration Options

| Option        | Required | Description                                        |
| ------------- | -------- | -------------------------------------------------- |
| `url`         | Yes      | AdGuard Home URL (e.g., `http://192.168.1.1:3000`) |
| `apiuser`     | Yes      | AdGuard Home username                              |
| `apipass`     | Yes      | AdGuard Home password                              |
| `ttl`         | No       | Ignored (AdGuard Rewrite doesn't support TTL)      |
| `fingerprint` | No       | TLS certificate fingerprint for HTTPS              |

## How It Works

```plain
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Proxmox VE    │     │  AdGuard Home   │     │     Clients     │
│                 │     │                 │     │                 │
│  VM Created     │────▶│  DNS Rewrite    │◀────│  DNS Query      │
│  in SDN         │ API │  Added          │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

1. VM is created in an SDN-managed network
2. Proxmox SDN calls the AdGuard plugin
3. Plugin adds a DNS Rewrite entry via AdGuard Home API
4. Clients can resolve the VM hostname

## Limitations

- **No TTL support**: AdGuard Home's DNS Rewrite doesn't support TTL values
- **No zone concept**: AdGuard Home doesn't have DNS zones; the plugin creates flat rewrite entries
- **PTR records**: Implemented via DNS Rewrite (may not work with all reverse DNS queries)

## Troubleshooting

### Plugin not appearing in GUI

1. Verify file permissions:

   ```bash
   ls -la /usr/share/perl5/PVE/Network/SDN/Dns/AdguardPlugin.pm
   ```

2. Check for syntax errors:

   ```bash
   perl -c /usr/share/perl5/PVE/Network/SDN/Dns/AdguardPlugin.pm
   perl -c /usr/share/perl5/PVE/API2/Network/SDN/Dns.pm
   ```

3. Restart services:

   ```bash
   systemctl restart pvedaemon pveproxy
   ```

### API connection errors

1. Test AdGuard Home API:

   ```bash
   curl -u user:pass http://adguard:3000/control/status
   ```

2. Verify network connectivity from Proxmox node to AdGuard Home

### Records not being created

1. Check SDN DNS configuration:

   ```bash
   pvesh get /cluster/sdn/dns
   ```

2. Verify SDN is using the AdGuard DNS:

   ```bash
   cat /etc/pve/sdn.cfg
   ```

## Uninstallation

1. Remove AdGuard DNS from SDN configuration

2. Delete the DNS entry:

   ```bash
   pvesh delete /cluster/sdn/dns/adguard
   ```

3. Remove plugin file:

   ```bash
   rm /usr/share/perl5/PVE/Network/SDN/Dns/AdguardPlugin.pm
   ```

4. Remove `use` and `register()` lines from Dns.pm files
5. Restart services

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## License

MIT License

## Acknowledgments

- Based on the PowerDNS plugin from Proxmox VE
- Inspired by the need to simplify homelab DNS management
