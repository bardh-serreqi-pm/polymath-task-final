import React, { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { authService } from '../services/authService'
import '../App.css'

function Login({ onLogin }) {
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const navigate = useNavigate()

  const handleSubmit = async (e) => {
    e.preventDefault()
    setError('')
    setLoading(true)

    try {
      await authService.login(username, password)
      onLogin()
      navigate('/')
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  return (
    <main role="main" className="container">
      <div className="row justify-content-center">
        <div className="col-md-7">
          <div className="card add-habit-card">
            <h2 className="card-header text-center">Login</h2>
            <div className="card-body">
              <form method="post" onSubmit={handleSubmit}>
                <div className="form-group row">
                  <label htmlFor="username" className="col-sm-3 col-form-label text-right">Username</label>
                  <div className="col-sm-8">
                    <input
                      type="text"
                      id="username"
                      className="form-control form-control-lg"
                      value={username}
                      onChange={(e) => setUsername(e.target.value)}
                      required
                    />
                    {error && <small className="text-danger">{error}</small>}
                  </div>
                </div>
                <div className="form-group row">
                  <label htmlFor="password" className="col-sm-3 col-form-label text-right">Password</label>
                  <div className="col-sm-8">
                    <input
                      type="password"
                      id="password"
                      className="form-control form-control-lg"
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      required
                    />
                  </div>
                </div>
                <div className="col-sm-6 offset-sm-3">
                  <button type="submit" className="btn btn-primary btn-block" disabled={loading}>
                    {loading ? 'Logging in...' : 'Log In'}
                  </button>
                </div>
              </form>
            </div>
            <div className="card-footer text-center">
              <p className="mt-3">Don't have an account? <a href="/register">Sign up here</a>.</p>
            </div>
          </div>
        </div>
      </div>
    </main>
  )
}

export default Login

