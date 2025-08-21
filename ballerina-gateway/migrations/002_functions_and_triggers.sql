-- Functions and triggers migration for Ballerina API Gateway
-- Migration: 002_functions_and_triggers
-- Description: Create utility functions and triggers for automated operations

-- Function to update the updated_at column
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers for updated_at columns
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

-- Function to reset monthly quotas (to be called by cron job or scheduler)
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

-- Function to clean up old request logs (retention policy)
CREATE OR REPLACE FUNCTION cleanup_old_request_logs(retention_days INTEGER DEFAULT 90)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM request_logs 
    WHERE created_at < NOW() - INTERVAL '1 day' * retention_days;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Function to clean up old rate limit records (older than 1 hour)
CREATE OR REPLACE FUNCTION cleanup_old_rate_limits()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM rate_limits 
    WHERE window_start < NOW() - INTERVAL '1 hour';
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Function to get current month quota usage for an API key
CREATE OR REPLACE FUNCTION get_current_quota_usage(api_key_value VARCHAR)
RETURNS TABLE(
    quota_limit INTEGER,
    quota_used INTEGER,
    quota_remaining INTEGER,
    reset_date TIMESTAMP WITH TIME ZONE
) AS $$
DECLARE
    current_month VARCHAR(7);
    key_id UUID;
    monthly_quota INTEGER;
BEGIN
    current_month := TO_CHAR(NOW(), 'YYYY-MM');
    
    -- Get API key ID and monthly quota
    SELECT ak.id, ak.monthly_quota INTO key_id, monthly_quota
    FROM api_keys ak 
    WHERE ak.key_value = api_key_value AND ak.is_active = true;
    
    IF key_id IS NULL THEN
        RETURN;
    END IF;
    
    -- Get or create quota usage record for current month
    INSERT INTO quota_usage (api_key_id, month_year, requests_used, last_reset)
    VALUES (key_id, current_month, 0, NOW())
    ON CONFLICT (api_key_id, month_year) DO NOTHING;
    
    -- Return quota information
    RETURN QUERY
    SELECT 
        monthly_quota as quota_limit,
        qu.requests_used as quota_used,
        (monthly_quota - qu.requests_used) as quota_remaining,
        (DATE_TRUNC('month', NOW()) + INTERVAL '1 month')::TIMESTAMP WITH TIME ZONE as reset_date
    FROM quota_usage qu
    WHERE qu.api_key_id = key_id AND qu.month_year = current_month;
END;
$$ LANGUAGE plpgsql;

-- Function to increment quota usage atomically
CREATE OR REPLACE FUNCTION increment_quota_usage(api_key_value VARCHAR)
RETURNS BOOLEAN AS $$
DECLARE
    current_month VARCHAR(7);
    key_id UUID;
    monthly_quota INTEGER;
    current_usage INTEGER;
BEGIN
    current_month := TO_CHAR(NOW(), 'YYYY-MM');
    
    -- Get API key ID and monthly quota
    SELECT ak.id, ak.monthly_quota INTO key_id, monthly_quota
    FROM api_keys ak 
    WHERE ak.key_value = api_key_value AND ak.is_active = true;
    
    IF key_id IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- Get or create quota usage record for current month
    INSERT INTO quota_usage (api_key_id, month_year, requests_used, last_reset)
    VALUES (key_id, current_month, 0, NOW())
    ON CONFLICT (api_key_id, month_year) DO NOTHING;
    
    -- Check current usage and increment if under quota
    SELECT requests_used INTO current_usage
    FROM quota_usage
    WHERE api_key_id = key_id AND month_year = current_month;
    
    IF current_usage >= monthly_quota THEN
        RETURN FALSE;
    END IF;
    
    -- Increment usage counter
    UPDATE quota_usage 
    SET requests_used = requests_used + 1
    WHERE api_key_id = key_id AND month_year = current_month;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;