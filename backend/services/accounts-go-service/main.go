package main

import (
	"context"
	"database/sql"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	_ "github.com/lib/pq"
	"go.elastic.co/apm/module/apmgin/v2"
	"go.elastic.co/apm/module/apmsql/v2"
	_ "go.elastic.co/apm/module/apmsql/v2/pq"
)

// Config struct
type Config struct {
	Port           string
	JWTSecret      string
	DBConfig       DBConfig
	APMServerURL   string
	APMServiceName string
}

type DBConfig struct {
	Host     string
	Port     string
	User     string
	Password string
	DBName   string
	SSLMode  string
}

// Models
type Account struct {
	ID            int     `json:"id"`
	AccountNumber string  `json:"accountNumber"`
	AccountName   string  `json:"accountName"`
	AccountType   string  `json:"accountType"`
	Balance       float64 `json:"balance"`
	Currency      string  `json:"currency"`
	Status        string  `json:"status"`
}

type Transaction struct {
	ID              int     `json:"id"`
	TransactionType string  `json:"transactionType"`
	Amount          float64 `json:"amount"`
	Description     string  `json:"description"`
	ReferenceNumber string  `json:"referenceNumber"`
	TransactionDate string  `json:"transactionDate"`
	BalanceAfter    float64 `json:"balanceAfter"`
	Status          string  `json:"status"`
}

type AccountsResponse struct {
	UserID       string        `json:"userId"`
	Accounts     []Account     `json:"accounts"`
	Transactions []Transaction `json:"recentTransactions"`
}

type ErrorResponse struct {
	Error   string `json:"error"`
	Message string `json:"message"`
}

type UpdateBalanceRequest struct {
	AccountNumber   string  `json:"accountNumber" binding:"required"`
	Amount          float64 `json:"amount" binding:"required"`
	TransactionType string  `json:"transactionType" binding:"required"`
	ReferenceNumber string  `json:"referenceNumber" binding:"required"`
	Description     string  `json:"description" binding:"required"`
}

type UpdateBalanceResponse struct {
	Success       bool    `json:"success"`
	AccountNumber string  `json:"accountNumber"`
	OldBalance    float64 `json:"oldBalance"`
	NewBalance    float64 `json:"newBalance"`
	TransactionID int     `json:"transactionId"`
	Message       string  `json:"message,omitempty"`
}

type CreateTransactionRequest struct {
	AccountNumber   string  `json:"accountNumber" binding:"required"`
	TransactionType string  `json:"transactionType" binding:"required"`
	Amount          float64 `json:"amount" binding:"required"`
	Description     string  `json:"description" binding:"required"`
	ReferenceNumber string  `json:"referenceNumber" binding:"required"`
	BalanceAfter    float64 `json:"balanceAfter" binding:"required"`
	Status          string  `json:"status"`
}

type CreateTransactionResponse struct {
	Success       bool   `json:"success"`
	TransactionID int    `json:"transactionId"`
	AccountNumber string `json:"accountNumber"`
	Message       string `json:"message,omitempty"`
}

// JWT Claims
type Claims struct {
	UserID string   `json:"user_id"`
	Roles  []string `json:"roles"`
	jwt.RegisteredClaims
}

