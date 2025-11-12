import React from 'react'
import { Link } from 'react-router-dom'

function HabitCard({ habit }) {
  // Handle both array and object streak formats
  const streak = habit.streak && (Array.isArray(habit.streak) ? habit.streak[0] : habit.streak) || {}
  const progressPercentage = habit.progress || habit.progress_percentage || 0

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

  return (
    <div className="col-md-6 mb-4">
      <div className="card streak-card">
        <div className="card-body d-flex flex-column">
          <div className="d-flex justify-content-between align-items-center">
            <h5 
              className="card-title" 
              style={{
                maxHeight: '3.6rem', 
                overflow: 'hidden', 
                textOverflow: 'ellipsis', 
                whiteSpace: 'nowrap'
              }}
            >
              {habit.name?.charAt(0).toUpperCase() + habit.name?.slice(1) || 'Habit'}
            </h5>
            <div className="btn-group">
              <Link 
                className="btn btn-text mt-1" 
                to={`/delete-habit/${habit.id}`}
                onClick={(e) => {
                  if (!window.confirm('Are you sure you want to delete this habit?')) {
                    e.preventDefault()
                  }
                }}
              >
                <i className="fas fa-trash text-danger"></i>
              </Link>
            </div>
          </div>
          <h6 className="card-subtitle mb-2 text-muted">
            {(habit.period || 'daily').charAt(0).toUpperCase() + (habit.period || 'daily').slice(1)} Habit
          </h6>
          <p className="card-text"><strong>Started:</strong> {formatDate(habit.creation_time)}</p>
          <p className="card-text"><strong>Completion date:</strong> {formatDate(habit.completion_date)}</p>
          <p className="card-text"><strong>Longest Streak:</strong> {streak.longest_streak || 0}</p>
          <p className="card-text"><strong>Current Streak:</strong> {streak.current_streak || 0}</p>
          <div className="progress mt-auto">
            <div 
              className="progress-bar bg-blue" 
              role="progressbar" 
              style={{ width: `${progressPercentage}%` }}
              aria-valuenow={progressPercentage} 
              aria-valuemin="0" 
              aria-valuemax="100"
            ></div>
          </div>
          <div className="row">
            <div className="col text-left">
              <p className="progress-text"><strong>Progress:</strong></p>
            </div>
            <div className="col text-right">
              <p className="progress-text">{progressPercentage.toFixed(2)}%</p>
            </div>
          </div>
          <Link className="btn btn-text btn-block mt-1" to={`/habit-details/${habit.id}`}>
            More Details
          </Link>
        </div>
      </div>
    </div>
  )
}

export default HabitCard

