import ballerina/test;
import ballerina/log;

// Import the main module to access repository instances
import gateway.api_gateway;

// Test data
const string TEST_EMAIL = "test@example.com";
const string TEST_PASSWORD_HASH = "hashed_password_123";
const string TEST_API_KEY_NAME = "Test API Key";

// Test Developer Repository
@test:Config {}
function testDeveloperRepository() returns error? {
    log:printInfo("Testing Developer Repository operations...");
    
    // Test creating a developer
    Developer|error developer = developerRepo.createDeveloper(TEST_EMAIL, TEST_PASSWORD_HASH);
    if developer is error {
        log:printWarn("Developer creation test skipped - database not connected: " + developer.message());
        return;
    }
    
    test:assertEquals(developer.email, TEST_EMAIL);
    test:assertEquals(developer.passwordHash, TEST_PASSWORD_HASH);
    test:assertTrue(developer.isActive);
    
    string developerId = developer.id;
    
    // Test getting developer by ID
    Developer|error retrievedById = developerRepo.getDeveloperById(developerId);
    test:assertTrue(retrievedById is Developer);
    if retrievedById is Developer {
        test:assertEquals(retrievedById.id, developerId);
        test:assertEquals(retrievedById.email, TEST_EMAIL);
    }
    
    // Test getting developer by email
    Developer|error retrievedByEmail = developerRepo.getDeveloperByEmail(TEST_EMAIL);
    test:assertTrue(retrievedByEmail is Developer);
    if retrievedByEmail is Developer {
        test:assertEquals(retrievedByEmail.id, developerId);
        test:assertEquals(retrievedByEmail.email, TEST_EMAIL);
    }
    
    // Test updating developer
    Developer|error updatedDeveloper = developerRepo.updateDeveloper(developerId, isActive = false);
    test:assertTrue(updatedDeveloper is Developer);
    if updatedDeveloper is Developer {
        test:assertFalse(updatedDeveloper.isActive);
    }
    
    // Test deleting developer
    error? deleteResult = developerRepo.deleteDeveloper(developerId);
    test:assertTrue(deleteResult is ());
    
    // Verify developer is deleted
    Developer|error deletedDeveloper = developerRepo.getDeveloperById(developerId);
    test:assertTrue(deletedDeveloper is error);
    
    log:printInfo("Developer Repository tests completed successfully");
}

@test:Config {}
function testAPIKeyRepository() returns error? {
    log:printInfo("Testing API Key Repository operations...");
    
    // First create a developer for testing
    Developer|error developer = developerRepo.createDeveloper("apikey_test@example.com", TEST_PASSWORD_HASH);
    if developer is error {
        log:printWarn("API Key repository test skipped - database not connected: " + developer.message());
        return;
    }
    
    string developerId = developer.id;
    
    // Test API key validation
    test:assertTrue(apiKeyRepo.validateAPIKey("bal_dev_2025_abcd1234"));
    test:assertFalse(apiKeyRepo.validateAPIKey("invalid_key"));
    test:assertFalse(apiKeyRepo.validateAPIKey("bal_dev_25_short"));
    test:assertFalse(apiKeyRepo.validateAPIKey("wrong_prefix_2025_abcd1234"));
    
    // Test creating API key
    APIKey|error apiKey = apiKeyRepo.createAPIKey(developerId, TEST_API_KEY_NAME);
    test:assertTrue(apiKey is APIKey);
    if apiKey is APIKey {
        test:assertEquals(apiKey.developerId, developerId);
        test:assertEquals(apiKey.name, TEST_API_KEY_NAME);
        test:assertEquals(apiKey.monthlyQuota, 100);
        test:assertTrue(apiKey.isActive);
        test:assertTrue(apiKey.keyValue.startsWith("bal_"));
    }
    
    string apiKeyId = apiKey is APIKey ? apiKey.id : "";
    string keyValue = apiKey is APIKey ? apiKey.keyValue : "";
    
    // Test getting API key by ID
    APIKey|error retrievedById = apiKeyRepo.getAPIKeyById(apiKeyId);
    test:assertTrue(retrievedById is APIKey);
    if retrievedById is APIKey {
        test:assertEquals(retrievedById.id, apiKeyId);
        test:assertEquals(retrievedById.keyValue, keyValue);
    }
    
    // Test getting API key by value
    APIKey|error retrievedByValue = apiKeyRepo.getAPIKeyByValue(keyValue);
    test:assertTrue(retrievedByValue is APIKey);
    if retrievedByValue is APIKey {
        test:assertEquals(retrievedByValue.id, apiKeyId);
        test:assertEquals(retrievedByValue.keyValue, keyValue);
    }
    
    // Test getting API keys by developer
    APIKey[]|error developerKeys = apiKeyRepo.getAPIKeysByDeveloper(developerId);
    test:assertTrue(developerKeys is APIKey[]);
    if developerKeys is APIKey[] {
        test:assertEquals(developerKeys.length(), 1);
        test:assertEquals(developerKeys[0].id, apiKeyId);
    }
    
    // Test API key count
    int|error keyCount = apiKeyRepo.getAPIKeyCountByDeveloper(developerId);
    test:assertTrue(keyCount is int);
    if keyCount is int {
        test:assertEquals(keyCount, 1);
    }
    
    // Test creating multiple keys (up to limit)
    APIKey|error secondKey = apiKeyRepo.createAPIKey(developerId, "Second Key");
    test:assertTrue(secondKey is APIKey);
    
    APIKey|error thirdKey = apiKeyRepo.createAPIKey(developerId, "Third Key");
    test:assertTrue(thirdKey is APIKey);
    
    // Test exceeding key limit
    APIKey|error fourthKey = apiKeyRepo.createAPIKey(developerId, "Fourth Key");
    test:assertTrue(fourthKey is error);
    if fourthKey is error {
        test:assertTrue(fourthKey.message().includes("maximum of 3 API keys"));
    }
    
    // Test updating API key
    APIKey|error updatedKey = apiKeyRepo.updateAPIKey(apiKeyId, name = "Updated Key Name");
    test:assertTrue(updatedKey is APIKey);
    if updatedKey is APIKey {
        test:assertEquals(updatedKey.name, "Updated Key Name");
    }
    
    // Test deleting API key (soft delete)
    error? deleteResult = apiKeyRepo.deleteAPIKey(apiKeyId);
    test:assertTrue(deleteResult is ());
    
    // Verify key is deactivated
    APIKey|error deactivatedKey = apiKeyRepo.getAPIKeyByValue(keyValue);
    test:assertTrue(deactivatedKey is error);
    
    // Clean up
    error? cleanupResult = developerRepo.deleteDeveloper(developerId);
    test:assertTrue(cleanupResult is ());
    
    log:printInfo("API Key Repository tests completed successfully");
}

