"""
Health check views for monitoring service status.
"""
import logging
from django.http import JsonResponse
from django.db import connection
from django.core.cache import cache
from django.views import View
from django.contrib.auth.models import User
from django.contrib.auth import authenticate, login, logout
from django.db import models
from django.utils import timezone


class HealthCheckView(View):
    """
    Health check endpoint that verifies database and cache connectivity.
    """
    
    def get(self, request):
        """
        Returns health status of the application.
        
        Checks:
        - Database connectivity
        - Redis cache connectivity
        - Overall service status
        """
        health_status = {
            'status': 'healthy',
            'services': {}
        }
        
        logger = logging.getLogger(__name__)
        logger.info("Health check: starting database check")

        # Check database
        try:
            with connection.cursor() as cursor:
                logger.debug("Health check: executing SELECT 1")
                cursor.execute("SELECT 1")
                health_status['services']['database'] = {
                    'status': 'healthy',
                    'message': 'Database connection successful'
                }
                logger.info("Health check: database check passed")
        except Exception as e:
            health_status['status'] = 'unhealthy'
            logger.exception("Health check: database check failed")
            health_status['services']['database'] = {
                'status': 'unhealthy',
                'message': str(e)
            }
        
        # Check Redis cache
        logger.info("Health check: starting Redis check")
        try:
            logger.debug("Health check: writing to Redis cache key")
            cache.set('health_check', 'ok', 10)
            cache_result = cache.get('health_check')
            if cache_result == 'ok':
                health_status['services']['cache'] = {
                    'status': 'healthy',
                    'message': 'Redis cache connection successful'
                }
                logger.info("Health check: Redis check passed")
            else:
                health_status['status'] = 'unhealthy'
                logger.warning("Health check: Redis read/write mismatch (expected 'ok', got %s)", cache_result)
                health_status['services']['cache'] = {
                    'status': 'unhealthy',
                    'message': 'Cache read/write failed'
                }
        except Exception as e:
            health_status['status'] = 'unhealthy'
            logger.exception("Health check: Redis check failed")
            health_status['services']['cache'] = {
                'status': 'unhealthy',
                'message': str(e)
            }
        
        # Return appropriate HTTP status code
        status_code = 200 if health_status['status'] == 'healthy' else 503
        return JsonResponse(health_status, status=status_code)


class LoginAPIView(View):
    """
    API endpoint for user login.
    """
    
    def post(self, request):
        """
        Authenticate user and create session.
        
        Expected POST data:
        - username: user's username
        - password: user's password
        
        Returns:
        - success: boolean
        - message: status message
        - user: user data if successful
        """
        username = request.POST.get('username')
        password = request.POST.get('password')
        
        if not username or not password:
            return JsonResponse({
                'success': False,
                'error': 'Username and password are required'
            }, status=400)
        
        # Authenticate user
        user = authenticate(request, username=username, password=password)
        
        if user is not None:
            # Login user (creates session)
            login(request, user)
            return JsonResponse({
                'success': True,
                'message': 'Login successful',
                'user': {
                    'id': user.id,
                    'username': user.username,
                    'email': user.email or '',
                }
            })
        else:
            return JsonResponse({
                'success': False,
                'error': 'Invalid username or password'
            }, status=401)


class LogoutAPIView(View):
    """
    API endpoint for user logout.
    """
    
    def post(self, request):
        """
        Logout user and clear session.
        
        Returns:
        - success: boolean
        - message: status message
        """
        if request.user.is_authenticated:
            username = request.user.username
            logout(request)
            return JsonResponse({
                'success': True,
                'message': f'User {username} logged out successfully'
            })
        else:
            return JsonResponse({
                'success': True,
                'message': 'No user was logged in'
            })


class AuthCheckView(View):
    """
    Authentication check endpoint that returns user authentication status.
    """
    
    def get(self, request):
        """
        Returns authentication status of the current user.
        
        Returns:
        - authenticated: boolean indicating if user is authenticated
        - user_id: user ID if authenticated, None otherwise
        - username: username if authenticated, None otherwise
        """
        if request.user.is_authenticated:
            # Verify user actually exists in database
            try:
                user = User.objects.get(id=request.user.id)
                return JsonResponse({
                    'authenticated': True,
                    'user_id': user.id,
                    'username': user.username,
                })
            except User.DoesNotExist:
                # User doesn't exist in database, clear session
                return JsonResponse({
                    'authenticated': False,
                    'user_id': None,
                    'username': None,
                })
        else:
            return JsonResponse({
                'authenticated': False,
                'user_id': None,
                'username': None,
            })