// Load configuration
func loadConfig() *Config {
	return &Config{
		Port:           getEnv("PUBLIC_API_PORT", "8002"),
		JWTSecret:      getEnv("JWT_SECRET", "your-super-secret-jwt-key"),
		APMServerURL:   getEnv("ELASTIC_APM_SERVER_URL", "http://91.203.133.240:30200"),
		APMServiceName: getEnv("ELASTIC_APM_SERVICE_NAME", "accounts-go-service"),
		DBConfig: DBConfig{
			Host:     getEnv("DB_HOST", "localhost"),
			Port:     getEnv("DB_PORT", "5432"),
			User:     getEnv("DB_USER", "vubank_user"),
			Password: getEnv("DB_PASSWORD", "vubank_pass"),
			DBName:   getEnv("DB_NAME", "vubank_db"),
			SSLMode:  getEnv("DB_SSLMODE", "disable"),
		},
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// Database connection
func connectDB(config DBConfig) (*sql.DB, error) {
	connStr := "host=" + config.Host + " port=" + config.Port + " user=" + config.User +
		" password=" + config.Password + " dbname=" + config.DBName + " sslmode=" + config.SSLMode

	// Use APM instrumented SQL driver
	db, err := apmsql.Open("postgres", connStr)
	if err != nil {
		return nil, err
	}

	if err = db.Ping(); err != nil {
		return nil, err
	}

	return db, nil
}

// JWT middleware
func jwtMiddleware(jwtSecret string) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.JSON(http.StatusUnauthorized, ErrorResponse{
				Error:   "missing_token",
				Message: "Authorization header required",
			})
			c.Abort()
			return
		}

		// Check Bearer prefix
		tokenString := strings.TrimPrefix(authHeader, "Bearer ")
		if tokenString == authHeader {
			c.JSON(http.StatusUnauthorized, ErrorResponse{
				Error:   "invalid_token_format",
				Message: "Authorization header must be Bearer token",
			})
			c.Abort()
			return
		}

		// Parse token
		log.Printf("Parsing JWT token for validation")
		token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
			return []byte(jwtSecret), nil
		})

		if err != nil || !token.Valid {
			log.Printf("JWT validation failed: err=%v, valid=%v", err, token != nil && token.Valid)
			c.JSON(http.StatusUnauthorized, ErrorResponse{
				Error:   "invalid_token",
				Message: "Invalid or expired token",
			})
			c.Abort()
			return
		}

		claims, ok := token.Claims.(*Claims)
		if !ok {
			log.Printf("Failed to parse token claims")
			c.JSON(http.StatusUnauthorized, ErrorResponse{
				Error:   "invalid_claims",
				Message: "Invalid token claims",
			})
			c.Abort()
			return
		}

		log.Printf("JWT claims parsed: UserID=%s, Roles=%v", claims.UserID, claims.Roles)

		// Check roles
		hasValidRole := false
		for _, role := range claims.Roles {
			if role == "retail" || role == "corporate" {
				hasValidRole = true
				break
			}
		}

		if !hasValidRole {
			c.JSON(http.StatusForbidden, ErrorResponse{
				Error:   "insufficient_permissions",
				Message: "Insufficient permissions for account access",
			})
			c.Abort()
			return
		}

		c.Set("user_id", claims.UserID)
		c.Set("roles", claims.Roles)
		c.Next()
	}
}

