# Django Habit Tracker

Django Habit Tracker is a web application designed to help users track their habits, manage tasks, and monitor progress towards their goals.
This README provides an overview of the project's features, installation instructions, usage guidelines.

# Installation #

## Option 1: Docker Setup (Recommended)

To install and run Django Habit Tracker using Docker, follow these steps:

1. Clone the repository
```
git clone https://github.com/UsfZA/Habit-Tracker.git
cd Habit-Tracker-development
```

2. Create environment file:
```
cp .env.example .env
```
Edit `.env` file and update `SECRET_KEY` and other configuration values.

3. Start services:
```bash
# Windows
docker-start.bat

# Linux/Mac
chmod +x docker-start.sh
./docker-start.sh

# Or manually
docker-compose up --build
```

4. Access the application:
- **React Frontend** (Recommended): http://localhost
- **Django Backend** (Direct): http://localhost:8000
- Health Check: http://localhost/health/
- Admin: http://localhost/admin/

5. Create superuser (optional):
```
docker-compose exec api python manage.py createsuperuser
```

6. **First Run:** The app starts with a completely empty database. You'll need to:
   - Register a new user at `http://localhost/register`
   - Or create a superuser (see step 5)

### Reset Database to Clean State

If you need to reset the database to a clean state:

**Windows:**
```powershell
.\reset-database.bat
```

**Linux/Mac:**
```bash
chmod +x reset-database.sh
./reset-database.sh
```

Or manually:
```bash
docker-compose down
docker volume rm habit-tracker-development_postgres_data
docker-compose up -d
```

See `CLEAN_BUILD.md` for more details.

### Project Structure

The project is organized as follows:
- `api/` - Django backend API
- `web/` - React frontend application
- `docker/` - Docker configuration files
- Root level - Docker Compose and configuration files

For detailed Docker setup instructions, see [DOCKER_SETUP.md](DOCKER_SETUP.md)
For project structure details, see [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md)
For deployment architecture decision and AWS ECS Fargate vs Serverless analysis, see [docs/DEPLOYMENT_ARCHITECTURE.md](../docs/DEPLOYMENT_ARCHITECTURE.md)

## Option 2: Local Development Setup

To install and run Django Habit Tracker locally, follow these steps:

1. Clone the repository
```
git clone https://github.com/UsfZA/Habit-Tracker.git
cd Habit-Tracker
```

2. Install dependencies:
```
pip install -r requirements.txt
```

3. ### Database configuration ###
I'm using MySQL as the database, so I've included `mysqlclient` in the requirements.
If you don't have MySQL installed, you can use the built-in SQLite configuration. Follow these steps:
 
  - Ensure you have SQLite installed on your system.
  - Comment out the MySQL configuration in the 'local_settings.py' file.
  - Copy the '**local_settings.example.py**' file and rename it to `local_settings.py`.
  - Update the database configuration in '**local_settings.py**' with your own database credentials.

4. Apply database migrations:
```
python manage.py migrate
```

5. Run the development server:
```
python manage.py runserver
```

6. Access the application in your web browser at [http://localhost:8000](http://localhost:8000)

# Features #
### User Authentication and Registration: ###
  * Users can create accounts and log in to track their habits.
### Habit Tracking: ###
  * Add, and delete habits.
  * Tasks are automatically generated based on habit goal, frequency and period.
  * Track streaks for each habit to maintain consistency.
  * Earn achievements for hitting streak milestones or completing habits.
### Analytics: ###
  * View detailed analytics on habit tracking, including active habits, streak lengths, and progress towards goals.
  * Visualize habit data to gain insights into behavior patterns.
### User Profile: ###
  * Users have personalized profiles displaying their active habits and other relevant information.

# Usage #
Once the application is running, you can perform the following actions: 

### Register/Login: ###
  * Create an account or log in with existing credentials.
### Add Habits: ###
  * Navigate to the "Add Habit" page and input details such as habit name, frequency, period, and goal.
### View and Mark tasks as completed In Home page: ###
  * View due today tasks and active tasks.
  * Mark tasks as completed by clicking on them.
### Monitor Progress: ###
  * Check your analytics regularly to monitor streak lengths, progress percentages, and achievements.
### Habit Manager: ###
  * Navigate to the "Habit Manager" :
     * View all tracked habits and access their details including tasks journal and streak log for each habit
     * Delete habits along with associated tasks, streaks, and achievements.
