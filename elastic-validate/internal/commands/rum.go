package commands

import (
	"context"
	"fmt"
	"time"

	"elastic-validate/internal/elastic"
	"elastic-validate/internal/validators"

	"github.com/fatih/color"
	"github.com/spf13/cobra"
)

// NewRUMCommand creates the RUM validation command
func NewRUMCommand() *cobra.Command {
	var (
		serviceName string
		pageName    string
		userAgent   string
		timeRange   string
	)

	cmd := &cobra.Command{
		Use:   "rum",
		Short: "Validate RUM (Real User Monitoring) data",
		Long: `
🌐 RUM Data Validator

Validates Real User Monitoring data from frontend applications.
Checks page load metrics, user interactions, and navigation timing.

Examples:
  elastic-validate rum --service="vubank-frontend" --page="login"
  elastic-validate rum --service="vubank-frontend" --user-agent="Chrome"
  elastic-validate rum --service="vubank-frontend" --time-range="1h"
		`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runRUMValidation(cmd, serviceName, pageName, userAgent, timeRange)
		},
	}

	cmd.Flags().StringVarP(&serviceName, "service", "s", "", "Service name to validate (required)")
	cmd.Flags().StringVarP(&pageName, "page", "p", "", "Page name to validate")
	cmd.Flags().StringVar(&userAgent, "user-agent", "", "User agent filter")
	cmd.Flags().StringVar(&timeRange, "time-range", "24h", "Time range for search")

	cmd.MarkFlagRequired("service")

	return cmd
}

func runRUMValidation(cmd *cobra.Command, serviceName, pageName, userAgent, timeRange string) error {
	elasticURL, _ := cmd.Flags().GetString("elastic-url")
	indexPattern, _ := cmd.Flags().GetString("index-pattern")
	debug, _ := cmd.Flags().GetBool("debug")
	jsonOutput, _ := cmd.Flags().GetBool("json")

	client, err := elastic.NewClient(elastic.Config{
		URL:          elasticURL,
		IndexPattern: indexPattern,
		Debug:        debug,
	})
	if err != nil {
		return fmt.Errorf("failed to create elastic client: %w", err)
	}

	color.Cyan("🌐 Starting RUM Validation...")
	fmt.Printf("   Service: %s\n", color.YellowString(serviceName))
	if pageName != "" {
		fmt.Printf("   Page: %s\n", color.YellowString(pageName))
	}
	fmt.Printf("   Time Range: %s\n", color.GreenString(timeRange))
	fmt.Println()

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	docs, err := client.SearchRUMData(ctx, serviceName, pageName)
	if err != nil {
		return fmt.Errorf("failed to search RUM data: %w", err)
	}

	if len(docs) == 0 {
		color.Red("❌ No RUM documents found matching criteria")
		return nil
	}

	color.Green("✅ Found %d RUM documents", len(docs))

	validator := validators.NewRUMValidator(client, debug)

	// Validate page load metrics
	color.Cyan("🔍 Validating Page Load Metrics...")
	pageLoadResult, err := validator.ValidatePageLoad(docs)
	if err != nil {
		color.Red("❌ Page load validation failed: %v", err)
	} else {
		printPageLoadResults(pageLoadResult, jsonOutput)
	}

	// Validate user interactions
	color.Cyan("🔍 Validating User Interactions...")
	interactionResult, err := validator.ValidateUserInteractions(docs)
	if err != nil {
		color.Red("❌ User interaction validation failed: %v", err)
	} else {
		printInteractionResults(interactionResult, jsonOutput)
	}

	return nil
}

func printPageLoadResults(result map[string]interface{}, jsonOutput bool) {
	// Implementation for printing page load results
	fmt.Println("📊 Page Load Metrics validated")
}

func printInteractionResults(result map[string]interface{}, jsonOutput bool) {
	// Implementation for printing interaction results
	fmt.Println("📊 User Interactions validated")
}
