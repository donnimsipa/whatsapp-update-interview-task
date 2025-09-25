// WhatsApp Patient Phone Sync - Optimized Go Implementation
// Uses pure encoding/json with optimized patterns for best performance
package main

import (
	"bytes"
	"encoding/csv"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"
)

const fhirNikSystem = "https://fhir.kemkes.go.id/id/nik"

// Pre-compiled regex patterns for better performance
var (
	phoneCleanRegex = regexp.MustCompile(`[\s\-\(\)\.\+]`)
	digitOnlyRegex  = regexp.MustCompile(`\D`)
	dateFormatRegex = regexp.MustCompile(`^(\d{2})-(\d{2})-(\d{4})$`)
	versionRegex    = regexp.MustCompile(`^v(\d+)$`)
)

// Object pools for memory efficiency
var (
	stringBuilderPool = sync.Pool{
		New: func() interface{} {
			return &strings.Builder{}
		},
	}
	mapPool = sync.Pool{
		New: func() interface{} {
			return make(map[string]interface{})
		},
	}
)

type phoneUpdate struct {
	nik        string
	normalized string
	sourceRow  map[string]string
}

type summary struct {
	CsvRowsProcessed    int      `json:"csv_rows_processed"`
	PatientsTotal       int      `json:"patients_total"`
	PatientsWithUpdates int      `json:"patients_with_updates"`
	ExecutionTimeMs     int64    `json:"execution_time_ms,omitempty"`
	Errors              []string `json:"errors,omitempty"`
}

// Optimized patient structure for better performance
type PatientResource struct {
	ResourceType string                   `json:"resourceType"`
	ID           string                   `json:"id,omitempty"`
	Meta         map[string]interface{}   `json:"meta,omitempty"`
	Identifier   []map[string]interface{} `json:"identifier,omitempty"`
	Telecom      []map[string]interface{} `json:"telecom,omitempty"`
	// Keep other fields as interface{} for flexibility
	Other map[string]interface{} `json:"-"`
}

type PatientEntry struct {
	Resource PatientResource `json:"resource"`
}

func main() {
	csvPath := flag.String("csv", "", "Path to WhatsApp data CSV export")
	inputJSON := flag.String("input-json", "", "Path to patients-data.json containing patients_before_phone_update")
	outputJSON := flag.String("output-json", "", "Destination file for transformed bundle")
	lastUpdatedDate := flag.String("last-updated-date", "", "Optional filter for CSV rows (DD-MM-YYYY)")
	help := flag.Bool("help", false, "Show help message")
	flag.BoolVar(help, "h", false, "Show help message")

	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "WhatsApp Patient Phone Sync Tool\n")
		fmt.Fprintf(os.Stderr, "Usage: %s --csv <path> --input-json <path> --output-json <path> [--last-updated-date DD-MM-YYYY]\n\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "Arguments:\n")
		fmt.Fprintf(os.Stderr, "  --csv <path>              Path to CSV file with WhatsApp phone updates\n")
		fmt.Fprintf(os.Stderr, "  --input-json <path>       Path to input FHIR bundle JSON file\n")
		fmt.Fprintf(os.Stderr, "  --output-json <path>      Path for output FHIR bundle JSON file\n")
		fmt.Fprintf(os.Stderr, "  --last-updated-date <date> Optional date filter (DD-MM-YYYY format)\n")
		fmt.Fprintf(os.Stderr, "  --help, -h                Show this help message\n\n")
		fmt.Fprintf(os.Stderr, "Examples:\n")
		fmt.Fprintf(os.Stderr, "  %s --csv data.csv --input-json patients.json --output-json updated.json\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "  %s --csv data.csv --input-json patients.json --output-json updated.json --last-updated-date 23-09-2025\n", os.Args[0])
	}

	flag.Parse()

	if *help {
		flag.Usage()
		os.Exit(0)
	}

	if len(os.Args) == 1 {
		fmt.Fprintf(os.Stderr, "Error: No arguments provided\n\n")
		flag.Usage()
		os.Exit(1)
	}

	if *csvPath == "" || *inputJSON == "" || *outputJSON == "" {
		missing := []string{}
		if *csvPath == "" {
			missing = append(missing, "csv")
		}
		if *inputJSON == "" {
			missing = append(missing, "input-json")
		}
		if *outputJSON == "" {
			missing = append(missing, "output-json")
		}
		fmt.Fprintf(os.Stderr, "Error: Missing required arguments: %s\n\n", strings.Join(missing, ", "))
		flag.Usage()
		os.Exit(1)
	}

	// Validate date format if provided
	if *lastUpdatedDate != "" && !validateDateFormat(*lastUpdatedDate) {
		fmt.Fprintf(os.Stderr, "Error: Invalid date format for --last-updated-date. Expected DD-MM-YYYY, got: %s\n\n", *lastUpdatedDate)
		flag.Usage()
		os.Exit(1)
	}

	startTime := time.Now()

	updates, processedRows, err := loadWhatsAppUpdates(*csvPath, *lastUpdatedDate)
	if err != nil {
		exitWithError(err)
	}

	bundle, err := loadBundle(*inputJSON)
	if err != nil {
		exitWithError(err)
	}

	transformed, updatedCount, processingErrors, err := applyUpdates(bundle, updates)
	if err != nil {
		exitWithError(err)
	}

	bundle["patients_after_phone_update"] = transformed

	if err := writeBundle(bundle, *outputJSON); err != nil {
		exitWithError(err)
	}

	endTime := time.Now()
	executionTime := endTime.Sub(startTime).Milliseconds()

	result := summary{
		CsvRowsProcessed:    processedRows,
		PatientsTotal:       len(transformed),
		PatientsWithUpdates: updatedCount,
		ExecutionTimeMs:     executionTime,
	}

	if len(processingErrors) > 0 {
		result.Errors = processingErrors
	}

	payload, _ := json.Marshal(result)
	fmt.Println(string(payload))
}

