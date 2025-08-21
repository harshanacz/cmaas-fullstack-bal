# Ballerina API Gateway Integration Guide for RAG Moderation API

This guide explains how to integrate the RAG Moderation Python service with **Ballerina API Gateway** for production deployment, including developer management, API key creation, and quota limits.

## 🏗️ **Ballerina API Gateway Architecture**

```
┌─────────────────┐    ┌─────────────────────┐    ┌─────────────────┐
│   Developers    │───▶│ Ballerina Gateway   │───▶│ RAG Moderation  │
│                 │    │                     │    │ Python Service  │
│ - Register      │    │ - Developer Login   │    │ - FastAPI       │
│ - Login         │    │ - API Key Creation  │    │ - ChromaDB      │
│ - Manage Keys   │    │ - Quota Management  │    │ - Gemini AI     │
│ - Create Rules  │    │ - Rate Limiting     │    │ - Rule Storage  │
└─────────────────┘    └─────────────────────┘    └─────────────────┘
```

### **🔑 Ballerina Gateway Management:**

#### **Developer Portal Features:**
- **User Registration & Login**: Developer account management
- **API Key Creation**: Up to 3 API keys per developer
- **Quota Management**: 100 free requests per month per key
- **Rule Management**: Web interface for creating/managing rules
- **Usage Analytics**: Request counts, remaining quota

#### **API Key Structure:**
- **Purpose**: Authenticate and organize rules in Python service
- **Format**: Ballerina-generated keys
- **Example**: `bal_dev_2025_abc123def456`
- **Limits**: Maximum 3 keys per developer account

## 🔧 **Ballerina Gateway Configuration**

### **1. Developer Portal Setup**

#### **Developer Registration Flow:**
```ballerina
// Developer registration endpoint
service /developer on new http:Listener(8080) {
    resource function post register(DeveloperRegistration registration) returns http:Response {
        // Create developer account
        // Send verification email
        // Initialize quota (100 requests/month)
        // Max 3 API keys per developer
    }
    
    resource function post login(LoginCredentials credentials) returns AuthResponse {
        // Authenticate developer
        // Return JWT token for portal access
        // Include developer_id and permissions
    }
}
```

#### **API Key Management:**
```ballerina
// API Key management service
service /api-keys on new http:Listener(8080) {
    resource function post create(http:Request req) returns APIKeyResponse|http:BadRequest {
        string developerId = extractDeveloperFromToken(req);
        
        // Check key limit (max 3 per developer)
        if (getKeyCount(developerId) >= 3) {
            return http:BAD_REQUEST;
        }
        
        // Generate new API key
        string apiKey = generateAPIKey(developerId);
        
        // Initialize quota (100 requests/month)
        initializeQuota(apiKey, 100);
        
        return {
            api_key: apiKey,
            quota_remaining: 100,
            created_at: time:utcNow()
        };
    }
    
    resource function get list(http:Request req) returns APIKey[] {
        string developerId = extractDeveloperFromToken(req);
        return getDeveloperAPIKeys(developerId);
    }
    
    resource function delete [string keyId](http:Request req) returns http:Response {
        string developerId = extractDeveloperFromToken(req);
        return revokeAPIKey(developerId, keyId);
    }
}
```

### **2. Quota Management System**

#### **Rate Limiting & Quota Enforcement:**
```ballerina
// Quota enforcement interceptor
service class QuotaInterceptor {
    public function onRequest(http:Request req) returns http:Response? {
        string apiKey = req.getHeader("X-API-Key");
        
        // Check if API key exists and is active
        APIKeyInfo? keyInfo = getAPIKeyInfo(apiKey);
        if (keyInfo is ()) {
            return createUnauthorizedResponse("Invalid API key");
        }
        
        // Check monthly quota
        int quotaUsed = getMonthlyUsage(apiKey);
        if (quotaUsed >= keyInfo.monthlyQuota) {
            return createQuotaExceededResponse();
        }
        
        // Increment usage counter
        incrementUsage(apiKey);
        
        return (); // Continue to backend
    }
}
```

### **3. Rule Management Interface**

#### **Web Portal for Rule Creation:**
```ballerina
// Rule management endpoints
service /rules on new http:Listener(8080) {
    resource function post create(http:Request req, RuleCreationRequest ruleReq) returns RuleResponse {
        string developerId = extractDeveloperFromToken(req);
        string apiKey = ruleReq.api_key;
        
        // Verify API key belongs to developer
        if (!verifyKeyOwnership(developerId, apiKey)) {
            return createForbiddenResponse();
        }
        
        // Forward to Python service
        return forwardToPythonService("/add-rule/", ruleReq);
    }
    
    resource function get list/[string apiKey](http:Request req) returns Rule[] {
        string developerId = extractDeveloperFromToken(req);
        
        // Verify ownership
        if (!verifyKeyOwnership(developerId, apiKey)) {
            return createForbiddenResponse();
        }
        
        // Get rules from Python service
        return getRulesFromPythonService(apiKey);
    }
}
```

