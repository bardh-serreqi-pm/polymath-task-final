import api from './api'

export const authService = {
  async login(username, password) {
    try {
      // Django login endpoint (CSRF exempt)
      const formData = new FormData()
      formData.append('username', username)
      formData.append('password', password)

      const response = await api.post('/Login/', formData, {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      })
      return response.data
    } catch (error) {
      if (error.response?.status === 401 || error.response?.status === 400) {
        throw new Error('Invalid username or password')
      }
      throw new Error(error.response?.data?.message || error.message || 'Login failed')
    }
  },

  async register(userData) {
    try {
      // Django register endpoint (CSRF exempt)
      const formData = new FormData()
      formData.append('username', userData.username)
      formData.append('email', userData.email)
      formData.append('password1', userData.password)
      formData.append('password2', userData.password2 || userData.password)
      if (userData.first_name) formData.append('first_name', userData.first_name)
      if (userData.last_name) formData.append('last_name', userData.last_name)

      const response = await api.post('/Register/', formData, {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      })
      return response.data
    } catch (error) {
      // Handle validation errors
      if (error.response?.data?.form?.errors) {
        // Extract Django form errors
        const errors = error.response.data.form.errors
        const errorMessages = Object.values(errors).flat().join(', ')
        throw new Error(errorMessages || 'Registration failed')
      }
      throw new Error(error.response?.data?.message || error.message || 'Registration failed')
    }
  },

  async logout() {
    try {
      // Django logout endpoint (CSRF exempt)
      const response = await api.post('/Logout/')
      // Clear any local storage or session storage
      localStorage.clear()
      sessionStorage.clear()
      return response
    } catch (error) {
      // Log but don't throw - we'll clear local state anyway
      console.error('Logout error:', error)
      // Clear storage even on error
      localStorage.clear()
      sessionStorage.clear()
      // Return success even on error to allow local state cleanup
      return { success: true }
    }
  },

  async isAuthenticated() {
    try {
      // Check if user is authenticated using the auth check endpoint
      const response = await api.get('/api/auth/check/')
      if (response.data && response.data.authenticated === true) {
        // Verify user actually exists
        return true
      }
      return false
    } catch (error) {
      // If endpoint doesn't exist or returns error, user is not authenticated
      return false
    }
  },
}