class ProfileView(View):
    """
    Profile endpoint that returns current user's profile information.
    """
    
    def get(self, request):
        """
        Returns profile information for the authenticated user.
        
        Returns:
        - user: user information (id, username, first_name, last_name, email, date_joined)
        - profile: profile information if exists
        """
        if not request.user.is_authenticated:
            return JsonResponse({'error': 'Authentication required'}, status=401)
        
        try:
            user = User.objects.get(id=request.user.id)
            from Users.models import Profile
            
            # Get or create profile
            profile, created = Profile.objects.get_or_create(user=user)
            
            return JsonResponse({
                'user': {
                    'id': user.id,
                    'username': user.username,
                    'first_name': user.first_name or '',
                    'last_name': user.last_name or '',
                    'email': user.email or '',
                    'date_joined': user.date_joined.isoformat() if user.date_joined else None,
                },
                'profile': {
                    'email': profile.email or user.email or '',
                }
            })
        except User.DoesNotExist:
            return JsonResponse({'error': 'User not found'}, status=404)
        except Exception as e:
            return JsonResponse({'error': str(e)}, status=500)


class HabitsView(View):
    """
    Habits API endpoint that returns all habits for the authenticated user.
    Also supports POST for creating new habits.
    """
    
    def get(self, request):
        """
        Returns all active habits for the authenticated user.
        
        Returns:
        - habits: list of habit objects with their details
        """
        if not request.user.is_authenticated:
            return JsonResponse({'error': 'Authentication required'}, status=401)
        
        try:
            from habit.analytics import all_tracked_habits, calculate_progress
            from habit.models import Habit
            from django.utils import timezone
            
            user_id = request.user.id
            # Get all habits (including those without completion_date or with future completion_date)
            # Also include habits where completion_date is None (just created)
            all_active_habits = Habit.objects.filter(
                user_id=user_id
            ).filter(
                models.Q(completion_date__gte=timezone.now()) | models.Q(completion_date__isnull=True)
            ).prefetch_related('streak')
            
            # Fallback to original function if needed, but try to get all active habits
            if all_active_habits.count() == 0:
                all_active_habits = all_tracked_habits(user_id=user_id)
            
            calculate_progress(all_active_habits)
            
            # Serialize habits to JSON
            habits_data = []
            for habit in all_active_habits:
                # Get streak - it's a related manager, use .first() or .all()[0]
                streak = habit.streak.first() if hasattr(habit, 'streak') else None
                habits_data.append({
                    'id': habit.id,
                    'name': habit.name,
                    'period': habit.period,
                    'frequency': habit.frequency,
                    'goal': habit.goal,
                    'notes': habit.notes or '',
                    'num_of_tasks': habit.num_of_tasks,
                    'in_progress': getattr(habit, 'in_progress', 0),
                    'progress': getattr(habit, 'progress', 0),
                    'streak': {
                        'current_streak': streak.current_streak if streak else 0,
                        'longest_streak': streak.longest_streak if streak else 0,
                        'num_of_completed_tasks': streak.num_of_completed_tasks if streak else 0,
                        'num_of_failed_tasks': streak.num_of_failed_tasks if streak else 0,
                    } if streak else {
                        'current_streak': 0,
                        'longest_streak': 0,
                        'num_of_completed_tasks': 0,
                        'num_of_failed_tasks': 0,
                    },
                    'creation_time': habit.creation_time.isoformat() if habit.creation_time else None,
                    'completion_date': habit.completion_date.isoformat() if habit.completion_date else None,
                })
            
            return JsonResponse({'habits': habits_data}, safe=False)
        except Exception as e:
            return JsonResponse({'error': str(e)}, status=500)
    
    def post(self, request):
        """
        Creates a new habit.
        
        Expects form data:
        - name: habit name
        - frequency: frequency number
        - period: 'daily', 'weekly', 'monthly', 'annual'
        - goal: goal string ('1 month', '3 days', etc.)
        - start_date: datetime string
        - notes: optional notes
        """
        if not request.user.is_authenticated:
            return JsonResponse({'error': 'Authentication required'}, status=401)
        
        try:
            from habit.forms import HabitForm
            
            form = HabitForm(request.POST)
            if form.is_valid():
                # Validate if the goal is achievable
                if not form.is_goal_achievable():
                    return JsonResponse({
                        'error': 'The frequency results in a goal that is not achievable. Choose a longer goal.'
                    }, status=400)
                
                # Validate if the habit name is not already used
                if not form.is_valid_habit_name(request.user):
                    return JsonResponse({
                        'error': 'You already used that name for another habit'
                    }, status=400)
                
                start_date = form.cleaned_data['start_date']
                # Save the form with the provided start_date
                habit = form.save(commit=False)
                habit.user = request.user
                habit.start_date = start_date
                habit.save()
                
                # Create tasks with their due and start dates for the habit
                from habit.models import TaskTracker
                TaskTracker.create_tasks(habit)
                
                habit_name = form.cleaned_data.get('name')
                return JsonResponse({
                    'success': True,
                    'message': f'{habit_name} Habit created',
                    'habit_id': habit.id
                })
            else:
                # Return form errors
                errors = {}
                for field, field_errors in form.errors.items():
                    errors[field] = field_errors
                return JsonResponse({
                    'error': 'Validation failed',
                    'errors': errors
                }, status=400)
        except Exception as e:
            return JsonResponse({'error': str(e)}, status=500)