// Get user accounts
func getUserAccounts(ctx context.Context, db *sql.DB, userID string) ([]Account, error) {
	query := `
		SELECT id, account_number, account_name, account_type, balance, currency, status
		FROM accounts 
		WHERE user_id = $1 AND status = 'active'
		ORDER BY created_at DESC
	`

	rows, err := db.QueryContext(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var accounts []Account
	for rows.Next() {
		var account Account
		err := rows.Scan(
			&account.ID,
			&account.AccountNumber,
			&account.AccountName,
			&account.AccountType,
			&account.Balance,
			&account.Currency,
			&account.Status,
		)
		if err != nil {
			return nil, err
		}
		accounts = append(accounts, account)
	}

	return accounts, nil
}

// Update account balance and create transaction record
func updateAccountBalance(ctx context.Context, db *sql.DB, request UpdateBalanceRequest) (*UpdateBalanceResponse, error) {
	// Start database transaction
	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	// Get current account balance and ID
	var accountID int
	var currentBalance float64
	var accountStatus string
	query := `SELECT id, balance, status FROM accounts WHERE account_number = $1 AND status = 'active'`

	err = tx.QueryRowContext(ctx, query, request.AccountNumber).Scan(&accountID, &currentBalance, &accountStatus)
	if err != nil {
		if err == sql.ErrNoRows {
			return &UpdateBalanceResponse{
				Success: false,
				Message: "Account not found or inactive",
			}, nil
		}
		return nil, err
	}

	// Calculate new balance
	newBalance := currentBalance + request.Amount

	// Check for sufficient funds (only for debit operations)
	if request.Amount < 0 && newBalance < 0 {
		return &UpdateBalanceResponse{
			Success:    false,
			OldBalance: currentBalance,
			Message:    "Insufficient funds",
		}, nil
	}

	// Update account balance
	updateQuery := `UPDATE accounts SET balance = $1 WHERE id = $2`
	_, err = tx.ExecContext(ctx, updateQuery, newBalance, accountID)
	if err != nil {
		return nil, err
	}

	// Insert transaction record
	insertTxQuery := `
		INSERT INTO transactions (account_id, transaction_type, amount, description, reference_number, balance_after, status)
		VALUES ($1, $2, $3, $4, $5, $6, 'completed')
		RETURNING id
	`

	var transactionID int
	err = tx.QueryRowContext(ctx, insertTxQuery,
		accountID, request.TransactionType, request.Amount,
		request.Description, request.ReferenceNumber, newBalance).Scan(&transactionID)
	if err != nil {
		return nil, err
	}

	// Commit transaction
	err = tx.Commit()
	if err != nil {
		return nil, err
	}

	return &UpdateBalanceResponse{
		Success:       true,
		AccountNumber: request.AccountNumber,
		OldBalance:    currentBalance,
		NewBalance:    newBalance,
		TransactionID: transactionID,
	}, nil
}

// Get recent transactions for user
func getRecentTransactions(ctx context.Context, db *sql.DB, userID string) ([]Transaction, error) {
	query := `
		SELECT t.id, t.transaction_type, t.amount, t.description, 
			   t.reference_number, t.transaction_date, t.balance_after, t.status
		FROM transactions t
		JOIN accounts a ON t.account_id = a.id
		WHERE a.user_id = $1
		ORDER BY t.transaction_date DESC
		LIMIT 20
	`

	rows, err := db.QueryContext(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var transactions []Transaction
	for rows.Next() {
		var transaction Transaction
		var transactionDate time.Time

		err := rows.Scan(
			&transaction.ID,
			&transaction.TransactionType,
			&transaction.Amount,
			&transaction.Description,
			&transaction.ReferenceNumber,
			&transactionDate,
			&transaction.BalanceAfter,
			&transaction.Status,
		)
		if err != nil {
			return nil, err
		}

		transaction.TransactionDate = transactionDate.Format("2006-01-02T15:04:05Z")
		transactions = append(transactions, transaction)
	}

	return transactions, nil
}

// Accounts handler
func accountsHandler(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")

		log.Printf("Fetching accounts for user: %s", userID)

		// Get user accounts
		accounts, err := getUserAccounts(c.Request.Context(), db, userID)
		if err != nil {
			log.Printf("Failed to get accounts: %v", err)
			c.JSON(http.StatusInternalServerError, ErrorResponse{
				Error:   "database_error",
				Message: "Failed to retrieve accounts",
			})
			return
		}

		// Get recent transactions
		transactions, err := getRecentTransactions(c.Request.Context(), db, userID)
		if err != nil {
			log.Printf("Failed to get transactions: %v", err)
			c.JSON(http.StatusInternalServerError, ErrorResponse{
				Error:   "database_error",
				Message: "Failed to retrieve transactions",
			})
			return
		}

		response := AccountsResponse{
			UserID:       userID,
			Accounts:     accounts,
			Transactions: transactions,
		}

		c.JSON(http.StatusOK, response)
	}
}

// Update account balance handler (for internal service calls only)
func updateBalanceHandler(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var request UpdateBalanceRequest
		if err := c.ShouldBindJSON(&request); err != nil {
			c.JSON(http.StatusBadRequest, ErrorResponse{
				Error:   "invalid_request",
				Message: "Invalid request format: " + err.Error(),
			})
			return
		}

		log.Printf("Processing balance update for account: %s, amount: %.2f",
			request.AccountNumber, request.Amount)

		// Update account balance
		response, err := updateAccountBalance(c.Request.Context(), db, request)
		if err != nil {
			log.Printf("Failed to update balance: %v", err)
			c.JSON(http.StatusInternalServerError, ErrorResponse{
				Error:   "database_error",
				Message: "Failed to update account balance",
			})
			return
		}

		if !response.Success {
			log.Printf("Balance update failed: %s", response.Message)
			c.JSON(http.StatusBadRequest, ErrorResponse{
				Error:   "balance_update_failed",
				Message: response.Message,
			})
			return
		}

		log.Printf("Balance updated successfully for account %s: %.2f -> %.2f",
			response.AccountNumber, response.OldBalance, response.NewBalance)

		c.JSON(http.StatusOK, response)
	}
}

