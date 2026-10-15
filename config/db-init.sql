-- ==============================================================================
-- PostgreSQL Database Initialization for Zitadel
-- Run as superuser/postgres admin on your external database
-- ==============================================================================

-- 1. Create zitadel user role (if not already existing)
DO
$do$
BEGIN
   IF NOT EXISTS (
      SELECT FROM pg_catalog.pg_roles WHERE rolname = 'zitadel') THEN
      CREATE ROLE zitadel LOGIN PASSWORD 'replace_with_strong_password';
   END IF;
END
$do$;

-- 2. Create database and assign ownership
-- (Run outside transaction if database does not exist)
-- CREATE DATABASE zitadel OWNER zitadel;

-- 3. Connect to zitadel database and setup permissions
-- \c zitadel

CREATE SCHEMA IF NOT EXISTS zitadel;
ALTER SCHEMA public OWNER TO zitadel;
GRANT ALL ON SCHEMA public TO zitadel;
GRANT ALL PRIVILEGES ON DATABASE zitadel TO zitadel;