## 🔐 **Ballerina Gateway Features**

### **1. Developer Account Management**

#### **Developer Limits & Quotas:**
```json
{
  "developer_limits": {
    "max_api_keys": 3,
    "quota_per_key": {
      "free_tier": {
        "requests_per_month": 100,
        "rules_per_key": 10,
        "max_rule_length": 500
      }
    },
    "rate_limiting": {
      "requests_per_minute": 10,
      "burst_limit": 20
    }
  }
}
```

#### **API Key Structure:**
```
Format: bal_{env}_{year}_{random}
Examples:
- bal_dev_2025_abc123def456    (Development key)
- bal_prod_2025_xyz789uvw012   (Production key)
- bal_test_2025_mno345pqr678   (Testing key)

Key Metadata:
{
  "key_id": "bal_prod_2025_xyz789uvw012",
  "developer_id": "dev_john_doe_001",
  "created_at": "2025-08-21T10:00:00Z",
  "quota_used": 25,
  "quota_remaining": 75,
  "rules_count": 3,
  "last_used": "2025-08-21T14:30:00Z",
  "status": "active"
}
```

### **2. Quota Management System**

#### **Monthly Quota Tracking:**
```ballerina
type QuotaInfo record {
    string apiKey;
    int monthlyQuota;     // 100 for free tier
    int currentUsage;     // Current month usage
    time:Utc resetDate;   // Next reset date
    boolean isActive;     // Key status
};

// Quota management functions
function checkQuota(string apiKey) returns boolean {
    QuotaInfo? quota = getQuotaInfo(apiKey);
    if (quota is ()) {
        return false;
    }
    return quota.currentUsage < quota.monthlyQuota;
}

function incrementUsage(string apiKey) {
    // Increment monthly counter
    // Log usage for analytics
    // Check if quota exceeded
}
```

### **3. Rule Management Limits**

#### **Rule Constraints:**
```json
{
  "rule_limits": {
    "max_rules_per_api_key": 10,
    "max_rule_length_chars": 500,
    "allowed_rule_types": [
      "content_filtering",
      "profanity_detection", 
      "spam_detection",
      "topic_restriction"
    ],
    "rule_creation_rate_limit": "5 per hour"
  }
}
```

#### **Rule Validation:**
```ballerina
type RuleValidationResult record {
    boolean isValid;
    string[] errors;
    int characterCount;
    boolean withinLimits;
};

function validateRule(string apiKey, string ruleText) returns RuleValidationResult {
    RuleValidationResult result = {
        isValid: true,
        errors: [],
        characterCount: ruleText.length(),
        withinLimits: true
    };
    
    // Check rule count limit
    int currentRules = getRuleCount(apiKey);
    if (currentRules >= 10) {
        result.errors.push("Maximum 10 rules per API key exceeded");
        result.isValid = false;
    }
    
    // Check rule length
    if (ruleText.length() > 500) {
        result.errors.push("Rule text exceeds 500 character limit");
        result.isValid = false;
        result.withinLimits = false;
    }
    
    return result;
}
```

## 📋 **Integration Implementation Steps**

### **Step 1: Ballerina Gateway Setup**

#### **1.1 Developer Portal Service:**
```ballerina
// main.bal - Developer portal service
import ballerina/http;
import ballerina/jwt;
import ballerina/time;

service /portal on new http:Listener(8080) {
    
    // Developer registration
    resource function post register(DeveloperRegistration registration) returns http:Response {
        // Validate email and create account
        string developerId = createDeveloperAccount(registration);
        
        // Initialize quotas and limits
        initializeDeveloperLimits(developerId);
        
        return new http:Response();
    }
    
    // API key creation (max 3 per developer)
    resource function post api-keys(http:Request req, APIKeyRequest keyReq) returns APIKeyResponse|http:BadRequest {
        string developerId = extractDeveloperFromJWT(req);
        
        // Check API key limit
        int currentKeys = getAPIKeyCount(developerId);
        if (currentKeys >= 3) {
            return <http:BadRequest>{ body: "Maximum 3 API keys allowed per developer" };
        }
        
        // Generate API key
        string apiKey = generateAPIKey("bal", developerId);
        
        // Store with quota (100 requests/month)
        storeAPIKey(apiKey, developerId, 100);
        
        return {
            api_key: apiKey,
            quota_limit: 100,
            quota_remaining: 100,
            rules_limit: 10
        };
    }
}
```

