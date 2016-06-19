#!/bin/bash

CONFIGFILE=bgp-konzentrator-setup.conf
[ -r ${CONFIGFILE} ] && . ${CONFIGFILE}

EXT=bgp

function myread {
	local prompt=$1
	local default=$2
	read -p "${prompt} (${default}): " v
	echo ${v:-${default}}
}


function show_sysctl_config {
	cat << _EOF > 20-ff-config.conf.${EXT}
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
net.ipv4.tcp_window_scaling = 1
net.netfilter.nf_conntrack_max=1337000
net.core.rmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 16384 16777216
net.ipv4.conf.default.rp_filter=2
net.ipv4.conf.all.rp_filter=2
_EOF
}

function show_bird_config {
	cat << _EOF > bird.conf.${EXT}
router id ${my_ffrl_exit_ipv4};
protocol direct announce {
        table master;
        import where net ~ [${my_ffrl_exit_ipv4}/32];
        interface "tun-ffrl-uplink";
};
protocol kernel {
        table master;
        device routes;
        import none;
        export filter {
                krt_prefsrc = ${my_ffrl_exit_ipv4};
                accept;
        };
        kernel table 42;
};
protocol device {
        scan time 15;
};
function is_default() {
        return (net ~ [0.0.0.0/0]);
};
template bgp uplink {
        local as ${my_as_number};
        import where is_default();
        export where proto = "announce";
};
protocol bgp ffrl_ber_a from uplink {
        source address ${BER_A_GRE_MY_IPV4}
        neighbor ${BER_A_GRE_BB_IPV4} as ${ffrl_as_number};
};
protocol bgp ffrl_ber_b from uplink {
        source address ${BER_B_GRE_MY_IPV4};
        neighbor ${BER_B_GRE_BB_IPV4} as ${ffrl_as_number};
};
protocol bgp ffrl_dus_a from uplink {
        source address ${DUS_A_GRE_MY_IPV4};
        neighbor ${DUS_A_GRE_BB_IPV4} as ${ffrl_as_number};
        preference 110;
};
protocol bgp ffrl_dus_b from uplink {
        source address ${DUS_B_GRE_MY_IPV4};
        neighbor ${DUS_B_GRE_BB_IPV4} as ${ffrl_as_number};
        preference 110;
};
_EOF
}

function show_interfaces {
	cat << _EOF >interfaces.${EXT}
# Konfiguration Backbone-Anbindung fuer eigene FFRL Exit-IP
auto eth1
iface eth1 inet static
	address 172.31.254.254
	netmask 255.255.255.0

auto tun-ffrl-uplink
iface tun-ffrl-uplink inet static
	address ${my_ffrl_exit_ipv4}
	netmask 255.255.255.255
	pre-up ip link add \$IFACE type dummy
	post-down ip link del \$IFACE

# Konfiguration Backbone-Anbindung Berlin A
auto  tun-ffrl-ber-a 
iface		tun-ffrl-ber-a inet tunnel
	mode		gre
	netmask		255.255.255.254
	address		${BER_A_GRE_MY_IPV4}
	dstaddr		${BER_A_GRE_BB_IPV4}
	endpoint	185.66.195.0
	local		${my_public_ipv4}
	ttl		255
	mtu		1400
	post-up ip -6 addr add ${BER_A_GRE_MY_IPV6} dev \$IFACE

# Konfiguration Backbone-Anbindung Duesseldorf A
auto  tun-ffrl-dus-a 
iface	tun-ffrl-dus-a inet tunnel
	mode		gre
	netmask		255.255.255.254
	address		${DUS_A_GRE_MY_IPV4}
	dstaddr		${DUS_A_GRE_BB_IPV4}
	endpoint	185.66.193.0
	local		${my_public_ipv4}
	ttl		255
	mtu		1400
	post-up ip -6 addr add ${DUS_A_GRE_MY_IPV6} dev \$IFACE

# Konfiguration Backbone-Anbindung Berlin B
auto  tun-ffrl-ber-b 
iface	tun-ffrl-ber-b inet tunnel
	mode		gre
	netmask		255.255.255.254
	address		${BER_B_GRE_MY_IPV4}
	dstaddr		${BER_B_GRE_BB_IPV4}
	endpoint	185.66.195.1
	local		${my_public_ipv4}
	ttl		255
	mtu		1400
	post-up ip -6 addr add ${BER_B_GRE_MY_IPV6} dev \$IFACE

# Konfiguration Backbone-Anbindung Duesseldorf B
auto  tun-ffrl-dus-b
iface	tun-ffrl-dus-b inet tunnel
	mode		gre
	netmask		255.255.255.254
	address		${DUS_B_GRE_MY_IPV4}
	dstaddr		${DUS_B_GRE_BB_IPV4}
	endpoint	185.66.193.1
	local		${my_public_ipv4}
	ttl		255
	mtu		1400
	post-up ip -6 addr add ${DUS_B_GRE_MY_IPV6} dev \$IFACE
_EOF
}

