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

// NewTraceCommand creates the distributed tracing validation command
func NewTraceCommand() *cobra.Command {
	var (
		traceID   string
		spanID    string
		timeRange string
	)

	cmd := &cobra.Command{
		Use:   "trace",
		Short: "Validate distributed tracing data",
		Long: `
🔗 Distributed Trace Validator

Validates distributed tracing data across multiple services.
Tracks trace propagation and span relationships.

Examples:
  elastic-validate trace --trace-id="abc123def456"
  elastic-validate trace --span-id="span789"
  elastic-validate trace --trace-id="abc123" --time-range="1h"
		`,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runTraceValidation(cmd, traceID, spanID, timeRange)
		},
	}

	cmd.Flags().StringVar(&traceID, "trace-id", "", "Trace ID to validate")
	cmd.Flags().StringVar(&spanID, "span-id", "", "Span ID to validate")
	cmd.Flags().StringVar(&timeRange, "time-range", "24h", "Time range for search")

	return cmd
}

func runTraceValidation(cmd *cobra.Command, traceID, spanID, timeRange string) error {
	if traceID == "" && spanID == "" {
		return fmt.Errorf("either --trace-id or --span-id must be provided")
	}

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

	color.Cyan("🔗 Starting Trace Validation...")
	if traceID != "" {
		fmt.Printf("   Trace ID: %s\n", color.YellowString(traceID))
	}
	if spanID != "" {
		fmt.Printf("   Span ID: %s\n", color.YellowString(spanID))
	}
	fmt.Println()

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	var docs []elastic.APMDocument
	if traceID != "" {
		docs, err = client.SearchByTraceID(ctx, traceID)
	}

	if err != nil {
		return fmt.Errorf("failed to search trace data: %w", err)
	}

	if len(docs) == 0 {
		color.Red("❌ No trace documents found")
		return nil
	}

	color.Green("✅ Found %d trace documents", len(docs))

	validator := validators.NewTraceValidator(client, debug)

	// Validate trace continuity
	color.Cyan("🔍 Validating Trace Continuity...")
	continuityResult, err := validator.ValidateTraceContinuity(docs)
	if err != nil {
		color.Red("❌ Trace continuity validation failed: %v", err)
	} else {
		printTraceContinuityResults(continuityResult)
	}

	return nil
}

func printTraceContinuityResults(result map[string]interface{}) {
	fmt.Println("📊 Trace Continuity validated")
}
