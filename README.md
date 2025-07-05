# SDN RoCE POC - FreeRADIUS Setup

This repository contains a FreeRADIUS deployment for SDN RoCE (RDMA over Converged Ethernet) proof-of-concept testing. The setup uses Docker containers with PostgreSQL as the backend database.

## 📋 Prerequisites

Before running the setup, ensure you have the following installed:

- **Docker** (version 20.10 or later)
- **Docker Compose** (version 2.0 or later)
- **radtest** utility (for testing authentication)

### Installing radtest

On Ubuntu/Debian:
```bash
sudo apt-get install freeradius-utils
```

On CentOS/RHEL:
```bash
sudo yum install freeradius-utils
```

## 🚀 Quick Setup

The `setup.sh` script automates the entire FreeRADIUS deployment process:

```bash
cd freeradius
chmod +x setup.sh
./setup.sh
```

## 🔧 What `setup.sh` Does

The setup script performs the following steps in sequence:

### 1. Directory Structure Creation
Creates the necessary directory structure:
```
freeradius/
├── postgres/
├── radius/
│   ├── mods-enabled/
│   ├── mods-config/
│   │   └── sql/
│   │       └── main/
│   │           └── postgresql/
│   └── sites-enabled/
```

### 2. FreeRADIUS Configuration Downloads
Downloads official FreeRADIUS 3.2.7 configuration files:
- **PostgreSQL Schema**: `postgres/schema.sql` - Database table definitions
- **SQL Queries**: `radius/mods-config/sql/main/postgresql/queries.conf` - SQL query templates

### 3. Docker Compose Configuration
Generates `docker-compose.yml` with two services:

#### PostgreSQL Database Service
- **Image**: `postgres:15`
- **Container Name**: `radius-postgres`
- **Database**: `radius`
- **User**: `radius`
- **Password**: `radiuspass`
- **Port**: 5432 (internal)
- **Volume**: Mounts schema.sql for automatic initialization

#### FreeRADIUS Service
- **Image**: `freeradius/freeradius-server:latest`
- **Container Name**: `freeradius`
- **Ports**: 
  - 1812/udp (authentication)
  - 1813/udp (accounting)
- **Dependencies**: Waits for PostgreSQL service
- **Volumes**: Mounts configuration files as read-only

### 4. FreeRADIUS SQL Module Configuration
Creates `radius/mods-enabled/sql` with PostgreSQL connection settings:
- **Driver**: `rlm_sql_postgresql`
- **Database**: `radius` on `db` container
- **Credentials**: `radius`/`radiuspass`
- **Tables**: Configures all RADIUS tables (radcheck, radreply, etc.)

### 5. FreeRADIUS Site Configuration
Creates `radius/sites-enabled/default` with authentication flow:
- **Authentication**: PAP (Password Authentication Protocol)
- **Authorization**: SQL database lookup
- **Accounting**: SQL database logging
- **Session Management**: SQL-based
- **Post-Authentication**: SQL logging

### 6. Container Deployment
- Stops any existing containers (`docker-compose down -v`)
- Starts fresh containers (`docker-compose up -d`)
- Waits 5 seconds for database initialization

### 7. Initial Data Setup
Inserts default test data into PostgreSQL:

#### NAS Client Configuration
```sql
INSERT INTO nas (nasname, shortname, type, secret)
VALUES ('127.0.0.1', 'localhost', 'other', 'testing123')
```

#### Test User Account
```sql
INSERT INTO radcheck (username, attribute, op, value)
VALUES ('testuser', 'Cleartext-Password', ':=', 'testpass')
```

## 🧪 Testing the Setup

After successful setup, test authentication with:

```bash
radtest testuser testpass 127.0.0.1 0 testing123
```

**Expected Output:**
```
Sent Access-Request ...
Received Access-Accept ...
```

## 📊 Database Schema

The setup creates the following PostgreSQL tables:
- `nas` - Network Access Server (client) configurations
- `radcheck` - User authentication attributes
- `radreply` - User reply attributes
- `radgroupcheck` - Group check attributes
- `radgroupreply` - Group reply attributes
- `radusergroup` - User-group associations
- `radacct` - Accounting records
- `radpostauth` - Post-authentication records

## 🔧 Management Commands

### View Running Containers
```bash
docker-compose ps
```

### View Logs
```bash
# FreeRADIUS logs
docker-compose logs radius

# PostgreSQL logs
docker-compose logs db
```

### Access PostgreSQL Database
```bash
docker exec -it radius-postgres psql -U radius -d radius
```

### Add New NAS Client
```bash
docker exec -it radius-postgres psql -U radius -d radius -c \
"INSERT INTO nas (nasname, shortname, type, secret)
 VALUES ('192.168.1.100', 'router1', 'other', 'mysecret');"
```

### Add New User
```bash
docker exec -it radius-postgres psql -U radius -d radius -c \
"INSERT INTO radcheck (username, attribute, op, value)
 VALUES ('newuser', 'Cleartext-Password', ':=', 'newpass');"
```

## 🔄 Reset Environment

To completely reset the environment:

```bash
docker-compose down -v
./setup.sh
```

This will:
- Stop all containers
- Remove all volumes (destroying database data)
- Re-run the entire setup process

## 🛠 Troubleshooting

### Common Issues

1. **Port Already in Use**
   ```bash
   # Check what's using the ports
   sudo netstat -tulpn | grep :1812
   sudo netstat -tulpn | grep :1813
   ```

2. **Database Connection Issues**
   ```bash
   # Check if PostgreSQL is running
   docker-compose logs db
   ```

3. **FreeRADIUS Configuration Errors**
   ```bash
   # Check FreeRADIUS logs
   docker-compose logs radius
   ```

### Debug Mode

To run FreeRADIUS in debug mode, modify the docker-compose.yml:
```yaml
command: freeradius -X
```

## 📁 File Structure

After setup, your directory will contain:
```
freeradius/
├── setup.sh                    # Setup script
├── docker-compose.yml          # Generated Docker configuration
├── postgres/
│   └── schema.sql             # Downloaded PostgreSQL schema
└── radius/
    ├── mods-enabled/
    │   └── sql                # SQL module configuration
    ├── mods-config/
    │   └── sql/
    │       └── main/
    │           └── postgresql/
    │               └── queries.conf  # Downloaded SQL queries
    └── sites-enabled/
        └── default            # FreeRADIUS site configuration
```

## 🔐 Security Notes

- Default credentials are used for testing only
- In production, change all passwords and secrets
- Consider using environment variables for sensitive data
- The setup uses cleartext passwords for simplicity; consider hashing in production

## 📝 License

This project is part of the SDN RoCE POC and is intended for research and testing purposes.
