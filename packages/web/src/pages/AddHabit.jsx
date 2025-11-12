import React, { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { habitService } from '../services/habitService'
import api from '../services/api'
import '../App.css'

function AddHabit() {
  const navigate = useNavigate()
  const [formData, setFormData] = useState({
    name: '',
    frequency: 1,
    period: 'daily',
    goal: '1 month', // Django expects string like '1 month', '3 days', etc.
    start_date: new Date().toISOString().slice(0, 16), // datetime-local format
    notes: ''
  })
  const [errors, setErrors] = useState({})
  const [loading, setLoading] = useState(false)

  const preDefinedHabits = {
    'Exercise': { frequency: 1, period: 'daily', goal: '1 month', notes: 'Regular exercise for fitness' },
    'Meditation': { frequency: 1, period: 'daily', goal: '1 month', notes: 'Daily meditation practice' },
    'Reading': { frequency: 1, period: 'daily', goal: '1 month', notes: 'Read for 30 minutes daily' },
    'Water Intake': { frequency: 8, period: 'daily', goal: '1 month', notes: 'Drink 8 glasses of water daily' },
  }

  const handleChange = (e) => {
    const { name, value } = e.target
    setFormData({
      ...formData,
      [name]: name === 'frequency' ? parseInt(value) || 0 : value
    })
    // Clear error for this field
    if (errors[name]) {
      setErrors({ ...errors, [name]: '' })
    }
  }

  const populateForm = (habitName) => {
    if (habitName && preDefinedHabits[habitName]) {
      const details = preDefinedHabits[habitName]
      setFormData({
        ...formData,
        name: habitName,
        frequency: details.frequency,
        period: details.period,
        goal: details.goal,
        notes: details.notes
      })
    }
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    setErrors({})
    setLoading(true)

    // Validation
    const newErrors = {}
    if (!formData.name.trim()) {
      newErrors.name = 'Name is required'
    }
    if (formData.frequency < 1) {
      newErrors.frequency = 'Frequency must be at least 1'
    }
    if (!formData.goal) {
      newErrors.goal = 'Goal is required'
    }
    if (!formData.start_date) {
      newErrors.start_date = 'Start date is required'
    }

    if (Object.keys(newErrors).length > 0) {
      setErrors(newErrors)
      setLoading(false)
      return
    }

    try {
      // Get CSRF token from API endpoint
      await api.get('/api/habits/')
      
      await habitService.createHabit(formData)
      // Navigate to habit manager after successful creation
      navigate('/habit-manager')
    } catch (error) {
      console.error('Create habit error:', error)
      setErrors({ submit: error.message || 'Failed to create habit. Please try again.' })
    } finally {
      setLoading(false)
    }
  }

  return (
    <main role="main" className="container">
      <div className="row justify-content-center">
        <div className="col-md-8">
          <div className="card add-habit-card">
            <h2 className="card-header text-center">Create a New Habit</h2>
            <div className="card-body">
              <div className="form-group row">
                <label htmlFor="habitSelect" className="col-sm-3 col-form-label text-right">
                  Select Habit:
                </label>
                <div className="col-sm-9">
                  <select
                    id="habitSelect"
                    onChange={(e) => populateForm(e.target.value)}
                    className="form-control"
                  >
                    <option value="">Choose Predefined Habits</option>
                    {Object.keys(preDefinedHabits).map(habit => (
                      <option key={habit} value={habit}>{habit}</option>
                    ))}
                  </select>
                </div>
              </div>

              {/* Custom creation prompt */}
              <div className="form-group row">
                <div className="col-sm-9 offset-sm-3">
                  <h5 className="text-start custom-create-habit-text">Or Custom Create a New Habit</h5>
                </div>
              </div>

              <form onSubmit={handleSubmit}>
                <div className="form-group row">
                  <label htmlFor="name" className="col-sm-3 col-form-label text-right">Name:</label>
                  <div className="col-sm-9">
                    <input
                      type="text"
                      id="name"
                      name="name"
                      value={formData.name}
                      onChange={handleChange}
                      className={errors.name ? 'is-invalid' : ''}
                    />
                    {errors.name && <small className="text-danger">{errors.name}</small>}
                  </div>
                </div>

                <div className="form-group row">
                  <label htmlFor="frequency" className="col-sm-3 col-form-label text-right">Frequency:</label>
                  <div className="col-sm-9">
                    <input
                      type="number"
                      id="frequency"
                      name="frequency"
                      value={formData.frequency}
                      onChange={handleChange}
                      min="1"
                      className={errors.frequency ? 'is-invalid' : ''}
                    />
                    {errors.frequency && <small className="text-danger">{errors.frequency}</small>}
                  </div>
                </div>

                <div className="form-group row">
                  <label htmlFor="period" className="col-sm-3 col-form-label text-right">Period:</label>
                  <div className="col-sm-9">
                    <select
                      id="period"
                      name="period"
                      value={formData.period}
                      onChange={handleChange}
                      className="form-select"
                    >
                      <option value="daily">Daily</option>
                      <option value="weekly">Weekly</option>
                      <option value="monthly">Monthly</option>
                    </select>
                  </div>
                </div>

                <div className="form-group row">
                  <label htmlFor="goal" className="col-sm-3 col-form-label text-right">Goal:</label>
                  <div className="col-sm-9">
                    <select
                      id="goal"
                      name="goal"
                      value={formData.goal}
                      onChange={handleChange}
                      className={errors.goal ? 'is-invalid' : 'form-select'}
                    >
                      <option value="3 days">3 Days</option>
                      <option value="1 week">1 Week</option>
                      <option value="1 month">1 Month</option>
                      <option value="2 months">2 Months</option>
                      <option value="3 months">3 Months</option>
                      <option value="6 months">6 Months</option>
                      <option value="1 year">1 Year</option>
                    </select>
                    {errors.goal && <small className="text-danger">{errors.goal}</small>}
                  </div>
                </div>

                <div className="form-group row">
                  <label htmlFor="start_date" className="col-sm-3 col-form-label text-right">Start Date:</label>
                  <div className="col-sm-9">
                    <div className="input-group">
                      <input
                        type="datetime-local"
                        id="start_date"
                        name="start_date"
                        value={formData.start_date}
                        onChange={handleChange}
                        className="start-date-field"
                      />
                    </div>
                  </div>
                </div>

                <div className="form-group row">
                  <label htmlFor="notes" className="col-sm-3 col-form-label text-right">Notes:</label>
                  <div className="col-sm-9">
                    <textarea
                      id="notes"
                      name="notes"
                      value={formData.notes}
                      onChange={handleChange}
                      rows="3"
                    />
                  </div>
                </div>

                {errors.submit && <div className="alert alert-danger">{errors.submit}</div>}

                <div className="form-group row">
                  <div className="col-sm-7 offset-sm-3">
                    <button type="submit" className="btn btn-primary btn-block" disabled={loading}>
                      {loading ? 'Creating...' : 'Create Habit'}
                    </button>
                  </div>
                </div>
              </form>
            </div>
          </div>
        </div>
      </div>
    </main>
  )
}

export default AddHabit

