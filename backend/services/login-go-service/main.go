package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"go.elastic.co/apm/module/apmgin/v2"
	"go.elastic.co/apm/module/apmhttp/v2"
	"go.elastic.co/apm/v2"
)

// Config struct
type Config struct {
	Port               string
	AuthServiceURL     string
	AccountsServiceURL string
	JWTSecret          string
	APIClient          string
	APMServerURL       string
	APMServiceName     string
}

// Request/Response models
type LoginRequest struct {
	Username   string `json:"username" binding:"required"`
	Password   string `json:"password" binding:"required"`
	ForceLogin bool   `json:"force_login,omitempty"`
}

type AuthRequest struct {
	Username   string `json:"username"`
	Password   string `json:"password"`
	ForceLogin bool   `json:"force_login,omitempty"`
}

type AuthResponse struct {
	OK              bool                   `json:"ok"`
	UserID          *string                `json:"userId"`
	Roles           []string               `json:"roles"`
	SessionConflict bool                   `json:"session_conflict,omitempty"`
	ExistingSession map[string]interface{} `json:"existing_session,omitempty"`
	SessionID       string                 `json:"session_id,omitempty"`
}

type LoginResponse struct {
	Token           string                 `json:"token"`
	User            User                   `json:"user"`
	SessionConflict bool                   `json:"session_conflict,omitempty"`
	ExistingSession map[string]interface{} `json:"existing_session,omitempty"`
}

