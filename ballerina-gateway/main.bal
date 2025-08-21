import ballerina/io;
import ballerina/log;
import gateway.database as db;
import gateway.config;

// Main entry point for the API Gateway
public function main() returns error? {
    log:printInfo("Starting Ballerina API Gateway...");
    
    // Validate configuration
    check config:validateConfig();
    config:printConfigSummary();
    
    // Initialize database connection
    check db:initDatabase();
    
    // Run database migrations
    check db:runMigrations();
    
    // Start the HTTP listeners
    check startServices();
    
    log:printInfo("API Gateway started successfully");
    
    // Keep the main thread alive
    // This will be replaced with actual HTTP service listeners in subsequent tasks
    
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
    check db:closeDatabaseConnection();
    
    log:printInfo("API Gateway shutdown complete");
    return;
}