import React, { useState, useEffect } from 'react'
import { useParams } from 'react-router-dom'
import { habitService } from '../services/habitService'
import '../App.css'

function HabitDetails() {
  const { id } = useParams()
  const [habit, setHabit] = useState(null)
  const [tasks, setTasks] = useState([])
  const [streak, setStreak] = useState({})
  const [achievements, setAchievements] = useState([])
  const [activeTab, setActiveTab] = useState('task')
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    loadHabitDetails()
  }, [id])

  const loadHabitDetails = async () => {
    try {
      setLoading(true)
      const habitData = await habitService.getHabit(id)
      // API returns { habit, tasks, streak, achievements }
      setHabit(habitData.habit || habitData)
      setTasks(Array.isArray(habitData?.tasks) ? habitData.tasks : [])
      setStreak(habitData.streak || {})
      setAchievements(Array.isArray(habitData?.achievements) ? habitData.achievements : [])
    } catch (error) {
      console.error('Failed to load habit details:', error)
      // Ensure arrays are set even on error
      setTasks([])
      setStreak({})
      setAchievements([])
    } finally {
      setLoading(false)
    }
  }

  const formatDate = (dateString) => {
    if (!dateString) return 'N/A'
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

  const showTasks = (kind) => {
    setActiveTab(kind)
  }

  if (loading) {
    return (
      <main role="main" className="container">
        <div className="loading-container">
          <div className="spinner"></div>
        </div>
      </main>
    )
  }

  if (!habit) {
    return (
      <main role="main" className="container">
        <p>No habit found.</p>
      </main>
    )
  }

  // streak is already in state

  return (
    <main role="main" className="container mt-2">
      <div className="row">
        <div className="col-md-6">
          <div className="card streak-card mb-2">
            <h2 className="card-header">Habit Infos</h2>
            <div className="card-body">
              <h4 className="card-subtitle mb-1 text-muted">
                {(habit.period || 'daily').charAt(0).toUpperCase() + (habit.period || 'daily').slice(1)} Habit
              </h4>
              <p><i className="bi bi-person mt-2"></i> <strong>Habit Name:</strong> {habit.name?.charAt(0).toUpperCase() + habit.name?.slice(1)}</p>
              <p><i className="bi bi-calendar"></i> <strong>Started:</strong> {formatDate(habit.creation_time)}</p>
              <p><i className="bi bi-calendar"></i> <strong>Completion date:</strong> {formatDate(habit.completion_date)}</p>
              <h4 className="mt-3"><strong>Tasks</strong></h4>
              <div className="row">
                <div className="col">
                  <p><i className="bi bi-check2"></i> <strong>Total:</strong> {habit.num_of_tasks || 0}</p>
                </div>
                <div className="col">
                  <p><i className="bi bi-check2"></i> <strong>In progress:</strong> {habit.in_progress || 0}</p>
                </div>
              </div>
              <div className="row">
                <div className="col">
                  <p><i className="bi bi-check2"></i> <strong>Success:</strong> {streak.num_of_completed_tasks || 0}</p>
                </div>
                <div className="col">
                  <p><i className="bi bi-check2"></i> <strong>Failed:</strong> {streak.num_of_failed_tasks || 0}</p>
                </div>
              </div>
              <h4 className="mt-3"><strong>Streak</strong></h4>
              <div className="row">
                <div className="col">
                  <p><i className="bi bi-check2"></i> <strong>Longest:</strong> {streak.longest_streak || 0}</p>
                </div>
                <div className="col">
                  <p><i className="bi bi-check2"></i> <strong>Current:</strong> {streak.current_streak || 0}</p>
                </div>
              </div>
              <p><i className="bi bi-person mt-2"></i> <strong>Notes:</strong> {habit.notes || 'No notes'}</p>
            </div>
          </div>
        </div>
        <div className="col-md-6">
          <button
            id="task-log-button"
            className={`switcher-button ${activeTab === 'task' ? 'active' : ''}`}
            onClick={() => showTasks('task')}
          >
            Task log
          </button>
          <button
            id="streak-log-button"
            className={`switcher-button ${activeTab === 'streak' ? 'active' : ''}`}
            onClick={() => showTasks('streak')}
          >
            Streak log
          </button>
          <div className="container mt-5 table-container" id="task-log" style={{ display: activeTab === 'task' ? 'block' : 'none' }}>
            <div className="row">
              <div className="col-md-12">
                <table className="table">
                  <thead>
                    <tr>
                      <th>N</th>
                      <th>Status</th>
                      <th>Completion Date</th>
                    </tr>
                  </thead>
                  <tbody>
                    {Array.isArray(tasks) && tasks.filter(task => task.task_status === 'Completed' || task.task_status === 'Failed').map((task, index) => (
                      <tr key={task.id || index}>
                        <td>{index + 1}</td>
                        <td>{task.task_status}</td>
                        <td>{formatDate(task.task_completion_date)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
          <div className="container mt-5 table-container" id="streak-log" style={{ display: activeTab === 'streak' ? 'block' : 'none' }}>
            <div className="row">
              <div className="col-md-12">
                <table className="table">
                  <thead>
                    <tr>
                      <th>Id</th>
                      <th>Streak</th>
                      <th>Date</th>
                    </tr>
                  </thead>
                  <tbody>
                    {Array.isArray(achievements) && achievements.map((achievement, index) => (
                      <tr key={achievement.id || index}>
                        <td>{index + 1}</td>
                        <td>{achievement.title}</td>
                        <td>{formatDate(achievement.date)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        </div>
      </div>
    </main>
  )
}

export default HabitDetails