class TasksView(View):
    """
    Tasks API endpoint that returns tasks for the authenticated user.
    """
    
    def get(self, request):
        """
        Returns tasks for the authenticated user.
        
        Query params:
        - type: 'due_today', 'active', or 'upcoming'
        
        Returns:
        - tasks: list of task objects
        """
        if not request.user.is_authenticated:
            return JsonResponse({'error': 'Authentication required'}, status=401)
        
        try:
            from habit.analytics import due_today_tasks, active_tasks, upcoming_tasks, update_user_activity
            
            user_id = request.user.id
            # Update user activity when fetching tasks (like the home view does)
            update_user_activity(user_id)
            
            task_type = request.GET.get('type', 'due_today')
            
            # Get tasks based on type
            if task_type == 'due_today':
                tasks_queryset = due_today_tasks(user_id=user_id)
            elif task_type == 'active':
                tasks_queryset = active_tasks(user_id=user_id)
            elif task_type == 'upcoming':
                tasks_queryset = upcoming_tasks(user_id=user_id)
            else:
                return JsonResponse({'error': 'Invalid task type'}, status=400)
            
            # Serialize tasks to JSON
            tasks_data = []
            for task in tasks_queryset:
                tasks_data.append({
                    'id': task.id,
                    'task_number': task.task_number,
                    'task_status': task.task_status,
                    'due_date': task.due_date.isoformat() if task.due_date else None,
                    'start_date': task.start_date.isoformat() if task.start_date else None,
                    'task_completion_date': task.task_completion_date.isoformat() if task.task_completion_date else None,
                    'habit': {
                        'id': task.habit.id,
                        'name': task.habit.name,
                        'period': task.habit.period,
                        'notes': task.habit.notes or '',
                    } if task.habit else None,
                })
            
            return JsonResponse({'tasks': tasks_data}, safe=False)
        except Exception as e:
            return JsonResponse({'error': str(e)}, status=500)


