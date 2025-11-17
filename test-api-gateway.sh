#!/bin/bash
#
# API Gateway and Lambda Diagnostic Script
#
# This script helps diagnose why API Gateway returns 500 errors and Lambda doesn't log
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PROJECT_NAME="apprentice-final"
ENVIRONMENT="staging"
REGION="us-east-1"

echo -e "${GREEN}=== API Gateway & Lambda Diagnostics ===${NC}\n"

# 1. Get Lambda function name
echo -e "${YELLOW}1. Checking Lambda function...${NC}"
LAMBDA_NAME="${PROJECT_NAME}-${ENVIRONMENT}-api"
aws lambda get-function --function-name "$LAMBDA_NAME" --region "$REGION" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Lambda function exists: $LAMBDA_NAME${NC}"
    
    # Get Lambda configuration
    LAMBDA_TIMEOUT=$(aws lambda get-function-configuration --function-name "$LAMBDA_NAME" --region "$REGION" --query 'Timeout' --output text)
    LAMBDA_MEMORY=$(aws lambda get-function-configuration --function-name "$LAMBDA_NAME" --region "$REGION" --query 'MemorySize' --output text)
    LAMBDA_STATE=$(aws lambda get-function-configuration --function-name "$LAMBDA_NAME" --region "$REGION" --query 'State' --output text)
    
    echo "  - Timeout: ${LAMBDA_TIMEOUT}s"
    echo "  - Memory: ${LAMBDA_MEMORY}MB"
    echo "  - State: $LAMBDA_STATE"
    
    if [ "$LAMBDA_STATE" != "Active" ]; then
        echo -e "${RED}✗ Lambda is not Active!${NC}"
    fi
else
    echo -e "${RED}✗ Lambda function not found: $LAMBDA_NAME${NC}"
    exit 1
fi

# 2. Check Lambda CloudWatch Logs
echo -e "\n${YELLOW}2. Checking Lambda CloudWatch logs...${NC}"
LAMBDA_LOG_GROUP="/aws/lambda/$LAMBDA_NAME"
aws logs describe-log-groups --log-group-name-prefix "$LAMBDA_LOG_GROUP" --region "$REGION" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Log group exists: $LAMBDA_LOG_GROUP${NC}"
    
    # Get recent log streams
    RECENT_STREAMS=$(aws logs describe-log-streams \
        --log-group-name "$LAMBDA_LOG_GROUP" \
        --region "$REGION" \
        --order-by LastEventTime \
        --descending \
        --max-items 3 \
        --query 'logStreams[*].[logStreamName,lastEventTime]' \
        --output text)
    
    if [ -n "$RECENT_STREAMS" ]; then
        echo "  Recent log streams:"
        echo "$RECENT_STREAMS" | while read -r stream timestamp; do
            if [ -n "$timestamp" ]; then
                date_str=$(date -d "@$((timestamp/1000))" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "Unknown")
                echo "    - $stream (Last: $date_str)"
            fi
        done
    else
        echo -e "${RED}  ✗ No log streams found - Lambda has never been invoked!${NC}"
    fi
else
    echo -e "${RED}✗ Log group not found: $LAMBDA_LOG_GROUP${NC}"
fi

# 3. Get API Gateway ID
echo -e "\n${YELLOW}3. Checking API Gateway...${NC}"
API_ID=$(aws apigatewayv2 get-apis --region "$REGION" \
    --query "Items[?Name=='${PROJECT_NAME}-${ENVIRONMENT}-http-api'].ApiId" \
    --output text)

if [ -z "$API_ID" ]; then
    echo -e "${RED}✗ API Gateway not found${NC}"
    exit 1
fi

echo -e "${GREEN}✓ API Gateway ID: $API_ID${NC}"

# 4. Check API Gateway stage
echo -e "\n${YELLOW}4. Checking API Gateway stage...${NC}"
STAGE_URL=$(aws apigatewayv2 get-stage \
    --api-id "$API_ID" \
    --stage-name "$ENVIRONMENT" \
    --region "$REGION" \
    --query 'StageVariables' 2>/dev/null)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Stage exists: $ENVIRONMENT${NC}"
    API_URL="https://${API_ID}.execute-api.${REGION}.amazonaws.com/${ENVIRONMENT}"
    echo "  - URL: $API_URL"
else
    echo -e "${RED}✗ Stage not found: $ENVIRONMENT${NC}"
fi