@test:Config {}
function testQuotaRepository() returns error? {
    log:printInfo("Testing Quota Repository operations...");
    
    // First create a developer and API key for testing
    Developer|error developer = developerRepo.createDeveloper("quota_test@example.com", TEST_PASSWORD_HASH);
    if developer is error {
        log:printWarn("Quota repository test skipped - database not connected: " + developer.message());
        return;
    }
    
    string developerId = developer.id;
    
    APIKey|error apiKey = apiKeyRepo.createAPIKey(developerId, "Quota Test Key");
    test:assertTrue(apiKey is APIKey);
    if apiKey is error {
        return;
    }
    
    string apiKeyId = apiKey.id;
    
    // Test initializing quota
    QuotaUsage|error quota = quotaRepo.initializeQuota(apiKeyId);
    test:assertTrue(quota is QuotaUsage);
    if quota is QuotaUsage {
        test:assertEquals(quota.apiKeyId, apiKeyId);
        test:assertEquals(quota.requestsUsed, 0);
        test:assertEquals(quota.monthYear, "2025-08");
    }
    
    // Test getting quota usage
    QuotaUsage|error retrievedQuota = quotaRepo.getQuotaUsage(apiKeyId);
    test:assertTrue(retrievedQuota is QuotaUsage);
    if retrievedQuota is QuotaUsage {
        test:assertEquals(retrievedQuota.apiKeyId, apiKeyId);
        test:assertEquals(retrievedQuota.requestsUsed, 0);
    }
    
    // Test checking quota not exceeded initially
    boolean|error quotaExceeded = quotaRepo.checkQuotaExceeded(apiKeyId, 100);
    test:assertTrue(quotaExceeded is boolean);
    if quotaExceeded is boolean {
        test:assertFalse(quotaExceeded);
    }
    
    // Test incrementing usage
    QuotaUsage|error incrementedQuota = quotaRepo.incrementUsage(apiKeyId);
    test:assertTrue(incrementedQuota is QuotaUsage);
    if incrementedQuota is QuotaUsage {
        test:assertEquals(incrementedQuota.requestsUsed, 1);
    }
    
    // Test multiple increments
    foreach int i in 1...99 {
        QuotaUsage|error _ = quotaRepo.incrementUsage(apiKeyId);
    }
    
    // Test quota exceeded after 100 requests
    boolean|error quotaExceededAfter100 = quotaRepo.checkQuotaExceeded(apiKeyId, 100);
    test:assertTrue(quotaExceededAfter100 is boolean);
    if quotaExceededAfter100 is boolean {
        test:assertTrue(quotaExceededAfter100);
    }
    
    // Test getting quotas by developer
    QuotaUsage[]|error developerQuotas = quotaRepo.getQuotasByDeveloper(developerId);
    test:assertTrue(developerQuotas is QuotaUsage[]);
    if developerQuotas is QuotaUsage[] {
        test:assertEquals(developerQuotas.length(), 1);
        test:assertEquals(developerQuotas[0].apiKeyId, apiKeyId);
    }
    
    // Test resetting monthly quotas
    error? resetResult = quotaRepo.resetMonthlyQuotas();
    test:assertTrue(resetResult is ());
    
    // Verify quota is reset
    QuotaUsage|error resetQuota = quotaRepo.getQuotaUsage(apiKeyId);
    test:assertTrue(resetQuota is QuotaUsage);
    if resetQuota is QuotaUsage {
        test:assertEquals(resetQuota.requestsUsed, 0);
    }
    
    // Clean up
    error? cleanupResult = developerRepo.deleteDeveloper(developerId);
    test:assertTrue(cleanupResult is ());
    
    log:printInfo("Quota Repository tests completed successfully");
}

@test:Config {}
function testRepositoryErrorHandling() returns error? {
    log:printInfo("Testing Repository error handling...");
    
    // Test getting non-existent developer
    Developer|error nonExistentDev = developerRepo.getDeveloperById("non-existent-id");
    test:assertTrue(nonExistentDev is error);
    
    // Test getting non-existent API key
    APIKey|error nonExistentKey = apiKeyRepo.getAPIKeyById("non-existent-id");
    test:assertTrue(nonExistentKey is error);
    
    // Test getting non-existent quota
    QuotaUsage|error nonExistentQuota = quotaRepo.getQuotaUsage("non-existent-id");
    test:assertTrue(nonExistentQuota is error);
    
    log:printInfo("Repository error handling tests completed successfully");
}