class HabitDetailView(View):
    """
    Habit detail API endpoint that returns detailed information about a specific habit.
    """
    
    def get(self, request, habit_id):
        """
        Returns detailed information for a specific habit.
        
        Returns:
        - habit: habit information
        - tasks: list of tasks for this habit
        - streak: streak information
        - achievements: list of achievements
        """
        if not request.user.is_authenticated:
            return JsonResponse({'error': 'Authentication required'}, status=401)
        
        try:
            from habit.models import Habit, TaskTracker, Streak, Achievement
            from habit.analytics import num_inprogress_tasks
            
            habit = Habit.objects.get(pk=habit_id, user=request.user)
            tasks = TaskTracker.objects.filter(habit_id=habit_id)
            streak = Streak.objects.filter(habit_id=habit_id).first()
            achievements = Achievement.objects.filter(habit_id=habit_id)
            
            # Update in-progress tasks count
            num_inprogress_tasks(habit)
            
            # Serialize tasks
            tasks_data = []
            for task in tasks:
                tasks_data.append({
                    'id': task.id,
                    'task_number': task.task_number,
                    'task_status': task.task_status,
                    'due_date': task.due_date.isoformat() if task.due_date else None,
                    'start_date': task.start_date.isoformat() if task.start_date else None,
                    'task_completion_date': task.task_completion_date.isoformat() if task.task_completion_date else None,
                })
            
            # Serialize achievements
            achievements_data = []
            for achievement in achievements:
                achievements_data.append({
                    'id': achievement.id,
                    'title': achievement.title,
                    'date': achievement.date.isoformat() if achievement.date else None,
                    'streak_length': achievement.streak_length,
                })
            
            return JsonResponse({
                'habit': {
                    'id': habit.id,
                    'name': habit.name,
                    'period': habit.period,
                    'frequency': habit.frequency,
                    'goal': habit.goal,
                    'notes': habit.notes or '',
                    'num_of_tasks': habit.num_of_tasks,
                    'in_progress': getattr(habit, 'in_progress', 0),
                    'creation_time': habit.creation_time.isoformat() if habit.creation_time else None,
                    'completion_date': habit.completion_date.isoformat() if habit.completion_date else None,
                },
                'tasks': tasks_data,
                'streak': {
                    'current_streak': streak.current_streak if streak else 0,
                    'longest_streak': streak.longest_streak if streak else 0,
                    'num_of_completed_tasks': streak.num_of_completed_tasks if streak else 0,
                    'num_of_failed_tasks': streak.num_of_failed_tasks if streak else 0,
                } if streak else None,
                'achievements': achievements_data,
            })
        except Habit.DoesNotExist:
            return JsonResponse({'error': 'Habit not found'}, status=404)
        except Exception as e:
            return JsonResponse({'error': str(e)}, status=500)


class CompleteTaskView(View):
    """
    Complete task API endpoint.
    """
    
    def get(self, request):
        """
        GET method to allow CSRF token fetching.
        Returns a simple success response.
        """
        if not request.user.is_authenticated:
            return JsonResponse({'error': 'Authentication required'}, status=401)
        return JsonResponse({'message': 'CSRF token endpoint'})
    
    def post(self, request):
        """
        Marks a task as completed.
        
        Expects:
        - task_id: ID of the task to complete
        - habit_id: ID of the habit the task belongs to
        """
        if not request.user.is_authenticated:
            return JsonResponse({'error': 'Authentication required'}, status=401)
        
        try:
            from habit.models import TaskTracker, Habit, Streak
            from habit.models import Achievement
            
            task_id = request.POST.get('task_id') or (hasattr(request, 'data') and request.data.get('task_id'))
            habit_id = request.POST.get('habit_id') or (hasattr(request, 'data') and request.data.get('habit_id'))
            
            if not task_id or not habit_id:
                return JsonResponse({'error': 'task_id and habit_id are required'}, status=400)
            
            task = TaskTracker.objects.get(id=task_id, habit__user=request.user)
            habit = Habit.objects.get(id=habit_id, user=request.user)
            streak = Streak.objects.get(habit_id=habit_id)
            
            # Update task
            task.task_status = 'Completed'
            task.task_completion_date = timezone.now()
            task.save()
            
            # Update streak
            streak.current_streak += 1
            streak.num_of_completed_tasks += 1
            Achievement.rewards_streaks(habit_id, streak)
            
            # Update user activity
            from habit.analytics import update_user_activity
            update_user_activity(request.user.id)
            
            habit.save()
            streak.save()
            
            return JsonResponse({
                'success': True,
                'message': f'{habit.name} task marked as completed'
            })
        except TaskTracker.DoesNotExist:
            return JsonResponse({'error': 'Task not found'}, status=404)
        except Habit.DoesNotExist:
            return JsonResponse({'error': 'Habit not found'}, status=404)
        except Streak.DoesNotExist:
            return JsonResponse({'error': 'Streak not found'}, status=404)
        except Exception as e:
            return JsonResponse({'error': str(e)}, status=500)


class DeleteHabitView(View):
    """
    Delete habit API endpoint.
    """
    
    def delete(self, request, habit_id):
        """
        Deletes a habit.
        """
        if not request.user.is_authenticated:
            return JsonResponse({'error': 'Authentication required'}, status=401)
        
        try:
            from habit.models import Habit
            
            habit = Habit.objects.get(pk=habit_id, user=request.user)
            habit_name = habit.name
            habit.delete()
            
            return JsonResponse({
                'success': True,
                'message': f'{habit_name} habit deleted successfully'
            })
        except Habit.DoesNotExist:
            return JsonResponse({'error': 'Habit not found'}, status=404)
        except Exception as e:
            return JsonResponse({'error': str(e)}, status=500)


