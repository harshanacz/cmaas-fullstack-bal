// Database connection utilities and error handling
import ballerina/sql;
import ballerinax/postgresql;
import ballerina/os;
import ballerina/log;
import ballerina/time;
import gateway.config;

// Database connection pool
postgresql:Client? dbClient = ();

// Initialize database connection
public function initDatabase() returns error? {
    config:DatabaseConfig dbConfig = config:getDatabaseConfig();
    
    postgresql:Client|sql:Error client = new (
        host = dbConfig.host,
        port = dbConfig.port,
        database = dbConfig.database,
        username = dbConfig.username,
        password = dbConfig.password
    );
    
    if client is sql:Error {
        log:printError("Failed to initialize database connection", 'error = client);
        return client;
    }
    
    dbClient = client;
    log:printInfo("Database connection initialized successfully");
    
    // Test the connection
    sql:ExecutionResult|sql:Error result = client->execute(`SELECT 1 as test`);
    if result is sql:Error {
        log:printError("Database connection test failed", 'error = result);
        return result;
    }
    
    log:printInfo("Database connection test successful");
    return;
}

// Get database client instance
public function getDatabaseClient() returns postgresql:Client|error {
    if dbClient is () {
        return error("Database not initialized. Call initDatabase() first.");
    }
    return dbClient;
}

// Close database connection
public function closeDatabaseConnection() returns error? {
    if dbClient is postgresql:Client {
        check dbClient.close();
        dbClient = ();
        log:printInfo("Database connection closed");
    }
    return;
}



// Database error handling utilities

// Check if error is a connection error
public function isConnectionError(sql:Error err) returns boolean {
    string message = err.message();
    return message.includes("connection") || message.includes("timeout") || message.includes("refused");
}

// Check if error is a constraint violation
public function isConstraintViolationError(sql:Error err) returns boolean {
    string message = err.message();
    return message.includes("duplicate key") || message.includes("violates") || message.includes("constraint");
}

// Check if error is a not found error
public function isNotFoundError(sql:Error err) returns boolean {
    string message = err.message();
    return message.includes("no rows") || message.includes("not found");
}

// Error response type
public type ErrorResponse record {|
    int code;
    string message;
    string? details;
    time:Utc timestamp;
|};

// Convert SQL error to application error response
public function sqlErrorToResponse(sql:Error err) returns ErrorResponse {
    int code = 500;
    string message = "Internal server error";
    string details = err.message();
    
    if isConnectionError(err) {
        code = 503;
        message = "Database service unavailable";
    } else if isConstraintViolationError(err) {
        code = 409;
        message = "Data conflict - resource already exists";
    } else if isNotFoundError(err) {
        code = 404;
        message = "Resource not found";
    }
    
    return {
        code: code,
        message: message,
        details: details,
        timestamp: checkpanic time:utcNow()
    };
}

// Simple retry logic for database operations
public function retryDatabaseOperation(function() returns sql:ExecutionResult|sql:Error operation) returns sql:ExecutionResult|error {
    int maxRetries = 3;
    int attempts = 0;
    
    while attempts < maxRetries {
        sql:ExecutionResult|sql:Error result = operation();
        
        if result is sql:ExecutionResult {
            return result;
        }
        
        attempts += 1;
        
        // Only retry on connection errors
        if !isConnectionError(result) || attempts >= maxRetries {
            return result;
        }
        
        log:printWarn(string `Database operation failed, retrying... (attempt ${attempts}/${maxRetries})`);
    }
    
    return error("Maximum retry attempts exceeded");
}

// Health check function
public function checkDatabaseHealth() returns boolean {
    postgresql:Client|error client = getDatabaseClient();
    
    if client is error {
        return false;
    }
    
    sql:ExecutionResult|sql:Error result = client->execute(`SELECT 1 as health_check`);
    return result is sql:ExecutionResult;
}