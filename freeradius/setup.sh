#!/bin/bash
set -e

echo "🔧 Creating directory structure..."
mkdir -p postgres
mkdir -p radius/mods-enabled
mkdir -p radius/mods-config/sql/main/postgresql
mkdir -p radius/sites-enabled

echo "📥 Downloading FreeRADIUS 3.2.7 schema.sql..."
curl -sSL -o postgres/schema.sql \
  https://raw.githubusercontent.com/FreeRADIUS/freeradius-server/release_3_2_7/raddb/mods-config/sql/main/postgresql/schema.sql

echo "📥 Downloading FreeRADIUS 3.2.7 queries.conf..."
curl -sSL -o radius/mods-config/sql/main/postgresql/queries.conf \
  https://raw.githubusercontent.com/FreeRADIUS/freeradius-server/release_3_2_7/raddb/mods-config/sql/main/postgresql/queries.conf

echo "⚙️ Writing docker-compose.yml..."
cat > docker-compose.yml <<EOF
version: '3.8'

services:
  db:
    image: postgres:15
    container_name: radius-postgres
    restart: always
    environment:
      - POSTGRES_USER=radius
      - POSTGRES_PASSWORD=radiuspass
      - POSTGRES_DB=radius
    volumes:
      - ./postgres/schema.sql:/docker-entrypoint-initdb.d/init.sql

  radius:
    image: freeradius/freeradius-server:latest
    container_name: freeradius
    restart: always
    ports:
      - "1812:1812/udp"
      - "1813:1813/udp"
    depends_on:
      - db
    volumes:
      - ./radius/mods-enabled/sql:/etc/freeradius/mods-enabled/sql:ro
      - ./radius/mods-config/sql/main/postgresql:/etc/freeradius/mods-config/sql/main/postgresql:ro
      - ./radius/sites-enabled/default:/etc/freeradius/sites-enabled/default:ro
EOF

echo "⚙️ Creating radius/mods-enabled/sql config..."
cat > radius/mods-enabled/sql <<EOF
sql {
  driver = "rlm_sql_postgresql"
  dialect = "postgresql"
  server = "db"
  port = 5432
  login = "radius"
  password = "radiuspass"
  radius_db = "radius"
  read_clients = yes
  group_attribute = "sqlgroup"

  authcheck_table = "radcheck"
  authreply_table = "radreply"
  groupcheck_table = "radgroupcheck"
  groupreply_table = "radgroupreply"
  usergroup_table = "radusergroup"
  acct_table1 = "radacct"
  acct_table2 = "radacct"
  postauth_table = "radpostauth"
  client_table = "nas"

  \$INCLUDE /etc/freeradius/mods-config/sql/main/postgresql/queries.conf
}
EOF

echo "⚙️ Creating radius/sites-enabled/default config..."
cat > radius/sites-enabled/default <<EOF
server default {
  listen {
    type = auth
    ipaddr = *
    port = 1812
  }

  authorize {
    sql
  }

  authenticate {
    pap
  }

  accounting {
    sql
  }

  session {
    sql
  }

  post-auth {
    sql
  }
}
EOF

echo "✅ Bootstrapping FreeRADIUS SQL-only environment..."

docker-compose down -v && docker-compose up -d

echo "⏳ Waiting for database to start..."
sleep 5

echo "➕ Inserting initial NAS and test user..."
docker exec -i radius-postgres psql -U radius -d radius <<EOF
INSERT INTO nas (nasname, shortname, type, secret)
VALUES ('127.0.0.1', 'localhost', 'other', 'testing123')
ON CONFLICT DO NOTHING;

INSERT INTO radcheck (username, attribute, op, value)
VALUES ('testuser', 'Cleartext-Password', ':=', 'testpass')
ON CONFLICT DO NOTHING;
EOF

echo ""
echo "✅ Setup complete!"
echo "🧪 Run this to test:"
echo "   radtest testuser testpass 127.0.0.1 0 testing123"

