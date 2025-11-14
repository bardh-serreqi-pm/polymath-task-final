"""
Middleware to strip API Gateway stage prefix from request paths.

When using API Gateway with CloudFront, the stage name (e.g., 'staging') 
is included in the path. This middleware removes it so Django URLs work correctly.
"""
import os
import re


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

