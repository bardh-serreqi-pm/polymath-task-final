import React, { useState, useEffect } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { habitService } from '../services/habitService'
import '../App.css'

function DeleteHabit() {
  const { id } = useParams()
  const navigate = useNavigate()
  const [habit, setHabit] = useState(null)
  const [loading, setLoading] = useState(true)
  const [deleting, setDeleting] = useState(false)

  useEffect(() => {
    loadHabit()
  }, [id])

  const loadHabit = async () => {
    try {
      const habitData = await habitService.getHabit(id)
      // API returns { habit, tasks, streak, achievements }
      setHabit(habitData.habit || habitData)
    } catch (error) {
      console.error('Failed to load habit:', error)
    } finally {
      setLoading(false)
    }
  }

  const handleDelete = async () => {
    if (!window.confirm('Are you sure you want to delete this habit? This action cannot be undone.')) {
      return
    }

    try {
      setDeleting(true)
      await habitService.deleteHabit(id)
      navigate('/habit-manager')
    } catch (error) {
      console.error('Failed to delete habit:', error)
      alert('Failed to delete habit. Please try again.')
    } finally {
      setDeleting(false)
    }
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
        <p>Habit not found.</p>
      </main>
    )
  }

  return (
    <main role="main" className="container">
      <div className="row">
        <div className="col-md-8">
          <div className="card">
            <div className="card-body">
              <h2>Delete Habit</h2>
              <p>Are you sure you want to delete the habit: <strong>{habit?.name || 'Unknown'}</strong>?</p>
              <p className="text-danger">This action cannot be undone. All associated tasks, streaks, and achievements will be deleted.</p>
              <div className="mt-4">
                <button
                  onClick={handleDelete}
                  className="btn btn-danger mr-2"
                  disabled={deleting}
                >
                  {deleting ? 'Deleting...' : 'Yes, Delete'}
                </button>
                <button
                  onClick={() => navigate('/habit-manager')}
                  className="btn btn-secondary"
                  disabled={deleting}
                >
                  Cancel
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </main>
  )
}

export default DeleteHabit

