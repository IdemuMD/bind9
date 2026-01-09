# BIND9 DNS Server Setup

This repository contains the configuration and setup script for a BIND9 DNS server in the ikt-fag.no domain.

## Overview

- **DNS Server**: ns2.ikt-fag.no
- **Server IP**: 10.12.2.10
- **Zone**: ikt-fag.no
- **Web Server**: guide.ikt-fag.no -> 10.12.2.106

## Quick Start

### Run the Setup Script

```bash
# Upload to VM and run
chmod +x setup.sh
sudo ./setup.sh
```

### Manual Setup

```bash
# Install BIND9
sudo apt-get update
sudo apt-get install -y bind9 bind9utils dnsutils

# Copy configuration files
sudo cp named.conf.options /etc/bind/
sudo cp named.conf.local /etc/bind/
sudo cp zones/ikt-fag.no.db /var/lib/bind/
sudo cp zones/2.12.10.in-addr.arpa.db /var/lib/bind/

# Set permissions
sudo chown -R bind:bind /var/lib/bind/

# Test configuration
sudo named-checkconf
sudo named-checkzone ikt-fag.no /var/lib/bind/ikt-fag.no.db

# Start service
sudo systemctl enable bind9
sudo systemctl start bind9
```

## Configuration Files

### named.conf.options
BIND9 main options file - configures listening interfaces, allow-query, and forwarders.

### named.conf.local
Zone definitions for:
- Forward zone: ikt-fag.no
- Reverse zone: 2.12.10.in-addr.arpa (for 10.12.2.0/24)

### Zone Files

#### ikt-fag.no.db (Forward Zone)
Contains A and CNAME records:
- guide.ikt-fag.no -> 10.12.2.106
- www.ikt-fag.no -> guide.ikt-fag.no (CNAME)

#### 2.12.10.in-addr.arpa.db (Reverse Zone)
Contains PTR records for reverse DNS lookups.

## Testing

### Test from DNS Server
```bash
# Test forward lookup
dig @10.12.2.10 guide.ikt-fag.no

# Test reverse lookup
dig @10.12.2.10 -x 10.12.2.106

# Test CNAME
dig @10.12.2.10 www.ikt-fag.no
```

### Test from Another Machine
```bash
dig @10.12.2.10 guide.ikt-fag.no
```

## Managing DNS Records

### Adding a New A Record

Edit `/var/lib/bind/ikt-fag.no.db`:

```
newsubdomain    IN      A       10.12.2.107
```

Then restart BIND9:
```bash
sudo systemctl restart bind9
```

### Adding a New CNAME Record

Edit `/var/lib/bind/ikt-fag.no.db`:

```
alias   IN      CNAME   guide.ikt-fag.no.
```

Then restart BIND9:
```bash
sudo systemctl restart bind9
```

## Useful Commands

```bash
# Check BIND9 status
sudo systemctl status bind9

# View logs
sudo journalctl -u bind9 -f

# Test configuration
sudo named-checkconf
sudo named-checkzone ikt-fag.no /var/lib/bind/ikt-fag.no.db

# Query DNS records
dig guide.ikt-fag.no @10.12.2.10
nslookup guide.ikt-fag.no 10.12.2.10

# Check which ports BIND9 is listening on
sudo netstat -tulpn | grep named
```

## Post-Setup Tasks

1. **Add Forwarders**: Edit `/etc/bind/named.conf.options` and add school DNS servers in the forwarders section
2. **Coordinate with School IT**: Ensure the primary DNS server knows about ns2.ikt-fag.no
3. **Firewall**: Ensure UDP/TCP port 53 is open for DNS queries
4. **Serial Number**: Increment the serial number in zone files when making changes

## Troubleshooting

### BIND9 won't start
```bash
# Check configuration syntax
sudo named-checkconf

# Check logs
sudo journalctl -u bind9 -e
```

### DNS queries timeout
```bash
# Check if BIND9 is listening
sudo netstat -tulpn | grep :53

# Check firewall
sudo ufw status
```

### Zone transfer failed
```bash
# Check zone file syntax
sudo named-checkzone ikt-fag.no /var/lib/bind/ikt-fag.no.db

# Check file permissions
ls -la /var/lib/bind/
```

## File Structure

```
bind9/
├── README.md
├── setup.sh              # Automated setup script
├── named.conf.options    # BIND9 options
├── named.conf.local      # Zone definitions
└── zones/
    ├── ikt-fag.no.db     # Forward zone file
    └── 2.12.10.in-addr.arpa.db  # Reverse zone file
```

## Author

Created for ikt-fag.no DNS infrastructure.