function show_bird6_config {
	cat << _EOF >bird6.conf.${EXT}
log syslog { info };
debug protocols { states, routes, filters, interfaces, events, packets };
router id ${my_ffrl_exit_ipv4};
protocol direct {
        interface "-eth0", "*";  # Restrict network interfaces it works with
}
protocol kernel {
        device routes;
        import none;
        export all;             # Default is export none
        kernel table 42;        # Kernel table to synchronize with (default: main)
}
protocol device {
        scan time 10;           # Scan interfaces every 10 seconds
}
function is_default() {
        return (net ~ [::/0]);
}
filter hostroute {
	if net ~ [${my_ffrl_ipv6}{56,56}] then accept;
        reject;
}
template bgp uplink {
        local as ${my_as_number};
        import where is_default();
        export filter hostroute;
        gateway recursive;
}
protocol bgp ffrl_ber_a from uplink {
        description "Rheinland Backbone Berlin A";
        source address ${BER_A_GRE_MY_IPV6};
        neighbor ${BER_A_GRE_BB_IPV6} as ${ffrl_as_number};
}
protocol bgp ffrl_ber_b from uplink {
        description "Rheinland Backbone Berlin B";
        source address ${BER_B_GRE_MY_IPV6};
        neighbor ${BER_B_GRE_BB_IPV6} as ${ffrl_as_number};
}
protocol bgp ffrl_dus_a from uplink {
        description "Rheinland Backbone Duesseldorf A";
        source address ${DUS_A_GRE_MY_IPV6};
        neighbor ${DUS_A_GRE_BB_IPV6} as ${ffrl_as_number};
	preference 110;
}
protocol bgp ffrl_dus_b from uplink {
        description "Rheinland Backbone Duesseldorf B";
        source address ${DUS_B_GRE_MY_IPV6};
        neighbor ${DUS_B_GRE_BB_IPV6} as ${ffrl_as_number};
}
_EOF
}


function show_ferm_config {
	cat << _EOF > ferm.conf.${EXT}
domain (ip ip6) {
    table filter {
        chain INPUT {
            policy ACCEPT;
            proto gre ACCEPT;
            mod state state INVALID DROP;
            mod state state (ESTABLISHED RELATED) ACCEPT;
            interface lo ACCEPT;
            proto icmp ACCEPT;
            proto udp dport 500 ACCEPT;
            proto (esp) ACCEPT;
            proto tcp dport ssh ACCEPT;
            proto tcp dport ${my_ssh_port} ACCEPT;
        }
        chain OUTPUT {
            policy ACCEPT;
            mod state state (ESTABLISHED RELATED) ACCEPT;
        }
        chain FORWARD {
            policy ACCEPT;
            mod state state INVALID DROP;
            mod state state (ESTABLISHED RELATED) ACCEPT;
        }
    }
    table mangle {
        chain PREROUTING {
            interface tun-ffrl-+ {
                MARK set-mark 1;
            }
        }
        chain POSTROUTING {
            outerface tun-ffrl-+ proto tcp tcp-flags (SYN RST) SYN TCPMSS clamp-mss-to-pmtu;
        }
    }
    table nat {
        chain POSTROUTING {
            outerface tun-ffrl-+ saddr 172.16.0.0/12 SNAT to ${my_ffrl_exit_ipv4};
            policy ACCEPT;
        }
    }
}
_EOF
}



echo "========================================="
echo "Konfigurationshelfer für BGP-Konzentrator"
echo "========================================="

echo -e "\n=== Allgemeine Parameter:"

## @@FFRL_AS_NUMBER@@
echo -en "\t" 
ffrl_as_number=$(myread "AS Nummer vom FF-RL" "${FFRL_AS_NUMBER:-201701}")

## @@MY_AS_NUMBER@@
echo -en "\t" 
my_as_number=$(myread "Eigene AS Nummer" "${MY_AS_NUMBER}")

## @@MY_FFRL_EXIT_IPV4@@
echo -en "\t" 
my_ffrl_exit_ipv4=$(myread "Zugewiesene FFRL-IPV4-Exit-Adresse" "${MY_FFRL_EXIT_IPV4}")

echo -en "\t"
my_ffrl_ipv6=$(myread "Zugewiesenes FFRL-IPV6-Netz" "${MY_FFRL_IPV6_PREFIX}")

# @@MY_PUBLIC_IPV4@@
# TODO: Adresse automatisch ermitteln
echo -en "\t" 
my_public_ipv4=$(myread "Eigene öffentliche IPV4 Adresse" "${MY_PUBLIC_IPV4}")

echo -en "\t"
my_ssh_port=$(myread "Eigener SSH-Port" "${MY_SSH_PORT}")


TUNNELENDPOINTS="BER_A DUS_A BER_B DUS_B"

for bb_endpoint in ${TUNNELENDPOINTS}; do 
	echo -e "\n=== Konfiguration für GRE-Tunnel nach ${bb_endpoint}:"
	echo -en "\t" 

	unset value
	bar=${bb_endpoint}_GRE_BB_IPV4
	eval $bar=\$${bar}
	value=$(eval echo \$${bar})
	value=$(myread "IPV4 Adresse für Tunnelendpunkt auf Backbone-Server" "${value}")
	eval $bar=$value

	echo -en "\t" 
	unset value
	bar=${bb_endpoint}_GRE_MY_IPV4
	eval $bar=\$${bar}
	value=$(eval echo \$${bar})
	value=$(myread "IPV4 Adresse für Tunnelendpunk auf Konzentrator" "${value}") 
	eval $bar=$value

	echo -en "\t" 
	unset value
	bar=${bb_endpoint}_GRE_MY_IPV6
	eval $bar=\$${bar}
	value=$(eval echo \$${bar})
	value=$(myread "IPV6 Adresse auf Konzentrator" "${value}") 
	eval $bar=$value

done

echo -e "\n=== Ausgaben"
echo -e "\tKonfigurationen geschrieben nach:"
show_bird_config
echo -e "\t\tbird.conf.${EXT}"
show_bird6_config
echo -e "\t\tbird6.conf.${EXT}"
show_interfaces
echo -e "\t\tinterfaces.${EXT}"
show_ferm_config
echo -e "\t\tferm.conf.${EXT}"
show_sysctl_config
echo -e "\t\t20-ff-config.conf.${EXT}"

