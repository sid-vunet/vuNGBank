package validators

import (
	"encoding/json"

	"elastic-validate/internal/elastic"

	"github.com/tidwall/gjson"
)

// APMValidator handles validation of APM transaction data
type APMValidator struct {
	client *elastic.Client
	debug  bool
}

// NewAPMValidator creates a new APM validator
func NewAPMValidator(client *elastic.Client, debug bool) *APMValidator {
	return &APMValidator{
		client: client,
		debug:  debug,
	}
}

// ValidateHeaders validates that request headers are properly captured
func (v *APMValidator) ValidateHeaders(docs []elastic.APMDocument) (map[string]interface{}, error) {
	result := map[string]interface{}{
		"total_documents": len(docs),
		"with_headers":    0,
		"missing_headers": 0,
		"header_details":  []map[string]interface{}{},
	}

	for _, doc := range docs {
		hasHeaders := false
		headerDetails := map[string]interface{}{
			"document_id": doc.ID,
			"timestamp":   doc.Timestamp,
			"service":     doc.ServiceName,
			"headers":     map[string]interface{}{},
		}

		// Convert source to JSON for gjson parsing
		sourceBytes, err := json.Marshal(doc.Source)
		if err != nil {
			continue
		}

		source := gjson.ParseBytes(sourceBytes)

		// Check various paths where headers might be stored
		headerPaths := []string{
			"http.request.headers",
			"transaction.context.request.headers",
			"context.request.headers",
			"labels.http_request_headers",
			"http_request_headers",
		}

		for _, path := range headerPaths {
			if headers := source.Get(path); headers.Exists() {
				hasHeaders = true
				headerDetails["headers"] = headers.Value()
				headerDetails["header_path"] = path
				break
			}
		}

		// Check for specific important headers
		if hasHeaders {
			headers := headerDetails["headers"].(map[string]interface{})
			importantHeaders := []string{
				"authorization", "Authorization",
				"content-type", "Content-Type",
				"user-agent", "User-Agent",
				"x-trace-id", "X-Trace-Id",
				"elastic-apm-traceparent",
			}

			foundImportant := []string{}
			for _, header := range importantHeaders {
				if _, exists := headers[header]; exists {
					foundImportant = append(foundImportant, header)
				}
			}
			headerDetails["important_headers"] = foundImportant
		}

		if hasHeaders {
			result["with_headers"] = result["with_headers"].(int) + 1
		} else {
			result["missing_headers"] = result["missing_headers"].(int) + 1
		}

		result["header_details"] = append(result["header_details"].([]map[string]interface{}), headerDetails)
	}

	// Calculate header coverage percentage
	total := result["total_documents"].(int)
	withHeaders := result["with_headers"].(int)
	result["header_coverage_percentage"] = float64(withHeaders) / float64(total) * 100

	return result, nil
}

// ValidateRequestBodies validates that request bodies are properly captured
func (v *APMValidator) ValidateRequestBodies(docs []elastic.APMDocument) (map[string]interface{}, error) {
	result := map[string]interface{}{
		"total_documents": len(docs),
		"with_body":       0,
		"missing_body":    0,
		"body_details":    []map[string]interface{}{},
	}

	for _, doc := range docs {
		hasBody := false
		bodyDetails := map[string]interface{}{
			"document_id": doc.ID,
			"timestamp":   doc.Timestamp,
			"service":     doc.ServiceName,
		}

		sourceBytes, err := json.Marshal(doc.Source)
		if err != nil {
			continue
		}

		source := gjson.ParseBytes(sourceBytes)

		// Check various paths where request body might be stored
		bodyPaths := []string{
			"http.request.body.original",
			"http.request.body",
			"transaction.context.request.body",
			"context.request.body",
			"request_body",
		}

		var bodyContent string
		for _, path := range bodyPaths {
			if body := source.Get(path); body.Exists() {
				hasBody = true
				bodyContent = body.String()
				bodyDetails["body_path"] = path
				break
			}
		}

		if hasBody {
			bodyDetails["body_size"] = len(bodyContent)
			bodyDetails["body_preview"] = bodyContent
			if len(bodyContent) > 200 {
				bodyDetails["body_preview"] = bodyContent[:200] + "..."
			}

			// Try to detect body type
			if bodyContent != "" {
				if bodyContent[0] == '{' || bodyContent[0] == '[' {
					bodyDetails["body_type"] = "JSON"
				} else if len(bodyContent) > 0 && bodyContent[0] == '<' {
					bodyDetails["body_type"] = "XML"
				} else {
					bodyDetails["body_type"] = "TEXT"
				}
			}
		}

		if hasBody {
			result["with_body"] = result["with_body"].(int) + 1
		} else {
			result["missing_body"] = result["missing_body"].(int) + 1
		}

		result["body_details"] = append(result["body_details"].([]map[string]interface{}), bodyDetails)
	}

	// Calculate body coverage percentage
	total := result["total_documents"].(int)
	withBody := result["with_body"].(int)
	result["body_coverage_percentage"] = float64(withBody) / float64(total) * 100

	return result, nil
}