func exitWithError(err error) {
	fmt.Fprintf(os.Stderr, "[whatsapp-sync] Failed: %v\n", err)
	os.Exit(1)
}

func validateDateFormat(dateStr string) bool {
	if dateStr == "" {
		return false
	}
	re := regexp.MustCompile(`^(\d{2})-(\d{2})-(\d{4})$`)
	matches := re.FindStringSubmatch(dateStr)
	if matches == nil {
		return false
	}

	day, _ := strconv.Atoi(matches[1])
	month, _ := strconv.Atoi(matches[2])
	year, _ := strconv.Atoi(matches[3])

	return day >= 1 && day <= 31 &&
		month >= 1 && month <= 12 &&
		year >= 1900 && year <= 2100
}

func loadWhatsAppUpdates(csvPath, lastUpdated string) (map[string]phoneUpdate, int, error) {
	file, err := os.Open(csvPath)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, 0, fmt.Errorf("CSV file does not exist: %s", csvPath)
		}
		return nil, 0, fmt.Errorf("failed to read CSV file: %v", err)
	}
	defer file.Close()

	reader := csv.NewReader(file)
	reader.TrimLeadingSpace = true
	reader.ReuseRecord = true // Optimize memory usage

	header, err := reader.Read()
	if err != nil {
		if errors.Is(err, io.EOF) {
			return nil, 0, fmt.Errorf("CSV file is empty")
		}
		return nil, 0, fmt.Errorf("error reading CSV header: %v", err)
	}

	// Pre-calculate column indices
	nikIdx, phoneIdx, dateIdx := -1, -1, -1
	for idx, col := range header {
		switch strings.TrimSpace(col) {
		case "nik_identifier":
			nikIdx = idx
		case "phone_number":
			phoneIdx = idx
		case "last_updated_date":
			dateIdx = idx
		}
	}

	if nikIdx == -1 || phoneIdx == -1 || dateIdx == -1 {
		missing := []string{}
		if nikIdx == -1 {
			missing = append(missing, "nik_identifier")
		}
		if phoneIdx == -1 {
			missing = append(missing, "phone_number")
		}
		if dateIdx == -1 {
			missing = append(missing, "last_updated_date")
		}
		return nil, 0, fmt.Errorf("missing required CSV columns: %s", strings.Join(missing, ", "))
	}

	updates := make(map[string]phoneUpdate, 1000) // Pre-allocate with reasonable capacity
	processedRows := 0
	skippedRows := 0
	lineNum := 1

	for {
		record, err := reader.Read()
		if err != nil {
			if errors.Is(err, io.EOF) {
				break
			}
			return nil, 0, fmt.Errorf("error parsing CSV line %d: %v", lineNum+1, err)
		}
		lineNum++
		processedRows++

		// Direct index access for better performance
		nik := strings.TrimSpace(record[nikIdx])
		rawPhone := strings.TrimSpace(record[phoneIdx])
		rowDate := strings.TrimSpace(record[dateIdx])

		// Skip rows with missing required fields
		if nik == "" || rawPhone == "" {
			skippedRows++
			continue
		}

		// Apply date filter if specified (optimized)
		if lastUpdated != "" && rowDate != lastUpdated {
			skippedRows++
			continue
		}

		// Validate row date format (only if needed)
		if rowDate != "" && !validateDateFormatOptimized(rowDate) {
			fmt.Fprintf(os.Stderr, "Row %d: Invalid date format '%s' for NIK %s, skipping\n", lineNum, rowDate, nik)
			skippedRows++
			continue
		}

		normalized, err := normalizePhoneNumberOptimized(rawPhone)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Skipping NIK %s: %v\n", nik, err)
			skippedRows++
			continue
		}

		// Create minimal row data
		row := map[string]string{
			"nik_identifier":    nik,
			"phone_number":      rawPhone,
			"last_updated_date": rowDate,
		}

		updates[nik] = phoneUpdate{nik: nik, normalized: normalized, sourceRow: row}
	}

	fmt.Fprintf(os.Stderr, "Processed %d CSV rows, %d skipped, %d valid phone updates\n", processedRows, skippedRows, len(updates))
	return updates, len(updates), nil
}

