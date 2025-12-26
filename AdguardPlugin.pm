package PVE::Network::SDN::Dns::AdguardPlugin;

use strict;
use warnings;

use JSON;
use Net::IP;
use MIME::Base64;

use PVE::Cluster;
use PVE::Tools;

use base('PVE::Network::SDN::Dns::Plugin');

sub type {
    return 'adguard';
}

sub properties {
    return {
        # Note: 'url' is already defined in PowerdnsPlugin and shared
        # AdGuard-specific properties with unique names
        apiuser => {
            type => 'string',
            description => 'AdGuard Home username',
        },
        apipass => {
            type => 'string',
            description => 'AdGuard Home password',
        },
    };
}

sub options {
    return {
        url => { optional => 0 },
        apiuser => { optional => 0 },
        apipass => { optional => 0 },
        ttl => { optional => 1 },  # ignored, AdGuard doesn't support TTL for rewrites
        fingerprint => { optional => 1 },
    };
}

my sub adguard_api_request {
    my ($config, $method, $path, $params) = @_;

    my $auth = encode_base64("$config->{apiuser}:$config->{apipass}", '');

    return PVE::Network::SDN::api_request(
        $method,
        "$config->{url}${path}",
        ['Content-Type' => 'application/json', 'Authorization' => "Basic $auth"],
        $params,
        $config->{fingerprint},
    );
}

# Plugin implementation

sub add_a_record {
    my ($class, $plugin_config, $zone, $hostname, $ip, $noerr) = @_;

    my $fqdn = $hostname . "." . $zone;

    # Check if record already exists
    my $existing = get_rewrite($plugin_config, $fqdn, $ip);
    return if $existing;  # already exists

    my $params = {
        domain => $fqdn,
        answer => $ip,
    };

    eval { adguard_api_request($plugin_config, 'POST', '/control/rewrite/add', $params) };
    die "error add $fqdn: $@" if $@ && !$noerr;
}

sub add_ptr_record {
    my ($class, $plugin_config, $zone, $hostname, $ip, $noerr) = @_;

    # AdGuard Home doesn't support PTR records via rewrite
    # Create a reverse lookup entry as workaround

    my $reverseip = Net::IP->new($ip)->reverse_ip();
    $reverseip =~ s/\.$//;  # remove trailing dot

    my $fqdn = $hostname . "." . $zone;

    my $params = {
        domain => $reverseip,
        answer => $fqdn,
    };

    eval { adguard_api_request($plugin_config, 'POST', '/control/rewrite/add', $params) };
    die "error add PTR $reverseip: $@" if $@ && !$noerr;
}

sub del_a_record {
    my ($class, $plugin_config, $zone, $hostname, $ip, $noerr) = @_;

    my $fqdn = $hostname . "." . $zone;

    my $params = {
        domain => $fqdn,
        answer => $ip,
    };

    eval { adguard_api_request($plugin_config, 'POST', '/control/rewrite/delete', $params) };
    die "error delete $fqdn: $@" if $@ && !$noerr;
}

sub del_ptr_record {
    my ($class, $plugin_config, $zone, $ip, $noerr) = @_;

    my $reverseip = Net::IP->new($ip)->reverse_ip();
    $reverseip =~ s/\.$//;  # remove trailing dot

    # Get hostname from existing rewrite to delete
    my $rewrites = get_all_rewrites($plugin_config);
    for my $rewrite (@$rewrites) {
        if ($rewrite->{domain} eq $reverseip) {
            my $params = {
                domain => $reverseip,
                answer => $rewrite->{answer},
            };
            eval { adguard_api_request($plugin_config, 'POST', '/control/rewrite/delete', $params) };
            die "error delete PTR $reverseip: $@" if $@ && !$noerr;
            last;
        }
    }
}

sub verify_zone {
    my ($class, $plugin_config, $zone, $noerr) = @_;

    # AdGuard doesn't have zones, just verify API is accessible
    eval { adguard_api_request($plugin_config, 'GET', '/control/rewrite/list', undef) };
    die "can't connect to AdGuard Home: $@" if $@ && !$noerr;
}

sub get_reversedns_zone {
    my ($class, $plugin_config, $subnetid, $subnet, $ip) = @_;

    # AdGuard doesn't use zones, but we need to return something
    # for compatibility
    my $cidr = $subnet->{cidr};
    my $mask = $subnet->{mask};

    if (Net::IP::ip_is_ipv4($ip)) {
        my ($ipblock1, $ipblock2, $ipblock3) = split(/\./, $ip);
        if ($mask >= 24) {
            return "$ipblock3.$ipblock2.$ipblock1.in-addr.arpa";
        } elsif ($mask >= 16) {
            return "$ipblock2.$ipblock1.in-addr.arpa";
        } else {
            return "$ipblock1.in-addr.arpa";
        }
    } else {
        my $networkv6 = NetAddr::IP->new($cidr)->network();
        return Net::IP->new($networkv6)->reverse_ip();
    }
}

sub on_update_hook {
    my ($class, $plugin_config) = @_;

    # verify that API is working
    eval { adguard_api_request($plugin_config, 'GET', '/control/status', undef) };
    die "AdGuard Home API error: $@" if $@;
}

# Helper functions

sub get_all_rewrites {
    my ($plugin_config) = @_;

    my $result = eval { adguard_api_request($plugin_config, 'GET', '/control/rewrite/list', undef) };
    return [] if $@;
    return $result // [];
}

sub get_rewrite {
    my ($plugin_config, $domain, $answer) = @_;

    my $rewrites = get_all_rewrites($plugin_config);
    for my $rewrite (@$rewrites) {
        if ($rewrite->{domain} eq $domain && $rewrite->{answer} eq $answer) {
            return $rewrite;
        }
    }
    return;  # not found
}

1;
