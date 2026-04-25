-- Initial database setup for the Nexus Ledger

-- ledger_dev is created by the environment variable POSTGRES_DB in docker-compose.yml.
-- We use this trick to create the test databases only if they don't exist.
SELECT 'CREATE DATABASE ledger_test'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'ledger_test')\gexec

-- eventstore_test is the EventStore database used in MIX_ENV=test.
-- It must be separate from ledger_test so the Ecto sandbox and EventStore
-- can be reset independently during integration tests.
SELECT 'CREATE DATABASE eventstore_test'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'eventstore_test')\gexec

\c ledger_dev;

-- Extensions for professional financial data
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Grant permissions for dev
-- NOTE: This script runs at container init time and uses hardcoded dev credentials.
-- The password must match DB_PASS in your .env file AND the CI fallback in
-- .github/workflows/nexus-audit.yml (default: 'ledger_password').
-- Production deployments should use a secrets manager (Vault) to inject credentials
-- rather than relying on this init script.
DO $$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = 'ledger') THEN
      CREATE USER ledger WITH PASSWORD 'ledger_password' CREATEDB;
   ELSE
      ALTER USER ledger CREATEDB;
   END IF;
END
$$;

GRANT ALL PRIVILEGES ON DATABASE ledger_dev TO ledger;
GRANT ALL PRIVILEGES ON DATABASE ledger_test TO ledger;
GRANT ALL PRIVILEGES ON DATABASE eventstore_test TO ledger;
ALTER DATABASE ledger_dev OWNER TO ledger;
ALTER DATABASE ledger_test OWNER TO ledger;
ALTER DATABASE eventstore_test OWNER TO ledger;

-- Create the EventStore schema in ledger_dev so `mix event_store.init` can run
-- without requiring the ledger user to have CREATEDB privilege.
CREATE SCHEMA IF NOT EXISTS event_store;
ALTER SCHEMA event_store OWNER TO ledger;
GRANT ALL ON SCHEMA event_store TO ledger;

-- Bootstrap the same event_store schema in ledger_test for test runs that
-- target the main test database rather than eventstore_test.
\c ledger_test;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE SCHEMA IF NOT EXISTS event_store;
ALTER SCHEMA event_store OWNER TO ledger;
GRANT ALL ON SCHEMA event_store TO ledger;

-- eventstore_test: the dedicated test event store database.
-- MIX_ENV=test points EventStore here via EVENTSTORE_NAME_TEST || "eventstore_test".
\c eventstore_test;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE SCHEMA IF NOT EXISTS event_store;
ALTER SCHEMA event_store OWNER TO ledger;
GRANT ALL ON SCHEMA event_store TO ledger;
