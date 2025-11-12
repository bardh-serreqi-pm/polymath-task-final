import React, { useState, useEffect } from 'react'
import { Link } from 'react-router-dom'
import { habitService } from '../services/habitService'
import api from '../services/api'
import '../App.css'

function Home() {
  const [dueTodayTasks, setDueTodayTasks] = useState([])
  const [availableTasks, setAvailableTasks] = useState([])
  const [upcomingTasks, setUpcomingTasks] = useState([])
  const [activeTab, setActiveTab] = useState('daily')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [userFullName, setUserFullName] = useState('')

  useEffect(() => {
    loadTasks()
    loadUserProfile()
  }, [])

  const loadUserProfile = async () => {
    try {
      const response = await api.get('/api/profile/')
      if (response.data?.user) {
        const firstName = response.data.user.first_name || ''
        const lastName = response.data.user.last_name || ''
        const fullName = `${firstName} ${lastName}`.trim() || response.data.user.username || 'User'
        setUserFullName(fullName)
      }
    } catch (err) {
      console.error('Failed to load user profile:', err)
      setUserFullName('User')
    }
  }

  const loadTasks = async () => {
    try {
      setLoading(true)
      setError('')
      
      // Fetch tasks from API
      const [dueTodayResponse, activeResponse, upcomingResponse] = await Promise.all([
        api.get('/api/tasks/?type=due_today'),
        api.get('/api/tasks/?type=active'),
        api.get('/api/tasks/?type=upcoming'),
      ])
      
      setDueTodayTasks(Array.isArray(dueTodayResponse.data?.tasks) ? dueTodayResponse.data.tasks : [])
      setAvailableTasks(Array.isArray(activeResponse.data?.tasks) ? activeResponse.data.tasks : [])
      setUpcomingTasks(Array.isArray(upcomingResponse.data?.tasks) ? upcomingResponse.data.tasks : [])
    } catch (err) {
      console.error('Failed to load tasks:', err)
      setError(err.response?.data?.error || err.message || 'Failed to load tasks')
      // Set empty arrays on error
      setDueTodayTasks([])
      setAvailableTasks([])
      setUpcomingTasks([])
    } finally {
      setLoading(false)
    }
  }

  const handleCompleteTask = async (taskId, habitId) => {
    try {
      // First, get CSRF token
      await api.get('/api/tasks/complete/')
      await habitService.completeTask(taskId, habitId)
      loadTasks() // Reload tasks
    } catch (err) {
      console.error('Failed to complete task:', err)
      setError(err.message || 'Failed to complete task')
    }
  }

  const formatDate = (dateString) => {
    if (!dateString) return ''
    const date = new Date(dateString)
    return date.toLocaleDateString('en-US', { 
      year: 'numeric', 
      month: 'long', 
      day: 'numeric',
      hour: 'numeric',
      minute: '2-digit',
      hour12: true
    })
  }

  const showTasks = (period) => {
    setActiveTab(period)
  }

  const renderTaskCard = (task) => (
    <div key={task.id} className="col-md-8 mb-3">
      <div className="card home-streak-card">
        <h5 className="home-card-title">{task.habit?.name || 'Habit'}</h5>
        <h7 className="card-subtitle mb-1 text-muted">
          {(task.habit?.period || 'daily').charAt(0).toUpperCase() + (task.habit?.period || 'daily').slice(1)} Habit
        </h7>
        <div className="card-body">
          <form onSubmit={(e) => {
            e.preventDefault()
            handleCompleteTask(task.id, task.habit?.id)
          }}>
            <input type="hidden" name="task_id" value={task.id} />
            <input type="hidden" name="habit_id" value={task.habit?.id} />
            <label className="form-check-label" htmlFor={`task_${task.id}`}>
              N of Task: {task.task_number}
            </label>
            <p className="mt-2">
              {activeTab === 'upcoming' ? (
                <>
                  Start: {formatDate(task.start_date)} at {formatDate(task.due_date)}
                  <br />
                  Due: {formatDate(task.due_date)}
                </>
              ) : (
                <>Due: {formatDate(task.due_date)}</>
              )}
            </p>
            {activeTab === 'upcoming' && task.habit?.notes && (
              <p><i className="bi bi-person mt-2"></i> <strong>Notes:</strong> {task.habit.notes}</p>
            )}
            {activeTab !== 'upcoming' && (
              <button type="submit" className="btn btn-success">Mark as Complete</button>
            )}
          </form>
        </div>
      </div>
    </div>
  )

  if (loading) {
    return (
      <main role="main" className="container">
        <div className="row">
          <div className="col-md-8">
            <div className="loading-container">
              <div className="spinner"></div>
              <p>Loading...</p>
            </div>
          </div>
        </div>
      </main>
    )
  }

  return (
    <main role="main" className="container">
      <div className="row">
        <div className="col-md-8">
          {error && <div className="alert alert-danger">{error}</div>}
          <h1 className="mt-4">Welcome {userFullName}</h1>

          {/* Buttons for Add Habit, Habit Manager, Habit Analysis */}
          <Link className="btn btn-primary mb-4" to="/add-habit">Add Habit</Link>
          <Link className="btn btn-danger mb-4" to="/habit-manager">Habit Manager</Link>
          <Link className="btn btn-success mb-4" to="/analysis">Habit Analysis</Link>

          {/* Buttons for Daily, Weekly, and Upcoming Tasks */}
          <div className="mb-4">
            <button
              id="daily-tasks-button"
              className={`switcher-button ${activeTab === 'daily' ? 'active' : ''}`}
              onClick={() => showTasks('daily')}
            >
              Due Today Tasks
            </button>
            <button
              id="weekly-tasks-button"
              className={`switcher-button ${activeTab === 'weekly' ? 'active' : ''}`}
              onClick={() => showTasks('weekly')}
            >
              Active Tasks
            </button>
            <button
              id="upcoming-tasks-button"
              className={`switcher-button ${activeTab === 'upcoming' ? 'active' : ''}`}
              onClick={() => showTasks('upcoming')}
            >
              Upcoming Tasks
            </button>
          </div>

          {/* Display Due Today Tasks */}
          {activeTab === 'daily' && (
            <div id="daily-tasks" className="task-container">
              {!Array.isArray(dueTodayTasks) || dueTodayTasks.length === 0 ? (
                <p>No tasks due today.</p>
              ) : (
                dueTodayTasks.map(renderTaskCard)
              )}
            </div>
          )}

          {/* Display Active Tasks */}
          {activeTab === 'weekly' && (
            <div id="weekly-tasks" className="task-container">
              {!Array.isArray(availableTasks) || availableTasks.length === 0 ? (
                <p>No active tasks available.</p>
              ) : (
                availableTasks.map(renderTaskCard)
              )}
            </div>
          )}

          {/* Display Upcoming Tasks */}
          {activeTab === 'upcoming' && (
            <div id="upcoming-tasks" className="task-container">
              {!Array.isArray(upcomingTasks) || upcomingTasks.length === 0 ? (
                <p>No upcoming tasks.</p>
              ) : (
                upcomingTasks.map(renderTaskCard)
              )}
            </div>
          )}
        </div>
      </div>
    </main>
  )
}

export default Home
