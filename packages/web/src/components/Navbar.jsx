import React from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { authService } from '../services/authService'
import '../App.css'

function Navbar({ onLogout }) {
  const navigate = useNavigate()

  const handleLogout = async (e) => {
    e.preventDefault()
    e.stopPropagation()
    try {
      await authService.logout()
      onLogout()
      navigate('/login')
    } catch (error) {
      console.error('Logout error:', error)
      // Even if logout fails, clear local auth state
      onLogout()
      navigate('/login')
    }
  }

  return (
    <header className="site-header">
      <nav className="navbar navbar-expand-md navbar-dark bg-steel fixed-top">
        <div className="container">
          <Link className="navbar-brand mr-4" to="/">
            <i className="fa-solid fa-house"></i> Habit Tracker
          </Link>
          <button 
            className="navbar-toggler" 
            type="button" 
            data-toggle="collapse" 
            data-target="#navbarToggle" 
            aria-controls="navbarToggle" 
            aria-expanded="false" 
            aria-label="Toggle navigation"
          >
            <span className="navbar-toggler-icon"></span>
          </button>
          <div className="collapse navbar-collapse" id="navbarToggle">
            <div className="navbar-nav ml-auto">
              <div className="nav-item dropdown">
                <a 
                  className="nav-link dropdown-toggle" 
                  href="#" 
                  id="navbarDropdown" 
                  role="button" 
                  data-toggle="dropdown" 
                  aria-haspopup="true" 
                  aria-expanded="false"
                >
                  Menu
                </a>
                <div className="dropdown-menu" aria-labelledby="navbarDropdown">
                  <Link className="dropdown-item" to="/profile">Profile</Link>
                  <div className="dropdown-divider"></div>
                  <button 
                    className="dropdown-item" 
                    onClick={handleLogout} 
                    style={{ border: 'none', background: 'none', width: '100%', textAlign: 'left', padding: '0.5rem 1rem' }}
                  >
                    Logout
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </nav>
    </header>
  )
}

export default Navbar
