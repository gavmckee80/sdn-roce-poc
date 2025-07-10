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
    container_name: freeradius-postgres
    restart: always
    environment:
      - POSTGRES_USER=radius
      - POSTGRES_PASSWORD=radiuspass
      - POSTGRES_DB=radius
    volumes:
      - ./postgres/schema.sql:/docker-entrypoint-initdb.d/init.sql

  freeradius:
    image: freeradius/freeradius-server:latest
    container_name: freeradius
    restart: always
    command: freeradius -X
    ports:
      - "1812:1812/udp"
      - "1813:1813/udp"
    depends_on:
      - db
    volumes:
      - ./radius/mods-enabled/sql:/etc/freeradius/mods-enabled/sql:ro
      - ./radius/mods-config/sql/main/postgresql:/etc/freeradius/mods-config/sql/main/postgresql:ro
      - ./radius/sites-enabled/default:/etc/freeradius/sites-enabled/default:ro
      - ./radius/dictionary.d/dictionary.arista:/usr/share/freeradius/dictionary.arista

  gnmic-collector: &gnmic
    image: ghcr.io/openconfig/gnmic:latest
    container_name: gnmic-collector
    volumes:
      - ./gnmic.yml:/app/gnmic.yml
      #- ./targets.yml:/app/targets.yml
    command: "subscribe --config /app/gnmic.yml"
    depends_on:
      - consul-agent

  victoriametrics:
    container_name: victoriametrics
    image: victoriametrics/victoria-metrics:v1.93.4
    ports:
      - 8428:8428
      - 8089:8089
      - 8089:8089/udp
      - 2003:2003
      - 2003:2003/udp
      - 4242:4242
    volumes:
      - ./vmdata:/storage
    command:
      - "--storageDataPath=/storage"
      - "--graphiteListenAddr=:2003"
      - "--opentsdbListenAddr=:4242"
      - "--httpListenAddr=:8428"
      - "--influxListenAddr=:8089"
      - "--vmalert.proxyURL=http://vmalert:8880"
    restart: always
  nats:
    image: 'nats:latest'
    container_name: nats
    # networks:
    #   - vm_net    
    ports:
      - "4222:4222"
      - "6222:6222"
      - "8222:8222"
  consul-agent:
    image: hashicorp/consul:latest
    container_name: consul
    # networks:
    #   - vm_net
    ports:
      - 8500:8500
      - 8600:8600/udp
    command: agent -server -ui -node=server-1 -bootstrap-expect=1 -client=0.0.0.0  
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

  authenticate {
    pap
  }

  authorize {
    sql
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

INSERT INTO nas (nasname, shortname, type, secret)
VALUES ('172.21.0.1', 'docker-network', 'other', 'testing123')
ON CONFLICT DO NOTHING;

INSERT INTO radcheck (username, attribute, op, value)
VALUES ('testuser', 'Cleartext-Password', ':=', 'testpass')
ON CONFLICT DO NOTHING;
EOF

echo ""
echo "✅ Setup complete!"
echo "🧪 Run this to test:"
echo "   radtest testuser testpass 127.0.0.1 0 testing123"

