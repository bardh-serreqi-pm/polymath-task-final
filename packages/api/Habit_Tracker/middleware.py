"""
Middleware to strip API Gateway stage prefix from request paths and handle CORS.

When using API Gateway with CloudFront, the stage name (e.g., 'staging') 
is included in the path. This middleware removes it so Django URLs work correctly.
Also handles CORS headers for cross-origin requests with credentials.
"""
import os
import re


class AllowAllHostsMiddleware:
    """
    Middleware to bypass ALLOWED_HOSTS check for API Gateway requests.
    
    API Gateway doesn't send Host header in a format Django expects,
    so we bypass the check when running in Lambda.
    """
    
    def __init__(self, get_response):
        self.get_response = get_response
    
    def __call__(self, request):
        # When running in Lambda, bypass ALLOWED_HOSTS check
        # by setting a valid host in the request
        if os.environ.get('AWS_LAMBDA_FUNCTION_NAME'):
            # Set a dummy host that Django will accept
            request.META['HTTP_HOST'] = 'api-gateway.amazonaws.com'
        
        response = self.get_response(request)
        return response


class StripStagePrefixMiddleware:
    """
    Middleware to remove API Gateway stage prefix from request paths.
    
    For example: /staging/api/auth/check/ -> /api/auth/check/
    """
    
    def __init__(self, get_response):
        self.get_response = get_response
        # Get stage name from environment variable, default to 'staging'
        self.stage_name = os.environ.get('API_GATEWAY_STAGE', 'staging')
        # Create regex pattern to match stage prefix at start of path
        self.stage_pattern = re.compile(r'^/' + re.escape(self.stage_name) + r'(/|$)')
    
    def __call__(self, request):
        # Strip stage prefix from path if present
        if self.stage_pattern.match(request.path):
            # Remove the stage prefix (e.g., /staging/api/... -> /api/...)
            request.path = self.stage_pattern.sub('/', request.path, count=1)
            # Also update path_info which Django uses for URL routing
            request.path_info = request.path
        
        response = self.get_response(request)
        return response


class CorsMiddleware:
    """
    Middleware to add CORS headers to responses.
    
    Handles CORS for cross-origin requests with credentials support.
    Validates origin and adds appropriate CORS headers.
    """
    
    def __init__(self, get_response):
        self.get_response = get_response
        # Get allowed origins from environment variable
        # Default to allowing all origins (for development)
        allowed_origins = os.environ.get('CORS_ALLOWED_ORIGINS', '*')
        self.allowed_origins = [origin.strip() for origin in allowed_origins.split(',')] if allowed_origins != '*' else ['*']
    
    def __call__(self, request):
        response = self.get_response(request)
        
        # Get origin from request
        origin = request.META.get('HTTP_ORIGIN', '')
        
        # Determine if origin is allowed
        # When allow_credentials is true, we cannot use '*' - must specify exact origin
        if origin:
            if self.allowed_origins == ['*'] or origin in self.allowed_origins:
                # Add CORS headers with exact origin (required when credentials are allowed)
                response['Access-Control-Allow-Origin'] = origin
                response['Access-Control-Allow-Credentials'] = 'true'
                response['Access-Control-Allow-Methods'] = 'GET, HEAD, OPTIONS, PUT, POST, PATCH, DELETE'
                response['Access-Control-Allow-Headers'] = 'Content-Type, X-CSRFToken, Authorization, Accept, Origin, X-Requested-With, Cache-Control, Pragma'
                response['Access-Control-Max-Age'] = '3600'
                
                # Handle preflight OPTIONS requests
                if request.method == 'OPTIONS':
                    response.status_code = 200
                    response.content = b''
        
        return response

