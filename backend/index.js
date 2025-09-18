// Initialize APM agent first (before any other require statements)
const apm = require('elastic-apm-node').start({
  serviceName: 'vubank-login-service',
  serverUrl: 'http://91.203.133.240:30200',
  environment: 'development',
  active: true,
  logLevel: 'info',
  captureHeaders: true,
  captureBody: 'all',
  useHttps: false,
  verifyServerCert: false
});

const express = require('express');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const { faker } = require('@faker-js/faker');

const app = express();
const PORT = process.env.PORT || 5000;
const JWT_SECRET = 'your-secret-key'; // In production, use environment variable

// Middleware
app.use(cors());
app.use(express.json());

// Mock data
let users = [
  {
    id: 1,
    name: 'John Doe',
    email: 'john.doe@example.com',
    userId: 'johndoe123',
    groupId: 'CORPORATE',
    password: bcrypt.hashSync('password123', 10),
    accounts: [
      {
        id: 1,
        name: 'Current Account',
        number: '****1234',
        balance: 25430.50,
        currency: 'INR'
      },
      {
        id: 2,
        name: 'Savings Account',
        number: '****5678',
        balance: 15750.25,
        currency: 'INR'
      }
    ]
  }
];

// Generate synthetic transaction data
const generateTransactions = (accountId, count = 50) => {
  const transactions = [];
  for (let i = 0; i < count; i++) {
    const isCredit = Math.random() > 0.7; // 30% credit transactions
    transactions.push({
      id: i + 1,
      accountId: accountId,
      description: isCredit 
        ? faker.finance.transactionDescription() + ' - Credit'
        : faker.finance.transactionDescription(),
      date: faker.date.recent({ days: 90 }),
      amount: isCredit 
        ? parseFloat(faker.finance.amount({ min: 100, max: 5000, dec: 2 }))
        : -parseFloat(faker.finance.amount({ min: 10, max: 1000, dec: 2 })),
      type: isCredit ? 'credit' : 'debit',
      category: faker.helpers.arrayElement(['Food', 'Transport', 'Entertainment', 'Shopping', 'Bills', 'Salary', 'Transfer']),
      reference: faker.finance.transactionDescription()
    });
  }
  return transactions.sort((a, b) => new Date(b.date) - new Date(a.date));
};

// Generate transactions for each account
users[0].accounts.forEach(account => {
  account.transactions = generateTransactions(account.id);
});

// Authentication middleware
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ message: 'Access token required' });
  }

  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({ message: 'Invalid token' });
    }
    req.user = user;
    next();
  });
};

// Routes
app.get('/', (req, res) => {
  res.json({ 
    message: 'VuBank NextGen Banking API',
    version: '1.0.0',
    endpoints: {
      'POST /api/auth/login': 'Login user',
      'GET /api/user/profile': 'Get user profile (authenticated)',
      'GET /api/accounts': 'Get user accounts (authenticated)',
      'GET /api/accounts/:id/transactions': 'Get account transactions (authenticated)',
      'POST /api/transactions/transfer': 'Transfer money (authenticated)'
    }
  });
});

// Authentication Routes
app.post('/api/auth/login', async (req, res) => {
  const { userIdOrEmail, groupId } = req.body;

  try {
    // Find user by email or userId
    const user = users.find(u => 
      u.email === userIdOrEmail || u.userId === userIdOrEmail
    );

    if (!user) {
      return res.status(400).json({ message: 'Invalid credentials' });
    }

    // For demo purposes, we'll skip password validation
    // In production, you'd validate the password with bcrypt

    // Generate JWT token
    const token = jwt.sign(
      { 
        userId: user.id, 
        email: user.email,
        name: user.name 
      },
      JWT_SECRET,
      { expiresIn: '24h' }
    );

    res.json({
      message: 'Login successful',
      token,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        groupId: user.groupId
      }
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// User Routes
app.get('/api/user/profile', authenticateToken, (req, res) => {
  const user = users.find(u => u.id === req.user.userId);
  if (!user) {
    return res.status(404).json({ message: 'User not found' });
  }

  res.json({
    id: user.id,
    name: user.name,
    email: user.email,
    groupId: user.groupId
  });
});

// Account Routes
app.get('/api/accounts', authenticateToken, (req, res) => {
  const user = users.find(u => u.id === req.user.userId);
  if (!user) {
    return res.status(404).json({ message: 'User not found' });
  }

  // Return accounts without transactions for performance
  const accounts = user.accounts.map(acc => ({
    id: acc.id,
    name: acc.name,
    number: acc.number,
    balance: acc.balance,
    currency: acc.currency
  }));

  res.json(accounts);
});

app.get('/api/accounts/:id/transactions', authenticateToken, (req, res) => {
  const accountId = parseInt(req.params.id);
  const limit = parseInt(req.query.limit) || 20;
  const offset = parseInt(req.query.offset) || 0;

  const user = users.find(u => u.id === req.user.userId);
  if (!user) {
    return res.status(404).json({ message: 'User not found' });
  }

  const account = user.accounts.find(acc => acc.id === accountId);
  if (!account) {
    return res.status(404).json({ message: 'Account not found' });
  }

  const transactions = account.transactions.slice(offset, offset + limit);
  
  res.json({
    accountId: accountId,
    transactions: transactions,
    totalCount: account.transactions.length,
    hasMore: offset + limit < account.transactions.length
  });
});

// Transaction Routes
app.post('/api/transactions/transfer', authenticateToken, (req, res) => {
  const { fromAccountId, toAccount, amount, description } = req.body;

  const user = users.find(u => u.id === req.user.userId);
  if (!user) {
    return res.status(404).json({ message: 'User not found' });
  }

  const fromAccount = user.accounts.find(acc => acc.id === parseInt(fromAccountId));
  if (!fromAccount) {
    return res.status(404).json({ message: 'Source account not found' });
  }

  if (fromAccount.balance < amount) {
    return res.status(400).json({ message: 'Insufficient balance' });
  }

  // Create transaction record
  const transaction = {
    id: Date.now(),
    accountId: fromAccount.id,
    description: description || `Transfer to ${toAccount}`,
    date: new Date(),
    amount: -amount,
    type: 'debit',
    category: 'Transfer',
    reference: `TXN${Date.now()}`
  };

  // Update account balance and add transaction
  fromAccount.balance -= amount;
  fromAccount.transactions.unshift(transaction);

  res.json({
    message: 'Transfer successful',
    transaction: transaction,
    newBalance: fromAccount.balance
  });
});

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ 
    message: 'Something went wrong!',
    error: process.env.NODE_ENV === 'development' ? err.message : undefined
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ message: 'Route not found' });
});

app.listen(PORT, () => {
  console.log(`VuBank NextGen Banking API running on port ${PORT}`);
  console.log(`API Documentation available at http://localhost:${PORT}`);
});