func loadBundle(path string) (map[string]interface{}, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, fmt.Errorf("input JSON file does not exist: %s", path)
		}
		return nil, fmt.Errorf("failed to read input JSON file: %v", err)
	}

	var bundle map[string]interface{}

	// Use optimized JSON processing
	if err := json.Unmarshal(raw, &bundle); err != nil {
		return nil, fmt.Errorf("invalid JSON in input file: %v", err)
	}

	// Validate bundle structure
	if bundle == nil {
		return nil, fmt.Errorf("input JSON must be an object")
	}

	if _, ok := bundle["patients_before_phone_update"]; !ok {
		return nil, fmt.Errorf("input JSON must contain patients_before_phone_update array")
	}

	if _, ok := bundle["patients_before_phone_update"].([]interface{}); !ok {
		return nil, fmt.Errorf("input JSON must contain patients_before_phone_update array")
	}

	return bundle, nil
}

func applyUpdates(bundle map[string]interface{}, updates map[string]phoneUpdate) ([]interface{}, int, []string, error) {
	rawPatients, ok := bundle["patients_before_phone_update"].([]interface{})
	if !ok {
		return nil, 0, nil, fmt.Errorf("patients_before_phone_update missing or invalid")
	}

	transformed := make([]interface{}, 0, len(rawPatients))
	updated := make(map[string]struct{}, len(updates))
	var processingErrors []string

	fmt.Fprintf(os.Stderr, "Applying %d phone updates to %d patients\n", len(updates), len(rawPatients))

	for i, entry := range rawPatients {
		cloned, err := cloneEntryOptimized(entry)
		if err != nil {
			errorMsg := fmt.Sprintf("Error processing patient entry %d: %v", i+1, err)
			fmt.Fprintf(os.Stderr, "%s\n", errorMsg)
			processingErrors = append(processingErrors, errorMsg)
			transformed = append(transformed, entry) // Return original entry on error
			continue
		}

		resource, _ := cloned["resource"].(map[string]interface{})
		if resource != nil {
			// Validate patient resource structure
			if resourceType, ok := resource["resourceType"].(string); !ok || resourceType != "Patient" {
				transformed = append(transformed, cloned)
				continue
			}

			nik := extractNikOptimized(resource)
			if nik != "" {
				if update, ok := updates[nik]; ok {
					applyTelecomOptimized(resource, update.normalized)
					applyMetaOptimized(resource, update.sourceRow["last_updated_date"])
					updated[nik] = struct{}{}
				}
			}
		}
		transformed = append(transformed, cloned)
	}

	return transformed, len(updated), processingErrors, nil
}