// ValidateTransactionMetadata validates transaction metadata completeness
func (v *APMValidator) ValidateTransactionMetadata(docs []elastic.APMDocument) (map[string]interface{}, error) {
	result := map[string]interface{}{
		"total_documents":     len(docs),
		"complete_metadata":   0,
		"incomplete_metadata": 0,
		"metadata_details":    []map[string]interface{}{},
	}

	requiredFields := []string{
		"transaction.id",
		"transaction.name",
		"transaction.type",
		"transaction.duration.us",
		"service.name",
		"service.version",
		"@timestamp",
	}

	for _, doc := range docs {
		sourceBytes, err := json.Marshal(doc.Source)
		if err != nil {
			continue
		}

		source := gjson.ParseBytes(sourceBytes)

		metadataDetails := map[string]interface{}{
			"document_id":    doc.ID,
			"timestamp":      doc.Timestamp,
			"service":        doc.ServiceName,
			"missing_fields": []string{},
			"present_fields": []string{},
		}

		missingCount := 0
		for _, field := range requiredFields {
			if !source.Get(field).Exists() {
				metadataDetails["missing_fields"] = append(metadataDetails["missing_fields"].([]string), field)
				missingCount++
			} else {
				metadataDetails["present_fields"] = append(metadataDetails["present_fields"].([]string), field)
			}
		}

		metadataDetails["completeness_percentage"] = float64(len(requiredFields)-missingCount) / float64(len(requiredFields)) * 100

		if missingCount == 0 {
			result["complete_metadata"] = result["complete_metadata"].(int) + 1
		} else {
			result["incomplete_metadata"] = result["incomplete_metadata"].(int) + 1
		}

		result["metadata_details"] = append(result["metadata_details"].([]map[string]interface{}), metadataDetails)
	}

	return result, nil
}

// ValidateErrorCapture validates error capture in transactions
func (v *APMValidator) ValidateErrorCapture(docs []elastic.APMDocument) (map[string]interface{}, error) {
	result := map[string]interface{}{
		"total_documents": len(docs),
		"with_errors":     0,
		"error_details":   []map[string]interface{}{},
	}

	for _, doc := range docs {
		sourceBytes, err := json.Marshal(doc.Source)
		if err != nil {
			continue
		}

		source := gjson.ParseBytes(sourceBytes)

		// Check for error indicators
		hasError := false
		errorDetails := map[string]interface{}{
			"document_id": doc.ID,
			"timestamp":   doc.Timestamp,
			"service":     doc.ServiceName,
		}

		// Check transaction result
		if result := source.Get("transaction.result"); result.Exists() {
			resultValue := result.String()
			errorDetails["transaction_result"] = resultValue
			if resultValue == "error" || resultValue == "failure" {
				hasError = true
			}
		}

		// Check HTTP status code
		if statusCode := source.Get("http.response.status_code"); statusCode.Exists() {
			code := statusCode.Int()
			errorDetails["http_status"] = code
			if code >= 400 {
				hasError = true
			}
		}

		// Check for exception details
		if exception := source.Get("error.exception"); exception.Exists() {
			hasError = true
			errorDetails["exception"] = exception.Value()
		}

		if hasError {
			result["with_errors"] = result["with_errors"].(int) + 1
			result["error_details"] = append(result["error_details"].([]map[string]interface{}), errorDetails)
		}
	}

	return result, nil
}
