import ballerina/io;
import ballerina/log;
import ballerina/os;
import ballerina/sql;
import ballerinax/postgresql;
import ballerina/time;

// Data types
public type Developer record {|
    string id;
    string email;
    string passwordHash;
    time:Utc createdAt;
    time:Utc updatedAt;
    boolean isActive;
|};

public type APIKey record {|
    string id;
    string developerId;
    string keyValue;
    string? name;
    int monthlyQuota;
    time:Utc createdAt;
    time:Utc updatedAt;
    boolean isActive;
|};

public type QuotaUsage record {|
    string id;
    string apiKeyId;
    string monthYear;
    int requestsUsed;
    time:Utc lastReset;
    time:Utc createdAt;
    time:Utc updatedAt;
|};

public type RequestLog record {|
    string id;
    string? apiKeyId;
    string endpoint;
    string method;
    int statusCode;
    int? responseTimeMs;
    int? requestSizeBytes;
    int? responseSizeBytes;
    string? userAgent;
    string? ipAddress;
    time:Utc createdAt;
|};

// Database connection
postgresql:Client? dbClient = ();

// Helper function to get string environment variable with default
function getStringEnv(string key, string defaultValue) returns string {
    string? value = os:getEnv(key);
    return value ?: defaultValue;
}

// Helper function to get integer environment variable with default
function getIntEnv(string key, int defaultValue) returns int {
    string? value = os:getEnv(key);
    if value is () {
        return defaultValue;
    }
    
    int|error parsed = int:fromString(value);
    if parsed is error {
        log:printWarn("Invalid integer value for environment variable " + key + ": " + value + 
                     ". Using default: " + defaultValue.toString());
        return defaultValue;
    }
    
    return parsed;
}

// Initialize database connection
function initDatabase() returns error? {
    string host = getStringEnv("DB_HOST", "localhost");
    int port = getIntEnv("DB_PORT", 5432);
    string database = getStringEnv("DB_NAME", "gateway_db");
    string username = getStringEnv("DB_USER", "postgres");
    string password = getStringEnv("DB_PASSWORD", "password");
    
    postgresql:Client|sql:Error clientResult = new (
        host = host,
        port = port,
        database = database,
        username = username,
        password = password
    );
    
    if clientResult is sql:Error {
        log:printError("Failed to initialize database connection", 'error = clientResult);
        return clientResult;
    }
    
    dbClient = clientResult;
    log:printInfo("Database connection initialized successfully");
    
    // Test the connection
    sql:ExecutionResult|sql:Error result = clientResult->execute(`SELECT 1 as test`);
    if result is sql:Error {
        log:printError("Database connection test failed", 'error = result);
        return result;
    }
    
    log:printInfo("Database connection test successful");
    return;
}

// Run database migrations
function runMigrations() returns error? {
    log:printInfo("Starting database migrations...");
    
    if dbClient is () {
        return error("Database not initialized");
    }
    
    postgresql:Client dbConn = <postgresql:Client>dbClient;
    
    // Create migrations table if it doesn't exist
    sql:ExecutionResult|sql:Error result = dbConn->execute(`
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
    record {int count;}|sql:Error migrationCheck = dbConn->queryRow(`
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
    result = dbConn->execute(`
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
    result = dbConn->execute(`
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
    result = dbConn->execute(`
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
    result = dbConn->execute(`
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
    result = dbConn->execute(`CREATE INDEX IF NOT EXISTS idx_developers_email ON developers(email)`);
    if result is sql:Error {
        log:printError("Failed to create developers email index", 'error = result);
        return result;
    }
    
    result = dbConn->execute(`CREATE INDEX IF NOT EXISTS idx_api_keys_developer_id ON api_keys(developer_id)`);
    if result is sql:Error {
        log:printError("Failed to create api_keys developer_id index", 'error = result);
        return result;
    }
    
    result = dbConn->execute(`CREATE INDEX IF NOT EXISTS idx_api_keys_key_value ON api_keys(key_value)`);
    if result is sql:Error {
        log:printError("Failed to create api_keys key_value index", 'error = result);
        return result;
    }
    
    // Record the migration as applied
    result = dbConn->execute(`INSERT INTO schema_migrations (version, filename) VALUES (1, '001_initial_schema.sql')`);
    if result is sql:Error {
        log:printError("Failed to record migration", 'error = result);
        return result;
    }
    
    log:printInfo("Initial schema migration completed successfully");
    return;
}

// Close database connection
function closeDatabaseConnection() returns error? {
    if dbClient is postgresql:Client {
        postgresql:Client conn = <postgresql:Client>dbClient;
        check conn.close();
        dbClient = ();
        log:printInfo("Database connection closed");
    }
    return;
}

// Main entry point for the API Gateway
public function main() returns error? {
    log:printInfo("Starting Ballerina API Gateway...");
    
    // Print configuration summary
    log:printInfo("=== Configuration Summary ===");
    log:printInfo("Environment: " + getStringEnv("ENVIRONMENT", "development"));
    log:printInfo("Database Host: " + getStringEnv("DB_HOST", "localhost") + ":" + getIntEnv("DB_PORT", 5432).toString());
    log:printInfo("Database Name: " + getStringEnv("DB_NAME", "gateway_db"));
    log:printInfo("=============================");
    
    // Initialize database connection
    check initDatabase();
    
    // Run database migrations
    check runMigrations();
    
    // Start the HTTP listeners
    check startServices();
    
    log:printInfo("API Gateway started successfully");
    
    return;
}

// Function to start all HTTP services
function startServices() returns error? {
    // This will be implemented in subsequent tasks
    log:printInfo("Services initialization placeholder");
    return;
}

// Graceful shutdown handler
public function gracefulShutdown() returns error? {
    log:printInfo("Shutting down API Gateway...");
    
    // Close database connections
    check closeDatabaseConnection();
    
    log:printInfo("API Gateway shutdown complete");
    return;
}