# WhatsApp Patient Phone Sync - Node.js Implementation

This directory contains the Node.js implementation of the WhatsApp Patient Phone Sync system. This solution provides excellent performance for large datasets and leverages the rich JavaScript ecosystem for rapid development and integration.

## 🚀 Quick Start

### Prerequisites
- Node.js 14.0.0 or later
- No external dependencies (uses built-in Node.js modules only)

### Install Dependencies
```bash
cd solutions/nodejs
npm install  # No dependencies to install, but validates package.json
```

### Run
```bash
# From the Part A root (preferred)
../process-offline.sh --runtime node

# Direct invocation
node src/index.js \
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
node src/index.js \
  --csv "../../docs/interview/Whatsapp Data - Sheet.csv" \
  --input-json "../../docs/interview/patients-data.json" \
  --output-json "../../outputs/$(date -u +%Y%m%dT%H%M%SZ)-patients-data-nodejs.json" \
  --last-updated-date "23-09-2025"
```

## 🏗️ Architecture

### Core Components
- **CSV Processing**: Custom CSV parser with quote handling
- **Phone Normalization**: Regex-based normalization with validation
- **FHIR Updates**: Deep cloning and telecom entry management
- **Metadata Handling**: Automatic version increment and Jakarta timestamp formatting

### Key Features
1. **Modular Design**: Separate utilities for CSV parsing, phone normalization, and patient updates
2. **Asynchronous Operations**: Promise-based file I/O for non-blocking performance
3. **Error Classes**: Custom error types for better error identification
4. **Comprehensive Validation**: Input validation and graceful error handling

### Dependencies
- **None**: Pure Node.js built-in modules
- **Node.js Version**: >=14.0.0 (specified in `package.json`)

## 📊 Performance Characteristics

### Benchmarks (latest runs)
- **Small datasets (≤1K rows)**: Competitive; expect ~10–15 ms on a modern laptop.
- **Large datasets (≥5K rows)**: Sustained throughput during stress/invalid/mixed scenarios (see `outputs/performance/`).
- **Extreme datasets (1 M rows)**: Runs to completion when the Python generator seeds fixtures (no Node OOM).

### Recommended Use Cases
- ✅ Large batch processing
- ✅ High-throughput scenarios
- ✅ Development with rich ecosystem
- ✅ Rapid prototyping and iteration

## 🔧 Development

### Available Scripts
```bash
npm run start      # Run the application with default flags
npm run validate   # Static syntax check of source files
```

### Code Structure
```
solutions/nodejs/
├── src/
│   ├── index.js           # CLI entry point
│   ├── updatePatients.js  # Core transformation logic
│   ├── normalizePhone.js  # Phone normalization
│   └── csv.js             # CSV parsing utilities
├── package.json           # Package configuration
└── README.md              # This file
```

## 🧪 Testing

Use the Part A orchestration scripts (`test/run-all.sh` or targeted validation/performance helpers) to verify behaviour end-to-end.

## 🐛 Error Handling

The implementation includes robust error handling for:
- Missing or invalid input files
- Malformed CSV data
- Invalid phone number formats
- JSON parsing errors
- File system operations

Errors are logged to stderr with stack traces in development mode, and the application exits with code 1 on failure.

Example (missing output path):

```bash
$ node src/index.js \
    --csv "../../docs/interview/Whatsapp Data - Sheet.csv" \
    --input-json "../../docs/interview/patients-data.json"
[error] Missing required option: --output-json
usage: node src/index.js --csv <path> --input-json <path> --output-json <path> [options]
```

Example (invalid phone number encountered during processing):

```bash
$ node src/index.js --csv bad.csv --input-json patients.json --output-json result.json
[warn] Skipping NIK 9000000000000003: unexpected prefix in number 'abcde12345'
[info] Processed 10 CSV rows, 6 skipped, 4 valid phone updates
```

## 📝 Assumptions and Limitations

- CSV file must contain required columns: `nik_identifier`, `phone_number`, `last_updated_date`
- Phone numbers are normalized to Indonesian local format (0-prefixed)
- FHIR bundle structure follows the expected schema
- Date format in CSV is DD-MM-YYYY
- Output directory must be writable
- Node.js async operations may have higher memory usage for very large files

## 🔮 Future Enhancements

- Streaming CSV processing for memory efficiency
- Worker threads for parallel processing
- HTTP server wrapper for API integration
- Configuration file support
- Advanced logging and monitoring

---

*Node.js implementation optimized for large-scale processing - Updated September 25, 2025*
