package main
package main

import (
	"fmt"
	"log"
	"os"

	"elastic-validate/internal/commands"
	"github.com/spf13/cobra"
)

var (
	version = "1.0.0"
	commit  = "dev"
	date    = "unknown"
)

func main() {
	rootCmd := &cobra.Command{
		Use:   "elastic-validate",
		Short: "VuBank Elastic APM Data Validator",
		Long: `
🔍 VuBank Elastic APM Data Validator

A comprehensive tool to query and validate APM/RUM data collected in Elasticsearch.
Validates request headers, bodies, transactions, and distributed tracing data.

Examples:
  elastic-validate apm --service="vubank-login-service" --transaction="POST /api/login"
  elastic-validate rum --service="vubank-frontend" --page="login"
  elastic-validate trace --trace-id="abc123"
  elastic-validate health --check-all
		`,
		Version: fmt.Sprintf("%s (commit: %s, built: %s)", version, commit, date),
	}

	// Global flags
	rootCmd.PersistentFlags().String("elastic-url", "http://91.203.133.240:8082", "Elasticsearch URL")
	rootCmd.PersistentFlags().String("index-pattern", ".ds-*", "Index pattern for APM data")
	rootCmd.PersistentFlags().Bool("debug", false, "Enable debug logging")
	rootCmd.PersistentFlags().Bool("json", false, "Output results in JSON format")

	// Add subcommands
	rootCmd.AddCommand(commands.NewAPMCommand())
	rootCmd.AddCommand(commands.NewRUMCommand())
	rootCmd.AddCommand(commands.NewTraceCommand())
	rootCmd.AddCommand(commands.NewHealthCommand())
	rootCmd.AddCommand(commands.NewBulkValidateCommand())

	if err := rootCmd.Execute(); err != nil {
		log.Fatal(err)
		os.Exit(1)
	}
}