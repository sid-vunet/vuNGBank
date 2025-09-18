import React, { useState } from 'react';
import LoginPage from './components/LoginPage';
import Dashboard from './components/Dashboard';
import './App.css';

function App() {
  const [isLoggedIn, setIsLoggedIn] = useState(false);
  const [user, setUser] = useState(null);

  const handleLogin = (userData) => {
    setUser(userData);
    setIsLoggedIn(true);
  };

  const handleLogout = async () => {
    try {
      const token = localStorage.getItem('vubank_token');
      if (token && user?.id) {
        try {
          // Call backend logout API to terminate sessions
          const apiUrl = process.env.REACT_APP_API_URL || 'http://localhost:8000';
          
          await fetch(`${apiUrl}/api/logout`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'X-Api-Client': 'web-portal',
              'Authorization': `Bearer ${token}`,
              'X-Requested-With': 'XMLHttpRequest',
              'Origin': window.location.origin
            },
            body: JSON.stringify({
              user_id: user.id,
              terminate_all_sessions: true
            })
          });
          
        } catch (apiError) {
          console.error('Logout API error:', apiError);
          // Continue with frontend logout even if backend call fails
        }
      }
      
    } catch (error) {
      console.error('Error during logout:', error);
      // Continue with frontend logout even if backend call fails
    } finally {
      // Clear frontend data regardless of API call result
      localStorage.removeItem('vubank_token');
      localStorage.removeItem('vubank_user');
      setUser(null);
      setIsLoggedIn(false);
    }
  };

  return (
    <div className="App">
      {!isLoggedIn ? (
        <LoginPage onLogin={handleLogin} />
      ) : (
        <Dashboard user={user} onLogout={handleLogout} />
      )}
    </div>
  );
}

export default App;