"""
AWS Lambda handler for Django application.
Uses Mangum to adapt Django ASGI application to Lambda's HTTP API v2 interface.
"""
import os
import sys
import traceback
import logging

# Add the project directory to Python path
sys.path.insert(0, os.path.dirname(__file__))

LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO").upper()
logging.basicConfig(level=getattr(logging, LOG_LEVEL, logging.INFO))
logger = logging.getLogger("apprentice_final.lambda")
logger.setLevel(getattr(logging, LOG_LEVEL, logging.INFO))


def _log_event_summary(event):
    """Log basic request metadata to make troubleshooting easier."""
    try:
        request_context = event.get("requestContext", {})
        http = request_context.get("http", {})
        method = http.get("method") or event.get("requestContext", {}).get("httpMethod", "UNKNOWN")
        path = event.get("rawPath") or http.get("path") or event.get("requestContext", {}).get("path", "UNKNOWN")
        stage = request_context.get("stage", os.environ.get("API_GATEWAY_STAGE", "staging"))
        source_ip = http.get("sourceIp") or request_context.get("identity", {}).get("sourceIp")
        request_id = request_context.get("requestId") or request_context.get("requestId")

        logger.info(
            "Lambda invocation received",
            extra={
                "method": method,
                "path": path,
                "stage": stage,
                "source_ip": source_ip,
                "request_id": request_id,
            },
        )
    except Exception:
        logger.debug("Unable to summarize incoming event", exc_info=True)

# Load AWS configuration from Secrets Manager and SSM BEFORE Django setup
# This must happen before any Django imports
try:
    from Habit_Tracker.aws_config import load_aws_config
    load_aws_config()
    logger.info("AWS config loaded successfully from Secrets Manager/SSM")
except Exception as e:
    logger.warning("Could not load AWS config, falling back to environment variables: %s", e, exc_info=True)

# Set Django settings module BEFORE importing ASGI/WSGI
# The asgi.py/wsgi.py module will also set this, but we set it here to ensure it's set before Django initializes
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'Habit_Tracker.settings')

# Import ASGI application - Mangum works better with ASGI
# This will trigger Django setup via get_asgi_application()
try:
    from Habit_Tracker.asgi import application
    logger.info("Django ASGI application loaded successfully")
except Exception as e:
    logger.error("Failed to load Django ASGI application: %s", e, exc_info=True)
    # Fallback to WSGI if ASGI fails
    try:
        from Habit_Tracker.wsgi import application
        logger.warning("Fell back to Django WSGI application")
    except Exception as e2:
        logger.critical("Failed to load Django WSGI application: %s", e2, exc_info=True)
        # Create a dummy application that returns 500 error
        async def error_application(scope, receive, send):
            await send({
                'type': 'http.response.start',
                'status': 500,
                'headers': [[b'content-type', b'text/plain']],
            })
            await send({
                'type': 'http.response.body',
                'body': b'Django application failed to initialize',
            })
        application = error_application

# Run migrations on cold start (only if needed, can be optimized)
# This happens after Django is set up by the ASGI/WSGI import
try:
    from django.core.management import execute_from_command_line
    from django.db import connection
    
    # Only run migrations if DB_MIGRATE_ON_START is set
    if os.environ.get('DB_MIGRATE_ON_START', 'false').lower() == 'true':
        # Check if migrations are needed by checking if auth_user table exists
        with connection.cursor() as cursor:
            cursor.execute("""
                SELECT EXISTS (
                    SELECT FROM information_schema.tables 
                    WHERE table_schema = 'public' 
                    AND table_name = 'auth_user'
                );
            """)
            tables_exist = cursor.fetchone()[0]
        
        if not tables_exist:
            logger.info("Database tables not found. Running migrations...")
            execute_from_command_line(['manage.py', 'migrate', '--noinput'])
            logger.info("Migrations completed successfully")
        else:
            logger.info("Database tables already exist. Skipping migrations.")
except Exception as e:
    logger.warning("Could not run migrations on cold start: %s", e, exc_info=True)

# Import Mangum adapter
try:
    from mangum import Mangum
    # Create the Lambda handler at module level
    # Mangum works with ASGI applications (Django ASGI is preferred for Lambda)
    # lifespan="off" disables ASGI lifespan events (not needed for basic HTTP)
    handler = Mangum(application, lifespan="off")
    logger.info("Mangum handler created successfully")
except Exception as e:
    logger.critical("Failed to create Mangum handler: %s", e, exc_info=True)
    # Create a fallback handler
    def error_handler(event, context):
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': '{"error": "Lambda handler initialization failed"}'
        }
    handler = error_handler

def lambda_handler(event, context):
    """
    AWS Lambda handler entry point.
    
    Args:
        event: Lambda event (API Gateway HTTP API v2 event)
        context: Lambda context object
    
    Returns:
        API Gateway HTTP API v2 response
    """
    _log_event_summary(event)
    try:
        response = handler(event, context)
        status = None
        if isinstance(response, dict):
            status = response.get("statusCode")
        logger.info("Lambda invocation completed", extra={"status_code": status})
        return response
    except Exception as e:
        logger.error("Unhandled exception in lambda_handler: %s", e, exc_info=True)
        # Return a proper error response
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': f'{{"error": "Internal server error", "message": "{str(e)}"}}'
        }

