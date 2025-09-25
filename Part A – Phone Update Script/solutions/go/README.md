# WhatsApp Patient Phone Sync - Go Implementation

This directory contains the optimized Go implementation of the WhatsApp Patient Phone Sync system. This solution provides high performance for small to medium datasets and serves as a production-ready alternative to the Node.js implementation.

## 🚀 Quick Start

### Prerequisites
- Go 1.25 or later available on your PATH

### Build
```bash
cd solutions/go
go build ./cmd/whatsapp-sync
```
# binary `whatsapp-sync` is created in the current directory

### Run
```bash
# From the Part A root (preferred)
./process-offline.sh             # defaults to Go

# Direct invocation after go build
./whatsapp-sync \
  --csv "../../docs/interview/Whatsapp Data - Sheet.csv" \
  --input-json "../../docs/interview/patients-data.json" \
  --output-json "../../outputs/$(date -u +%Y%m%dT%H%M%SZ)-patients-data.json"
```

## 📋 Usage

### Command Line Options
- `--csv <path>`: Path to CSV file with WhatsApp phone updates (required)
- `--input-json <path>`: Path to input FHIR bundle JSON file (required)
- `--output-json <path>`: Path for output FHIR bundle JSON file (required)
- `--last-updated-date <date>`: Optional date filter (DD-MM-YYYY format)
- `--help, -h`: Show help message

### Example
```bash
./whatsapp-sync \
  --csv "../../docs/interview/Whatsapp Data - Sheet.csv" \
  --input-json "../../docs/interview/patients-data.json" \
  --output-json "../../outputs/$(date -u +%Y%m%dT%H%M%SZ)-patients-data.json" \
  --last-updated-date "23-09-2025"
```

## 🏗️ Architecture

### Core Components
- **CSV Processing**: Efficient parsing with pre-calculated column indices
- **Phone Normalization**: Optimized regex-based normalization with object pooling
- **FHIR Updates**: Direct manipulation of patient telecom entries
- **Metadata Handling**: Automatic version increment and timestamp formatting

### Performance Optimizations
1. **Pre-compiled Regex Patterns**: Eliminates compilation overhead
2. **Object Pools**: `sync.Pool` for memory-efficient string builders and maps
3. **Direct Index Access**: Avoids map lookups for CSV columns
4. **Memory Pre-allocation**: Reduces reallocations in slices and maps
5. **Optimized String Operations**: StringBuilder with pooling for concatenation

### Dependencies
- **None**: Pure Go standard library implementation
- **Go Version**: 1.25 (specified in `go.mod`)

## 📊 Performance Characteristics

### Benchmarks (latest runs)
- **Small datasets (≤1K rows)**: Finishes in tens of milliseconds with negligible memory use.
- **Nominal workloads (≤5K rows)**: See `outputs/performance/go-time-*.log` for wall-clock timings.
- **Extreme datasets (≥500K rows)**: Completes when invoked via `performance-extreme.sh`; 1 M-row runs require several minutes but succeed with the Python generator feeding inputs.

### Recommended Use Cases
- ✅ Real-time processing
- ✅ Resource-constrained environments
- ✅ Small to medium batch sizes
- ✅ Microservices deployment

## 🔧 Development

### Build Commands
```bash
go build ./cmd/whatsapp-sync    # Build optimized binary
```

### Code Structure
```
solutions/go/
├── cmd/whatsapp-sync/
│   └── main.go          # Main application
├── go.mod               # Module definition
└── README.md            # This file
```

## 🐛 Error Handling

The implementation includes comprehensive error handling for:
- Missing or invalid input files
- Malformed CSV data
- Invalid phone number formats
- JSON parsing errors
- File I/O operations

Errors are reported to stderr with descriptive messages, and the application exits with code 1 on failure.

Example (missing input file):

```bash
$ ./whatsapp-sync --csv missing.csv --input-json patients.json --output-json out.json
2025/09/25 08:31:12 open missing.csv: no such file or directory
exit status 1
```

Example (invalid phone number during processing):

```bash
$ ./whatsapp-sync --csv invalid.csv --input-json patients.json --output-json out.json
2025/09/25 08:31:45 Skipping NIK 9000000000000003: unexpected prefix in number "abcde12345"
Processed 10 CSV rows, 6 skipped, 4 valid phone updates
```

## 📝 Assumptions and Limitations

- CSV file must contain required columns: `nik_identifier`, `phone_number`, `last_updated_date`
- Phone numbers are normalized to Indonesian local format (0-prefixed)
- FHIR bundle structure follows the expected schema
- Date format in CSV is DD-MM-YYYY
- Output directory must be writable

## 🔮 Future Enhancements

- Custom JSON parser for additional performance gains
- Streaming processing for unlimited dataset sizes
- Parallel processing with goroutines
- HTTP API wrapper for service integration

---

*Go implementation optimized for performance and reliability - September 25, 2025*
