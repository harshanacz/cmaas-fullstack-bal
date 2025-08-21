
import ballerina/log;
import ballerina/os;

// Data types
public type Developer record {|
    string id;
    string email;
    string passwordHash;
    string createdAt;
    string updatedAt;
    boolean isActive;
|};

public type APIKey record {|
    string id;
    string developerId;
    string keyValue;
    string? name;
    int monthlyQuota;
    string createdAt;
    string updatedAt;
    boolean isActive;
|};

public type QuotaUsage record {|
    string id;
    string apiKeyId;
    string monthYear;
    int requestsUsed;
    string lastReset;
    string createdAt;
    string updatedAt;
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
    string createdAt;
|};

// Error response type
public type ErrorResponse record {|
    int code;
    string message;
    string? details;
    string timestamp;
|};

// Request types for API operations
public type DeveloperRegistrationRequest record {|
    string email;
    string password;
|};

public type DeveloperLoginRequest record {|
    string email;
    string password;
|};

public type APIKeyRequest record {|
    string? name;
|};

// Response types
public type DeveloperResponse record {|
    string id;
    string email;
    string createdAt;
    boolean isActive;
|};

public type APIKeyResponse record {|
    string id;
    string keyValue;
    string? name;
    int monthlyQuota;
    int quotaUsed;
    int quotaRemaining;
    string createdAt;
    boolean isActive;
|};

public type QuotaInfo record {|
    string apiKey;
    int monthlyQuota;
    int currentUsage;
    string resetDate;
    boolean isActive;
|};

// Database connection placeholder (will be implemented in task 2.2)
// postgresql:Client? dbClient = ();

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

// Database connection utilities (placeholder for task 2.2)
// These will be implemented in the next task when we create the repository layer

function initDatabase() returns error? {
    log:printInfo("Database initialization placeholder - will be implemented in task 2.2");
    return;
}

function runMigrations() returns error? {
    log:printInfo("Database migrations placeholder - will be implemented in task 2.2");
    return;
}

function closeDatabaseConnection() returns error? {
    log:printInfo("Database connection close placeholder - will be implemented in task 2.2");
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
    
    // Test data types
    log:printInfo("Testing data types...");
    
    Developer testDev = {
        id: "test-id",
        email: "test@example.com",
        passwordHash: "hashed-password",
        createdAt: "2025-08-21T10:00:00Z",
        updatedAt: "2025-08-21T10:00:00Z",
        isActive: true
    };
    
    log:printInfo("Created test developer: " + testDev.email);
    
    APIKey testKey = {
        id: "key-id",
        developerId: testDev.id,
        keyValue: "bal_dev_2025_test123",
        name: "Test Key",
        monthlyQuota: 100,
        createdAt: "2025-08-21T10:00:00Z",
        updatedAt: "2025-08-21T10:00:00Z",
        isActive: true
    };
    
    log:printInfo("Created test API key: " + testKey.keyValue);
    
    QuotaUsage testQuota = {
        id: "quota-id",
        apiKeyId: testKey.id,
        monthYear: "2025-08",
        requestsUsed: 0,
        lastReset: "2025-08-01T00:00:00Z",
        createdAt: "2025-08-21T10:00:00Z",
        updatedAt: "2025-08-21T10:00:00Z"
    };
    
    log:printInfo("Created test quota usage for month: " + testQuota.monthYear);
    
    RequestLog testLog = {
        id: "log-id",
        apiKeyId: testKey.id,
        endpoint: "/api/v1/moderation/moderate",
        method: "POST",
        statusCode: 200,
        responseTimeMs: 150,
        requestSizeBytes: 1024,
        responseSizeBytes: 512,
        userAgent: "TestClient/1.0",
        ipAddress: "192.168.1.1",
        createdAt: "2025-08-21T10:00:00Z"
    };
    
    log:printInfo("Created test request log for endpoint: " + testLog.endpoint);
    
    // Initialize database connection
    check initDatabase();
    
    // Run database migrations
    check runMigrations();
    
    // Start the HTTP listeners
    check startServices();
    
    log:printInfo("API Gateway started successfully");
    log:printInfo("Task 2.1 - Ballerina data types and database records - COMPLETED");
    
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