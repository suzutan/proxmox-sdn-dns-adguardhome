#!/bin/bash
set -e

PLUGIN_DIR="/usr/share/perl5/PVE/Network/SDN/Dns"
DNS_PM="/usr/share/perl5/PVE/Network/SDN/Dns.pm"
API_DNS_PM="/usr/share/perl5/PVE/API2/Network/SDN/Dns.pm"

echo "Uninstalling AdGuard Home SDN DNS Plugin..."

# Remove use and register statements from Dns.pm
sed -i '/use PVE::Network::SDN::Dns::AdguardPlugin;/d' "$DNS_PM"
sed -i '/PVE::Network::SDN::Dns::AdguardPlugin->register();/d' "$DNS_PM"
echo "✓ Removed from Dns.pm"

# Remove use statement from API Dns.pm
sed -i '/use PVE::Network::SDN::Dns::AdguardPlugin;/d' "$API_DNS_PM"
echo "✓ Removed from API Dns.pm"

# Remove plugin file
rm -f "$PLUGIN_DIR/AdguardPlugin.pm"
echo "✓ Plugin file removed"

# Restart services
echo "Restarting Proxmox services..."
systemctl restart pvedaemon pveproxy
echo "✓ Services restarted"

echo ""
echo "Uninstallation complete!"
echo ""
echo "Note: Make sure to remove any AdGuard DNS configurations from SDN before uninstalling."
echo "      Run this script on ALL cluster nodes."
