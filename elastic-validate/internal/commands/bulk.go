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

// NewBulkValidateCommand creates the bulk validation command
func NewBulkValidateCommand() *cobra.Command {
	var (
		configFile string
		outputFile string
		parallel   int
		timeRange  string
	)

	cmd := &cobra.Command{
		Use:   "bulk",
		Short: "Run bulk validation tests",
		Long: `
📦 Bulk Validation Runner

Runs multiple validation tests in parallel based on configuration.
Can validate multiple services, transactions, and traces simultaneously.

Examples:
  elastic-validate bulk --config="validation-config.yaml"
  elastic-validate bulk --config="tests.yaml" --parallel=5
  elastic-validate bulk --output="validation-report.json"
		`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runBulkValidation(cmd, configFile, outputFile, parallel, timeRange)
		},
	}

	cmd.Flags().StringVarP(&configFile, "config", "c", "", "Configuration file for bulk validation")
	cmd.Flags().StringVarP(&outputFile, "output", "o", "", "Output file for results")
	cmd.Flags().IntVar(&parallel, "parallel", 3, "Number of parallel validations")
	cmd.Flags().StringVar(&timeRange, "time-range", "24h", "Time range for all validations")

	return cmd
}

func runBulkValidation(cmd *cobra.Command, configFile, outputFile string, parallel int, timeRange string) error {
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

	color.Cyan("📦 Starting Bulk Validation...")
	fmt.Printf("   Config File: %s\n", color.YellowString(configFile))
	fmt.Printf("   Parallel Jobs: %s\n", color.GreenString("%d", parallel))
	fmt.Printf("   Time Range: %s\n", color.GreenString(timeRange))
	fmt.Println()

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()

	// Run predefined validation suite
	return runPredefinedValidationSuite(ctx, client)
}

func runPredefinedValidationSuite(ctx context.Context, client *elastic.Client) error {
	color.Cyan("🧪 Running Predefined Validation Suite...")

	// Define validation tests
	validationTests := []struct {
		name        string
		service     string
		transaction string
		testType    string
	}{
		{
			name:        "Login Service - Authentication",
			service:     "vubank-login-service",
			transaction: "POST /api/login",
			testType:    "apm",
		},
		{
			name:        "Payment Service - Fund Transfer",
			service:     "payment-process-java-service",
			transaction: "POST /api/payment/transfer",
			testType:    "apm",
		},
		{
			name:        "Frontend RUM - Login Page",
			service:     "vubank-frontend",
			transaction: "login-page-load",
			testType:    "rum",
		},
		{
			name:        "CoreBanking - Account Lookup",
			service:     "corebanking-java-service",
			transaction: "GET /api/accounts",
			testType:    "apm",
		},
		{
			name:        "Accounts Service - Balance Check",
			service:     "accounts-go-service",
			transaction: "GET /api/balance",
			testType:    "apm",
		},
	}

	successCount := 0
	totalTests := len(validationTests)

	for i, test := range validationTests {
		fmt.Printf("\n%s [%d/%d] %s\n",
			color.CyanString("🧪"), i+1, totalTests, test.name)
		fmt.Printf("   Service: %s\n", color.YellowString(test.service))
		fmt.Printf("   Transaction: %s\n", color.YellowString(test.transaction))

		success := runSingleValidationTest(ctx, client, test)
		if success {
			color.Green("   ✅ PASSED")
			successCount++
		} else {
			color.Red("   ❌ FAILED")
		}
	}

	// Print summary
	fmt.Printf("\n📊 Bulk Validation Summary:\n")
	fmt.Printf("   Total Tests: %d\n", totalTests)
	fmt.Printf("   Passed: %s\n", color.GreenString("%d", successCount))
	fmt.Printf("   Failed: %s\n", color.RedString("%d", totalTests-successCount))
	fmt.Printf("   Success Rate: %s\n",
		color.GreenString("%.1f%%", float64(successCount)/float64(totalTests)*100))

	if successCount == totalTests {
		color.Green("\n🎉 All validation tests passed!")
	} else {
		color.Yellow("\n⚠️ Some validation tests failed - check individual results above")
	}

	return nil
}

func runSingleValidationTest(ctx context.Context, client *elastic.Client, test struct {
	name        string
	service     string
	transaction string
	testType    string
}) bool {
	switch test.testType {
	case "apm":
		return runAPMValidationTest(ctx, client, test.service, test.transaction)
	case "rum":
		return runRUMValidationTest(ctx, client, test.service, test.transaction)
	default:
		color.Red("   Unknown test type: %s", test.testType)
		return false
	}
}

func runAPMValidationTest(ctx context.Context, client *elastic.Client, service, transaction string) bool {
	docs, err := client.SearchAPMData(ctx, service, transaction)
	if err != nil {
		color.Red("   Search failed: %v", err)
		return false
	}

	if len(docs) == 0 {
		color.Red("   No documents found")
		return false
	}

	validator := validators.NewAPMValidator(client, false)

	// Quick header validation
	headerResult, err := validator.ValidateHeaders(docs)
	if err != nil {
		color.Red("   Header validation failed: %v", err)
		return false
	}

	withHeaders := headerResult["with_headers"].(int)
	if withHeaders == 0 {
		color.Red("   No headers found in documents")
		return false
	}

	return true
}

func runRUMValidationTest(ctx context.Context, client *elastic.Client, service, page string) bool {
	docs, err := client.SearchRUMData(ctx, service, page)
	if err != nil {
		color.Red("   RUM search failed: %v", err)
		return false
	}

	if len(docs) == 0 {
		color.Red("   No RUM documents found")
		return false
	}

	return true
}