// Optimized cloning using standard JSON with better performance
func cloneEntryOptimized(entry interface{}) (map[string]interface{}, error) {
	// Use optimized JSON processing
	bytes, err := json.Marshal(entry)
	if err != nil {
		return nil, err
	}

	var clone map[string]interface{}
	if err := json.Unmarshal(bytes, &clone); err != nil {
		return nil, err
	}
	return clone, nil
}

// Optimized NIK extraction with early returns
func extractNikOptimized(resource map[string]interface{}) string {
	identifiers, ok := resource["identifier"].([]interface{})
	if !ok || len(identifiers) == 0 {
		return ""
	}

	for _, item := range identifiers {
		asMap, ok := item.(map[string]interface{})
		if !ok {
			continue
		}

		system, ok := asMap["system"].(string)
		if !ok || system != fhirNikSystem {
			continue
		}

		if value, ok := asMap["value"].(string); ok {
			return value
		}
	}
	return ""
}

// Optimized telecom handling with pre-allocated slices
func applyTelecomOptimized(resource map[string]interface{}, phone string) {
	existing, ok := resource["telecom"].([]interface{})
	if !ok {
		existing = []interface{}{}
	}

	// Pre-allocate with capacity for existing + 1 new entry
	telecom := make([]interface{}, 0, len(existing)+1)

	// Add new mobile phone entry first
	teleEntry := map[string]interface{}{
		"system": "phone",
		"use":    "mobile",
		"value":  phone,
	}
	telecom = append(telecom, teleEntry)

	// Filter and preserve existing non-mobile phone entries
	for _, item := range existing {
		asMap, ok := item.(map[string]interface{})
		if !ok {
			telecom = append(telecom, item)
			continue
		}

		system, systemOk := asMap["system"].(string)
		use, useOk := asMap["use"].(string)

		// Skip existing mobile phone entries
		if systemOk && useOk && system == "phone" && use == "mobile" {
			continue
		}

		telecom = append(telecom, asMap)
	}

	resource["telecom"] = telecom
}

// Optimized metadata handling with minimal allocations
func applyMetaOptimized(resource map[string]interface{}, rawDate string) {
	var meta map[string]interface{}

	if existing, ok := resource["meta"].(map[string]interface{}); ok {
		// Reuse existing map if possible
		meta = existing
	} else {
		meta = make(map[string]interface{}, 2) // Pre-allocate for lastUpdated and versionId
	}

	meta["lastUpdated"] = formatJakartaTimestampOptimized(rawDate)

	currentVersion := ""
	if value, ok := meta["versionId"].(string); ok {
		currentVersion = value
	}
	meta["versionId"] = incrementVersionOptimized(currentVersion)

	resource["meta"] = meta
}

// Optimized timestamp formatting with pre-compiled regex and string builder
func formatJakartaTimestampOptimized(dateRaw string) string {
	if dateRaw != "" {
		matches := dateFormatRegex.FindStringSubmatch(dateRaw)
		if matches != nil {
			// Use string builder for efficient concatenation
			sb := stringBuilderPool.Get().(*strings.Builder)
			defer func() {
				sb.Reset()
				stringBuilderPool.Put(sb)
			}()

			// Format: YYYY-MM-DDTHH:MM:SS+07:00
			sb.WriteString(matches[3]) // year
			sb.WriteByte('-')
			sb.WriteString(matches[2]) // month
			sb.WriteByte('-')
			sb.WriteString(matches[1]) // day
			sb.WriteString("T23:00:00+07:00")

			return sb.String()
		}
	}
	return time.Now().Format(time.RFC3339)
}

// Optimized version increment with pre-compiled regex and string builder
func incrementVersionOptimized(current string) string {
	if current == "" {
		return "v1"
	}

	matches := versionRegex.FindStringSubmatch(current)
	if matches != nil {
		width := len(matches[1])
		value, err := strconv.Atoi(matches[1])
		if err == nil {
			next := value + 1

			sb := stringBuilderPool.Get().(*strings.Builder)
			defer func() {
				sb.Reset()
				stringBuilderPool.Put(sb)
			}()

			sb.WriteByte('v')
			if width > 1 {
				// Pad with zeros if needed
				numStr := strconv.Itoa(next)
				for i := len(numStr); i < width; i++ {
					sb.WriteByte('0')
				}
				sb.WriteString(numStr)
			} else {
				sb.WriteString(strconv.Itoa(next))
			}

			return sb.String()
		}
	}

	return current + "-updated"
}

