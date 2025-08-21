import ballerina/os;

// Configuration management for the API Gateway

// Database configuration
public type DatabaseConfig record {
    string host;
    int port;
    string database;
    string username;
    string password;
    int maxPoolSize;
};

// JWT configuration
public type JWTConfig record {
    string secretKey;
    int expirationTime; // in seconds
    string issuer;
};

// Python service configuration
public type PythonServiceConfig record {
    string baseUrl;
    int timeoutMs;
    int retryAttempts;
};

// Rate limiting configuration
public type RateLimitConfig record {
    int requestsPerMinute;
    int burstLimit;
};

// Application configuration
public type AppConfig record {
    DatabaseConfig database;
    JWTConfig jwt;
    PythonServiceConfig pythonService;
    RateLimitConfig rateLimit;
    int serverPort;
};

// Load configuration from environment variables
public function loadConfig() returns AppConfig {
    string dbHost = os:getEnv("DB_HOST");
    string dbName = os:getEnv("DB_NAME");
    string dbUser = os:getEnv("DB_USER");
    string dbPassword = os:getEnv("DB_PASSWORD");
    string jwtSecret = os:getEnv("JWT_SECRET");
    string jwtIssuer = os:getEnv("JWT_ISSUER");
    string pythonUrl = os:getEnv("PYTHON_SERVICE_URL");
    
    return {
        database: {
            host: dbHost != "" ? dbHost : "localhost",
            port: getIntEnv("DB_PORT", 5432),
            database: dbName != "" ? dbName : "gateway_db",
            username: dbUser != "" ? dbUser : "gateway_user",
            password: dbPassword != "" ? dbPassword : "gateway_pass",
            maxPoolSize: getIntEnv("DB_MAX_POOL_SIZE", 10)
        },
        jwt: {
            secretKey: jwtSecret != "" ? jwtSecret : "default-secret-key-change-in-production",
            expirationTime: getIntEnv("JWT_EXPIRATION", 3600), // 1 hour
            issuer: jwtIssuer != "" ? jwtIssuer : "ballerina-gateway"
        },
        pythonService: {
            baseUrl: pythonUrl != "" ? pythonUrl : "http://localhost:8001",
            timeoutMs: getIntEnv("PYTHON_SERVICE_TIMEOUT", 30000),
            retryAttempts: getIntEnv("PYTHON_SERVICE_RETRIES", 3)
        },
        rateLimit: {
            requestsPerMinute: getIntEnv("RATE_LIMIT_PER_MINUTE", 10),
            burstLimit: getIntEnv("RATE_LIMIT_BURST", 20)
        },
        serverPort: getIntEnv("SERVER_PORT", 8080)
    };
}

// Helper function to get integer environment variables with defaults
function getIntEnv(string key, int defaultValue) returns int {
    string? envValue = os:getEnv(key);
    if envValue is string {
        int|error result = int:fromString(envValue);
        if result is int {
            return result;
        }
    }
    return defaultValue;
}