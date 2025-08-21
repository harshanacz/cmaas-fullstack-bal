// Simple database migration utilities
import ballerina/sql;
import ballerina/log;

// Run database migrations
public function runMigrations() returns error? {
    log:printInfo("Starting database migrations...");
    
    postgresql:Client client = check getDatabaseClient();
    
    // Create migrations table if it doesn't exist
    sql:ExecutionResult|sql:Error result = client->execute(`
        CREATE TABLE IF NOT EXISTS schema_migrations (
            version INTEGER PRIMARY KEY,
            filename VARCHAR(255) NOT NULL,
            applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        )
    `);
    
    if result is sql:Error {
        log:printError("Failed to create migrations table", 'error = result);
        return result;
    }
    
    // Check if initial schema is already applied
    record {int count;}|sql:Error migrationCheck = client->queryRow(`
        SELECT COUNT(*) as count FROM schema_migrations WHERE version = 1
    `);
    
    if migrationCheck is sql:Error {
        log:printError("Failed to check migration status", 'error = migrationCheck);
        return migrationCheck;
    }
    
    if migrationCheck.count > 0 {
        log:printInfo("Initial schema migration already applied");
        return;
    }
    
    // Apply initial schema migration
    log:printInfo("Applying initial schema migration...");
    
    // Create developers table
    result = client->execute(`
        CREATE TABLE IF NOT EXISTS developers (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            email VARCHAR(255) UNIQUE NOT NULL,
            password_hash VARCHAR(255) NOT NULL,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            is_active BOOLEAN DEFAULT true
        )
    `);
    
    if result is sql:Error {
        log:printError("Failed to create developers table", 'error = result);
        return result;
    }
    
    // Create API keys table
    result = client->execute(`
        CREATE TABLE IF NOT EXISTS api_keys (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            developer_id UUID NOT NULL REFERENCES developers(id) ON DELETE CASCADE,
            key_value VARCHAR(255) UNIQUE NOT NULL,
            name VARCHAR(100),
            monthly_quota INTEGER DEFAULT 100,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            is_active BOOLEAN DEFAULT true
        )
    `);
    
    if result is sql:Error {
        log:printError("Failed to create api_keys table", 'error = result);
        return result;
    }
    
    // Create quota usage table
    result = client->execute(`
        CREATE TABLE IF NOT EXISTS quota_usage (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            api_key_id UUID NOT NULL REFERENCES api_keys(id) ON DELETE CASCADE,
            month_year VARCHAR(7) NOT NULL,
            requests_used INTEGER DEFAULT 0,
            last_reset TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            UNIQUE(api_key_id, month_year)
        )
    `);
    
    if result is sql:Error {
        log:printError("Failed to create quota_usage table", 'error = result);
        return result;
    }
    
    // Create request logs table
    result = client->execute(`
        CREATE TABLE IF NOT EXISTS request_logs (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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
        )
    `);
    
    if result is sql:Error {
        log:printError("Failed to create request_logs table", 'error = result);
        return result;
    }
    
    // Create indexes
    result = client->execute(`
        CREATE INDEX IF NOT EXISTS idx_developers_email ON developers(email)
    `);
    
    if result is sql:Error {
        log:printError("Failed to create developers email index", 'error = result);
        return result;
    }
    
    result = client->execute(`
        CREATE INDEX IF NOT EXISTS idx_api_keys_developer_id ON api_keys(developer_id)
    `);
    
    if result is sql:Error {
        log:printError("Failed to create api_keys developer_id index", 'error = result);
        return result;
    }
    
    result = client->execute(`
        CREATE INDEX IF NOT EXISTS idx_api_keys_key_value ON api_keys(key_value)
    `);
    
    if result is sql:Error {
        log:printError("Failed to create api_keys key_value index", 'error = result);
        return result;
    }
    
    // Record the migration as applied
    result = client->execute(`
        INSERT INTO schema_migrations (version, filename) 
        VALUES (1, '001_initial_schema.sql')
    `);
    
    if result is sql:Error {
        log:printError("Failed to record migration", 'error = result);
        return result;
    }
    
    log:printInfo("Initial schema migration completed successfully");
    return;
}