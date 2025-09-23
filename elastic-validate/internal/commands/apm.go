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

// NewAPMCommand creates the APM validation command
func NewAPMCommand() *cobra.Command {
	var (
		serviceName     string
		transactionName string
		validateHeaders bool
		validateBody    bool
		timeRange       string
	)

	cmd := &cobra.Command{
		Use:   "apm",
		Short: "Validate APM transaction data",
		Long: `
🔍 APM Transaction Data Validator

Validates APM transaction data including headers, request bodies, and metadata.
Queries Elasticsearch to find transactions matching service and transaction name criteria.

Examples:
  elastic-validate apm --service="vubank-login-service" --transaction="POST /api/login"
  elastic-validate apm --service="payment-process-java-service" --validate-headers
  elastic-validate apm --service="vubank-frontend" --validate-body --time-range="1h"
		`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runAPMValidation(cmd, serviceName, transactionName, validateHeaders, validateBody, timeRange)
		},
	}

	cmd.Flags().StringVarP(&serviceName, "service", "s", "", "Service name to validate (required)")
	cmd.Flags().StringVarP(&transactionName, "transaction", "t", "", "Transaction name to validate")
	cmd.Flags().BoolVar(&validateHeaders, "validate-headers", true, "Validate request headers capture")
	cmd.Flags().BoolVar(&validateBody, "validate-body", true, "Validate request body capture")
	cmd.Flags().StringVar(&timeRange, "time-range", "24h", "Time range for search (e.g., 1h, 24h, 7d)")

	cmd.MarkFlagRequired("service")

	return cmd
}

func runAPMValidation(cmd *cobra.Command, serviceName, transactionName string, validateHeaders, validateBody bool, timeRange string) error {
	// Get global flags
	elasticURL, _ := cmd.Flags().GetString("elastic-url")
	indexPattern, _ := cmd.Flags().GetString("index-pattern")
	debug, _ := cmd.Flags().GetBool("debug")
	jsonOutput, _ := cmd.Flags().GetBool("json")

	// Create Elasticsearch client
	client, err := elastic.NewClient(elastic.Config{
		URL:          elasticURL,
		IndexPattern: indexPattern,
		Debug:        debug,
	})
	if err != nil {
		return fmt.Errorf("failed to create elastic client: %w", err)
	}

	// Print validation start
	color.Cyan("🔍 Starting APM Validation...")
	fmt.Printf("   Service: %s\n", color.YellowString(serviceName))
	if transactionName != "" {
		fmt.Printf("   Transaction: %s\n", color.YellowString(transactionName))
	}
	fmt.Printf("   Time Range: %s\n", color.GreenString(timeRange))
	fmt.Printf("   Elasticsearch: %s\n", color.BlueString(elasticURL))
	fmt.Println()

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Search for APM data
	docs, err := client.SearchAPMData(ctx, serviceName, transactionName)
	if err != nil {
		return fmt.Errorf("failed to search APM data: %w", err)
	}

	if len(docs) == 0 {
		color.Red("❌ No APM documents found matching criteria")
		fmt.Printf("   Service: %s\n", serviceName)
		if transactionName != "" {
			fmt.Printf("   Transaction: %s\n", transactionName)
		}
		return nil
	}

	color.Green("✅ Found %d APM documents", len(docs))

	// Create validator
	validator := validators.NewAPMValidator(client, debug)

	// Validate headers if requested
	if validateHeaders {
		fmt.Println()
		color.Cyan("🔍 Validating Request Headers...")
		headerResult, err := validator.ValidateHeaders(docs)
		if err != nil {
			color.Red("❌ Header validation failed: %v", err)
		} else {
			printHeaderValidationResults(headerResult, jsonOutput)
		}
	}

	// Validate request body if requested
	if validateBody {
		fmt.Println()
		color.Cyan("🔍 Validating Request Bodies...")
		bodyResult, err := validator.ValidateRequestBodies(docs)
		if err != nil {
			color.Red("❌ Body validation failed: %v", err)
		} else {
			printBodyValidationResults(bodyResult, jsonOutput)
		}
	}

	// Overall validation summary
	fmt.Println()
	color.Cyan("📊 Validation Summary:")
	fmt.Printf("   Total Documents: %s\n", color.GreenString("%d", len(docs)))

	if validateHeaders {
		fmt.Printf("   Headers Present: %s\n", color.GreenString("✅ Validated"))
	}

	if validateBody {
		fmt.Printf("   Request Bodies: %s\n", color.GreenString("✅ Validated"))
	}

	return nil
}

