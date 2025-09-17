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

type LogoutRequest struct {
	UserID               string `json:"user_id" binding:"required"`
	SessionID            string `json:"session_id,omitempty"`
	TerminateAllSessions bool   `json:"terminate_all_sessions,omitempty"`
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
func callAuthService(ctx context.Context, authURL string, username, password string, forceLogin bool, headers map[string]string) (*AuthResponse, error) {
	span, ctx := apm.StartSpan(ctx, "callAuthService", "external.http")
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
func createSession(ctx context.Context, authURL, userID, sessionID, jwtToken, ipAddress, userAgent string) error {
	span, ctx := apm.StartSpan(ctx, "createSession", "external.http")
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
		// Debug: Check if APM transaction exists
		tx := apm.TransactionFromContext(c.Request.Context())
		if tx != nil {
			log.Printf("APM Transaction detected: %s", tx.TraceContext().Trace)
		} else {
			log.Printf("No APM transaction found in context")
		}

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

		// Debug: Log distributed tracing headers
		traceparent := c.GetHeader("traceparent")
		tracestate := c.GetHeader("tracestate")
		if traceparent != "" || tracestate != "" {
			log.Printf("Distributed tracing headers - traceparent: %s, tracestate: %s", traceparent, tracestate)
		} else {
			log.Printf("No distributed tracing headers found in request")
		}

		// Prepare headers to forward to auth service
		headers := map[string]string{
			"X-Request-ID":    requestID,
			"X-Forwarded-For": c.ClientIP(),
			"User-Agent":      c.GetHeader("User-Agent"),
		}

		// Call Python authentication service
		authResp, err := callAuthService(c.Request.Context(), config.AuthServiceURL, loginReq.Username, loginReq.Password, loginReq.ForceLogin, headers)
		if err != nil {
			// Create span for auth service error
			span, _ := apm.StartSpan(c.Request.Context(), "auth_service_error", "app.external_service")
			span.Context.SetLabel("username", loginReq.Username)
			span.Context.SetLabel("error", err.Error())
			span.Context.SetLabel("auth_service_url", config.AuthServiceURL)
			span.Context.SetLabel("response_status", 500)
			defer span.End()

			log.Printf("Auth service error: %v", err)
			c.JSON(http.StatusInternalServerError, ErrorResponse{
				Error:   "auth_service_error",
				Message: "Authentication service unavailable",
			})
			return
		}

		// Check for session conflict
		if authResp.SessionConflict && !loginReq.ForceLogin {
			// Create span for session conflict handling
			span, _ := apm.StartSpan(c.Request.Context(), "session_conflict_handling", "app.business_logic")
			span.Context.SetLabel("username", loginReq.Username)
			span.Context.SetLabel("conflict_reason", "existing_session")
			span.Context.SetLabel("response_status", 409)
			defer span.End()

			log.Printf("Session conflict for user: %s", loginReq.Username)
			c.JSON(http.StatusConflict, LoginResponse{
				SessionConflict: true,
				ExistingSession: authResp.ExistingSession,
			})
			return
		}

		// Check authentication result
		if !authResp.OK || authResp.UserID == nil {
			// Create span for authentication failure
			span, _ := apm.StartSpan(c.Request.Context(), "authentication_failure", "app.business_logic")
			span.Context.SetLabel("username", loginReq.Username)
			span.Context.SetLabel("failure_reason", "invalid_credentials")
			span.Context.SetLabel("response_status", 401)
			defer span.End()

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
			// Create span for role validation failure
			span, _ := apm.StartSpan(c.Request.Context(), "role_validation_failure", "app.business_logic")
			span.Context.SetLabel("username", loginReq.Username)
			span.Context.SetLabel("user_roles", fmt.Sprintf("%v", authResp.Roles))
			span.Context.SetLabel("failure_reason", "insufficient_permissions")
			span.Context.SetLabel("response_status", 403)
			defer span.End()

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
			// Create span for JWT generation failure
			span, _ := apm.StartSpan(c.Request.Context(), "jwt_generation_failure", "app.business_logic")
			span.Context.SetLabel("username", loginReq.Username)
			span.Context.SetLabel("user_id", *authResp.UserID)
			span.Context.SetLabel("error", err.Error())
			span.Context.SetLabel("response_status", 500)
			defer span.End()

			log.Printf("Failed to generate JWT: %v", err)
			c.JSON(http.StatusInternalServerError, ErrorResponse{
				Error:   "token_generation_error",
				Message: "Failed to generate access token",
			})
			return
		}

		// Create session record if session_id was provided
		if authResp.SessionID != "" {
			err = createSession(c.Request.Context(), config.AuthServiceURL, *authResp.UserID, authResp.SessionID, token, c.ClientIP(), c.GetHeader("User-Agent"))
			if err != nil {
				log.Printf("Failed to create session: %v", err)
				// Continue anyway, session management is not critical for login
			}
		}

		log.Printf("Successful login for user: %s (Request ID: %s)", loginReq.Username, requestID)

		// Create span for successful login
		span, _ := apm.StartSpan(c.Request.Context(), "successful_login", "app.business_logic")
		span.Context.SetLabel("username", loginReq.Username)
		span.Context.SetLabel("user_id", *authResp.UserID)
		span.Context.SetLabel("roles", fmt.Sprintf("%v", authResp.Roles))
		span.Context.SetLabel("response_status", 200)
		span.Context.SetLabel("has_session", authResp.SessionID != "")
		defer span.End()

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

// Logout handler
func logoutHandler(config *Config) gin.HandlerFunc {
	return func(c *gin.Context) {
		span, ctx := apm.StartSpan(c.Request.Context(), "user_logout", "app.business_logic")
		defer span.End()

		requestID := c.GetString("request_id")

		var logoutReq LogoutRequest
		if err := c.ShouldBindJSON(&logoutReq); err != nil {
			span.Context.SetLabel("error", err.Error())
			span.Context.SetLabel("response_status", 400)
			log.Printf("Invalid logout request body: %v", err)
			c.JSON(http.StatusBadRequest, ErrorResponse{
				Error:   "invalid_request",
				Message: "Invalid request body",
			})
			return
		}

		log.Printf("Logout attempt for user: %s (Request ID: %s)", logoutReq.UserID, requestID)

		// Prepare logout request for auth service
		logoutData := map[string]interface{}{
			"user_id":                logoutReq.UserID,
			"terminate_all_sessions": logoutReq.TerminateAllSessions,
		}

		if logoutReq.SessionID != "" {
			logoutData["session_id"] = logoutReq.SessionID
		}

		jsonData, err := json.Marshal(logoutData)
		if err != nil {
			span.Context.SetLabel("error", err.Error())
			span.Context.SetLabel("response_status", 500)
			log.Printf("Failed to marshal logout request: %v", err)
			c.JSON(http.StatusInternalServerError, ErrorResponse{
				Error:   "request_marshal_error",
				Message: "Failed to prepare logout request",
			})
			return
		}

		// Call Python auth service logout endpoint
		req, err := http.NewRequestWithContext(ctx, "POST", config.AuthServiceURL+"/logout", bytes.NewBuffer(jsonData))
		if err != nil {
			span.Context.SetLabel("error", err.Error())
			span.Context.SetLabel("response_status", 500)
			log.Printf("Failed to create logout request: %v", err)
			c.JSON(http.StatusInternalServerError, ErrorResponse{
				Error:   "request_creation_error",
				Message: "Failed to create logout request",
			})
			return
		}

		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("X-Request-ID", requestID)
		req.Header.Set("X-Forwarded-For", c.ClientIP())
		req.Header.Set("User-Agent", c.GetHeader("User-Agent"))

		client := apmhttp.WrapClient(&http.Client{Timeout: 10 * time.Second})
		resp, err := client.Do(req)
		if err != nil {
			span.Context.SetLabel("error", err.Error())
			span.Context.SetLabel("response_status", 500)
			log.Printf("Auth service logout error: %v", err)
			c.JSON(http.StatusInternalServerError, ErrorResponse{
				Error:   "auth_service_error",
				Message: "Logout service unavailable",
			})
			return
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			span.Context.SetLabel("auth_service_status", resp.StatusCode)
			span.Context.SetLabel("response_status", 500)
			log.Printf("Auth service logout returned status: %d", resp.StatusCode)
			c.JSON(http.StatusInternalServerError, ErrorResponse{
				Error:   "logout_failed",
				Message: "Failed to terminate session",
			})
			return
		}

		var logoutResp map[string]interface{}
		if err := json.NewDecoder(resp.Body).Decode(&logoutResp); err != nil {
			span.Context.SetLabel("error", err.Error())
			span.Context.SetLabel("response_status", 500)
			log.Printf("Failed to decode logout response: %v", err)
			c.JSON(http.StatusInternalServerError, ErrorResponse{
				Error:   "response_decode_error",
				Message: "Failed to process logout response",
			})
			return
		}

		// Add success labels to span
		span.Context.SetLabel("user_id", logoutReq.UserID)
		span.Context.SetLabel("sessions_terminated", logoutResp["sessions_terminated"])
		span.Context.SetLabel("response_status", 200)

		log.Printf("Successful logout for user: %s (Request ID: %s)", logoutReq.UserID, requestID)

		c.JSON(http.StatusOK, gin.H{
			"success":             true,
			"message":             "Logout successful",
			"sessions_terminated": logoutResp["sessions_terminated"],
		})
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
		c.Header("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept, Authorization, X-Api-Client, X-Request-ID, traceparent, tracestate")

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
		api.POST("/logout", validateHeaders(config.APIClient), logoutHandler(config))
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
