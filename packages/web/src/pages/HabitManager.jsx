import React, { useState, useEffect } from 'react'
import { habitService } from '../services/habitService'
import HabitCard from '../components/HabitCard'
import '../App.css'

function HabitManager() {
  const [allHabits, setAllHabits] = useState([])
  const [dailyHabits, setDailyHabits] = useState([])
  const [weeklyHabits, setWeeklyHabits] = useState([])
  const [monthlyHabits, setMonthlyHabits] = useState([])
  const [activeTab, setActiveTab] = useState('all')
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    loadHabits()
  }, [])

  const loadHabits = async () => {
    try {
      setLoading(true)
      const habits = await habitService.getHabits()
      // Ensure habits is an array
      const habitsArray = Array.isArray(habits) ? habits : []
      // Filter habits by period
      setAllHabits(habitsArray)
      setDailyHabits(habitsArray.filter(h => h.period === 'daily'))
      setWeeklyHabits(habitsArray.filter(h => h.period === 'weekly'))
      setMonthlyHabits(habitsArray.filter(h => h.period === 'monthly'))
    } catch (error) {
      console.error('Failed to load habits:', error)
      // Ensure arrays are set even on error
      setAllHabits([])
      setDailyHabits([])
      setWeeklyHabits([])
      setMonthlyHabits([])
    } finally {
      setLoading(false)
    }
  }

  const showTasks = (period) => {
    setActiveTab(period)
  }

  const renderHabits = (habits) => {
    // Ensure habits is an array
    const habitsArray = Array.isArray(habits) ? habits : []
    if (habitsArray.length === 0) {
      return <p>No habits found.</p>
    }
    return (
      <div className="row">
        {habitsArray.map(habit => (
          <HabitCard key={habit.id} habit={habit} />
        ))}
      </div>
    )
  }

  if (loading) {
    return (
      <main role="main" className="container">
        <div className="row">
          <div className="col-md-8">
            <div className="loading-container">
              <div className="spinner"></div>
            </div>
          </div>
        </div>
      </main>
    )
  }

  return (
    <main role="main" className="container">
      <div className="row">
        <div className="col-md-11">
          <h1 className="my-4">Habits Manager</h1>
          {/* Buttons for Daily, Weekly, Monthly, and All Tasks */}
          <div className="mb-4">
            <button
              id="all-button"
              className={`switcher-button ${activeTab === 'all' ? 'active' : ''}`}
              onClick={() => showTasks('all')}
            >
              All
            </button>
            <button
              id="daily-button"
              className={`switcher-button ${activeTab === 'daily' ? 'active' : ''}`}
              onClick={() => showTasks('daily')}
            >
              Daily
            </button>
            <button
              id="weekly-button"
              className={`switcher-button ${activeTab === 'weekly' ? 'active' : ''}`}
              onClick={() => showTasks('weekly')}
            >
              Weekly
            </button>
            <button
              id="monthly-button"
              className={`switcher-button ${activeTab === 'monthly' ? 'active' : ''}`}
              onClick={() => showTasks('monthly')}
            >
              Monthly
            </button>
          </div>

          <div className="container">
            <div className="row">
              <div className="col-md-11">
                {/* Display All Habits */}
                {activeTab === 'all' && (
                  <div id="all-active-habits">
                    {renderHabits(allHabits)}
                  </div>
                )}

                {/* Display Daily Habits */}
                {activeTab === 'daily' && (
                  <div id="daily-active-habits">
                    {renderHabits(dailyHabits)}
                  </div>
                )}

                {/* Display Weekly Habits */}
                {activeTab === 'weekly' && (
                  <div id="weekly-active-habits">
                    {renderHabits(weeklyHabits)}
                  </div>
                )}

                {/* Display Monthly Habits */}
                {activeTab === 'monthly' && (
                  <div id="monthly-active-habits">
                    {renderHabits(monthlyHabits)}
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>
      </div>
    </main>
  )
}

export default HabitManager
