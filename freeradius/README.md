Absolutely — here's the full, production-ready `README.md` for your **SQL-only FreeRADIUS setup** in `sdn-roce-poc/freeradius`. This version:

✅ Walks through setup, testing, and reset
✅ Fixes all common issues (BlastRADIUS, `Cleartext-Password`, SQL auth, missing tables)
✅ Works cleanly with Docker + PostgreSQL
✅ Assumes you are using the `setup.sh` provided earlier

---

## 📘 `sdn-roce-poc/freeradius/README.md`

````markdown
# FreeRADIUS SQL-Only Deployment

This folder provides a fully containerized FreeRADIUS 3.2.7 deployment using PostgreSQL as the sole backend. It is part of the broader `sdn-roce-poc` project and is designed for dynamic, infrastructure-integrated RADIUS deployments.

---

## 📦 Components

- **FreeRADIUS** – latest image with only SQL-based configuration
- **PostgreSQL** – stores all user, NAS (client), accounting, group, and post-auth data
- **setup.sh** – builds the config and initializes the environment

---

## 🚀 Quickstart

### 1. Install dependencies

- Docker
- Docker Compose
- `radtest` (from `freeradius-utils` package)

### 2. Run setup

```bash
cd freeradius
chmod +x setup.sh
./setup.sh
````

This will:

* Download FreeRADIUS 3.2.7 schema and queries
* Create all required config files
* Start both containers
* Insert:

  * NAS client: `127.0.0.1` (secret: `testing123`)
  * Test user: `testuser` / `testpass`

---

## 🧪 Test Authentication

Run from your host:

```bash
radtest testuser testpass 127.0.0.1 0 testing123
```

Expected output:

```text
Sent Access-Request ...
Received Access-Accept ...
```

---

## 🔐 NAS (Client) Configuration

### Add a new NAS client (RADIUS device)

```bash
docker exec -it radius-postgres psql -U radius -d radius -c \
"INSERT INTO nas (nasname, shortname, type, secret)
 VALUES ('172.24.0.24', 'dockerhost2', 'other', 'testing123');"
```

### View existing NAS clients

```bash
docker exec -it radius-postgres psql -U radius -d radius -c "SELECT * FROM nas;"
```

---

## 👤 User Management

### Add a user

```bash
docker exec -it radius-postgres psql -U radius -d radius -c \
"INSERT INTO radcheck (username, attribute, op, value)
 VALUES ('alice', 'Cleartext-Password', ':=', 'securepass');"
```

### View all users

```bash
docker exec -it radius-postgres psql -U radius -d radius -c "SELECT * FROM radcheck;"
```

---

## 🔄 Reset Environment

To fully reset the environment:

```bash
docker-compose down -v
./setup.sh
```

This will destroy the database volume and re-run the schema and inserts.

---

## 🛠 Common Issues & Fixes

### 🔐 BlastRADIUS warning (Message-Authenticator)

**Log:**

```text
Please set "require_message_authenticator = true" for client localhost
```

**Fix:** Add `client localhost` to a `clients.d/localhost.conf` file:

```conf
client localhost {
  ipaddr = 127.0.0.1
  secret = testing123
  require_message_authenticator = yes
}
```

And mount it via Docker:

```yaml
volumes:
  - ./radius/clients.d:/etc/freeradius/clients.d:ro
```

---

### ⚠️ No Auth-Type found / Cleartext-Password not handled

**Log:**

```text
No module configured to handle comparisons with &control:Cleartext-Password
```

**Fix:** Make sure `pap` is enabled:

#### In `sites-enabled/default`:

```conf
authorize {
  sql
  pap
}

authenticate {
  pap
}
```

#### And ensure `mods-enabled/pap` exists:

```bash
ln -s ../mods-available/pap radius/mods-enabled/pap
```

---

### ❌ SQL table not found (e.g. `radusergroup`)

**Fix:** Connect to Postgres:

```bash
docker exec -it radius-postgres psql -U radius -d radius
```

And create the missing table:

```sql
CREATE TABLE radusergroup (
  id serial PRIMARY KEY,
  username TEXT NOT NULL,
  groupname TEXT NOT NULL,
  priority INTEGER DEFAULT 0
);
```

Optionally:

```sql
INSERT INTO radusergroup (username, groupname, priority)
VALUES ('testuser', 'default', 0);
```

---

## 📂 Files Used

| File / Dir                            | Purpose                                |
| ------------------------------------- | -------------------------------------- |
| `setup.sh`                            | Creates config and downloads schema    |
| `docker-compose.yml`                  | Launches FreeRADIUS and PostgreSQL     |
| `postgres/schema.sql`                 | Schema downloaded from FreeRADIUS repo |
| `radius/sites-enabled/default`        | Main virtual server                    |
| `radius/mods-enabled/sql`             | SQL connection + table config          |
| `radius/mods-config/sql/queries.conf` | SQL query templates                    |

---

## 📘 Reference

* FreeRADIUS SQL schema (PostgreSQL):
  [https://github.com/FreeRADIUS/freeradius-server/blob/release\_3\_2\_7/raddb/mods-config/sql/main/postgresql/schema.sql](https://github.com/FreeRADIUS/freeradius-server/blob/release_3_2_7/raddb/mods-config/sql/main/postgresql/schema.sql)
* Queries.conf:
  [https://github.com/FreeRADIUS/freeradius-server/blob/release\_3\_2\_7/raddb/mods-config/sql/main/postgresql/queries.conf](https://github.com/FreeRADIUS/freeradius-server/blob/release_3_2_7/raddb/mods-config/sql/main/postgresql/queries.conf)

