#!/bin/bash

# BIND9 DNS Server Setup Script
# Secondary DNS server for ikt-fag.no zone
# This script configures ns2.ikt-fag.no

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  BIND9 DNS Server Setup${NC}"
echo -e "${BLUE}  ns2.ikt-fag.no${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Configuration Variables
DNS_SERVER_NAME="ns2.ikt-fag.no"
DNS_SERVER_IP="10.12.2.10"
ZONE_NAME="ikt-fag.no"
WEB_SERVER_IP="10.12.2.106"
WEBSITE_NAME="guide"
WEB_URL="${WEBSITE_NAME}.${ZONE_NAME}"
WWW_URL="www.${ZONE_NAME}"
PRIMARY_DNS_IP=""  # To be configured by user - school's DNS

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 1: Updating system...${NC}"
apt-get update && apt-get upgrade -y

echo -e "${YELLOW}Step 2: Installing BIND9...${NC}"
apt-get install -y bind9 bind9utils bind9-doc dnsutils

echo -e "${YELLOW}Step 3: Configuring BIND9 options...${NC}"
mkdir -p /var/cache/bind
mkdir -p /var/lib/bind
mkdir -p /etc/bind/zones

# Create named.conf.options
cat > /etc/bind/named.conf.options << EOF
options {
    directory "/var/cache/bind";
    dnssec-validation auto;
    auth-nxdomain no;    # conform to RFC1035
    listen-on { 127.0.0.1; ${DNS_SERVER_IP}; };
    listen-on-v6 { none; };
    allow-query { 127.0.0.1; 10.12.2.0/24; };
    allow-recursion { 127.0.0.1; 10.12.2.0/24; };
    forwarders {
        # Add school DNS servers here - REPLACE with actual IPs
        # 8.8.8.8;
        # 8.8.4.4;
    };
    version "not disclosed";
    hostname "";
    server-id "";
};
EOF

echo -e "${YELLOW}Step 4: Configuring local zones...${NC}"
# Create named.conf.local
cat > /etc/bind/named.conf.local << EOF
//
// Do any local configuration here
//

// Consider adding the 1918 zones here, if they are not used in your
// organization
// include "/etc/bind/zones.rfc1918";

# Zone: ${ZONE_NAME}
# This is a primary (master) zone for internal use
zone "${ZONE_NAME}" {
    type master;
    file "/var/lib/bind/${ZONE_NAME}.db";
    allow-transfer { none; };
    allow-update { none; };
};

# Reverse zone for 10.12.2.0/24
zone "2.12.10.in-addr.arpa" {
    type master;
    file "/var/lib/bind/2.12.10.in-addr.arpa.db";
    allow-transfer { none; };
    allow-update { none; };
};
EOF

echo -e "${YELLOW}Step 5: Creating forward zone file...${NC}"
# Create forward zone file
cat > /var/lib/bind/${ZONE_NAME}.db << EOF
;
; BIND9 Zone file for ${ZONE_NAME}
; Created by setup script
;
\$TTL 86400
@       IN      SOA     ${DNS_SERVER_NAME}. admin.${ZONE_NAME}. (
                        $(date +%Y%m%d)01  ; Serial
                        3600            ; Refresh (1 hour)
                        1800            ; Retry (30 minutes)
                        604800          ; Expire (1 week)
                        86400 )         ; Minimum TTL (1 day)

; Name servers
@       IN      NS      ${DNS_SERVER_NAME}.

; A records
@       IN      A       ${DNS_SERVER_IP}
${DNS_SERVER_NAME}.    IN      A       ${DNS_SERVER_IP}
${WEBSITE_NAME}.       IN      A       ${WEB_SERVER_IP}

; CNAME records
www     IN      CNAME   ${WEBSITE_NAME}.

; MX records (if needed)
; @       IN      MX      10      mail.${ZONE_NAME}.
; mail    IN      A       ${DNS_SERVER_IP}
EOF

echo -e "${YELLOW}Step 6: Creating reverse zone file...${NC}"
# Create reverse zone file
cat > /var/lib/bind/2.12.10.in-addr.arpa.db << EOF
;
; Reverse zone file for 10.12.2.0/24
;
\$TTL 86400
@       IN      SOA     ${DNS_SERVER_NAME}. admin.${ZONE_NAME}. (
                        $(date +%Y%m%d)01  ; Serial
                        3600            ; Refresh (1 hour)
                        1800            ; Retry (30 minutes)
                        604800          ; Expire (1 week)
                        86400 )         ; Minimum TTL (1 day)

; Name servers
@       IN      NS      ${DNS_SERVER_NAME}.

; PTR records
10      IN      PTR     ${DNS_SERVER_NAME}.
106     IN      PTR     ${WEBSITE_NAME}.${ZONE_NAME}.
EOF

echo -e "${YELLOW}Step 7: Setting permissions...${NC}"
chown -R bind:bind /var/lib/bind/
chown -R bind:bind /var/cache/bind/
chmod 640 /var/lib/bind/*.db

echo -e "${YELLOW}Step 8: Testing BIND9 configuration...${NC}"
named-checkconf
named-checkzone ${ZONE_NAME} /var/lib/bind/${ZONE_NAME}.db
named-checkzone 2.12.10.in-addr.arpa /var/lib/bind/2.12.10.in-addr.arpa.db

echo -e "${YELLOW}Step 9: Starting BIND9 service...${NC}"
systemctl enable bind9
systemctl start bind9
systemctl status bind9

echo -e "${YELLOW}Step 10: Configuring firewall...${NC}"
apt-get install -y ufw
ufw allow ssh
ufw allow 53/tcp
ufw allow 53/udp
echo "y" | ufw enable

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  BIND9 Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}DNS Server:${NC} ${DNS_SERVER_NAME} (${DNS_SERVER_IP})"
echo -e "${BLUE}Zone:${NC} ${ZONE_NAME}"
echo ""
echo -e "${YELLOW}DNS Records Configured:${NC}"
echo -e "  ${WEB_URL} -> ${WEB_SERVER_IP}"
echo -e "  ${WWW_URL} -> ${WEB_URL} (CNAME)"
echo -e "  ${DNS_SERVER_NAME} -> ${DNS_SERVER_IP}"
echo ""
echo -e "${YELLOW}Useful Commands:${NC}"
echo -e "  Check status:  systemctl status bind9"
echo -e "  View logs:     journalctl -u bind9 -f"
echo -e "  Test DNS:      dig @${DNS_SERVER_IP} ${WEB_URL}"
echo -e "  Restart:       systemctl restart bind9"
echo ""
echo -e "${RED}IMPORTANT - Post-Setup Configuration:${NC}"
echo -e "  1. Add forwarders to /etc/bind/named.conf.options"
echo -e "  2. Ask school IT for their DNS server IP and add it"
echo -e "  3. Test from another machine:"
echo -e "     dig @10.12.2.10 ${WEB_URL}"
echo -e "     dig @10.12.2.10 ${WWW_URL}"
echo ""

