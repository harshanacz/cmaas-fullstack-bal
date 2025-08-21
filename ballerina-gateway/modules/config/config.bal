// Configuration management for the API Gateway
import ballerina/os;
import ballerina/log;
import ballerina/lang.regexp;

// Local type definitions for configuration
public type DatabaseConfig record {|
    string host;
    int port;
    string database;
    string username;
    string password;
    int maxPoolSize;
    int connectionTimeoutSeconds;
|};

public type JWTConfig record {|
    string secretKey;
    int expirationHours;
    string issuer;
|};

public type RateLimitConfig record {|
    int requestsPerMinute;
    int burstLimit;
    int windowSizeMinutes;
|};

public type AppConfig record {|
    DatabaseConfig database;
    JWTConfig jwt;
    RateLimitConfig rateLimit;
    string pythonServiceUrl;
    string environment;
|};

// Get complete application configuration
public function getAppConfig() returns AppConfig {
    return {
        database: getDatabaseConfig(),
        jwt: getJWTConfig(),
        rateLimit: getRateLimitConfig(),
        pythonServiceUrl: getPythonServiceUrl(),
        environment: getEnvironment()
    };
}

// Get database configuration from environment variables
public function getDatabaseConfig() returns DatabaseConfig {
    return {
        host: getStringEnv("DB_HOST", "localhost"),
        port: getIntEnv("DB_PORT", 5432),
        database: getStringEnv("DB_NAME", "gateway_db"),
        username: getStringEnv("DB_USER", "postgres"),
        password: getStringEnv("DB_PASSWORD", "password"),
        maxPoolSize: getIntEnv("DB_MAX_POOL_SIZE", 10),
        connectionTimeoutSeconds: getIntEnv("DB_CONNECTION_TIMEOUT", 30)
    };
}

// Get JWT configuration from environment variables
public function getJWTConfig() returns JWTConfig {
    return {
        secretKey: getStringEnv("JWT_SECRET", "default-secret-key-change-in-production"),
        expirationHours: getIntEnv("JWT_EXPIRATION_HOURS", 24),
        issuer: getStringEnv("JWT_ISSUER", "ballerina-api-gateway")
    };
}

// Get rate limiting configuration from environment variables
public function getRateLimitConfig() returns RateLimitConfig {
    return {
        requestsPerMinute: getIntEnv("RATE_LIMIT_REQUESTS_PER_MINUTE", 10),
        burstLimit: getIntEnv("RATE_LIMIT_BURST", 20),
        windowSizeMinutes: getIntEnv("RATE_LIMIT_WINDOW_MINUTES", 1)
    };
}

// Get Python service URL
public function getPythonServiceUrl() returns string {
    return getStringEnv("PYTHON_SERVICE_URL", "http://localhost:8001");
}

// Get environment name
public function getEnvironment() returns string {
    return getStringEnv("ENVIRONMENT", "development");
}

// Get server port
public function getServerPort() returns int {
    return getIntEnv("SERVER_PORT", 8080);
}

// Get CORS allowed origins
public function getCorsAllowedOrigins() returns string[] {
    string origins = getStringEnv("CORS_ALLOWED_ORIGINS", "http://localhost:3000");
    return regexp:split(re `,`, origins);
}

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

// Helper function to get boolean environment variable with default
public function getBoolEnv(string key, boolean defaultValue) returns boolean {
    string? value = os:getEnv(key);
    if value is () {
        return defaultValue;
    }
    
    string lowerValue = value.toLowerAscii();
    if lowerValue == "true" || lowerValue == "1" || lowerValue == "yes" {
        return true;
    } else if lowerValue == "false" || lowerValue == "0" || lowerValue == "no" {
        return false;
    }
    
    log:printWarn("Invalid boolean value for environment variable " + key + ": " + value + 
                 ". Using default: " + defaultValue.toString());
    return defaultValue;
}

// Validate configuration
public function validateConfig() returns error? {
    AppConfig config = getAppConfig();
    
    // Validate database configuration
    if config.database.host.trim().length() == 0 {
        return error("Database host cannot be empty");
    }
    
    if config.database.port <= 0 || config.database.port > 65535 {
        return error("Database port must be between 1 and 65535");
    }
    
    if config.database.database.trim().length() == 0 {
        return error("Database name cannot be empty");
    }
    
    if config.database.username.trim().length() == 0 {
        return error("Database username cannot be empty");
    }
    
    // Validate JWT configuration
    if config.jwt.secretKey.length() < 32 {
        log:printWarn("JWT secret key is shorter than recommended 32 characters");
    }
    
    if config.jwt.expirationHours <= 0 {
        return error("JWT expiration hours must be positive");
    }
    
    // Validate rate limiting configuration
    if config.rateLimit.requestsPerMinute <= 0 {
        return error("Rate limit requests per minute must be positive");
    }
    
    if config.rateLimit.burstLimit < config.rateLimit.requestsPerMinute {
        return error("Rate limit burst must be greater than or equal to requests per minute");
    }
    
    // Validate Python service URL
    if config.pythonServiceUrl.trim().length() == 0 {
        return error("Python service URL cannot be empty");
    }
    
    log:printInfo("Configuration validation passed");
    return;
}

// Print configuration summary (without sensitive data)
public function printConfigSummary() {
    AppConfig config = getAppConfig();
    
    log:printInfo("=== Configuration Summary ===");
    log:printInfo("Environment: " + config.environment);
    log:printInfo("Server Port: " + getServerPort().toString());
    log:printInfo("Database Host: " + config.database.host + ":" + config.database.port.toString());
    log:printInfo("Database Name: " + config.database.database);
    log:printInfo("Database Max Pool Size: " + config.database.maxPoolSize.toString());
    log:printInfo("JWT Expiration: " + config.jwt.expirationHours.toString() + " hours");
    log:printInfo("Rate Limit: " + config.rateLimit.requestsPerMinute.toString() + " requests/minute");
    log:printInfo("Rate Limit Burst: " + config.rateLimit.burstLimit.toString());
    log:printInfo("Python Service URL: " + config.pythonServiceUrl);
    log:printInfo("CORS Origins: " + getCorsAllowedOrigins().toString());
    log:printInfo("=============================");
}