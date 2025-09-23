package validators

import (
	"encoding/json"

	"elastic-validate/internal/elastic"

	"github.com/tidwall/gjson"
)

// TraceValidator handles validation of distributed tracing data
type TraceValidator struct {
	client *elastic.Client
	debug  bool
}

// NewTraceValidator creates a new trace validator
func NewTraceValidator(client *elastic.Client, debug bool) *TraceValidator {
	return &TraceValidator{
		client: client,
		debug:  debug,
	}
}

// ValidateTraceContinuity validates that traces are properly connected across services
func (v *TraceValidator) ValidateTraceContinuity(docs []elastic.APMDocument) (map[string]interface{}, error) {
	result := map[string]interface{}{
		"total_documents": len(docs),
		"unique_traces":   0,
		"trace_spans":     map[string][]string{},
		"missing_parents": []string{},
		"orphaned_spans":  []string{},
		"trace_details":   []map[string]interface{}{},
	}

	traceMap := make(map[string][]map[string]interface{})

	for _, doc := range docs {
		sourceBytes, err := json.Marshal(doc.Source)
		if err != nil {
			continue
		}

		source := gjson.ParseBytes(sourceBytes)

		traceDetails := map[string]interface{}{
			"document_id": doc.ID,
			"timestamp":   doc.Timestamp,
			"service":     doc.ServiceName,
		}

		// Extract trace ID
		var traceID string
		if tid := source.Get("trace.id"); tid.Exists() {
			traceID = tid.String()
			traceDetails["trace_id"] = traceID
		}

		// Extract span ID
		if spanID := source.Get("span.id"); spanID.Exists() {
			traceDetails["span_id"] = spanID.String()
		}

		// Extract parent ID
		if parentID := source.Get("parent.id"); parentID.Exists() {
			traceDetails["parent_id"] = parentID.String()
		}

		// Extract transaction ID
		if transactionID := source.Get("transaction.id"); transactionID.Exists() {
			traceDetails["transaction_id"] = transactionID.String()
		}

		if traceID != "" {
			if _, exists := traceMap[traceID]; !exists {
				traceMap[traceID] = []map[string]interface{}{}
				result["unique_traces"] = result["unique_traces"].(int) + 1
			}
			traceMap[traceID] = append(traceMap[traceID], traceDetails)
		}

		result["trace_details"] = append(result["trace_details"].([]map[string]interface{}), traceDetails)
	}

	// Analyze trace continuity
	for traceID, spans := range traceMap {
		result["trace_spans"].(map[string][]string)[traceID] = []string{}

		for _, span := range spans {
			if spanID, ok := span["span_id"].(string); ok {
				spanList := result["trace_spans"].(map[string][]string)[traceID]
				spanList = append(spanList, spanID)
				result["trace_spans"].(map[string][]string)[traceID] = spanList
			}
		}
	}

	return result, nil
}

// ValidateSpanRelationships validates parent-child relationships between spans
func (v *TraceValidator) ValidateSpanRelationships(docs []elastic.APMDocument) (map[string]interface{}, error) {
	result := map[string]interface{}{
		"total_spans":        len(docs),
		"root_spans":         0,
		"child_spans":        0,
		"orphaned_spans":     0,
		"relationship_chain": []map[string]interface{}{},
	}

	spanMap := make(map[string]map[string]interface{})
	parentChildMap := make(map[string][]string)

	for _, doc := range docs {
		sourceBytes, err := json.Marshal(doc.Source)
		if err != nil {
			continue
		}

		source := gjson.ParseBytes(sourceBytes)

		var spanID, parentID string

		if sid := source.Get("span.id"); sid.Exists() {
			spanID = sid.String()
		}

		if pid := source.Get("parent.id"); pid.Exists() {
			parentID = pid.String()
		}

		if spanID != "" {
			spanMap[spanID] = map[string]interface{}{
				"document_id": doc.ID,
				"service":     doc.ServiceName,
				"parent_id":   parentID,
			}

			if parentID != "" {
				if _, exists := parentChildMap[parentID]; !exists {
					parentChildMap[parentID] = []string{}
				}
				parentChildMap[parentID] = append(parentChildMap[parentID], spanID)
				result["child_spans"] = result["child_spans"].(int) + 1
			} else {
				result["root_spans"] = result["root_spans"].(int) + 1
			}
		}
	}

	// Check for orphaned spans
	for _, spanData := range spanMap {
		if parentID, ok := spanData["parent_id"].(string); ok && parentID != "" {
			if _, exists := spanMap[parentID]; !exists {
				result["orphaned_spans"] = result["orphaned_spans"].(int) + 1
			}
		}
	}

	return result, nil
}
