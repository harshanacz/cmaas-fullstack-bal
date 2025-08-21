import ballerinax/postgresql;
import ballerina/io;
import gateway/api_gateway.config;

// Database connection and utilities

// Database client instance
public class DatabaseClient {
    private postgresql:Client dbClient;

    public function init(config:DatabaseConfig dbConfig) returns error? {
        self.dbClient = check new (
            host = dbConfig.host,
            port = dbConfig.port,
            database = dbConfig.database,
            username = dbConfig.username,
            password = dbConfig.password
        );
        
        io:println("Database connection established");
    }

    // Get the database client for queries
    public function getClient() returns postgresql:Client {
        return self.dbClient;
    }

    // Close the database connection
    public function close() returns error? {
        return self.dbClient.close();
    }

    // Health check for database connection
    public function healthCheck() returns boolean {
        var result = self.dbClient->execute(`SELECT 1`);
        if result is error {
            io:println("Database health check failed: " + result.message());
            return false;
        }
        return true;
    }
}

// Global database client instance (will be initialized in main)
DatabaseClient? dbClient = ();

// Initialize database connection
public function initDatabase(config:DatabaseConfig dbConfig) returns error? {
    DatabaseClient newClient = check new(dbConfig);
    dbClient = newClient;
    io:println("Database client initialized");
}

// Get database client instance
public function getDatabase() returns DatabaseClient? {
    return dbClient;
}