// Optimized phone normalization with pre-compiled regex and efficient string operations
func normalizePhoneNumberOptimized(raw string) (string, error) {
	if raw == "" {
		return "", fmt.Errorf("empty phone number")
	}

	// Strip all formatting characters using pre-compiled regex
	cleaned := phoneCleanRegex.ReplaceAllString(raw, "")
	if cleaned == "" {
		return "", fmt.Errorf("empty phone number")
	}

	// Extract only digits using pre-compiled regex
	digits := digitOnlyRegex.ReplaceAllString(cleaned, "")
	if digits == "" {
		return "", fmt.Errorf("no digits found in phone number")
	}

	var normalized string

	// Handle different prefix formats with optimized string operations
	if len(digits) >= 2 && digits[0] == '6' && digits[1] == '2' {
		// +62 or 62 prefix - Indonesian country code
		if len(digits) <= 2 {
			return "", fmt.Errorf("country code without subscriber number")
		}
		localPart := digits[2:]
		if localPart[0] == '0' {
			normalized = localPart
		} else {
			// Use string builder for efficient concatenation
			sb := stringBuilderPool.Get().(*strings.Builder)
			defer func() {
				sb.Reset()
				stringBuilderPool.Put(sb)
			}()
			sb.WriteByte('0')
			sb.WriteString(localPart)
			normalized = sb.String()
		}
	} else if digits[0] == '0' {
		// Already in local format with leading 0
		normalized = digits
	} else if digits[0] == '8' {
		// Local format without leading 0 - add it
		sb := stringBuilderPool.Get().(*strings.Builder)
		defer func() {
			sb.Reset()
			stringBuilderPool.Put(sb)
		}()
		sb.WriteByte('0')
		sb.WriteString(digits)
		normalized = sb.String()
	} else {
		return "", fmt.Errorf("unexpected prefix in number '%s'", raw)
	}

	// Validate length
	if len(normalized) < 9 {
		return "", fmt.Errorf("number too short after normalisation '%s' -> '%s'", raw, normalized)
	}
	if len(normalized) > 15 {
		return "", fmt.Errorf("number too long after normalisation '%s' -> '%s'", raw, normalized)
	}

	return normalized, nil
}

// Optimized date format validation with pre-compiled regex
func validateDateFormatOptimized(dateStr string) bool {
	if len(dateStr) != 10 {
		return false
	}

	matches := dateFormatRegex.FindStringSubmatch(dateStr)
	if matches == nil {
		return false
	}

	day, _ := strconv.Atoi(matches[1])
	month, _ := strconv.Atoi(matches[2])
	year, _ := strconv.Atoi(matches[3])

	return day >= 1 && day <= 31 &&
		month >= 1 && month <= 12 &&
		year >= 1900 && year <= 2100
}

func writeBundle(bundle map[string]interface{}, outputPath string) error {
	// Use optimized JSON marshaling
	data, err := json.Marshal(bundle)
	if err != nil {
		return fmt.Errorf("failed to marshal JSON: %v", err)
	}

	// Format JSON manually for readability using standard library
	var formatted bytes.Buffer
	if err := json.Indent(&formatted, data, "", "  "); err != nil {
		// Fallback to unformatted if indent fails
		// data remains unchanged
	} else {
		data = formatted.Bytes()
	}

	resolved := outputPath
	if !filepath.IsAbs(resolved) {
		resolved = filepath.Clean(resolved)
	}

	if err := os.MkdirAll(filepath.Dir(resolved), 0o755); err != nil {
		return fmt.Errorf("cannot create output directory: %v", err)
	}

	data = append(data, '\n')
	if err := os.WriteFile(resolved, data, 0o644); err != nil {
		return fmt.Errorf("failed to write output file: %v", err)
	}

	absPath, _ := filepath.Abs(resolved)
	fmt.Fprintf(os.Stderr, "Output written to: %s\n", absPath)
	return nil
}
