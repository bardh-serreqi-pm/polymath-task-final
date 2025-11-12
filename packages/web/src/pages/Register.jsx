import React, { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { authService } from '../services/authService'
import '../App.css'

function Register({ onRegister }) {
  const [formData, setFormData] = useState({
    username: '',
    first_name: '',
    last_name: '',
    email: '',
    password: '',
    password2: '',
  })
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const navigate = useNavigate()

  const handleChange = (e) => {
    setFormData({
      ...formData,
      [e.target.name]: e.target.value,
    })
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    setError('')

    if (formData.password !== formData.password2) {
      setError('Passwords do not match')
      return
    }

    setLoading(true)

    try {
      await authService.register({
        username: formData.username,
        email: formData.email,
        password: formData.password,
        password2: formData.password2,
        first_name: formData.first_name,
        last_name: formData.last_name,
      })
      onRegister()
      navigate('/')
    } catch (err) {
      setError(err.message || 'Registration failed. Please try again.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <main role="main" className="container">
      <div className="row justify-content-center">
        <div className="col-md-9">
          <div className="card add-habit-card">
            <h2 className="card-header text-center">Sign up</h2>
            <div className="card-body">
              <form method="post" onSubmit={handleSubmit}>
                <div className="form-group row">
                  <label htmlFor="username" className="col-sm-4 col-form-label text-right">Username:</label>
                  <div className="col-sm-8">
                    <input
                      type="text"
                      id="username"
                      name="username"
                      className="form-control form-control-lg"
                      value={formData.username}
                      onChange={handleChange}
                      required
                    />
                  </div>
                </div>
                <div className="form-group row">
                  <label htmlFor="first_name" className="col-sm-4 col-form-label text-right">First name:</label>
                  <div className="col-sm-8">
                    <input
                      type="text"
                      id="first_name"
                      name="first_name"
                      className="form-control form-control-lg"
                      value={formData.first_name}
                      onChange={handleChange}
                    />
                  </div>
                </div>
                <div className="form-group row">
                  <label htmlFor="last_name" className="col-sm-4 col-form-label text-right">Last name:</label>
                  <div className="col-sm-8">
                    <input
                      type="text"
                      id="last_name"
                      name="last_name"
                      className="form-control form-control-lg"
                      value={formData.last_name}
                      onChange={handleChange}
                    />
                  </div>
                </div>
                <div className="form-group row">
                  <label htmlFor="email" className="col-sm-4 col-form-label text-right">Email:</label>
                  <div className="col-sm-8">
                    <input
                      type="email"
                      id="email"
                      name="email"
                      className="form-control form-control-lg"
                      value={formData.email}
                      onChange={handleChange}
                      required
                    />
                  </div>
                </div>
                <div className="form-group row">
                  <label htmlFor="password" className="col-sm-4 col-form-label text-right">Password:</label>
                  <div className="col-sm-8">
                    <input
                      type="password"
                      id="password"
                      name="password"
                      className="form-control form-control-lg"
                      value={formData.password}
                      onChange={handleChange}
                      required
                    />
                  </div>
                </div>
                <div className="form-group row">
                  <label htmlFor="password2" className="col-sm-4 col-form-label text-right">confirm Password :</label>
                  <div className="col-sm-8">
                    <input
                      type="password"
                      id="password2"
                      name="password2"
                      className="form-control form-control-lg"
                      value={formData.password2}
                      onChange={handleChange}
                      required
                    />
                  </div>
                </div>
                {error && <div className="text-danger mb-3">{error}</div>}
                <div className="col-sm-6 offset-sm-4">
                  <button type="submit" className="btn btn-primary btn-block" disabled={loading}>
                    {loading ? 'Registering...' : 'Sign Up'}
                  </button>
                </div>
              </form>
            </div>
            <div className="card-footer text-center">
              <p className="mt-3">Already have an account? <a href="/login">Sign in here</a>.</p>
            </div>
          </div>
        </div>
      </div>
    </main>
  )
}

export default Register

