#!/bin/bash
set -e

PLUGIN_DIR="/usr/share/perl5/PVE/Network/SDN/Dns"
DNS_PM="/usr/share/perl5/PVE/Network/SDN/Dns.pm"
API_DNS_PM="/usr/share/perl5/PVE/API2/Network/SDN/Dns.pm"

echo "Installing AdGuard Home SDN DNS Plugin for Proxmox VE..."

# Copy plugin file
cp AdguardPlugin.pm "$PLUGIN_DIR/"
echo "✓ Plugin file installed"

# Check if already registered in Dns.pm
if grep -q "AdguardPlugin" "$DNS_PM"; then
    echo "✓ Already registered in Dns.pm"
else
    # Add use statement after PowerdnsPlugin
    sed -i '/use PVE::Network::SDN::Dns::PowerdnsPlugin;/a use PVE::Network::SDN::Dns::AdguardPlugin;' "$DNS_PM"
    # Add register statement after PowerdnsPlugin register
    sed -i '/PVE::Network::SDN::Dns::PowerdnsPlugin->register();/a PVE::Network::SDN::Dns::AdguardPlugin->register();' "$DNS_PM"
    echo "✓ Registered in Dns.pm"
fi

# Check if already registered in API Dns.pm
if grep -q "AdguardPlugin" "$API_DNS_PM"; then
    echo "✓ Already registered in API Dns.pm"
else
    # Add use statement after PowerdnsPlugin
    sed -i '/use PVE::Network::SDN::Dns::PowerdnsPlugin;/a use PVE::Network::SDN::Dns::AdguardPlugin;' "$API_DNS_PM"
    echo "✓ Registered in API Dns.pm"
fi

# Verify syntax
echo "Verifying plugin syntax..."
perl -c "$PLUGIN_DIR/AdguardPlugin.pm"
perl -c "$DNS_PM"
perl -c "$API_DNS_PM"
echo "✓ Syntax OK"

# Restart services
echo "Restarting Proxmox services..."
systemctl restart pvedaemon pveproxy
echo "✓ Services restarted"

echo ""
echo "Installation complete!"
echo ""
echo "Next steps:"
echo "  1. Go to Datacenter → SDN → DNS → Add"
echo "  2. Select type: adguard"
echo "  3. Configure URL, API User, and API Pass"
echo ""
echo "Note: Run this script on ALL cluster nodes."
