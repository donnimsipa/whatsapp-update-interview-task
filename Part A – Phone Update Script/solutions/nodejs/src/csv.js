const fs = require('fs/promises');

class CsvParsingError extends Error {}

function parseCSVLine(line) {
  const result = [];
  let current = '';
  let inQuotes = false;
  let i = 0;
  
  while (i < line.length) {
    const char = line[i];
    
    if (char === '"') {
      if (inQuotes && line[i + 1] === '"') {
        // Escaped quote
        current += '"';
        i += 2;
      } else {
        // Toggle quote state
        inQuotes = !inQuotes;
        i++;
      }
    } else if (char === ',' && !inQuotes) {
      // Field separator
      result.push(current.trim());
      current = '';
      i++;
    } else {
      current += char;
      i++;
    }
  }
  
  // Add the last field
  result.push(current.trim());
  return result;
}

async function parseCsv(path) {
  let raw;
  try {
    raw = await fs.readFile(path, 'utf8');
  } catch (error) {
    if (error.code === 'ENOENT') {
      throw new CsvParsingError(`CSV file not found: ${path}`);
    }
    throw new CsvParsingError(`Failed to read CSV file: ${error.message}`);
  }

  const lines = raw.split(/\r?\n/).filter((line) => line.trim() !== '');
  if (lines.length === 0) {
    throw new CsvParsingError('CSV file is empty');
  }

  const headers = parseCSVLine(lines[0]).map((h) => h.trim());
  
  // Validate required columns
  const requiredColumns = ['last_updated_date', 'nik_identifier', 'phone_number'];
  const missingColumns = requiredColumns.filter(col => !headers.includes(col));
  if (missingColumns.length > 0) {
    throw new CsvParsingError(`Missing required CSV columns: ${missingColumns.join(', ')}`);
  }

  const records = [];
  for (let i = 1; i < lines.length; i++) {
    try {
      const values = parseCSVLine(lines[i]);
      const record = {};
      headers.forEach((header, idx) => {
        record[header] = (values[idx] || '').trim();
      });
      records.push(record);
    } catch (error) {
      throw new CsvParsingError(`Error parsing CSV line ${i + 1}: ${error.message}`);
    }
  }

  return records;
}

module.exports = { parseCsv, CsvParsingError };
