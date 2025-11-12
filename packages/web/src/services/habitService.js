import api from './api'

export const habitService = {
  async getHabits() {
    try {
      const response = await api.get('/api/habits/')
      // Return the habits array from the response
      return response.data.habits || []
    } catch (error) {
      console.error('Failed to fetch habits:', error)
      throw new Error(error.response?.data?.error || error.response?.data?.message || 'Failed to fetch habits')
    }
  },

  async getHabit(id) {
    try {
      const response = await api.get(`/api/habits/${id}/`)
      return response.data
    } catch (error) {
      throw new Error(error.response?.data?.error || error.response?.data?.message || 'Failed to fetch habit')
    }
  },

  async createHabit(habitData) {
    try {
      // Use API endpoint for habit creation
      const formData = new FormData()
      formData.append('name', habitData.name)
      formData.append('frequency', habitData.frequency)
      formData.append('period', habitData.period)
      formData.append('goal', habitData.goal)
      formData.append('start_date', habitData.start_date)
      if (habitData.notes) formData.append('notes', habitData.notes)
      
      const response = await api.post('/api/habits/', formData, {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      })
      return response.data
    } catch (error) {
      // Handle form validation errors
      if (error.response?.status === 400) {
        const errorData = error.response?.data
        if (errorData?.errors) {
          // Multiple field errors
          const errorMessages = Object.values(errorData.errors).flat().join(', ')
          throw new Error(errorMessages || 'Validation failed')
        }
        throw new Error(errorData?.error || 'Failed to create habit. Please check your input.')
      }
      throw new Error(error.response?.data?.error || error.response?.data?.message || 'Failed to create habit')
    }
  },

  async deleteHabit(id) {
    try {
      const response = await api.delete(`/api/habits/${id}/delete/`)
      return response.data
    } catch (error) {
      throw new Error(error.response?.data?.error || error.response?.data?.message || 'Failed to delete habit')
    }
  },

  async completeTask(taskId, habitId) {
    try {
      // Django expects form data for task completion
      const formData = new FormData()
      formData.append('task_id', taskId)
      formData.append('habit_id', habitId)
      
      const response = await api.post('/api/tasks/complete/', formData, {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      })
      return response.data
    } catch (error) {
      throw new Error(error.response?.data?.error || error.response?.data?.message || 'Failed to complete task')
    }
  },

  async getAnalysis() {
    try {
      const response = await api.get('/api/analysis/')
      return response.data
    } catch (error) {
      throw new Error(error.response?.data?.error || error.response?.data?.message || 'Failed to fetch analysis')
    }
  },
}