# 5. Check API Gateway CloudWatch logs
echo -e "\n${YELLOW}5. Checking API Gateway CloudWatch logs...${NC}"
API_LOG_GROUP="/aws/apigateway/$API_ID"
aws logs describe-log-groups --log-group-name-prefix "$API_LOG_GROUP" --region "$REGION" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Log group exists: $API_LOG_GROUP${NC}"
    
    # Get recent log streams
    RECENT_API_STREAMS=$(aws logs describe-log-streams \
        --log-group-name "$API_LOG_GROUP" \
        --region "$REGION" \
        --order-by LastEventTime \
        --descending \
        --max-items 3 \
        --query 'logStreams[*].[logStreamName,lastEventTime]' \
        --output text)
    
    if [ -n "$RECENT_API_STREAMS" ]; then
        echo "  Recent log streams:"
        echo "$RECENT_API_STREAMS" | while read -r stream timestamp; do
            if [ -n "$timestamp" ]; then
                date_str=$(date -d "@$((timestamp/1000))" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "Unknown")
                echo "    - $stream (Last: $date_str)"
            fi
        done
    else
        echo -e "${YELLOW}  ⚠ No log streams found${NC}"
    fi
else
    echo -e "${RED}✗ Log group not found: $API_LOG_GROUP${NC}"
fi

# 6. Test Lambda directly
echo -e "\n${YELLOW}6. Testing Lambda function directly...${NC}"
TEST_EVENT='{
  "version": "2.0",
  "routeKey": "ANY /health",
  "rawPath": "/health",
  "requestContext": {
    "http": {
      "method": "GET",
      "path": "/health"
    }
  },
  "isBase64Encoded": false
}'

echo "  Invoking Lambda with test event..."
LAMBDA_RESPONSE=$(aws lambda invoke \
    --function-name "$LAMBDA_NAME" \
    --payload "$TEST_EVENT" \
    --region "$REGION" \
    --log-type Tail \
    /dev/stdout 2>&1)

if echo "$LAMBDA_RESPONSE" | grep -q "StatusCode"; then
    STATUS=$(echo "$LAMBDA_RESPONSE" | grep "StatusCode" | awk '{print $2}' | tr -d ',')
    echo -e "${GREEN}✓ Lambda invoked successfully (Status: $STATUS)${NC}"
    
    # Extract and display logs
    LOGS=$(echo "$LAMBDA_RESPONSE" | grep "LogResult" | awk -F'"' '{print $4}')
    if [ -n "$LOGS" ]; then
        echo -e "\n  ${YELLOW}Lambda execution logs:${NC}"
        echo "$LOGS" | base64 -d 2>/dev/null || echo "  (Unable to decode logs)"
    fi
else
    echo -e "${RED}✗ Lambda invocation failed${NC}"
    echo "$LAMBDA_RESPONSE"
fi

# 7. Test API Gateway endpoint
echo -e "\n${YELLOW}7. Testing API Gateway endpoint...${NC}"
if [ -n "$API_URL" ]; then
    echo "  Testing: ${API_URL}/health"
    
    RESPONSE=$(curl -s -w "\n%{http_code}" "${API_URL}/health")
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | head -n-1)
    
    echo "  HTTP Status: $HTTP_CODE"
    if [ "$HTTP_CODE" = "200" ]; then
        echo -e "${GREEN}✓ API Gateway health check passed${NC}"
        echo "  Response: $BODY"
    else
        echo -e "${RED}✗ API Gateway returned error${NC}"
        echo "  Response: $BODY"
    fi
fi

# 8. Check recent Lambda errors
echo -e "\n${YELLOW}8. Checking for recent Lambda errors...${NC}"
ERRORS=$(aws logs filter-log-events \
    --log-group-name "$LAMBDA_LOG_GROUP" \
    --region "$REGION" \
    --start-time $(($(date +%s) * 1000 - 3600000)) \
    --filter-pattern "ERROR" \
    --query 'events[*].message' \
    --output text 2>/dev/null)

if [ -n "$ERRORS" ]; then
    echo -e "${RED}✗ Found errors in Lambda logs:${NC}"
    echo "$ERRORS" | head -n 10
else
    echo -e "${GREEN}✓ No ERROR entries in recent logs${NC}"
fi

echo -e "\n${GREEN}=== Diagnostic Complete ===${NC}"
echo -e "\n${YELLOW}Recommended CloudWatch Log Groups to check:${NC}"
echo "  - Lambda logs: $LAMBDA_LOG_GROUP"
echo "  - API Gateway logs: $API_LOG_GROUP"
echo -e "\n${YELLOW}To view logs in real-time:${NC}"
echo "  aws logs tail $LAMBDA_LOG_GROUP --follow --region $REGION"

