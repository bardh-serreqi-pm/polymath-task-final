"""
AWS Lambda handler for Django application.
Uses Mangum to adapt Django WSGI to Lambda's ASGI interface.
"""
import os
import sys

# Add the project directory to Python path
sys.path.insert(0, os.path.dirname(__file__))

# Load AWS configuration from Secrets Manager and SSM BEFORE Django setup
# This must happen before any Django imports
try:
    from Habit_Tracker.aws_config import load_aws_config
    load_aws_config()
except Exception as e:
    print(f"Warning: Could not load AWS config: {e}")
    print("Falling back to environment variables only.")

# Set Django settings module BEFORE importing WSGI
# The wsgi.py module will also set this, but we set it here to ensure it's set before Django initializes
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'Habit_Tracker.settings')

# Import WSGI application - this will trigger Django setup via get_wsgi_application()
# We don't call django.setup() here because wsgi.py will handle it
from Habit_Tracker.wsgi import application

# Run migrations on cold start (only if needed, can be optimized)
# This happens after Django is set up by the WSGI import
try:
    from django.core.management import execute_from_command_line
    # Only run migrations if DB_MIGRATE_ON_START is set
    if os.environ.get('DB_MIGRATE_ON_START', 'false').lower() == 'true':
        execute_from_command_line(['manage.py', 'migrate', '--noinput'])
except Exception as e:
    print(f"Warning: Could not run migrations: {e}")

# Import Mangum adapter
from mangum import Mangum

# Create the Lambda handler at module level
# Mangum automatically detects WSGI applications and wraps them correctly
# lifespan="off" disables ASGI lifespan events (not needed for WSGI)
handler = Mangum(application, lifespan="off")

def lambda_handler(event, context):
    """
    AWS Lambda handler entry point.
    
    Args:
        event: Lambda event (API Gateway HTTP API v2 event)
        context: Lambda context object
    
    Returns:
        API Gateway HTTP API v2 response
    """
    return handler(event, context)

