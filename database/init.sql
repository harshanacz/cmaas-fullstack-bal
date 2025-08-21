-- Database initialization script
-- This script creates the database and user for the API Gateway

-- Create database user
CREATE USER gateway_user WITH PASSWORD 'gateway_pass';

-- Create database
CREATE DATABASE gateway_db OWNER gateway_user;

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE gateway_db TO gateway_user;

-- Connect to the new database and set up schema
\c gateway_db;

-- Grant schema privileges
GRANT ALL ON SCHEMA public TO gateway_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO gateway_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO gateway_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO gateway_user;

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO gateway_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO gateway_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO gateway_user;