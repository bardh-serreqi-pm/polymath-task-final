import React, { useState, useEffect } from 'react'
import { Link } from 'react-router-dom'
import { habitService } from '../services/habitService'
import api from '../services/api'
import '../App.css'

function HabitAnalysis() {
  const [allHabits, setAllHabits] = useState([])
  const [dailyHabits, setDailyHabits] = useState([])
  const [weeklyHabits, setWeeklyHabits] = useState([])
  const [monthlyHabits, setMonthlyHabits] = useState([])
  const [completedHabits, setCompletedHabits] = useState([])
  const [selectedPeriod, setSelectedPeriod] = useState('all')
  const [selectedHabit, setSelectedHabit] = useState('')
  const [habitData, setHabitData] = useState(null)
  const [showHabitDropdown, setShowHabitDropdown] = useState(false)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    loadAnalysisData()
  }, [])

  const loadAnalysisData = async () => {
    try {
      setLoading(true)
      const data = await habitService.getAnalysis()
      // Ensure all values are arrays
      setAllHabits(Array.isArray(data?.all_habits) ? data.all_habits : [])
      setDailyHabits(Array.isArray(data?.daily_habits) ? data.daily_habits : [])
      setWeeklyHabits(Array.isArray(data?.weekly_habits) ? data.weekly_habits : [])
      setMonthlyHabits(Array.isArray(data?.monthly_habits) ? data.monthly_habits : [])
      setCompletedHabits(Array.isArray(data?.completed_habits) ? data.completed_habits : [])
    } catch (error) {
      console.error('Failed to load analysis:', error)
      // Ensure arrays are set even on error
      setAllHabits([])
      setDailyHabits([])
      setWeeklyHabits([])
      setMonthlyHabits([])
      setCompletedHabits([])
    } finally {
      setLoading(false)
    }
  }

  const handlePeriodChange = async (period) => {
    setSelectedPeriod(period)
    setShowHabitDropdown(period === 'habit-longest-streak')
    setHabitData(null)

    if (period === 'habit-longest-streak') {
      setShowHabitDropdown(true)
    }
  }

  const handleHabitSelect = async (habitId) => {
    if (!habitId) return
    try {
      // Use POST to get detailed habit analysis
      const formData = new FormData()
      formData.append('selectedValue', habitId)
      
      const response = await api.post('/api/analysis/', formData, {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      })
      setHabitData(response.data)
    } catch (error) {
      console.error('Failed to load habit data:', error)
      // Fallback to regular habit endpoint
      try {
        const data = await habitService.getHabit(habitId)
        setHabitData(data.habit || data)
      } catch (err) {
        console.error('Failed to load habit:', err)
      }
    }
  }

  const renderHabitCard = (habit, isStruggled = false) => {
    const streak = habit.streak?.[0] || {}
    return (
      <div key={habit.id} className="col-md-6 mb-4">
        <div className="card streak-card">
          <div className="card-body d-flex flex-column">
            <h4 className="card-title">{habit.name?.charAt(0).toUpperCase() + habit.name?.slice(1)}</h4>
            {isStruggled ? (
              <>
                <div className="streak-info">
                  <div className="streak-label">Failed Tasks</div>
                  <div className="streak-value">{streak.num_of_failed_tasks || 0}</div>
                </div>
                <div className="streak-info">
                  <div className="streak-label">Longest Streak</div>
                  <div className="streak-value">{streak.longest_streak || 0}</div>
                </div>
              </>
            ) : (
              <>
                <div className="streak-info">
                  <div className="streak-label">Current Streak</div>
                  <div className="streak-value">{streak.current_streak || 0}</div>
                </div>
                <div className="streak-info">
                  <div className="streak-label">Longest Streak</div>
                  <div className="streak-value">{streak.longest_streak || 0}</div>
                </div>
              </>
            )}
            <Link className="btn btn-text btn-block mt-1" to={`/habit-details/${habit.id}`}>
              More Details
            </Link>
          </div>
        </div>
      </div>
    )
  }

  const renderCompletedCard = (habit) => {
    const streak = habit.streak?.[0] || {}
    return (
      <div key={habit.id} className="col-md-6 mb-4">
        <div className="card completed-card">
          <div className="card-body d-flex flex-column">
            <h4 className="card-title">{habit.name}</h4>
            <h6 className="card-subtitle text-muted text-center">
              {(habit.period || 'daily').charAt(0).toUpperCase() + (habit.period || 'daily').slice(1)} Habit
            </h6>
            <div className="completed-info-line">
              <div className="completed-info-column">
                <div className="completed-label">Total Tasks</div>
                <div className="completed-value">{habit.num_of_tasks || 0}</div>
                <div className="completed-label">Completed</div>
                <div className="completed-value">{streak.num_of_completed_tasks || 0}</div>
              </div>
              <div className="vertical-line"></div>
              <div className="completed-info-column">
                <div className="completed-label">Top Streak</div>
                <div className="completed-value">{streak.longest_streak || 0}</div>
                <div className="completed-label">Failed</div>
                <div className="completed-value">{streak.num_of_failed_tasks || 0}</div>
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

  if (loading) {
    return (
      <main role="main" className="container">
        <div className="loading-container">
          <div className="spinner"></div>
        </div>
      </main>
    )
  }

  return (
    <main role="main" className="container">
      <div className="row">
        <div className="col-md-11">
          <h1 className="my-4">Habits Analysis</h1>
          
          {/* Dropdown for selecting period */}
          <div className="mb-4">
            <select
              className="form-select"
              value={selectedPeriod}
              onChange={(e) => handlePeriodChange(e.target.value)}
            >
              <option value="all">All tracked habits</option>
              <option value="completed">Completed habits</option>
              <option value="daily">Daily habits</option>
              <option value="weekly">Weekly habits</option>
              <option value="monthly">Monthly habits</option>
              <option value="d-struggled-most">Daily Habit struggled most last month</option>
              <option value="w-struggled-most">Weekly Habit struggled most last month</option>
              <option value="longest-streak">Longest run streak over all defined habits</option>
              <option value="longest-current-streak">Longest current streak over all defined habits</option>
              <option value="habit-longest-streak">Longest Streak for Habit:</option>
            </select>
          </div>

          {/* Dropdown for selecting habit (shown when habit-longest-streak is selected) */}
          {showHabitDropdown && (
            <div id="habit-dropdown" className="mb-4">
              <select
                className="form-select"
                id="habit-select"
                value={selectedHabit}
                onChange={(e) => {
                  setSelectedHabit(e.target.value)
                  handleHabitSelect(e.target.value)
                }}
              >
                <option value="" disabled>Choose a habit</option>
                {Array.isArray(allHabits) && allHabits.map(habit => (
                  <option key={habit.id} value={habit.id}>
                    {habit.name} ({habit.period})
                  </option>
                ))}
              </select>
            </div>
          )}

          <div className="container">
            <div className="row">
              <div className="col-md-11">
                {/* Display All Habits */}
                {selectedPeriod === 'all' && (
                  <div id="all-active-habits">
                    <div className="row">
                      {Array.isArray(allHabits) && allHabits.map(habit => renderHabitCard(habit))}
                    </div>
                  </div>
                )}

                {/* Display Daily Habits */}
                {selectedPeriod === 'daily' && (
                  <div id="daily-active-habits">
                    <div className="row">
                      {Array.isArray(dailyHabits) && dailyHabits.map(habit => renderHabitCard(habit))}
                    </div>
                  </div>
                )}

                {/* Display Weekly Habits */}
                {selectedPeriod === 'weekly' && (
                  <div id="weekly-active-habits">
                    <div className="row">
                      {Array.isArray(weeklyHabits) && weeklyHabits.map(habit => renderHabitCard(habit))}
                    </div>
                  </div>
                )}

                {/* Display Monthly Habits */}
                {selectedPeriod === 'monthly' && (
                  <div id="monthly-active-habits">
                    <div className="row">
                      {Array.isArray(monthlyHabits) && monthlyHabits.map(habit => renderHabitCard(habit))}
                    </div>
                  </div>
                )}

                {/* Display Most Struggled Daily Habit */}
                {selectedPeriod === 'd-struggled-most' && (
                  <div id="d-struggled-most-active-habits">
                    <div className="row">
                      {dailyHabits.length > 0 ? (
                        renderHabitCard(dailyHabits[0], true)
                      ) : (
                        <p>No daily struggled habit available.</p>
                      )}
                    </div>
                  </div>
                )}

                {/* Display Most Struggled Weekly Habit */}
                {selectedPeriod === 'w-struggled-most' && (
                  <div id="w-struggled-most-active-habits">
                    <div className="row">
                      {weeklyHabits.length > 0 ? (
                        renderHabitCard(weeklyHabits[0], true)
                      ) : (
                        <p>No weekly struggled habit available.</p>
                      )}
                    </div>
                  </div>
                )}

                {/* Display Longest Streak */}
                {selectedPeriod === 'longest-streak' && (
                  <div id="longest-streak-active-habits">
                    <div className="row">
                      {allHabits.length > 0 ? (
                        renderHabitCard(allHabits[0])
                      ) : (
                        <p>No streak data available.</p>
                      )}
                    </div>
                  </div>
                )}

                {/* Display Longest Current Streak */}
                {selectedPeriod === 'longest-current-streak' && (
                  <div id="longest-current-streak-active-habits">
                    <div className="row">
                      {allHabits.length > 0 ? (
                        renderHabitCard(allHabits[0])
                      ) : (
                        <p>No streak data available.</p>
                      )}
                    </div>
                  </div>
                )}

                {/* Display Completed Habits */}
                {selectedPeriod === 'completed' && (
                  <div id="completed-active-habits">
                    <div className="row">
                      {Array.isArray(completedHabits) && completedHabits.map(habit => renderCompletedCard(habit))}
                    </div>
                  </div>
                )}

                {/* Display Selected Habit Data */}
                {selectedPeriod === 'habit-longest-streak' && habitData && (
                  <div id="habit-cards">
                    <div className="row">
                      <div className="col-md-6 mb-4">
                        <div className="card streak-card">
                          <div className="card-body">
                            <h4 className="card-title">{habitData.name}</h4>
                            {habitData.streak && habitData.streak.length > 0 && (
                              <>
                                <div className="streak-info">
                                  <div className="streak-label">Current Streak</div>
                                  <div className="streak-value">{habitData.streak[0].current_streak || 0}</div>
                                </div>
                                <div className="streak-info">
                                  <div className="streak-label">Longest Streak</div>
                                  <div className="streak-value">{habitData.streak[0].longest_streak || 0}</div>
                                </div>
                              </>
                            )}
                            <Link className="btn btn-text btn-block mt-1" to={`/habit-details/${habitData.id}`}>
                              More Details
                            </Link>
                          </div>
                        </div>
                      </div>
                    </div>
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

export default HabitAnalysis
