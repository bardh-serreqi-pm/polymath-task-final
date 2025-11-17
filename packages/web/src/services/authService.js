import api from './api'

// Helper function to get CSRF token
async function getCsrfToken() {
  try {
    // Make a GET request to get the CSRF token cookie
    // Try Login first (for login requests), then Register (for registration)
    try {
      await api.get('/Login/')
    } catch {
      await api.get('/Register/')
    }
    // The cookie should now be set by Django
  } catch (error) {
    // Ignore errors, we just need the cookie
    console.log('CSRF token fetch:', error)
  }
}

export const authService = {
  async login(username, password) {
    try {
      // First, get CSRF token by making a GET request
      await getCsrfToken()

      // Django expects form data for login
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
      if (error.response?.status === 403) {
        throw new Error('CSRF verification failed. Please refresh the page and try again.')
      }
      throw new Error(error.response?.data?.message || error.message || 'Login failed')
    }
  },

  async register(userData) {
    try {
      // First, get CSRF token by making a GET request
      await getCsrfToken()

      // Django expects form data for registration (like login)
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
      // Handle CSRF or validation errors
      if (error.response?.status === 403) {
        throw new Error('CSRF verification failed. Please refresh the page and try again.')
      }
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
      // Django LogoutView requires POST with CSRF token
      // Use form data to match Django's expectations
      const formData = new FormData()
      const response = await api.post('/Logout/', formData, {
        headers: {
          'Content-Type': 'multipart/form-data',
        }
      })
      // Clear any local storage or session storage
      localStorage.clear()
      sessionStorage.clear()
      return response
    } catch (error) {
      // Log but don't throw - we'll clear local state anyway
      // Django logout might redirect or return HTML, which is fine
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

