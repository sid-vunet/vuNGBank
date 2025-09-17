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
	"go.elastic.co/apm/v2"
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
		token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
			return []byte(jwtSecret), nil
		})

		if err != nil || !token.Valid {
			c.JSON(http.StatusUnauthorized, ErrorResponse{
				Error:   "invalid_token",
				Message: "Invalid or expired token",
			})
			c.Abort()
			return
		}

		claims, ok := token.Claims.(*Claims)
		if !ok {
			c.JSON(http.StatusUnauthorized, ErrorResponse{
				Error:   "invalid_claims",
				Message: "Invalid token claims",
			})
			c.Abort()
			return
		}

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
	span, ctx := apm.StartSpan(ctx, "database_accounts_lookup", "db.postgresql")
	defer span.End()

	span.Context.SetLabel("user_id", userID)
	span.Context.SetLabel("operation", "get_accounts")

	query := `
		SELECT id, account_number, account_name, account_type, balance, currency, status
		FROM accounts 
		WHERE user_id = $1 AND status = 'active'
		ORDER BY created_at DESC
	`

	rows, err := db.QueryContext(ctx, query, userID)
	if err != nil {
		span.Context.SetLabel("query_result", "error")
		apm.CaptureError(ctx, err).Send()
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
			span.Context.SetLabel("scan_result", "error")
			apm.CaptureError(ctx, err).Send()
			return nil, err
		}
		accounts = append(accounts, account)
	}

	span.Context.SetLabel("query_result", "success")
	span.Context.SetLabel("accounts_count", len(accounts))
	return accounts, nil
}

// Get recent transactions for user
func getRecentTransactions(ctx context.Context, db *sql.DB, userID string) ([]Transaction, error) {
	span, ctx := apm.StartSpan(ctx, "database_transactions_lookup", "db.postgresql")
	defer span.End()

	span.Context.SetLabel("user_id", userID)
	span.Context.SetLabel("operation", "get_recent_transactions")

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
		span.Context.SetLabel("query_result", "error")
		apm.CaptureError(ctx, err).Send()
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
			span.Context.SetLabel("scan_result", "error")
			apm.CaptureError(ctx, err).Send()
			return nil, err
		}

		transaction.TransactionDate = transactionDate.Format("2006-01-02T15:04:05Z")
		transactions = append(transactions, transaction)
	}

	span.Context.SetLabel("query_result", "success")
	span.Context.SetLabel("transactions_count", len(transactions))
	return transactions, nil
}

// Accounts handler
func accountsHandler(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")
		rolesInterface, exists := c.Get("roles")
		var roles []string
		if exists {
			if rolesSlice, ok := rolesInterface.([]string); ok {
				roles = rolesSlice
			}
		}

		// Create APM transaction
		tx := apm.TransactionFromContext(c.Request.Context())
		if tx != nil {
			tx.Context.SetLabel("user_id", userID)
			tx.Context.SetLabel("endpoint", "accounts")
			tx.Context.SetLabel("user_roles", strings.Join(roles, ","))
		}

		log.Printf("Fetching accounts for user: %s", userID)

		// Create span for business logic
		span, ctx := apm.StartSpan(c.Request.Context(), "accounts_business_logic", "app")
		defer span.End()

		// Get user accounts
		accounts, err := getUserAccounts(ctx, db, userID)
		if err != nil {
			log.Printf("Failed to get accounts: %v", err)
			span.Context.SetLabel("accounts_result", "error")
			apm.CaptureError(ctx, err).Send()
			c.JSON(http.StatusInternalServerError, ErrorResponse{
				Error:   "database_error",
				Message: "Failed to retrieve accounts",
			})
			return
		}

		// Get recent transactions
		transactions, err := getRecentTransactions(ctx, db, userID)
		if err != nil {
			log.Printf("Failed to get transactions: %v", err)
			span.Context.SetLabel("transactions_result", "error")
			apm.CaptureError(ctx, err).Send()
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

		span.Context.SetLabel("accounts_result", "success")
		span.Context.SetLabel("accounts_count", len(accounts))
		span.Context.SetLabel("transactions_count", len(transactions))

		if tx != nil {
			tx.Context.SetLabel("response_accounts_count", len(accounts))
			tx.Context.SetLabel("response_transactions_count", len(transactions))
		}

		c.JSON(http.StatusOK, response)
	}
}

// Health check handler
func healthHandler(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx := c.Request.Context()
		span, ctx := apm.StartSpan(ctx, "health_check", "app")
		defer span.End()

		// Check database connection
		err := db.PingContext(ctx)
		dbHealthy := err == nil

		health := gin.H{
			"status":    "healthy",
			"service":   "accounts-go-service",
			"database":  dbHealthy,
			"timestamp": time.Now().UTC(),
		}

		span.Context.SetLabel("db_healthy", dbHealthy)

		if !dbHealthy {
			health["status"] = "unhealthy"
			health["error"] = err.Error()
			span.Context.SetLabel("health_result", "unhealthy")
			apm.CaptureError(ctx, err).Send()
			c.JSON(http.StatusServiceUnavailable, health)
		} else {
			span.Context.SetLabel("health_result", "healthy")
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
	}

	port := config.Port
	log.Printf("Starting VuBank Accounts Service on port %s", port)
	log.Printf("Database: %s:%s/%s", config.DBConfig.Host, config.DBConfig.Port, config.DBConfig.DBName)
	log.Printf("APM Server: %s", config.APMServerURL)

	if err := r.Run(":" + port); err != nil {
		log.Fatal("Failed to start server:", err)
	}
}