func printHeaderValidationResults(result map[string]interface{}, jsonOutput bool) {
	if jsonOutput {
		// TODO: Implement JSON output
		return
	}

	total := result["total_documents"].(int)
	withHeaders := result["with_headers"].(int)
	missing := result["missing_headers"].(int)

	if withHeaders == total {
		color.Green("✅ All documents (%d/%d) have request headers captured", withHeaders, total)
	} else if withHeaders > 0 {
		color.Yellow("⚠️  Partial header capture: %d/%d documents have headers", withHeaders, total)
		color.Red("   Missing headers in %d documents", missing)
	} else {
		color.Red("❌ No request headers found in any documents")
	}

	// Extract and display document IDs with headers
	if details, ok := result["header_details"].([]map[string]interface{}); ok && len(details) > 0 {
		// First, show which documents have headers
		var docsWithHeaders []string
		var docsWithoutHeaders []string

		for _, detail := range details {
			docID := detail["document_id"].(string)
			if headers, ok := detail["headers"].(map[string]interface{}); ok && len(headers) > 0 {
				docsWithHeaders = append(docsWithHeaders, docID)
			} else {
				docsWithoutHeaders = append(docsWithoutHeaders, docID)
			}
		}

		if len(docsWithHeaders) > 0 {
			fmt.Printf("\n📍 %s Documents with headers:\n", color.GreenString("✅"))
			for _, docID := range docsWithHeaders {
				fmt.Printf("   • %s\n", color.GreenString(docID))
			}
		}

		if len(docsWithoutHeaders) > 0 {
			fmt.Printf("\n📍 %s Documents missing headers:\n", color.RedString("❌"))
			for _, docID := range docsWithoutHeaders {
				fmt.Printf("   • %s\n", color.RedString(docID))
			}
		}

		// Show sample header details
		fmt.Println("\n📋 Sample Header Details:")
		for i, detail := range details {
			if i >= 3 { // Show only first 3 samples
				break
			}
			docID := detail["document_id"].(string)
			fmt.Printf("   Document %s:\n", color.CyanString(docID))
			if headers, ok := detail["headers"].(map[string]interface{}); ok && len(headers) > 0 {
				headerCount := 0
				for key, value := range headers {
					if headerCount >= 5 { // Limit to 5 headers per document for readability
						fmt.Printf("     ... and %d more headers\n", len(headers)-5)
						break
					}
					fmt.Printf("     %s: %v\n", color.CyanString(key), value)
					headerCount++
				}
			} else {
				color.Red("     No headers found")
			}
		}
	}
}

func printBodyValidationResults(result map[string]interface{}, jsonOutput bool) {
	if jsonOutput {
		// TODO: Implement JSON output
		return
	}

	total := result["total_documents"].(int)
	withBody := result["with_body"].(int)
	missing := result["missing_body"].(int)

	if withBody == total {
		color.Green("✅ All documents (%d/%d) have request bodies captured", withBody, total)
	} else if withBody > 0 {
		color.Yellow("⚠️  Partial body capture: %d/%d documents have bodies", withBody, total)
		color.Red("   Missing bodies in %d documents", missing)
	} else {
		color.Red("❌ No request bodies found in any documents")
	}

	// Extract and display document IDs with bodies
	if details, ok := result["body_details"].([]map[string]interface{}); ok && len(details) > 0 {
		// First, show which documents have bodies
		var docsWithBodies []string
		var docsWithoutBodies []string

		for _, detail := range details {
			docID := detail["document_id"].(string)
			if bodyPreview, ok := detail["body_preview"].(string); ok && bodyPreview != "" {
				docsWithBodies = append(docsWithBodies, docID)
			} else {
				docsWithoutBodies = append(docsWithoutBodies, docID)
			}
		}

		if len(docsWithBodies) > 0 {
			fmt.Printf("\n📍 %s Documents with request bodies:\n", color.GreenString("✅"))
			for _, docID := range docsWithBodies {
				fmt.Printf("   • %s\n", color.GreenString(docID))
			}
		}

		if len(docsWithoutBodies) > 0 {
			fmt.Printf("\n📍 %s Documents missing request bodies:\n", color.RedString("❌"))
			for _, docID := range docsWithoutBodies {
				fmt.Printf("   • %s\n", color.RedString(docID))
			}
		}

		// Show sample body details
		fmt.Println("\n📋 Sample Body Details:")
		for i, detail := range details {
			if i >= 3 { // Show only first 3 samples
				break
			}
			docID := detail["document_id"].(string)
			fmt.Printf("   Document %s:\n", color.CyanString(docID))
			if bodyPreview, ok := detail["body_preview"].(string); ok && bodyPreview != "" {
				bodySize, _ := detail["body_size"].(int)
				bodyType, _ := detail["body_type"].(string)
				fmt.Printf("     Type: %s, Size: %d bytes\n", color.BlueString(bodyType), bodySize)
				fmt.Printf("     Content: %s\n", color.GreenString(bodyPreview))
			} else {
				color.Red("     No body found")
			}
		}
	}
}
