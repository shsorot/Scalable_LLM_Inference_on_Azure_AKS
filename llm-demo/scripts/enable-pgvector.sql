-- ============================================
-- Enable PGVector Extension on Azure PostgreSQL
-- Run this in Azure Portal Query Editor or psql
-- ============================================

-- Connect to the openwebui database first
-- In Azure Portal: Select database "openwebui" from dropdown

-- Enable pgvector extension for vector operations
CREATE EXTENSION IF NOT EXISTS vector;

-- Enable uuid-ossp extension for UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Verify extensions are installed
\dx

-- Expected output should include:
--   vector    | 0.5.x or higher
--   uuid-ossp | 1.1

-- Check vector type is available
SELECT typname FROM pg_type WHERE typname = 'vector';
-- Should return: vector

-- Grant necessary permissions (if needed)
-- GRANT ALL ON SCHEMA public TO pgadmin;

-- Done! You can now run the migration script.
