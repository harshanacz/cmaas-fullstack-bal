import ballerina/time;

// Core data types for the API Gateway

// Developer account information
public type Developer record {
    string id;
    string email;
    string passwordHash;
    time:Utc createdAt;
    boolean isActive;
};

// API key with metadata
public type APIKey record {
    string id;
    string developerId;
    string keyValue;
    string name?;
    int monthlyQuota;
    time:Utc createdAt;
    boolean isActive;
};

// Quota usage tracking
public type QuotaUsage record {
    string id;
    string apiKeyId;
    string monthYear;
    int requestsUsed;
    time:Utc lastReset;
};

// Request analytics
public type RequestLog record {
    string id;
    string apiKeyId;
    string endpoint;
    int statusCode;
    int responseTimeMs;
    time:Utc createdAt;
};

// Request/Response types for API operations

// Request for API key creation
public type APIKeyRequest record {
    string name?;
};

// Response with API key details
public type APIKeyResponse record {
    string apiKey;
    int quotaLimit;
    int quotaRemaining;
    int rulesLimit;
    time:Utc createdAt;
};

// Developer registration request
public type DeveloperRegistrationRequest record {
    string email;
    string password;
};

// Developer login request
public type DeveloperLoginRequest record {
    string email;
    string password;
};

// JWT token response
public type TokenResponse record {
    string accessToken;
    string tokenType;
    int expiresIn;
};

// Error response format
public type ErrorResponse record {
    int code;
    string message;
    string details?;
    time:Utc timestamp;
};

// Rule management types
public type Rule record {
    string id;
    string apiKey;
    string ruleText;
    time:Utc createdAt;
};

public type RuleRequest record {
    string ruleText;
};