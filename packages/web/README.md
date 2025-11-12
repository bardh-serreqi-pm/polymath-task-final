# Web Frontend Service

This directory contains the React frontend application for the Habit Tracker.

## Technology Stack

- **React 18** - UI library
- **Vite** - Build tool and dev server
- **React Router** - Client-side routing
- **Axios** - HTTP client for API calls
- **Nginx** - Web server for production

## Project Structure

```
web/
├── src/
│   ├── components/        # Reusable React components
│   │   ├── Navbar.jsx
│   │   └── Navbar.css
│   ├── pages/            # Page components
│   │   ├── Login.jsx
│   │   ├── Register.jsx
│   │   ├── Home.jsx
│   │   ├── HabitManager.jsx
│   │   ├── HabitAnalysis.jsx
│   │   └── Profile.jsx
│   ├── services/         # API services
│   │   ├── api.js        # Axios instance
│   │   ├── authService.js
│   │   └── habitService.js
│   ├── App.jsx           # Main app component
│   ├── App.css           # App styles
│   ├── main.jsx          # Entry point
│   └── index.css        # Global styles
├── public/               # Static assets
├── Dockerfile            # Production Dockerfile
├── nginx.conf           # Nginx configuration
├── package.json         # Dependencies
├── vite.config.js       # Vite configuration
└── index.html           # HTML template
```

## Development

### Local Development (without Docker)

1. Install dependencies:
```bash
cd web
npm install
```

2. Start development server:
```bash
npm run dev
```

The app will be available at `http://localhost:3000`

### Docker Development

The frontend is built and served via Docker:

```bash
# Build and start all services
docker-compose up --build

# Access at http://localhost
```

## API Integration

The frontend communicates with the Django API through:

1. **API Proxy**: Nginx proxies `/api/*` requests to Django
2. **Direct Endpoints**: Some Django endpoints are proxied directly (Login, Register, etc.)
3. **CSRF Token**: Automatically handled via cookies

### API Service

The `src/services/api.js` file configures Axios to:
- Use `/api` as base URL (proxied to Django)
- Include CSRF token from cookies
- Handle authentication errors
- Include credentials for session management

## Building for Production

The Dockerfile uses a multi-stage build:

1. **Build Stage**: Installs dependencies and builds the React app
2. **Production Stage**: Copies built files to Nginx and serves them

Build process:
```bash
npm run build
```

Output: `dist/` directory with optimized production build

## Nginx Configuration

The `nginx.conf` file:
- Serves React app from `/usr/share/nginx/html`
- Proxies API requests to Django backend
- Serves static and media files
- Handles client-side routing (SPA)

## Environment Variables

For development, you can create a `.env` file:

```env
VITE_API_URL=http://localhost:8000
```

Access in code:
```javascript
const apiUrl = import.meta.env.VITE_API_URL
```

## Adding New Features

### Add a New Page

1. Create component in `src/pages/`
2. Add route in `src/App.jsx`
3. Add navigation link in `src/components/Navbar.jsx`

### Add a New API Service

1. Create service in `src/services/`
2. Use the `api` instance from `api.js`
3. Export functions for use in components

### Add a New Component

1. Create component in `src/components/`
2. Add corresponding CSS file
3. Import and use in pages

## Testing

To add testing:

```bash
npm install --save-dev @testing-library/react @testing-library/jest-dom vitest
```

## Production Deployment

The production build is optimized:
- Code splitting
- Minification
- Tree shaking
- Asset optimization

## Troubleshooting

### Build Errors

- Clear `node_modules` and reinstall: `rm -rf node_modules && npm install`
- Check Node.js version: Requires Node 18+

### API Connection Issues

- Verify API service is running: `docker-compose ps api`
- Check Nginx logs: `docker-compose logs web`
- Verify proxy configuration in `nginx.conf`

### Routing Issues

- Ensure Nginx `try_files` directive includes `/index.html`
- Check that all routes are handled in React Router

## Future Enhancements

- [ ] Add state management (Redux/Zustand)
- [ ] Add form validation library
- [ ] Add UI component library (Material-UI, Ant Design)
- [ ] Add testing framework
- [ ] Add E2E testing
- [ ] Add PWA support
- [ ] Add internationalization (i18n)
