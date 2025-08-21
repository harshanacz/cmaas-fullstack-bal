import ballerina/sql;
import ballerinax/postgresql;
import ballerina/log;
import gateway.config;

// Database connection and utilities

// Database connection pool
isolated sql:ConnectionPool connectionPool = {
    maxOpenConnections: 10,
    maxConnectionLifeTime: 1800,
    minIdleConnections: 1
};

// Database client instance
public isolated class DatabaseClient {
    private final postgresql:Client dbClient;

    public isolated function init(config:DatabaseConfig dbConfig) returns error? {
        self.dbClient = check new (
            host = dbConfig.host,
            port = dbConfig.port,
            database = dbConfig.database,
            username = dbConfig.username,
            password = dbConfig.password,
            connectionPool = connectionPool
        );
        
        log:printInfo("Database connection established");
    }

    // Get the database client for queries
    public isolated function getClient() returns postgresql:Client {
        return self.dbClient;
    }

    // Close the database connection
    public isolated function close() returns error? {
        return self.dbClient.close();
    }

    // Health check for database connection
    public isolated function healthCheck() returns boolean {
        sql:ExecutionResult|error result = self.dbClient->execute(`SELECT 1`);
        if result is error {
            log:printError("Database health check failed", result);
            return false;
        }
        return true;
    }
}

// Global database client instance (will be initialized in main)
public isolated DatabaseClient? dbClient = ();

// Initialize database connection
public isolated function initDatabase(config:DatabaseConfig dbConfig) returns error? {
    DatabaseClient client = check new(dbConfig);
    lock {
        dbClient = client;
    }
    log:printInfo("Database client initialized");
}

// Get database client instance
public isolated function getDatabase() returns DatabaseClient? {
    lock {
        return dbClient;
    }
}