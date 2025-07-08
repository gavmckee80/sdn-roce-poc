# SDN RoCE POC

Software-Defined Networking (SDN) with RDMA over Converged Ethernet (RoCE) Proof of Concept

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Virtual Lab Setup](#virtual-lab-setup)
- [FreeRADIUS Setup](#freeradius-setup)
- [Testing](#testing)
- [Database Management](#database-management)
- [Troubleshooting](#troubleshooting)
- [Reference](#reference)

## 🎯 Overview

This project demonstrates a complete SDN RoCE setup with FreeRADIUS authentication for network access control. The system includes:

- **FreeRADIUS Server** - Network authentication and authorization
- **PostgreSQL Database** - Backend storage for user and client data
- **Arista vEOS Switches** - Virtual network infrastructure
- **Docker Containerization** - Easy deployment and management
- **802.1X Authentication** - Network access control for SDN environments

## 🏗 Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Test Client   │    │   FreeRADIUS    │    │   PostgreSQL    │
│   (802.1X)      │◄──►│   Server        │◄──►│   Database      │
│                 │    │   (Docker)      │    │   (Docker)      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │
         ▼                       ▼
┌─────────────────┐    ┌─────────────────┐
│   Arista vEOS   │    │   Consul        │
│   Switch        │    │   Service Reg.  │
└─────────────────┘    └─────────────────┘
```

## 📋 Prerequisites

### Required Software
- **Docker & Docker Compose** (version 20.10+)
- **Libvirt/KVM** for virtual machine management
- **Arista vEOS-lab image** (vEOS64-lab-4.34.1F.qcow2)
- **Arista Aboot image** (Aboot-veos-serial-8.0.2.iso)

### Network Tools
```bash
# Install radtest utility
sudo apt-get install freeradius-utils  # Ubuntu/Debian
sudo yum install freeradius-utils      # CentOS/RHEL

# Install wpa_supplicant for 802.1X testing
sudo apt-get install wpasupplicant
```

## 🚀 Quick Start

### 1. Setup FreeRADIUS
```bash
cd freeradius
chmod +x setup.sh
./setup.sh
```

### 2. Test Authentication
```bash
radtest testuser testpass 127.0.0.1 0 testing123
```

### 3. Verify Database
```bash
docker exec -it radius-postgres psql -U radius -d radius -c "\dt"
```

## 🖥️ Virtual Lab Setup

### Network Bridge Configuration

Create a Linux bridge for 802.1X testing:

```xml
<!-- /etc/libvirt/qemu/networks/8021x.xml -->
<network>
  <name>8021x</name>
  <forward mode='bridge'/>
  <bridge name='8021x-br1'/>
</network>
```

Enable EAPOL and LLDP forwarding:
```bash
echo 24 > /sys/class/net/8021x-br1/bridge/group_fwd_mask
```

### Virtual Ethernet Interfaces

Create veth pairs for lab connectivity:
```bash
sudo bash -c '
for i in {1..10}; do
    ip link add veth-eth$i type veth peer name veth-br$i
    ip link set veth-eth$i up
    ip link set veth-br$i up
done'
```

**Important**: Disable checksum offload for proper operation:
```bash
ethtool -K veth-eth1 tx-checksumming off
```

### Arista vEOS Switch Deployment

```bash
virt-install \
  --name vEOS-lab-sw1 \
  --os-type linux --os-variant generic \
  --memory 8912 \
  --vcpus 8 \
  --cpu host-model \
  --disk path=/var/lib/libvirt/images/vEOS64-lab-4.34.1F.qcow2,bus=virtio,cache=directsync \
  --disk device=cdrom,path=/var/lib/libvirt/images/Aboot-veos-serial-8.0.2.iso,readonly=on \
  --controller type=scsi,model=virtio-scsi \
  --boot cdrom,hd,menu=on \
  --network type=direct,target=eth1,source=veth-eth1,model=virtio,mac=c0:cc:ff:00:00:14 \
  --network network=8021x,target=eth2,model=virtio,mac=c0:cc:ff:ee:ff:00 \
  --graphics none \
  --console pty,target_type=serial
```

### Test VM Deployment

```bash
virt-install \
  --name vlab-8021x-vm1 \
  --ram 8192 \
  --vcpus 8 \
  --os-type linux \
  --os-variant ubuntu24.04 \
  --disk path=/var/lib/libvirt/images/vlab-8021x-vm1.qcow2,format=qcow2,bus=virtio \
  --disk path=/var/lib/libvirt/images/seed.iso,device=cdrom \
  --network type=direct,target=eth3,source=veth-eth3,model=virtio,mac=c0:cc:ff:00:00:15 \
  --network network=8021x,target=eth4,model=virtio,mac=c0:cc:ff:ee:ff:01 \
  --graphics none \
  --console pty,target_type=serial \
  --import
```

## 🔐 FreeRADIUS Setup

### Automated Setup Process

The `setup.sh` script performs these steps:

1. **Directory Structure** - Creates required folders
2. **Configuration Downloads** - Downloads FreeRADIUS 3.2.7 files
3. **Docker Compose** - Generates container configuration
4. **Database Schema** - Sets up PostgreSQL tables
5. **Service Deployment** - Starts containers
6. **Initial Data** - Adds test users and clients

### Container Services

#### PostgreSQL Database
- **Image**: `postgres:15`
- **Database**: `radius`
- **Credentials**: `radius`/`radiuspass`
- **Port**: 5432 (internal)

#### FreeRADIUS Server
- **Image**: `freeradius/freeradius-server:latest`
- **Ports**: 1812/udp (auth), 1813/udp (accounting)
- **Authentication**: PAP protocol
- **Backend**: PostgreSQL

### Database Schema

| Table | Purpose |
|-------|---------|
| `nas` | Network Access Server configurations |
| `radcheck` | User authentication attributes |
| `radreply` | User reply attributes |
| `radacct` | Accounting records |
| `radpostauth` | Post-authentication records |

## 🧪 Testing

### Basic Authentication Test
```bash
radtest testuser testpass 127.0.0.1 0 testing123
```

### Advanced RADIUS Testing
```bash
radclient -x 127.0.0.1 auth testing123 <<< $'User-Name = "testuser"\nUser-Password = "testpass"\nNAS-IP-Address = 127.0.0.1\nArista-Tenant-Id = 12345\n'
```

### 802.1X Client Testing
```bash
sudo wpa_supplicant -i enp2s0 -c /etc/wpa_supplicant/enp2s0.conf -D wired -d
```

## 🗄️ Database Management

### Connect to Database
```bash
docker exec -it radius-postgres psql -U radius -d radius
```

### List All Tables
```bash
docker exec -it radius-postgres psql -U radius -d radius -c "\dt"
```

### Add New Client
```sql
INSERT INTO nas (nasname, shortname, type, secret) 
VALUES ('172.21.0.1', 'test1', 'other', 'testing123');
```

### Add New User
```sql
INSERT INTO radcheck (username, attribute, op, value) 
VALUES ('L3U1', 'Cleartext-Password', ':=', 'whatever');
```

### View Current Data
```sql
-- View all NAS clients
SELECT * FROM nas;

-- View all users
SELECT * FROM radcheck;
```

## 🔧 Management Commands

### Container Management
```bash
# View running containers
docker-compose ps

# View logs
docker-compose logs radius
docker-compose logs db

# Restart services
docker-compose restart
```

### Database Operations
```bash
# Backup database
docker exec radius-postgres pg_dump -U radius radius > backup.sql

# Reset environment
docker-compose down -v
./setup.sh
```

## 🛠 Troubleshooting

### Common Issues

#### 1. "Unknown Client" Error
**Symptom**: `Ignoring request from unknown client 172.21.0.1`

**Solution**: Add the client IP to the database:
```sql
INSERT INTO nas (nasname, shortname, type, secret) 
VALUES ('172.21.0.1', 'docker-network', 'other', 'testing123');
```

#### 2. Port Conflicts
```bash
# Check port usage
sudo netstat -tulpn | grep :1812
sudo netstat -tulpn | grep :1813
```

#### 3. Database Connection Issues
```bash
# Check container status
docker-compose logs db
docker-compose ps
```

### Debug Mode
```bash
# Run FreeRADIUS with debug output
docker-compose down
docker-compose up radius
```

## 🔗 Service Registration

### Consul Service Registration
```bash
curl -X PUT http://localhost:8500/v1/agent/service/register \
  -H "Content-Type: application/json" \
  -d '{
    "Name": "veos-gnmic",
    "ID": "vEOS-lab-sw1",
    "Address": "172.24.0.23",
    "Port": 6030,
    "Checks": [
      {
        "CheckID": "gnmi-check",
        "Name": "gnmi TCP check",
        "TCP": "172.24.0.23:6030",
        "Interval": "10s",
        "Timeout": "2s"
      }
    ],
    "Tags": ["eos"],
    "Meta": {
      "env": "lab"
    }
  }'
```

Validate that the service check is successful

```shell
curl http://localhost:8500/v1/agent/checks | jq
{
  "gnmi-check": {
    "Node": "server-1",
    "CheckID": "gnmi-check",
    "Name": "gnmi TCP check",
    "Status": "passing",
    "Notes": "",
    "Output": "TCP connect 172.24.0.23:6030: Success",
    "ServiceID": "vEOS-lab-sw1",
    "ServiceName": "veos-gnmic",
    "ServiceTags": [
      "eos"
    ],
    "Type": "tcp",
    "Interval": "10s",
    "Timeout": "2s",
    "ExposedPort": 0,
    "Definition": {},
    "CreateIndex": 0,
    "ModifyIndex": 0
  }
}
```

## 📁 Project Structure
```
sdn-roce-poc/
├── README.md              # This file
├── .gitignore            # Git ignore rules
└── freeradius/           # FreeRADIUS deployment
    ├── setup.sh          # Automated setup script
    ├── docker-compose.yml # Container configuration
    ├── postgres/         # Database files
    └── radius/           # FreeRADIUS configuration
```

## 🔐 Security Notes

- Default credentials are for testing only
- Change passwords in production environments
- Consider using environment variables for secrets
- Implement proper password hashing for production

## 📚 Reference

### Arista EOS OpenConfig Support
- [Arista EOS Path Support](https://www.arista.com/en/support/toi/path-support?pn=EOS-4.34.1F)

To subscribe to an Openconfig path with GNMIC 

```shell
./app/gnmic subscribe --encoding=json --path "/interfaces/interface[name=Ethernet1]" -a 172.24.0.23:6030 --username gmckee --password ******** --insecure
```

EOS native path 

dot1x

```shell
./app/gnmic subscribe --encoding=json --path "eos_native:/Sysdb/dot1x/status/dot1xIntfStatus" -a 172.24.0.23:6030 --username gmckee --password ****** --insecure
```

You can also provide the interface name `Ethernet1` in this example

```shell
./app/gnmic subscribe --encoding=json --path "eos_native:/Sysdb/dot1x/status/dot1xIntfStatus[name=Ethernet1]" -a 172.24.0.23:6030 --username gmckee --password ****** --insecure

{
  "source": "172.24.0.23:6030",
  "subscription-name": "default-1751989115",
  "timestamp": 1751989131151086729,
  "time": "2025-07-08T15:38:51.151086729Z",
  "prefix": "eos_native:Sysdb/dot1x/status/dot1xIntfStatus/Ethernet1/supplicant/c0:cc:ff:ee:ff:01",
  "updates": [
    {
      "Path": "authStage",
      "values": {
        "authStage": "authWaitForAuthServer"
      }
    }
  ]
}
{
  "source": "172.24.0.23:6030",
  "subscription-name": "default-1751989115",
  "timestamp": 1751989131151115472,
  "time": "2025-07-08T15:38:51.151115472Z",
  "prefix": "eos_native:Sysdb/dot1x/status/dot1xIntfStatus/Ethernet1/supplicant/c0:cc:ff:ee:ff:01",
  "updates": [
    {
      "Path": "lastActivityTime",
      "values": {
        "lastActivityTime": 1751989131.1501586
      }
    }
  ]
}
{
  "source": "172.24.0.23:6030",
  "subscription-name": "default-1751989115",
  "timestamp": 1751989131151353680,
  "time": "2025-07-08T15:38:51.15135368Z",
  "prefix": "eos_native:Sysdb/dot1x/status/dot1xIntfStatus/Ethernet1/stats",
  "updates": [
    {
      "Path": "rxInvalid",
      "values": {
        "rxInvalid": 2242
      }
    }
  ]
}
{
  "source": "172.24.0.23:6030",
  "subscription-name": "default-1751989115",
  "timestamp": 1751989131153614652,
  "time": "2025-07-08T15:38:51.153614652Z",
  "prefix": "eos_native:Sysdb/dot1x/status/dot1xIntfStatus/Ethernet1/supplicant/c0:cc:ff:ee:ff:01",
  "updates": [
    {
      "Path": "authStage",
      "values": {
        "authStage": "authWaitForSupplicant"
      }
    }
  ]
}
{
  "source": "172.24.0.23:6030",
  "subscription-name": "default-1751989115",
  "timestamp": 1751989131153624046,
  "time": "2025-07-08T15:38:51.153624046Z",
  "prefix": "eos_native:Sysdb/dot1x/status/dot1xIntfStatus/Ethernet1/stats",
  "updates": [
    {
      "Path": "txReq",
      "values": {
        "txReq": 16462
      }
    }
  ]
}
{
  "source": "172.24.0.23:6030",
  "subscription-name": "default-1751989115",
  "timestamp": 1751989131154170646,
  "time": "2025-07-08T15:38:51.154170646Z",
  "prefix": "eos_native:Sysdb/dot1x/status/dot1xIntfStatus/Ethernet1/stats",
  "updates": [
    {
      "Path": "rxResp",
      "values": {
        "rxResp": 14201
      }
    }
  ]
}
```


```shell
./app/gnmic subscribe --encoding=json --path "eos_native:/Sysdb/l3tenantseg/isolation/request/isolationIntfRequest" -a 172.24.0.23:6030 --username gmckee --password ******** --insecure
{
  "sync-response": true
}
{
  "source": "172.24.0.23:6030",
  "subscription-name": "default-1751988682",
  "timestamp": 1751988687394840446,
  "time": "2025-07-08T15:31:27.394840446Z",
  "prefix": "eos_native:Sysdb/l3tenantseg/isolation/request/isolationIntfRequest/Ethernet1",
  "updates": [
    {
      "Path": "intfId",
      "values": {
        "intfId": "Ethernet1"
      }
    },
    {
      "Path": "name",
      "values": {
        "name": "Ethernet1"
      }
    },
    {
      "Path": "profileName",
      "values": {
        "profileName": ""
      }
    }
  ]
}
{
  "source": "172.24.0.23:6030",
  "subscription-name": "default-1751988682",
  "timestamp": 1751988687394863430,
  "time": "2025-07-08T15:31:27.39486343Z",
  "prefix": "eos_native:Sysdb/l3tenantseg/isolation/request/isolationIntfRequest/Ethernet1",
  "updates": [
    {
      "Path": "profileName",
      "values": {
        "profileName": "roce-poc"
      }
    }
  ]
}
{
  "source": "172.24.0.23:6030",
  "subscription-name": "default-1751988682",
  "timestamp": 1751988687394865263,
  "time": "2025-07-08T15:31:27.394865263Z",
  "prefix": "eos_native:Sysdb/l3tenantseg/isolation/request/isolationIntfRequest/Ethernet1/isolationRequest",
  "updates": [
    {
      "Path": "0:0:2a00:100::_0:0:ffff:ff00::/description",
      "values": {
        "0:0:2a00:100::_0:0:ffff:ff00::/description": "Permit Et1 bits 32-39 value 0x2a, bits 40-55 value 0x1"
      }
    },
    {
      "Path": "0:0:2a00:100::_0:0:ffff:ff00::/isolationCriteria/address",
      "values": {
        "0:0:2a00:100::_0:0:ffff:ff00::/isolationCriteria/address": "0:0:2a00:100::"
      }
    },
    {
      "Path": "0:0:2a00:100::_0:0:ffff:ff00::/isolationCriteria/mask",
      "values": {
        "0:0:2a00:100::_0:0:ffff:ff00::/isolationCriteria/mask": "0:0:ffff:ff00::"
      }
    }
  ]
}
```

### Useful Commands
```bash
# List all database tables
docker exec -it radius-postgres psql -U radius -d radius -c "\dt"

# View table structure
docker exec -it radius-postgres psql -U radius -d radius -c "\d nas"

# Count rows in tables
docker exec -it radius-postgres psql -U radius -d radius -c "SELECT COUNT(*) FROM radcheck;"
```

## 📝 License

Research and development project - not for production use.



sudo wpa_supplicant -i enp2s0 -c /etc/wpa_supplicant/enp2s0.conf -D wired -d


radclient -x 127.0.0.1 auth testing123 <<< $'User-Name = "testuser"\nUser-Password = "testpass"\nNAS-IP-Address = 127.0.0.1\nArista-Tenant-Id = 12345\n'


```
INSERT INTO radcheck (username, attribute, op, value) VALUES ('L3U1', 'Cleartext-Password', ':=', 'whatever');
```


Consul

```shell
curl -X PUT http://localhost:8500/v1/agent/service/register \
  -H "Content-Type: application/json" \
  -d '{
    "Name": "veos-gnmic",
    "ID": "vEOS-lab-sw1",
    "Address": "172.24.0.23",
    "Port": 6030,
    "Checks": [
      {
        "CheckID": "gnmi-check",
        "Name": "gnmi TCP check",
        "TCP": "172.24.0.23:6030",
        "Interval": "10s",
        "Timeout": "2s"
      }
    ],
    "Tags": ["eos"],
    "Meta": {
      "env": "lab"
    }
  }'
```

Check the status of the health check

```shell
curl http://localhost:8500/v1/agent/checks | jq

{
  "gnmi-check": {
    "Node": "server-1",
    "CheckID": "gnmi-check",
    "Name": "gnmi TCP check",
    "Status": "passing",
    "Notes": "",
    "Output": "TCP connect 172.24.0.23:6030: Success",
    "ServiceID": "vEOS-lab-sw1",
    "ServiceName": "veos-gnmic",
    "ServiceTags": [
      "eos"
    ],
    "Type": "tcp",
    "Interval": "10s",
    "Timeout": "2s",
    "ExposedPort": 0,
    "Definition": {},
    "CreateIndex": 0,
    "ModifyIndex": 0
  }
}
```
