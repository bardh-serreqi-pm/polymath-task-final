# Lambda Function Testing Guide

## Testing in AWS Console

### Step 1: Navigate to Lambda Function

1. Go to [AWS Console](https://console.aws.amazon.com/)
2. Navigate to **Lambda** service
3. Find your function: **`apprentice-final-staging-api`**
4. Click on the function name to open it

### Step 2: Create a Test Event

1. Click on the **"Test"** tab (or the **"Test"** button at the top)
2. If you don't have a test event yet, click **"Create new test event"**
3. Select **"Create new test event"** from the dropdown
4. Choose **"API Gateway AWS Proxy"** template (or use the JSON below)
5. Name your test event: `health-check-test`

### Step 3: Use This Test Event JSON

Copy and paste this JSON into the test event editor:

**For Health Check:**
```json
{
  "version": "2.0",
  "routeKey": "GET /health",
  "rawPath": "/health",
  "rawQueryString": "",
  "headers": {
    "accept": "application/json",
    "content-type": "application/json",
    "host": "api.example.com",
    "user-agent": "Mozilla/5.0",
    "x-forwarded-for": "127.0.0.1",
    "x-forwarded-port": "443",
    "x-forwarded-proto": "https"
  },
  "requestContext": {
    "accountId": "123456789012",
    "apiId": "test-api-id",
    "domainName": "api.example.com",
    "domainPrefix": "api",
    "http": {
      "method": "GET",
      "path": "/health",
      "protocol": "HTTP/1.1",
      "sourceIp": "127.0.0.1",
      "userAgent": "Mozilla/5.0"
    },
    "requestId": "test-request-id",
    "routeKey": "GET /health",
    "stage": "staging",
    "time": "16/Nov/2025:00:00:00 +0000",
    "timeEpoch": 1731686400000
  },
  "isBase64Encoded": false,
  "body": null
}
```

**For API Endpoint (e.g., /api/auth/check/):**
```json
{
  "version": "2.0",
  "routeKey": "GET /api/auth/check/",
  "rawPath": "/api/auth/check/",
  "rawQueryString": "",
  "headers": {
    "accept": "application/json",
    "content-type": "application/json",
    "host": "api.example.com",
    "user-agent": "Mozilla/5.0",
    "x-forwarded-for": "127.0.0.1",
    "x-forwarded-port": "443",
    "x-forwarded-proto": "https",
    "origin": "https://d3dw2izdb09tes.cloudfront.net"
  },
  "requestContext": {
    "accountId": "123456789012",
    "apiId": "test-api-id",
    "domainName": "api.example.com",
    "domainPrefix": "api",
    "http": {
      "method": "GET",
      "path": "/api/auth/check/",
      "protocol": "HTTP/1.1",
      "sourceIp": "127.0.0.1",
      "userAgent": "Mozilla/5.0"
    },
    "requestId": "test-request-id",
    "routeKey": "GET /api/auth/check/",
    "stage": "staging",
    "time": "16/Nov/2025:00:00:00 +0000",
    "timeEpoch": 1731686400000
  },
  "isBase64Encoded": false,
  "body": null
}
```

### Step 4: Run the Test

1. Click **"Save"** to save the test event
2. Click **"Test"** to execute the test
3. Wait for the execution to complete

### Step 5: Review Results

After the test completes, you'll see:

1. **Execution result**: Success or failure
2. **Response**: The HTTP response from your Lambda
3. **Function Logs**: Click on "Logs" to see CloudWatch logs
4. **Duration**: How long the function took to execute
5. **Billed Duration**: How much you were charged
6. **Memory Used**: Memory consumption

### Step 6: Check CloudWatch Logs

1. In the test results, click **"Click here"** next to "Logs" or go to **CloudWatch** → **Log Groups**
2. Find: `/aws/lambda/apprentice-final-staging-api`
3. Click on the most recent log stream
4. Look for:
   - Error messages
   - Stack traces
   - Print statements from your code
   - Database connection errors
   - SSM parameter retrieval errors

## What to Look For

### Success Indicators:
- Status code: `200`
- Response body contains expected data
- No errors in logs

### Common Error Patterns:

1. **500 Internal Server Error**:
   - Check CloudWatch logs for Django initialization errors
   - Verify SSM parameters exist
   - Check database connectivity

2. **ModuleNotFoundError**:
   - Check if all dependencies are in the Docker image
   - Verify `requirements.txt` includes all packages

3. **Database Connection Errors**:
   - Verify Secrets Manager secret exists
   - Check VPC configuration (Lambda needs to be in same VPC as RDS)
   - Verify security group rules allow Lambda to access RDS

4. **ParameterNotFound**:
   - Verify SSM parameters are created by Terraform
   - Check parameter names match what the code expects

## Quick Test Commands (AWS CLI)

If you prefer using AWS CLI:

```bash
# Test with health check event
aws lambda invoke \
  --function-name apprentice-final-staging-api \
  --payload file://test-health.json \
  response.json

# View the response
cat response.json
```

## Troubleshooting Tips

1. **Check Environment Variables**: In Lambda console → Configuration → Environment variables
2. **Check IAM Role**: Lambda needs permissions for Secrets Manager, SSM, and VPC access
3. **Check VPC Configuration**: If Lambda is in VPC, ensure NAT Gateway is configured
4. **Check Timeout**: Increase timeout if function is timing out (default is 30 seconds)
5. **Check Memory**: Increase memory if function runs out of memory