#### **1.2 Proxy Service to Python Backend:**
```ballerina
// proxy.bal - Routes requests to Python service
service /api/v1 on new http:Listener(8080) {
    
    // Quota enforcement interceptor
    http:Interceptor quotaInterceptor = new QuotaInterceptor();
    
    // Proxy to Python service
    resource function post moderation/add\-rule(http:Request req) returns http:Response|http:ClientError {
        // Extract and validate API key
        string apiKey = req.getHeader("X-API-Key");
        
        // Check quota before forwarding
        if (!checkAndDecrementQuota(apiKey)) {
            return createQuotaExceededResponse();
        }
        
        // Forward to Python service
        return forwardToPythonService("http://python-service:8000/add-rule/", req);
    }
    
    resource function post moderation/moderate(http:Request req) returns http:Response|http:ClientError {
        string apiKey = req.getHeader("X-API-Key");
        
        if (!checkAndDecrementQuota(apiKey)) {
            return createQuotaExceededResponse();
        }
        
        return forwardToPythonService("http://python-service:8000/moderate/", req);
    }
}
```

### **Step 2: Python Service Integration**

#### **2.1 Update Python Service for Ballerina:**
```python
# app/core/config.py - Updated for Ballerina integration
class Settings:
    # Ballerina gateway integration
    BALLERINA_GATEWAY_URL: str = os.getenv("BALLERINA_GATEWAY_URL", "http://localhost:8080")
    BALLERINA_AUTH_ENABLED: bool = os.getenv("BALLERINA_AUTH_ENABLED", "true").lower() == "true"
    
    # Service configuration
    ALLOWED_API_KEY_PREFIX: str = "bal_"  # Only accept Ballerina keys
    GEMINI_API_KEY: str = os.getenv("GEMINI_API_KEY")
    
    # Rule limits (enforced by Ballerina, but validated here too)
    MAX_RULES_PER_API_KEY: int = 10
    MAX_RULE_LENGTH: int = 500
```

#### **2.2 Enhanced Middleware for Ballerina Keys:**
```python
# app/middleware.py - Ballerina-specific middleware
from fastapi import Request, HTTPException
import re

async def ballerina_auth_middleware(request: Request, call_next):
    """Middleware for Ballerina API Gateway integration"""
    
    if request.method == "OPTIONS":
        return await call_next(request)
    
    # Extract API key
    api_key = request.headers.get("X-API-Key")
    if not api_key:
        raise HTTPException(status_code=401, detail="API key required")
    
    # Validate Ballerina key format
    if not api_key.startswith("bal_"):
        raise HTTPException(status_code=403, detail="Invalid API key format")
    
    # Validate key pattern: bal_{env}_{year}_{random}
    pattern = r'^bal_[a-z]+_\d{4}_[a-z0-9]+$'
    if not re.match(pattern, api_key):
        raise HTTPException(status_code=403, detail="Malformed API key")
    
    # Add to request state
    request.state.api_key = api_key
    
    return await call_next(request)
```

### **Step 3: Developer Portal Frontend**

#### **3.1 API Key Management UI:**
```javascript
// portal-dashboard.js
class DeveloperPortal {
    constructor(baseUrl, authToken) {
        this.baseUrl = baseUrl;
        this.authToken = authToken;
    }
    
    async getAPIKeys() {
        const response = await fetch(`${this.baseUrl}/api-keys`, {
            headers: { 'Authorization': `Bearer ${this.authToken}` }
        });
        return response.json();
    }
    
    async createAPIKey(keyName) {
        const response = await fetch(`${this.baseUrl}/api-keys`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${this.authToken}`
            },
            body: JSON.stringify({ name: keyName })
        });
        
        if (response.status === 400) {
            throw new Error('Maximum 3 API keys allowed');
        }
        
        return response.json();
    }
    
    async getQuotaUsage(apiKey) {
        const response = await fetch(`${this.baseUrl}/quota/${apiKey}`, {
            headers: { 'Authorization': `Bearer ${this.authToken}` }
        });
        return response.json();
    }
}
```

#### **3.2 Rule Management Interface:**
```html
<!-- rule-manager.html -->
<div class="rule-manager">
    <h3>Rule Management</h3>
    
    <div class="api-key-selector">
        <label>Select API Key:</label>
        <select id="apiKeySelect">
            <!-- Populated with user's API keys -->
        </select>
        <span class="quota">Quota: <span id="quotaRemaining">75</span>/100</span>
    </div>
    
    <div class="rule-creation">
        <h4>Create New Rule</h4>
        <input type="text" id="ruleId" placeholder="Rule ID" maxlength="50">
        <textarea id="ruleText" placeholder="Rule description..." maxlength="500"></textarea>
        <div class="char-count"><span id="charCount">0</span>/500 characters</div>
        <div class="rule-count">Rules: <span id="ruleCount">3</span>/10</div>
        <button onclick="createRule()">Create Rule</button>
    </div>
    
    <div class="existing-rules">
        <h4>Existing Rules</h4>
        <div id="rulesList">
            <!-- Rules populated here -->
        </div>
    </div>
