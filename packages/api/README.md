# API Service

This directory contains the Django backend API.

## Structure

```
api/
├── habit/              # Habit tracking app
├── Users/              # User management app
├── Habit_Tracker/      # Django project settings
├── manage.py           # Django management script
├── requirements.txt    # Python dependencies
└── pytest.ini         # Pytest configuration
```

## Development

### Local Development (without Docker)

1. Create virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # Linux/Mac
# or
venv\Scripts\activate     # Windows
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Set up database:
```bash
# Copy local_settings.example.py to local_settings.py
cp local_settings.example.py local_settings.py
# Edit local_settings.py with your database configuration

# Run migrations
python manage.py migrate
```

4. Run development server:
```bash
python manage.py runserver
```

### Docker Development

The API service runs in a Docker container. See the root `README.md` for Docker setup instructions.

## Environment Variables

The API uses environment variables for configuration (when running in Docker):
- `DB_HOST` - Database host
- `DB_PORT` - Database port
- `DB_NAME` - Database name
- `DB_USER` - Database user
- `DB_PASSWORD` - Database password
- `REDIS_HOST` - Redis host
- `REDIS_PORT` - Redis port
- `SECRET_KEY` - Django secret key
- `DEBUG` - Debug mode

## Health Check

The API provides a health check endpoint at `/health/` that checks:
- Database connectivity
- Redis cache connectivity

## Testing

Run tests with pytest:
```bash
pytest habit/tests/ -v
```

Or with Django's test runner:
```bash
python manage.py test
```

## Static Files

Static files are collected to `/app/staticfiles` in the Docker container and served by Nginx.

## Media Files

Media files are stored in `/app/media` in the Docker container and served by Nginx.

