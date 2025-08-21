-- Initial schema migration for Ballerina API Gateway
-- Migration: 001_initial_schema
-- Description: Create core tables for developers, API keys, quota usage, and request logs

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

-- Rate limiting tracking
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