</div>
```

## � **Deployment Architecture**

### **Ballerina + Python Service Deployment:**
```yaml
# docker-compose.yml
version: '3.8'
services:
  ballerina-gateway:
    image: ballerina/ballerina:latest
    ports:
      - "8080:8080"    # Developer portal
      - "8443:8443"    # HTTPS
    environment:
      - DATABASE_URL=postgresql://postgres:password@db:5432/gateway_db
      - JWT_SECRET=${JWT_SECRET}
      - PYTHON_SERVICE_URL=http://rag-moderation:8000
    volumes:
      - ./ballerina-config:/home/ballerina/config
    depends_on:
      - db
      - rag-moderation
    
  rag-moderation:
    image: rag-moderation:latest
    ports:
      - "8000:8000"
    environment:
      - GEMINI_API_KEY=${GEMINI_API_KEY}
      - BALLERINA_AUTH_ENABLED=true
      - ALLOWED_API_KEY_PREFIX=bal_
    volumes:
      - ./chroma_db:/app/chroma_db
    
  db:
    image: postgres:13
    environment:
      - POSTGRES_DB=gateway_db
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=password
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

## 🔄 **Ballerina Gateway Workflow**

### **1. Developer Onboarding:**
```
1. Developer registers at portal.example.com
2. Email verification and account activation
3. Login to developer dashboard
4. Create API keys (max 3) with 100 requests/month each
5. Start creating rules and testing moderation
```

### **2. API Key Usage Flow:**
```
┌─────────────────┐    ┌─────────────────────┐    ┌─────────────────┐
│   Client App    │───▶│ Ballerina Gateway   │───▶│ Python Service  │
│                 │    │                     │    │                 │
│ X-API-Key:      │    │ 1. Validate key     │    │ 1. Process      │
│ bal_prod_2025_  │    │ 2. Check quota      │    │ 2. ChromaDB     │
│ abc123def456    │    │ 3. Rate limit       │    │ 3. Gemini AI    │
│                 │    │ 4. Forward request  │    │ 4. Return result│
└─────────────────┘    └─────────────────────┘    └─────────────────┘
```

### **3. Quota Management:**
```
Monthly Quota per API Key: 100 requests
- Each moderation request = 1 quota
- Each rule CRUD operation = 1 quota
- Quota resets on 1st of each month
- Real-time quota tracking in portal
```

## 📊 **Developer Portal Features**

### **Dashboard Components:**
```json
{
  "dashboard_features": {
    "api_key_management": {
      "create_keys": "Max 3 per developer",
      "view_usage": "Real-time quota tracking",
      "regenerate": "Security key rotation",
      "delete": "Immediate key revocation"
    },
    "rule_management": {
      "create_rules": "Max 10 per API key",
      "edit_rules": "Update existing rules", 
      "delete_rules": "Remove unwanted rules",
      "test_rules": "Test with sample text"
    },
    "analytics": {
      "usage_stats": "Requests per day/month",
      "quota_alerts": "Approaching limits",
      "performance": "Response times",
      "error_rates": "Failed requests"
    }
  }
}
```

## 🔒 **Security & Best Practices**

### **1. API Key Security:**
- **Prefix validation**: Only `bal_` prefixed keys accepted
- **Format validation**: Strict pattern matching
- **Rotation support**: Easy key regeneration
- **Revocation**: Immediate key deactivation

### **2. Rate Limiting Strategy:**
```ballerina
// Rate limiting configuration
type RateLimit record {
    int requestsPerMinute = 10;      // Prevent abuse
    int burstLimit = 20;             // Allow bursts
    int monthlyQuota = 100;          // Free tier limit
    int maxConcurrent = 5;           // Concurrent requests
};
```

### **3. Monitoring & Alerting:**
```json
{
  "monitoring": {
    "gateway_metrics": [
      "requests_per_second",
      "quota_usage_percentage", 
      "error_rates",
      "response_latency"
    ],
    "alerts": [
      "quota_80_percent_used",
      "rate_limit_exceeded",
      "service_unavailable",
      "high_error_rate"
    ]
  }
}
```

This comprehensive guide provides everything needed to integrate your RAG Moderation Python service with **Ballerina API Gateway**, including developer portal management, quota enforcement, and production deployment strategies specifically designed for the Ballerina ecosystem!