// Create transaction handler
func createTransactionHandler(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx := c.Request.Context()

		var req CreateTransactionRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, ErrorResponse{
				Error:   "invalid_request",
				Message: "Invalid request body: " + err.Error(),
			})
			return
		}

		// Set default status if not provided
		if req.Status == "" {
			req.Status = "completed"
		}

		log.Printf("Creating transaction for account: %s, type: %s, amount: %.2f",
			req.AccountNumber, req.TransactionType, req.Amount)

		// Begin database transaction
		tx, err := db.BeginTx(ctx, nil)
		if err != nil {
			log.Printf("Failed to begin transaction: %v", err)
			c.JSON(http.StatusInternalServerError, ErrorResponse{
				Error:   "database_error",
				Message: "Failed to begin database transaction",
			})
			return
		}
		defer tx.Rollback()

		// Get account ID from account number
		var accountID int
		err = tx.QueryRowContext(ctx,
			"SELECT id FROM accounts WHERE account_number = $1",
			req.AccountNumber).Scan(&accountID)

		if err != nil {
			if err == sql.ErrNoRows {
				c.JSON(http.StatusNotFound, ErrorResponse{
					Error:   "account_not_found",
					Message: "Account not found: " + req.AccountNumber,
				})
			} else {
				log.Printf("Failed to lookup account: %v", err)
				c.JSON(http.StatusInternalServerError, ErrorResponse{
					Error:   "database_error",
					Message: "Failed to lookup account",
				})
			}
			return
		}

		// Insert transaction record
		var transactionID int
		err = tx.QueryRowContext(ctx, `
			INSERT INTO transactions (account_id, transaction_type, amount, description, reference_number, balance_after, status) 
			VALUES ($1, $2, $3, $4, $5, $6, $7) 
			RETURNING id`,
			accountID, req.TransactionType, req.Amount, req.Description, req.ReferenceNumber, req.BalanceAfter, req.Status).Scan(&transactionID)

		if err != nil {
			log.Printf("Failed to insert transaction: %v", err)
			c.JSON(http.StatusInternalServerError, ErrorResponse{
				Error:   "database_error",
				Message: "Failed to create transaction record",
			})
			return
		}

		// Commit the database transaction
		if err = tx.Commit(); err != nil {
			log.Printf("Failed to commit transaction: %v", err)
			c.JSON(http.StatusInternalServerError, ErrorResponse{
				Error:   "database_error",
				Message: "Failed to commit transaction",
			})
			return
		}

		// Create response
		response := CreateTransactionResponse{
			Success:       true,
			TransactionID: transactionID,
			AccountNumber: req.AccountNumber,
			Message:       "Transaction record created successfully",
		}

		log.Printf("Transaction created successfully: ID=%d, Account=%s, Type=%s, Amount=%.2f",
			transactionID, req.AccountNumber, req.TransactionType, req.Amount)

		c.JSON(http.StatusOK, response)
	}
}

// Health check handler
func healthHandler(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx := c.Request.Context()

		// Check database connection
		err := db.PingContext(ctx)
		dbHealthy := err == nil

		health := gin.H{
			"status":    "healthy",
			"service":   "accounts-go-service",
			"database":  dbHealthy,
			"timestamp": time.Now().UTC(),
		}

		if !dbHealthy {
			health["status"] = "unhealthy"
			health["error"] = err.Error()
			c.JSON(http.StatusServiceUnavailable, health)
		} else {
			c.JSON(http.StatusOK, health)
		}
	}
}

func main() {
	config := loadConfig()

	// Initialize APM
	log.Printf("Initializing APM with server URL: %s", config.APMServerURL)
	log.Printf("APM Service Name: %s", config.APMServiceName)

	// Set APM environment variables
	os.Setenv("ELASTIC_APM_SERVER_URL", config.APMServerURL)
	os.Setenv("ELASTIC_APM_SERVICE_NAME", config.APMServiceName)
	os.Setenv("ELASTIC_APM_ENVIRONMENT", getEnv("ELASTIC_APM_ENVIRONMENT", "production"))
	os.Setenv("ELASTIC_APM_SERVICE_VERSION", getEnv("ELASTIC_APM_SERVICE_VERSION", "1.0.0"))

	// Connect to database
	db, err := connectDB(config.DBConfig)
	if err != nil {
		log.Fatal("Failed to connect to database:", err)
	}
	defer db.Close()

	// Set Gin mode
	gin.SetMode(gin.ReleaseMode)

	r := gin.New()
	r.Use(gin.Logger())
	r.Use(gin.Recovery())

	// Add APM middleware
	r.Use(apmgin.Middleware(r))

	// Add CORS middleware
	r.Use(func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept, Authorization, X-Api-Client, X-Request-ID, traceparent, tracestate")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}

		c.Next()
	})

	// Routes
	r.GET("/health", healthHandler(db))

	// Internal API routes (protected by JWT)
	internal := r.Group("/internal")
	internal.Use(jwtMiddleware(config.JWTSecret))
	{
		internal.GET("/accounts", accountsHandler(db))
		internal.POST("/accounts/update-balance", updateBalanceHandler(db))
		internal.POST("/accounts/create-transaction", createTransactionHandler(db))
	}

	port := config.Port
	log.Printf("Starting VuBank Accounts Service on port %s", port)
	log.Printf("Database: %s:%s/%s", config.DBConfig.Host, config.DBConfig.Port, config.DBConfig.DBName)
	log.Printf("APM Server: %s", config.APMServerURL)

	if err := r.Run(":" + port); err != nil {
		log.Fatal("Failed to start server:", err)
	}
}
