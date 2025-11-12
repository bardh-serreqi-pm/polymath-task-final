import React, { useState, useEffect } from 'react'
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom'
import Login from './pages/Login'
import Register from './pages/Register'
import Home from './pages/Home'
import HabitManager from './pages/HabitManager'
import AddHabit from './pages/AddHabit'
import HabitDetails from './pages/HabitDetails'
import DeleteHabit from './pages/DeleteHabit'
import HabitAnalysis from './pages/HabitAnalysis'
import Profile from './pages/Profile'
import Navbar from './components/Navbar'
import { authService } from './services/authService'
import './App.css'

function App() {
  const [isAuthenticated, setIsAuthenticated] = useState(false)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    // Check if user is authenticated
    const checkAuth = async () => {
      try {
        const authenticated = await authService.isAuthenticated()
        setIsAuthenticated(authenticated)
      } catch (error) {
        console.error('Auth check failed:', error)
        setIsAuthenticated(false)
      } finally {
        setLoading(false)
      }
    }

    checkAuth()
  }, [])

  if (loading) {
    return (
      <div className="loading-container">
        <div className="spinner"></div>
        <p>Loading...</p>
      </div>
    )
  }

  return (
    <Router>
      <div className="App">
        {isAuthenticated && <Navbar onLogout={() => setIsAuthenticated(false)} />}
        <Routes>
          <Route 
            path="/login" 
            element={
              isAuthenticated ? <Navigate to="/" /> : <Login onLogin={() => setIsAuthenticated(true)} />
            } 
          />
          <Route 
            path="/register" 
            element={
              isAuthenticated ? <Navigate to="/" /> : <Register onRegister={() => setIsAuthenticated(true)} />
            } 
          />
          <Route 
            path="/" 
            element={
              isAuthenticated ? <Home /> : <Navigate to="/login" />
            } 
          />
          <Route 
            path="/habit-manager" 
            element={
              isAuthenticated ? <HabitManager /> : <Navigate to="/login" />
            } 
          />
          <Route 
            path="/add-habit" 
            element={
              isAuthenticated ? <AddHabit /> : <Navigate to="/login" />
            } 
          />
          <Route 
            path="/habit-details/:id" 
            element={
              isAuthenticated ? <HabitDetails /> : <Navigate to="/login" />
            } 
          />
          <Route 
            path="/delete-habit/:id" 
            element={
              isAuthenticated ? <DeleteHabit /> : <Navigate to="/login" />
            } 
          />
          <Route 
            path="/analysis" 
            element={
              isAuthenticated ? <HabitAnalysis /> : <Navigate to="/login" />
            } 
          />
          <Route 
            path="/profile" 
            element={
              isAuthenticated ? <Profile /> : <Navigate to="/login" />
            } 
          />
        </Routes>
      </div>
    </Router>
  )
}

export default App

