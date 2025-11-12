import React, { useState, useEffect } from 'react'
import { Link } from 'react-router-dom'
import api from '../services/api'
import '../App.css'

function Profile() {
  const [profile, setProfile] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    loadProfile()
  }, [])

  const loadProfile = async () => {
    try {
      setLoading(true)
      setError('')
      const response = await api.get('/api/profile/')
      setProfile(response.data)
    } catch (err) {
      console.error('Failed to load profile:', err)
      setError(err.response?.data?.error || 'Failed to load profile')
    } finally {
      setLoading(false)
    }
  }

  const formatDate = (dateString) => {
    if (!dateString) return 'N/A'
    const date = new Date(dateString)
    return date.toLocaleDateString('en-US', { 
      weekday: 'short',
      year: 'numeric', 
      month: 'short', 
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit'
    })
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

  if (error) {
    return (
      <main role="main" className="container mt-3">
        <div className="row justify-content-center">
          <div className="col-md-8">
            <div className="alert alert-danger">{error}</div>
            <Link className="btn btn-primary" to="/">Back to Home</Link>
          </div>
        </div>
      </main>
    )
  }

  if (!profile) {
    return (
      <main role="main" className="container mt-3">
        <div className="row justify-content-center">
          <div className="col-md-8">
            <div className="alert alert-warning">No profile data available</div>
            <Link className="btn btn-primary" to="/">Back to Home</Link>
          </div>
        </div>
      </main>
    )
  }

  return (
    <main role="main" className="container mt-3">
      <div className="row justify-content-center">
        <div className="col-md-8">
          <div className="card add-habit-card">
            <h1 className="card-header text-center">User Profile</h1>
            <div className="card-body">
              <p>
                <i className="bi bi-person"></i> <strong>Full Name:</strong>{' '}
                {profile?.user?.first_name || ''} {profile?.user?.last_name || ''}
                {(!profile?.user?.first_name && !profile?.user?.last_name) && (
                  <span className="text-muted">Not set</span>
                )}
              </p>
              <p>
                <i className="bi bi-envelope"></i> <strong>Email:</strong>{' '}
                {profile?.profile?.email || profile?.user?.email || 'Not set'}
              </p>
              <p>
                <i className="bi bi-calendar"></i> <strong>Joined:</strong>{' '}
                {formatDate(profile?.user?.date_joined)}
              </p>
              <div className="form-group row">
                <div className="col-sm-7 offset-sm-1">
                  <Link className="btn btn-primary btn-block" to="/">
                    Back to Habit Dashboard
                  </Link>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </main>
  )
}

export default Profile
