import React, { useState } from 'react';

const LoginPage = ({ onLogin }) => {
  const [formData, setFormData] = useState({
    username: '',
    password: '',
    rememberMe: false
  });
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState('');
  const [sessionConflict, setSessionConflict] = useState(null);
  const [showConfirmDialog, setShowConfirmDialog] = useState(false);

  const handleInputChange = (e) => {
    const { name, value, type, checked } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: type === 'checkbox' ? checked : value
    }));
    // Clear error when user starts typing
    if (error) setError('');
  };

  const performLogin = async (forceLogin = false) => {
    const apiUrl = process.env.REACT_APP_API_URL || 'http://localhost:8000';
    
    const response = await fetch(`${apiUrl}/api/login`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Origin': window.location.origin,
        'X-Requested-With': 'XMLHttpRequest',
        'X-Api-Client': 'web-portal'
      },
      body: JSON.stringify({
        username: formData.username,
        password: formData.password,
        force_login: forceLogin
      })
    });

    const data = await response.json();

    if (response.status === 409 && data.session_conflict) {
      // Handle session conflict
      setSessionConflict(data.existing_session);
      setShowConfirmDialog(true);
      return null;
    }

    if (response.ok && data.token) {
      // Store JWT token
      localStorage.setItem('vubank_token', data.token);
      localStorage.setItem('vubank_user', JSON.stringify(data.user));
      
      // Call parent component's onLogin
      onLogin({
        ...data.user,
        token: data.token
      });
      return true;
    } else {
      setError(data.message || 'Login failed. Please check your credentials.');
      return false;
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setIsLoading(true);
    setError('');
    setSessionConflict(null);
    setShowConfirmDialog(false);

    try {
      await performLogin(false);
    } catch (error) {
      console.error('Login error:', error);
      setError('Unable to connect to server. Please try again later.');
    } finally {
      setIsLoading(false);
    }
  };

  const handleForceLogin = async () => {
    setIsLoading(true);
    setError('');
    setShowConfirmDialog(false);

    try {
      await performLogin(true);
    } catch (error) {
      console.error('Force login error:', error);
      setError('Unable to connect to server. Please try again later.');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="login-container">
      <div className="language-selector">English (UK) ▼</div>
      <div className="contact-info">Contact us</div>
      
      <div className="welcome-section">
        <h1 className="welcome-title">Welcome to VuBank</h1>
      </div>
      
      <div className="login-card">
        <div className="logo">
          <div className="logo-icon">VU</div>
          <div className="logo-text">vubank</div>
        </div>
        
        <div className="security-icon">🔒</div>
        
        <h2 className="login-title">Log in to your account</h2>
        
        {error && (
          <div className="error-message" style={{ 
            color: '#d32f2f', 
            backgroundColor: '#ffebee', 
            padding: '10px', 
            borderRadius: '4px', 
            marginBottom: '20px', 
            border: '1px solid #ffcdd2' 
          }}>
            {error}
          </div>
        )}
        
        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label htmlFor="username">Username</label>
            <input
              type="text"
              id="username"
              name="username"
              placeholder="Enter username"
              value={formData.username}
              onChange={handleInputChange}
              required
              autoComplete="username"
            />
          </div>
          
          <div className="form-group">
            <label htmlFor="password">Password</label>
            <input
              type="password"
              id="password"
              name="password"
              placeholder="Enter password"
              value={formData.password}
              onChange={handleInputChange}
              required
              autoComplete="current-password"
            />
          </div>
          
          <div className="form-options">
            <label className="remember-me">
              <input
                type="checkbox"
                name="rememberMe"
                checked={formData.rememberMe}
                onChange={handleInputChange}
              />
              {' '}Remember me
            </label>
            <button 
              type="button" 
              className="forgot-password"
              onClick={() => alert('Please contact VuBank support for password recovery')}
            >
              Need help logging in?
            </button>
          </div>
          
          <button 
            type="submit" 
            className="login-button"
            disabled={isLoading}
          >
            {isLoading ? 'Logging in...' : 'Continue'}
          </button>
        </form>
      </div>
      
      <div className="footer-links">
        <div>IPv6 Supported</div>
        <div>VuBank © 2025</div>
      </div>

      {/* Session Conflict Dialog */}
      {showConfirmDialog && sessionConflict && (
        <div className="session-conflict-overlay" style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          backgroundColor: 'rgba(0, 0, 0, 0.5)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 1000
        }}>
          <div className="session-conflict-dialog" style={{
            backgroundColor: 'white',
            padding: '30px',
            borderRadius: '8px',
            maxWidth: '500px',
            margin: '20px',
            boxShadow: '0 4px 20px rgba(0, 0, 0, 0.15)'
          }}>
            <h3 style={{ color: '#d32f2f', marginBottom: '20px' }}>
              🛡️ Active Session Detected
            </h3>
            <p style={{ marginBottom: '20px', lineHeight: '1.5' }}>
              You are already logged in from another location. For security reasons, 
              only one session is allowed per user.
            </p>
            <div style={{ 
              backgroundColor: '#f5f5f5', 
              padding: '15px', 
              borderRadius: '4px', 
              marginBottom: '20px',
              fontSize: '14px'
            }}>
              <strong>Existing Session Details:</strong><br/>
              Started: {new Date(sessionConflict.created_at).toLocaleString()}<br/>
              Location: {sessionConflict.ip_address}<br/>
              Device: {sessionConflict.user_agent}
            </div>
            <p style={{ marginBottom: '25px', color: '#666' }}>
              Would you like to continue? This will log out your other session.
            </p>
            <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end' }}>
              <button 
                type="button"
                onClick={() => {
                  setShowConfirmDialog(false);
                  setSessionConflict(null);
                  setIsLoading(false);
                }}
                style={{
                  padding: '10px 20px',
                  backgroundColor: '#f5f5f5',
                  border: '1px solid #ddd',
                  borderRadius: '4px',
                  cursor: 'pointer'
                }}
              >
                Cancel
              </button>
              <button 
                type="button"
                onClick={handleForceLogin}
                disabled={isLoading}
                style={{
                  padding: '10px 20px',
                  backgroundColor: '#d32f2f',
                  color: 'white',
                  border: 'none',
                  borderRadius: '4px',
                  cursor: 'pointer'
                }}
              >
                {isLoading ? 'Logging in...' : 'Yes, Continue'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default LoginPage;