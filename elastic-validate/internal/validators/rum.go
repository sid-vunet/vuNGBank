package validators

import (
	"encoding/json"

	"elastic-validate/internal/elastic"

	"github.com/tidwall/gjson"
)

// RUMValidator handles validation of RUM data
type RUMValidator struct {
	client *elastic.Client
	debug  bool
}

// NewRUMValidator creates a new RUM validator
func NewRUMValidator(client *elastic.Client, debug bool) *RUMValidator {
	return &RUMValidator{
		client: client,
		debug:  debug,
	}
}

// ValidatePageLoad validates page load metrics
func (v *RUMValidator) ValidatePageLoad(docs []elastic.APMDocument) (map[string]interface{}, error) {
	result := map[string]interface{}{
		"total_documents":   len(docs),
		"with_page_load":    0,
		"missing_page_load": 0,
		"page_load_details": []map[string]interface{}{},
	}

	for _, doc := range docs {
		sourceBytes, err := json.Marshal(doc.Source)
		if err != nil {
			continue
		}

		source := gjson.ParseBytes(sourceBytes)

		hasPageLoad := false
		pageLoadDetails := map[string]interface{}{
			"document_id": doc.ID,
			"timestamp":   doc.Timestamp,
			"service":     doc.ServiceName,
		}

		// Check for page load transaction
		if transactionType := source.Get("transaction.type"); transactionType.Exists() {
			if transactionType.String() == "page-load" {
				hasPageLoad = true
				pageLoadDetails["transaction_type"] = "page-load"
			}
		}

		// Check for navigation timing
		if timing := source.Get("transaction.marks.navigationTiming"); timing.Exists() {
			hasPageLoad = true
			pageLoadDetails["navigation_timing"] = timing.Value()
		}

		// Check for page load duration
		if duration := source.Get("transaction.duration.us"); duration.Exists() {
			pageLoadDetails["duration_us"] = duration.Int()
			pageLoadDetails["duration_ms"] = float64(duration.Int()) / 1000
		}

		if hasPageLoad {
			result["with_page_load"] = result["with_page_load"].(int) + 1
		} else {
			result["missing_page_load"] = result["missing_page_load"].(int) + 1
		}

		result["page_load_details"] = append(result["page_load_details"].([]map[string]interface{}), pageLoadDetails)
	}

	return result, nil
}

// ValidateUserInteractions validates user interaction capture
func (v *RUMValidator) ValidateUserInteractions(docs []elastic.APMDocument) (map[string]interface{}, error) {
	result := map[string]interface{}{
		"total_documents":     len(docs),
		"with_interactions":   0,
		"interaction_details": []map[string]interface{}{},
	}

	for _, doc := range docs {
		sourceBytes, err := json.Marshal(doc.Source)
		if err != nil {
			continue
		}

		source := gjson.ParseBytes(sourceBytes)

		hasInteraction := false
		interactionDetails := map[string]interface{}{
			"document_id": doc.ID,
			"timestamp":   doc.Timestamp,
			"service":     doc.ServiceName,
		}

		// Check for user interaction transaction
		if transactionType := source.Get("transaction.type"); transactionType.Exists() {
			txType := transactionType.String()
			if txType == "user-interaction" || txType == "click" || txType == "form-submit" {
				hasInteraction = true
				interactionDetails["interaction_type"] = txType
			}
		}

		// Check for transaction name indicating interaction
		if transactionName := source.Get("transaction.name"); transactionName.Exists() {
			name := transactionName.String()
			if name == "click" || name == "form-submit" || name == "button-click" {
				hasInteraction = true
				interactionDetails["interaction_name"] = name
			}
		}

		if hasInteraction {
			result["with_interactions"] = result["with_interactions"].(int) + 1
			result["interaction_details"] = append(result["interaction_details"].([]map[string]interface{}), interactionDetails)
		}
	}

	return result, nil
}