type User struct {
	ID       string   `json:"id"`
	Username string   `json:"username"`
	Roles    []string `json:"roles"`
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

// Load configuration from environment
func loadConfig() *Config {
	return &Config{
		Port:               getEnv("PUBLIC_API_PORT", "8000"),
		AuthServiceURL:     getEnv("AUTH_SERVICE_URL", "http://login-python-authenticator:8001"),
		AccountsServiceURL: getEnv("ACCOUNTS_SERVICE_URL", "http://accounts-go-service:8002"),
		JWTSecret:          getEnv("JWT_SECRET", "your-super-secret-jwt-key"),
		APIClient:          getEnv("API_CLIENT", "web-portal"),
		APMServerURL:       getEnv("ELASTIC_APM_SERVER_URL", ""),
		APMServiceName:     getEnv("ELASTIC_APM_SERVICE_NAME", "vubank-login-service"),
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// Middleware for header validation
func validateHeaders(apiClient string) gin.HandlerFunc {
	return func(c *gin.Context) {
		// Check required headers
		origin := c.GetHeader("Origin")
		xRequestedWith := c.GetHeader("X-Requested-With")
		xAPIClient := c.GetHeader("X-Api-Client")

		// Validate X-Api-Client header
		if xAPIClient != apiClient {
			log.Printf("Invalid API client header: %s", xAPIClient)
			c.JSON(http.StatusBadRequest, ErrorResponse{
				Error:   "invalid_headers",
				Message: "Invalid API client header",
			})
			c.Abort()
			return
		}

		// Validate Origin (basic check for development)
		if origin == "" {
			log.Printf("Missing Origin header")
			c.JSON(http.StatusBadRequest, ErrorResponse{
				Error:   "invalid_headers",
				Message: "Missing required headers",
			})
			c.Abort()
			return
		}

		// Validate X-Requested-With
		if xRequestedWith != "XMLHttpRequest" {
			log.Printf("Invalid X-Requested-With header: %s", xRequestedWith)
			c.JSON(http.StatusBadRequest, ErrorResponse{
				Error:   "invalid_headers",
				Message: "Invalid request headers",
			})
			c.Abort()
			return
		}

		c.Next()
	}
}

// Middleware to set correlation ID
func correlationID() gin.HandlerFunc {
	return func(c *gin.Context) {
		requestID := c.GetHeader("X-Request-ID")
		if requestID == "" {
			requestID = uuid.New().String()
			c.Header("X-Request-ID", requestID)
		}
		c.Set("request_id", requestID)
		c.Next()
	}
}

// Call Python authentication service
func callAuthService(authURL string, username, password string, forceLogin bool, headers map[string]string) (*AuthResponse, error) {
	span, ctx := apm.StartSpan(context.Background(), "callAuthService", "external.http")
	defer span.End()

	authReq := AuthRequest{
		Username:   username,
		Password:   password,
		ForceLogin: forceLogin,
	}

	jsonData, err := json.Marshal(authReq)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal auth request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, "POST", authURL+"/verify", bytes.NewBuffer(jsonData))
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")

	// Forward headers to auth service
	for key, value := range headers {
		req.Header.Set(key, value)
	}

	client := apmhttp.WrapClient(&http.Client{Timeout: 10 * time.Second})
	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to call auth service: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("auth service returned status: %d", resp.StatusCode)
	}

	var authResp AuthResponse
	if err := json.NewDecoder(resp.Body).Decode(&authResp); err != nil {
		return nil, fmt.Errorf("failed to decode auth response: %w", err)
	}

	return &authResp, nil
}

// Create session in auth service
func createSession(authURL, userID, sessionID, jwtToken, ipAddress, userAgent string) error {
	span, ctx := apm.StartSpan(context.Background(), "createSession", "external.http")
	defer span.End()

	sessionReq := map[string]interface{}{
		"user_id":    userID,
		"session_id": sessionID,
		"jwt_token":  jwtToken,
		"ip_address": ipAddress,
		"user_agent": userAgent,
	}

	jsonData, err := json.Marshal(sessionReq)
	if err != nil {
		return fmt.Errorf("failed to marshal session request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, "POST", authURL+"/create-session", bytes.NewBuffer(jsonData))
	if err != nil {
		return fmt.Errorf("failed to create session request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")

	client := apmhttp.WrapClient(&http.Client{Timeout: 10 * time.Second})
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("failed to call session service: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("session service returned status: %d", resp.StatusCode)
	}

	return nil
}

// Generate JWT token
func generateJWT(userID string, roles []string, jwtSecret string) (string, error) {
	claims := Claims{
		UserID: userID,
		Roles:  roles,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(15 * time.Minute)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			Issuer:    "vubank-login-service",
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(jwtSecret))
}

// Login handler
func loginHandler(config *Config) gin.HandlerFunc {
	return func(c *gin.Context) {
		requestID := c.GetString("request_id")

		var loginReq LoginRequest
		if err := c.ShouldBindJSON(&loginReq); err != nil {
			log.Printf("Invalid request body: %v", err)
			c.JSON(http.StatusBadRequest, ErrorResponse{
				Error:   "invalid_request",
				Message: "Invalid request body",
			})
			return
		}

		log.Printf("Login attempt for user: %s (Request ID: %s)", loginReq.Username, requestID)

		// Prepare headers to forward to auth service
		headers := map[string]string{
			"X-Request-ID":    requestID,
			"X-Forwarded-For": c.ClientIP(),
			"User-Agent":      c.GetHeader("User-Agent"),
		}

		// Call Python authentication service
		authResp, err := callAuthService(config.AuthServiceURL, loginReq.Username, loginReq.Password, loginReq.ForceLogin, headers)
		if err != nil {
			log.Printf("Auth service error: %v", err)
			c.JSON(http.StatusInternalServerError, ErrorResponse{
				Error:   "auth_service_error",
				Message: "Authentication service unavailable",
			})
			return
		}

		// Check for session conflict
		if authResp.SessionConflict && !loginReq.ForceLogin {
			log.Printf("Session conflict for user: %s", loginReq.Username)
			c.JSON(http.StatusConflict, LoginResponse{
				SessionConflict: true,
				ExistingSession: authResp.ExistingSession,
			})
			return
		}

		// Check authentication result
		if !authResp.OK || authResp.UserID == nil {
			log.Printf("Authentication failed for user: %s", loginReq.Username)
			c.JSON(http.StatusUnauthorized, ErrorResponse{
				Error:   "invalid_credentials",
				Message: "Invalid username or password",
			})
			return
		}

		// Check roles (must have retail or corporate)
		hasValidRole := false
		for _, role := range authResp.Roles {
			if role == "retail" || role == "corporate" {
				hasValidRole = true
				break
			}
		}

		if !hasValidRole {
			log.Printf("User %s has no valid banking roles", loginReq.Username)
			c.JSON(http.StatusForbidden, ErrorResponse{
				Error:   "insufficient_permissions",
				Message: "Insufficient permissions for banking access",
			})
			return
		}

		// Generate JWT token
		token, err := generateJWT(*authResp.UserID, authResp.Roles, config.JWTSecret)
		if err != nil {
			log.Printf("Failed to generate JWT: %v", err)
			c.JSON(http.StatusInternalServerError, ErrorResponse{
				Error:   "token_generation_error",
				Message: "Failed to generate access token",
			})
			return
		}

		// Create session record if session_id was provided
		if authResp.SessionID != "" {
			err = createSession(config.AuthServiceURL, *authResp.UserID, authResp.SessionID, token, c.ClientIP(), c.GetHeader("User-Agent"))
			if err != nil {
				log.Printf("Failed to create session: %v", err)
				// Continue anyway, session management is not critical for login
			}
		}

		log.Printf("Successful login for user: %s (Request ID: %s)", loginReq.Username, requestID)

		// Return success response
		c.JSON(http.StatusOK, LoginResponse{
			Token: token,
			User: User{
				ID:       *authResp.UserID,
				Username: loginReq.Username,
				Roles:    authResp.Roles,
			},
		})
	}
}

// Health check handler
func healthHandler(config *Config) gin.HandlerFunc {
	return func(c *gin.Context) {
		span, ctx := apm.StartSpan(c.Request.Context(), "healthCheck", "app.health")
		defer span.End()

		// Check auth service health
		client := apmhttp.WrapClient(&http.Client{Timeout: 5 * time.Second})
		req, _ := http.NewRequestWithContext(ctx, "GET", config.AuthServiceURL+"/health", nil)
		resp, err := client.Do(req)
		authHealthy := err == nil && resp.StatusCode == http.StatusOK
		if resp != nil {
			resp.Body.Close()
		}

		health := gin.H{
			"status": "healthy",
			"services": gin.H{
				"auth_service": authHealthy,
			},
			"timestamp": time.Now().UTC(),
		}

		if !authHealthy {
			health["status"] = "degraded"
			c.JSON(http.StatusServiceUnavailable, health)
		} else {
			c.JSON(http.StatusOK, health)
		}
	}
}

func main() {
	config := loadConfig()

	// Initialize APM if server URL is provided
	if config.APMServerURL != "" {
		log.Printf("Initializing APM with server: %s", config.APMServerURL)
		// APM configuration is handled via environment variables
		// ELASTIC_APM_SERVER_URL and ELASTIC_APM_SERVICE_NAME
	}

	// Set Gin mode
	gin.SetMode(gin.ReleaseMode)

	r := gin.New()
	r.Use(gin.Logger())
	r.Use(gin.Recovery())

	// Add APM middleware if APM is configured
	if config.APMServerURL != "" {
		r.Use(apmgin.Middleware(r))
	}

	// Add CORS middleware
	r.Use(func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept, Authorization, X-Api-Client, X-Request-ID")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}

		c.Next()
	})

	// Add correlation ID middleware
	r.Use(correlationID())

	// API routes
	api := r.Group("/api")
	{
		// Health check (no header validation required)
		api.GET("/health", healthHandler(config))

		// Protected routes with header validation
		api.POST("/login", validateHeaders(config.APIClient), loginHandler(config))
	}

	port := config.Port
	log.Printf("Starting VuBank Login Gateway Service on port %s", port)
	log.Printf("Auth Service URL: %s", config.AuthServiceURL)
	log.Printf("API Client: %s", config.APIClient)
	if config.APMServerURL != "" {
		log.Printf("APM Server: %s", config.APMServerURL)
		log.Printf("APM Service Name: %s", config.APMServiceName)
	}

	if err := r.Run(":" + port); err != nil {
		log.Fatal("Failed to start server:", err)
	}
}