class AnalysisView(View):
    """
    Habit analysis API endpoint.
    """
    
    def get(self, request):
        """
        Returns habit analysis data.
        """
        if not request.user.is_authenticated:
            return JsonResponse({'error': 'Authentication required'}, status=401)
        
        try:
            from habit.analytics import (
                all_tracked_habits, habits_by_period, all_completed_habits,
                longest_streak_over_all_habits, longest_current_streak_over_all_habits,
                calculate_progress
            )
            
            user_id = request.user.id
            
            # Get all habits
            all_habits = all_tracked_habits(user_id=user_id)
            daily_habits = habits_by_period('daily')(all_habits)
            weekly_habits = habits_by_period('weekly')(all_habits)
            monthly_habits = habits_by_period('monthly')(all_habits)
            completed_habits = all_completed_habits(user_id=user_id)
            
            # Calculate progress
            calculate_progress(all_habits)
            calculate_progress(daily_habits)
            calculate_progress(weekly_habits)
            calculate_progress(monthly_habits)
            
            # Helper to serialize habit
            def serialize_habit(habit):
                streak = habit.streak.first() if hasattr(habit, 'streak') else None
                return {
                    'id': habit.id,
                    'name': habit.name,
                    'period': habit.period,
                    'frequency': habit.frequency,
                    'goal': habit.goal,
                    'notes': habit.notes or '',
                    'num_of_tasks': habit.num_of_tasks,
                    'in_progress': getattr(habit, 'in_progress', 0),
                    'progress': getattr(habit, 'progress', 0),
                    'streak': [{
                        'current_streak': streak.current_streak if streak else 0,
                        'longest_streak': streak.longest_streak if streak else 0,
                        'num_of_completed_tasks': streak.num_of_completed_tasks if streak else 0,
                        'num_of_failed_tasks': streak.num_of_failed_tasks if streak else 0,
                    }] if streak else [],
                }
            
            # Get longest streaks
            longest_streak_habit = longest_streak_over_all_habits().first() if longest_streak_over_all_habits().exists() else None
            longest_current_streak_habit = longest_current_streak_over_all_habits().first() if longest_current_streak_over_all_habits().exists() else None
            
            return JsonResponse({
                'all_habits': [serialize_habit(h) for h in all_habits],
                'daily_habits': [serialize_habit(h) for h in daily_habits],
                'weekly_habits': [serialize_habit(h) for h in weekly_habits],
                'monthly_habits': [serialize_habit(h) for h in monthly_habits],
                'completed_habits': [serialize_habit(h) for h in completed_habits],
                'longest_streak_habit': serialize_habit(longest_streak_habit) if longest_streak_habit else None,
                'longest_current_streak_habit': serialize_habit(longest_current_streak_habit) if longest_current_streak_habit else None,
            })
        except Exception as e:
            return JsonResponse({'error': str(e)}, status=500)
    
    def post(self, request):
        """
        Returns detailed analysis for a specific habit.
        
        Expects:
        - selectedValue: ID of the habit to analyze
        """
        if not request.user.is_authenticated:
            return JsonResponse({'error': 'Authentication required'}, status=401)
        
        try:
            from habit.models import Habit
            import json
            from django.core import serializers
            
            selected_value = request.POST.get('selectedValue') or (hasattr(request, 'data') and request.data.get('selectedValue'))
            
            if not selected_value:
                return JsonResponse({'error': 'selectedValue is required'}, status=400)
            
            # Retrieve the habit object with related streak using prefetch_related
            habit = Habit.objects.prefetch_related('streak').get(id=selected_value, user=request.user)
            
            # Serialize the habit object along with related streak data
            habit_data = serializers.serialize('json', [habit])
            
            # Convert serialized data to Python dictionary
            habit_dict = json.loads(habit_data)[0]['fields']
            
            # Add streak data to habit dictionary
            habit_dict['streak'] = list(habit.streak.values())
            habit_dict['id'] = habit.id
            
            return JsonResponse(habit_dict, safe=False)
        except Habit.DoesNotExist:
            return JsonResponse({'error': 'Habit not found'}, status=404)
        except Exception as e:
            return JsonResponse({'error': str(e)}, status=500)
