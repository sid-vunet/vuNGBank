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
    // Start RUM transaction for logout
    let logoutTransaction;
    if (window.elasticApm) {
      logoutTransaction = window.elasticApm.startTransaction('user-logout', 'user-interaction');
    }
    
    try {
      const token = localStorage.getItem('vubank_token');
      if (token && user?.id) {
        // Start span for backend logout call
        let logoutSpan;
        if (window.elasticApm) {
          logoutSpan = window.elasticApm.startSpan('logout-api-call', 'http');
        }
        
        try {
          // Call backend logout API to terminate sessions
          const apiUrl = process.env.REACT_APP_API_URL || 'http://localhost:8000';
          
          const response = await fetch(`${apiUrl}/api/logout`, {
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
          
          if (logoutSpan) {
            logoutSpan.addLabels({
              'http.status_code': response.status,
              'user.id': user.id,
              'logout.terminate_all': true
            });
          }
          
        } catch (apiError) {
          if (logoutSpan) {
            logoutSpan.addLabels({
              'error': true,
              'error.message': apiError.message
            });
          }
          throw apiError;
        } finally {
          if (logoutSpan) logoutSpan.end();
        }
      }
      
      // Add labels to transaction
      if (logoutTransaction) {
        logoutTransaction.addLabels({
          'user.id': user?.id || 'unknown',
          'user.username': user?.username || 'unknown',
          'logout.success': true,
          'page': 'react-app'
        });
      }
      
    } catch (error) {
      console.error('Error during logout:', error);
      
      // Add error to transaction
      if (logoutTransaction) {
        logoutTransaction.addLabels({
          'logout.success': false,
          'error': true,
          'error.message': error.message
        });
        if (window.elasticApm) {
          window.elasticApm.captureError(error);
        }
      }
      
      // Continue with frontend logout even if backend call fails
    } finally {
      // Clear frontend data regardless of API call result
      localStorage.removeItem('vubank_token');
      localStorage.removeItem('vubank_user');
      setUser(null);
      setIsLoggedIn(false);
      
      // End RUM transaction
      if (logoutTransaction) logoutTransaction.end();
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