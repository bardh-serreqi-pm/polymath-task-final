"""
AWS configuration helper for reading from Secrets Manager and SSM Parameter Store.
"""
import os
import json
import boto3
from botocore.exceptions import ClientError

# Initialize AWS clients
secrets_client = boto3.client('secretsmanager', region_name=os.environ.get('AWS_REGION', 'us-east-1'))
ssm_client = boto3.client('ssm', region_name=os.environ.get('AWS_REGION', 'us-east-1'))


def get_secret(secret_name):
    """
    Retrieve a secret from AWS Secrets Manager.
    
    Args:
        secret_name: Name or ARN of the secret
        
    Returns:
        dict: Secret value as dictionary, or None if not found
    """
    try:
        response = secrets_client.get_secret_value(SecretId=secret_name)
        secret_string = response['SecretString']
        return json.loads(secret_string)
    except ClientError as e:
        print(f"Error retrieving secret {secret_name}: {e}")
        return None
    except json.JSONDecodeError:
        # If not JSON, return as string
        return {'value': secret_string}


def get_parameter(parameter_name, decrypt=False, required=False):
    """
    Retrieve a parameter from AWS SSM Parameter Store.
    
    Args:
        parameter_name: Name of the parameter
        decrypt: Whether to decrypt SecureString parameters
        required: If True, log error; if False, silently return None
        
    Returns:
        str: Parameter value, or None if not found
    """
    try:
        response = ssm_client.get_parameter(
            Name=parameter_name,
            WithDecryption=decrypt
        )
        return response['Parameter']['Value']
    except ClientError as e:
        error_code = e.response.get('Error', {}).get('Code', '')
        if error_code == 'ParameterNotFound':
            if required:
                print(f"Error: Required parameter {parameter_name} not found: {e}")
            # Silently return None for optional parameters
            return None
        else:
            print(f"Error retrieving parameter {parameter_name}: {e}")
            return None


def load_aws_config():
    """
    Load configuration from AWS Secrets Manager and SSM Parameter Store.
    Sets environment variables that Django settings can read.
    
    Expected environment variables:
    - AWS_SECRET_NAME: Name/ARN of Secrets Manager secret containing DB credentials
    - AWS_SSM_PREFIX: Prefix for SSM parameters (e.g., /project/env/)
    """
    project_name = os.environ.get('PROJECT_NAME', 'habit-tracker')
    environment = os.environ.get('ENVIRONMENT', 'staging')
    
    # Load database credentials from Secrets Manager
    # Support both ARN and name formats
    secret_name = os.environ.get('AWS_SECRET_NAME') or os.environ.get('AURORA_SECRET_ARN', f'{project_name}/{environment}/aurora/master')
    secret = get_secret(secret_name)
    
    if secret:
        os.environ.setdefault('DB_NAME', secret.get('dbname', 'habittracker'))
        os.environ.setdefault('DB_USER', secret.get('username', 'dbadmin'))
        os.environ.setdefault('DB_PASSWORD', secret.get('password', ''))
        os.environ.setdefault('DB_HOST', secret.get('host', ''))
        os.environ.setdefault('DB_PORT', str(secret.get('port', 5432)))
    
    # Load other configuration from SSM Parameter Store
    ssm_prefix = os.environ.get('AWS_SSM_PREFIX', f'/{project_name}/{environment}')
    
    # Aurora endpoints - use specific parameter names from environment or fallback to SSM prefix
    writer_param = os.environ.get('AURORA_WRITER_ENDPOINT_PARAM', f'{ssm_prefix}/aurora/writer_endpoint')
    writer_endpoint = get_parameter(writer_param)
    if writer_endpoint:
        os.environ['DB_HOST'] = writer_endpoint
    
    reader_param = f'{ssm_prefix}/aurora/reader_endpoint'
    reader_endpoint = get_parameter(reader_param)
    if reader_endpoint:
        os.environ.setdefault('DB_READER_HOST', reader_endpoint)
    
    # Redis endpoint - use specific parameter name from environment or fallback to SSM prefix
    redis_param = os.environ.get('REDIS_ENDPOINT_PARAM', f'{ssm_prefix}/redis/endpoint')
    redis_endpoint = get_parameter(redis_param)
    if redis_endpoint:
        # Redis endpoint format: host:port or just host
        if ':' in redis_endpoint:
            redis_host, redis_port = redis_endpoint.split(':', 1)
            os.environ['REDIS_HOST'] = redis_host
            os.environ['REDIS_PORT'] = redis_port
        else:
            os.environ['REDIS_HOST'] = redis_endpoint
            os.environ.setdefault('REDIS_PORT', '6379')
    
    # Django settings (optional - will use defaults if not found)
    django_secret_key = get_parameter(f'{ssm_prefix}/django/secret_key', decrypt=True, required=False)
    if django_secret_key:
        os.environ.setdefault('SECRET_KEY', django_secret_key)
    
    django_debug = get_parameter(f'{ssm_prefix}/django/debug', required=False)
    if django_debug:
        os.environ.setdefault('DEBUG', django_debug)
    
    allowed_hosts = get_parameter(f'{ssm_prefix}/django/allowed_hosts', required=False)
    if allowed_hosts:
        os.environ['ALLOWED_HOSTS'] = allowed_hosts
    else:
        # Default: allow all hosts for API Gateway (API Gateway doesn't send Host header in a way Django expects)
        # In production, set this via SSM Parameter Store with specific domains
        os.environ.setdefault('ALLOWED_HOSTS', '*')

