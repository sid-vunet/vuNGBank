package commands

import (
	"context"
	"fmt"
	"time"

	"elastic-validate/internal/elastic"

	"github.com/fatih/color"
	"github.com/spf13/cobra"
)

// NewHealthCommand creates the health check command
func NewHealthCommand() *cobra.Command {
	var (
		serviceName string
		checkAll    bool
		timeRange   string
	)

	cmd := &cobra.Command{
		Use:   "health",
		Short: "Check APM data collection health",
		Long: `
🏥 APM Health Checker

Checks the overall health of APM data collection.
Validates data freshness, completeness, and service availability.

Examples:
  elastic-validate health --service="vubank-login-service"
  elastic-validate health --check-all
  elastic-validate health --service="payment-service" --time-range="1h"
		`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runHealthCheck(cmd, serviceName, checkAll, timeRange)
		},
	}

	cmd.Flags().StringVarP(&serviceName, "service", "s", "", "Service name to check")
	cmd.Flags().BoolVar(&checkAll, "check-all", false, "Check all services")
	cmd.Flags().StringVar(&timeRange, "time-range", "1h", "Time range for health check")

	return cmd
}

func runHealthCheck(cmd *cobra.Command, serviceName string, checkAll bool, timeRange string) error {
	elasticURL, _ := cmd.Flags().GetString("elastic-url")
	indexPattern, _ := cmd.Flags().GetString("index-pattern")
	debug, _ := cmd.Flags().GetBool("debug")

	client, err := elastic.NewClient(elastic.Config{
		URL:          elasticURL,
		IndexPattern: indexPattern,
		Debug:        debug,
	})
	if err != nil {
		return fmt.Errorf("failed to create elastic client: %w", err)
	}

	color.Cyan("🏥 Starting Health Check...")
	fmt.Printf("   Time Range: %s\n", color.GreenString(timeRange))
	fmt.Printf("   Elasticsearch: %s\n", color.BlueString(elasticURL))
	fmt.Println()

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if checkAll {
		return runAllServicesHealthCheck(ctx, client)
	}

	if serviceName == "" {
		return fmt.Errorf("either --service or --check-all must be provided")
	}

	return runSingleServiceHealthCheck(ctx, client, serviceName)
}

func runSingleServiceHealthCheck(ctx context.Context, client *elastic.Client, serviceName string) error {
	color.Cyan("🔍 Checking service: %s", serviceName)

	health, err := client.GetServiceHealth(ctx, serviceName)
	if err != nil {
		color.Red("❌ Health check failed: %v", err)
		return err
	}

	color.Green("✅ Service health check completed")
	fmt.Printf("   Service: %s\n", health["service_name"])
	fmt.Printf("   Status: %s\n", health["status"])

	return nil
}

func runAllServicesHealthCheck(ctx context.Context, client *elastic.Client) error {
	color.Cyan("🔍 Checking all services...")

	// List of known VuBank services
	services := []string{
		"vubank-frontend",
		"vubank-login-service",
		"payment-process-java-service",
		"corebanking-java-service",
		"accounts-go-service",
		"payee-store-dotnet-service",
		"pdf-receipt-java-service",
		"login-python-authenticator",
	}

	healthyCount := 0
	for _, service := range services {
		fmt.Printf("\n🔍 Checking %s...\n", color.YellowString(service))

		health, err := client.GetServiceHealth(ctx, service)
		if err != nil {
			color.Red("❌ %s: Health check failed - %v", service, err)
			continue
		}

		status := health["status"].(string)
		if status == "healthy" {
			color.Green("✅ %s: Healthy", service)
			healthyCount++
		} else {
			color.Yellow("⚠️ %s: %s", service, status)
		}
	}

	fmt.Printf("\n📊 Overall Health Summary:\n")
	fmt.Printf("   Healthy Services: %s/%d\n",
		color.GreenString("%d", healthyCount), len(services))

	if healthyCount == len(services) {
		color.Green("🎉 All services are healthy!")
	} else if healthyCount > len(services)/2 {
		color.Yellow("⚠️ Most services are healthy, but some need attention")
	} else {
		color.Red("❌ Multiple services need attention")
	}

	return nil
}
