import React, { useState, useEffect } from 'react';

const Dashboard = ({ user, onLogout }) => {
  const [accounts, setAccounts] = useState([]);
  const [recentTransactions, setRecentTransactions] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    const fetchAccountData = async () => {
      try {
        const token = localStorage.getItem('vubank_token');
        if (!token) {
          setError('No authentication token found');
          return;
        }

        const apiUrl = process.env.REACT_APP_API_URL || 'http://localhost:8000';
        
        const response = await fetch(`${apiUrl.replace(':8000', ':8002')}/internal/accounts`, {
          method: 'GET',
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json',
            'Origin': window.location.origin,
            'X-Requested-With': 'XMLHttpRequest',
            'X-Api-Client': 'web-portal'
          }
        });

        if (response.ok) {
          const data = await response.json();
          
          // Transform accounts data to match expected format
          const transformedAccounts = data.accounts.map(account => ({
            id: account.id,
            name: account.accountName,
            number: `****${account.accountNumber.slice(-4)}`,
            balance: account.balance,
            currency: account.currency,
            type: account.accountType
          }));
          
          // Transform transactions data
          const transformedTransactions = data.recentTransactions.map(transaction => ({
            id: transaction.id,
            description: transaction.description,
            date: new Date(transaction.transactionDate).toLocaleDateString(),
            amount: transaction.transactionType === 'credit' ? Math.abs(transaction.amount) : -Math.abs(transaction.amount),
            type: transaction.transactionType.toLowerCase(), // Ensure lowercase for CSS classes
            reference: transaction.referenceNumber
          }));

          console.log('📊 Dashboard Data Loaded:');
          console.log('Accounts:', transformedAccounts);
          console.log('Recent Transactions:', transformedTransactions);
          console.log('Raw API Response:', data);

          setAccounts(transformedAccounts);
          setRecentTransactions(transformedTransactions);
        } else if (response.status === 401) {
          // Token expired or invalid
          localStorage.removeItem('vubank_token');
          localStorage.removeItem('vubank_user');
          onLogout();
        } else {
          const errorData = await response.json();
          setError(errorData.message || 'Failed to fetch account data');
        }
      } catch (error) {
        console.error('Error fetching account data:', error);
        setError('Unable to connect to accounts service');
      } finally {
        setIsLoading(false);
      }
    };

    fetchAccountData();
  }, [onLogout]);

  const formatCurrency = (amount, currency = 'INR') => {
    return new Intl.NumberFormat('en-IN', {
      style: 'currency',
      currency: currency
    }).format(amount);
  };

  const formatDate = (dateString) => {
    return new Date(dateString).toLocaleDateString('en-IN', {
      month: 'short',
      day: 'numeric',
      year: 'numeric'
    });
  };

  // Show loading state
  if (isLoading) {
    return (
      <div className="dashboard">
        <div style={{ 
          display: 'flex', 
          justifyContent: 'center', 
          alignItems: 'center', 
          height: '100vh',
          fontSize: '18px' 
        }}>
          Loading your account data...
        </div>
      </div>
    );
  }

  // Show error state
  if (error) {
    return (
      <div className="dashboard">
        <div style={{ 
          display: 'flex', 
          flexDirection: 'column',
          justifyContent: 'center', 
          alignItems: 'center', 
          height: '100vh',
          gap: '20px'
        }}>
          <div style={{ color: '#d32f2f', fontSize: '18px' }}>
            Error loading dashboard: {error}
          </div>
          <button 
            onClick={() => window.location.reload()} 
            style={{ 
              padding: '10px 20px', 
              backgroundColor: '#1976d2', 
              color: 'white', 
              border: 'none', 
              borderRadius: '4px', 
              cursor: 'pointer' 
            }}
          >
            Retry
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="dashboard">
      <header className="dashboard-header">
        <div className="dashboard-nav">
          <div className="logo">
            <div className="logo-icon">VU</div>
            <div className="logo-text">vubank</div>
          </div>
          <nav>
            <span style={{ color: '#6b7280', marginLeft: '32px' }}>
              VuBank Straight2Bank Dashboard
            </span>
          </nav>
        </div>
        
        <div className="dashboard-user">
          <div className="user-avatar">
            {user?.username?.charAt(0).toUpperCase() || 'U'}
          </div>
          <div>
            <div style={{ fontWeight: '600', fontSize: '14px' }}>
              {user?.username || 'User'}
            </div>
            <div style={{ color: '#6b7280', fontSize: '12px' }}>
              ID: {user?.id} | Roles: {user?.roles?.join(', ') || 'N/A'}
            </div>
          </div>
          <button onClick={onLogout} className="logout-btn">
            Logout
          </button>
        </div>
      </header>

      <main className="dashboard-content">
        <div className="dashboard-grid">
          {/* Account Balance Cards */}
          {accounts.map(account => (
            <div key={account.id} className="dashboard-card">
              <div className="card-header">
                <h3 className="card-title">{account.name}</h3>
                <span style={{ color: '#6b7280', fontSize: '14px' }}>
                  {account.number}
                </span>
              </div>
              <div className="card-amount">
                {formatCurrency(account.balance, account.currency)}
              </div>
              <div className="card-subtitle">Available Balance</div>
            </div>
          ))}

          {/* Quick Actions */}
          <div className="dashboard-card">
            <h3 className="card-title">Quick Actions</h3>
            <div style={{ display: 'grid', gap: '12px', marginTop: '16px' }}>
              <button style={{ padding: '12px', background: '#3b82f6', color: 'white', border: 'none', borderRadius: '6px', cursor: 'pointer' }}>
                Transfer Money
              </button>
              <button style={{ padding: '12px', background: '#10b981', color: 'white', border: 'none', borderRadius: '6px', cursor: 'pointer' }}>
                Pay Bills
              </button>
              <button style={{ padding: '12px', background: '#8b5cf6', color: 'white', border: 'none', borderRadius: '6px', cursor: 'pointer' }}>
                View Statements
              </button>
            </div>
          </div>
        </div>

        {/* Recent Transactions */}
        <div className="dashboard-card">
          <h3 className="card-title">Recent Transactions</h3>
          <div className="transaction-list">
            {recentTransactions.length === 0 ? (
              <div style={{ padding: '20px', textAlign: 'center', color: '#666' }}>
                <p>No recent transactions found</p>
                <p style={{ fontSize: '14px', marginTop: '8px' }}>
                  Make a transfer or payment to see transactions here
                </p>
              </div>
            ) : (
              recentTransactions.map(transaction => (
                <div key={transaction.id} className="transaction-item">
                  <div className="transaction-details">
                    <h4>{transaction.description}</h4>
                    <p>{formatDate(transaction.date)} • Ref: {transaction.reference?.substring(0, 8) || 'N/A'}</p>
                  </div>
                  <div className={`transaction-amount ${transaction.type}`}>
                    {transaction.type === 'credit' ? '+' : ''}
                    {formatCurrency(Math.abs(transaction.amount))}
                  </div>
                </div>
              ))
            )}
          </div>
        </div>

        {/* Services Grid */}
        <div className="dashboard-grid" style={{ marginTop: '24px' }}>
          <div className="dashboard-card">
            <h3 className="card-title">Trade Services</h3>
            <div className="card-subtitle" style={{ marginTop: '8px' }}>
              Letters of Credit, Trade Finance, Documentary Collections
            </div>
            <button style={{ marginTop: '16px', padding: '8px 16px', background: '#f3f4f6', border: '1px solid #e5e7eb', borderRadius: '6px', cursor: 'pointer' }}>
              View Services
            </button>
          </div>

          <div className="dashboard-card">
            <h3 className="card-title">Cash Management</h3>
            <div className="card-subtitle" style={{ marginTop: '8px' }}>
              Account Services, Payments, Collections
            </div>
            <button style={{ marginTop: '16px', padding: '8px 16px', background: '#f3f4f6', border: '1px solid #e5e7eb', borderRadius: '6px', cursor: 'pointer' }}>
              Manage Cash
            </button>
          </div>

          <div className="dashboard-card">
            <h3 className="card-title">Support Centre</h3>
            <div className="card-subtitle" style={{ marginTop: '8px' }}>
              Help, FAQs, Contact Support
            </div>
            <button style={{ marginTop: '16px', padding: '8px 16px', background: '#f3f4f6', border: '1px solid #e5e7eb', borderRadius: '6px', cursor: 'pointer' }}>
              Get Help
            </button>
          </div>
        </div>
      </main>
    </div>
  );
};

export default Dashboard;