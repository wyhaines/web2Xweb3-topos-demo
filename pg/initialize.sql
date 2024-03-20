-- Give access to UUID functions.
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Give access to cryptographic functions.
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Give access to pg_cron.
CREATE EXTENSION "pg_cron";
