-- PostgreSQL schema for Ballerina API Gateway
-- This script creates all necessary tables and indexes

-- Create database (run separately if needed)
-- CREATE DATABASE gateway_db;

-- Use the database
-- \c gateway_db;

-- Create extension for UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Developer accounts table
CREATE TABLE IF NOT EXISTS developers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true
);

-- API keys table
CREATE TABLE IF NOT EXISTS api_keys (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    developer_id UUID NOT NULL REFERENCES developers(id) ON DELETE CASCADE,
    key_value VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(100),
    monthly_quota INTEGER DEFAULT 100,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true
);

-- Monthly quota usage tracking
CREATE TABLE IF NOT EXISTS quota_usage (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    api_key_id UUID NOT NULL REFERENCES api_keys(id) ON DELETE CASCADE,
    month_year VARCHAR(7) NOT NULL, -- Format: 2025-08
    requests_used INTEGER DEFAULT 0,
    last_reset TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(api_key_id, month_year)
);

-- Request analytics and logging
CREATE TABLE IF NOT EXISTS request_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    api_key_id UUID REFERENCES api_keys(id) ON DELETE SET NULL,
    endpoint VARCHAR(255) NOT NULL,
    method VARCHAR(10) NOT NULL,
    status_code INTEGER NOT NULL,
    response_time_ms INTEGER,
    request_size_bytes INTEGER,
    response_size_bytes INTEGER,
    user_agent VARCHAR(500),
    ip_address INET,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Rate limiting tracking (in-memory alternative, but keeping for persistence)
CREATE TABLE IF NOT EXISTS rate_limits (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    api_key_id UUID NOT NULL REFERENCES api_keys(id) ON DELETE CASCADE,
    window_start TIMESTAMP WITH TIME ZONE NOT NULL,
    request_count INTEGER DEFAULT 1,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(api_key_id, window_start)
);

-- Indexes for performance optimization

-- Developer indexes
CREATE INDEX IF NOT EXISTS idx_developers_email ON developers(email);
CREATE INDEX IF NOT EXISTS idx_developers_active ON developers(is_active);

-- API key indexes
CREATE INDEX IF NOT EXISTS idx_api_keys_developer_id ON api_keys(developer_id);
CREATE INDEX IF NOT EXISTS idx_api_keys_key_value ON api_keys(key_value);
CREATE INDEX IF NOT EXISTS idx_api_keys_active ON api_keys(is_active);

-- Quota usage indexes
CREATE INDEX IF NOT EXISTS idx_quota_usage_api_key_id ON quota_usage(api_key_id);
CREATE INDEX IF NOT EXISTS idx_quota_usage_month_year ON quota_usage(month_year);
CREATE INDEX IF NOT EXISTS idx_quota_usage_composite ON quota_usage(api_key_id, month_year);

-- Request logs indexes
CREATE INDEX IF NOT EXISTS idx_request_logs_api_key_id ON request_logs(api_key_id);
CREATE INDEX IF NOT EXISTS idx_request_logs_created_at ON request_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_request_logs_endpoint ON request_logs(endpoint);
CREATE INDEX IF NOT EXISTS idx_request_logs_status_code ON request_logs(status_code);

-- Rate limits indexes
CREATE INDEX IF NOT EXISTS idx_rate_limits_api_key_id ON rate_limits(api_key_id);
CREATE INDEX IF NOT EXISTS idx_rate_limits_window_start ON rate_limits(window_start);

-- Functions and triggers for updated_at timestamps

-- Function to update the updated_at column
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers for updated_at
CREATE TRIGGER update_developers_updated_at 
    BEFORE UPDATE ON developers 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_api_keys_updated_at 
    BEFORE UPDATE ON api_keys 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_quota_usage_updated_at 
    BEFORE UPDATE ON quota_usage 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_rate_limits_updated_at 
    BEFORE UPDATE ON rate_limits 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to generate API key with proper format
CREATE OR REPLACE FUNCTION generate_api_key(env_name VARCHAR DEFAULT 'dev')
RETURNS VARCHAR AS $$
DECLARE
    current_year VARCHAR(4);
    random_part VARCHAR(32);
BEGIN
    current_year := EXTRACT(YEAR FROM NOW())::VARCHAR;
    random_part := encode(gen_random_bytes(16), 'hex');
    RETURN 'bal_' || env_name || '_' || current_year || '_' || random_part;
END;
$$ LANGUAGE plpgsql;

-- Function to reset monthly quotas (to be called by cron job)
CREATE OR REPLACE FUNCTION reset_monthly_quotas()
RETURNS INTEGER AS $$
DECLARE
    current_month VARCHAR(7);
    reset_count INTEGER;
BEGIN
    current_month := TO_CHAR(NOW(), 'YYYY-MM');
    
    -- Reset quota usage for the current month
    UPDATE quota_usage 
    SET requests_used = 0, last_reset = NOW()
    WHERE month_year = current_month;
    
    GET DIAGNOSTICS reset_count = ROW_COUNT;
    
    -- Insert new quota records for API keys that don't have current month records
    INSERT INTO quota_usage (api_key_id, month_year, requests_used, last_reset)
    SELECT ak.id, current_month, 0, NOW()
    FROM api_keys ak
    WHERE ak.is_active = true
    AND NOT EXISTS (
        SELECT 1 FROM quota_usage qu 
        WHERE qu.api_key_id = ak.id 
        AND qu.month_year = current_month
    );
    
    RETURN reset_count;
END;
$$ LANGUAGE plpgsql;

-- Sample data for development (optional)
-- Uncomment the following lines to insert sample data

/*
-- Sample developer
INSERT INTO developers (email, password_hash) 
VALUES ('developer@example.com', '$2b$10$example.hash.here');

-- Sample API key (you'll need to get the developer ID first)
-- INSERT INTO api_keys (developer_id, key_value, name) 
-- VALUES ((SELECT id FROM developers WHERE email = 'developer@example.com'), 
--         generate_api_key('dev'), 'Test API Key');
*/

-- Grant permissions (adjust as needed for your setup)
-- GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO gateway_user;
-- GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO gateway_user;
-- GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO gateway_user;