const fs = require('fs/promises');
const path = require('path');
const { parseCsv, CsvParsingError } = require('./csv');
const { normalizePhoneNumber, PhoneNormalizationError } = require('./normalizePhone');

const FHIR_NIK_SYSTEM = 'https://fhir.kemkes.go.id/id/nik';

function validateDateFormat(dateStr) {
  if (!dateStr) return false;
  const match = dateStr.match(/^(\d{2})-(\d{2})-(\d{4})$/);
  if (!match) return false;
  
  const [, day, month, year] = match;
  const dayNum = parseInt(day, 10);
  const monthNum = parseInt(month, 10);
  const yearNum = parseInt(year, 10);
  
  return dayNum >= 1 && dayNum <= 31 && 
         monthNum >= 1 && monthNum <= 12 && 
         yearNum >= 1900 && yearNum <= 2100;
}

async function loadWhatsAppUpdates(csvPath, lastUpdatedDate) {
  let records;
  try {
    records = await parseCsv(csvPath);
  } catch (error) {
    if (error instanceof CsvParsingError) {
      throw new Error(`CSV parsing failed: ${error.message}`);
    }
    throw error;
  }

  // Validate lastUpdatedDate format if provided
  if (lastUpdatedDate && !validateDateFormat(lastUpdatedDate)) {
    throw new Error(`Invalid date format for --last-updated-date. Expected DD-MM-YYYY, got: ${lastUpdatedDate}`);
  }

  const updates = new Map();
  let processedRows = 0;
  let skippedRows = 0;

  records.forEach((row, index) => {
    const nik = (row.nik_identifier || '').trim();
    const phoneRaw = (row.phone_number || '').trim();
    const rowDate = (row.last_updated_date || '').trim();
    
    processedRows++;

    // Skip rows with missing required fields
    if (!nik) {
      console.warn(`Row ${index + 2}: Missing NIK identifier, skipping`);
      skippedRows++;
      return;
    }
    
    if (!phoneRaw) {
      console.warn(`Row ${index + 2}: Missing phone number for NIK ${nik}, skipping`);
      skippedRows++;
      return;
    }

    // Validate row date format
    if (rowDate && !validateDateFormat(rowDate)) {
      console.warn(`Row ${index + 2}: Invalid date format '${rowDate}' for NIK ${nik}, skipping`);
      skippedRows++;
      return;
    }

    // Apply date filter if specified
    if (lastUpdatedDate && rowDate !== lastUpdatedDate) {
      skippedRows++;
      return;
    }

    try {
      const normalized = normalizePhoneNumber(phoneRaw);
      updates.set(nik, {
        nik,
        normalizedPhone: normalized,
        sourceRow: row,
      });
    } catch (error) {
      if (error instanceof PhoneNormalizationError) {
        console.warn(`Skipping NIK ${nik}: ${error.message}`);
        skippedRows++;
        return;
      }
      throw error;
    }
  });

  console.log(`Processed ${processedRows} CSV rows, ${skippedRows} skipped, ${updates.size} valid phone updates`);
  return updates;
}

async function loadBundle(jsonPath) {
  let raw;
  try {
    raw = await fs.readFile(jsonPath, 'utf8');
  } catch (error) {
    if (error.code === 'ENOENT') {
      throw new Error(`Input JSON file not found: ${jsonPath}`);
    }
    throw new Error(`Failed to read input JSON file: ${error.message}`);
  }

  let bundle;
  try {
    bundle = JSON.parse(raw);
  } catch (error) {
    throw new Error(`Invalid JSON in input file: ${error.message}`);
  }

  // Validate bundle structure
  if (!bundle || typeof bundle !== 'object') {
    throw new Error('Input JSON must be an object');
  }

  if (!Array.isArray(bundle.patients_before_phone_update)) {
    throw new Error('Input JSON must contain patients_before_phone_update array');
  }

  return bundle;
}

function extractNik(patientResource) {
  const identifiers = Array.isArray(patientResource.identifier) ? patientResource.identifier : [];
  for (const identifier of identifiers) {
    if (identifier && identifier.system === FHIR_NIK_SYSTEM) {
      return identifier.value;
    }
  }
  return undefined;
}

function createTelecomEntry(phone) {
  return {
    system: 'phone',
    use: 'mobile',
    value: phone,
  };
}

function formatJakartaTimestamp(dateRaw) {
  if (typeof dateRaw === 'string') {
    const match = dateRaw.match(/^(\d{2})-(\d{2})-(\d{4})$/);
    if (match) {
      const [, day, month, year] = match;
      return `${year}-${month}-${day}T23:00:00+07:00`;
    }
  }
  return new Date().toISOString();
}

function incrementVersion(current) {
  if (typeof current === 'string') {
    const match = current.match(/^v(\d+)$/);
    if (match) {
      const width = match[1].length;
      const next = String(Number(match[1]) + 1).padStart(width, '0');
      return `v${next}`;
    }
    return `${current}-updated`;
  }
  return 'v1';
}

function applyUpdates(bundle, updates) {
  const patients = Array.isArray(bundle.patients_before_phone_update)
    ? bundle.patients_before_phone_update
    : [];
  
  const updatedNiks = new Set();
  const errors = [];
  
  const transformed = patients.map((entry, index) => {
    try {
      // Deep clone to avoid modifying original data
      const copy = JSON.parse(JSON.stringify(entry));
      const resource = copy.resource || {};
      
      // Validate patient resource structure
      if (!resource.resourceType || resource.resourceType !== 'Patient') {
        console.warn(`Entry ${index + 1}: Not a Patient resource, skipping phone update`);
        return copy;
      }
      
      const nik = extractNik(resource);
      if (nik && updates.has(nik)) {
        const update = updates.get(nik);
        
        // Handle telecom array - preserve existing non-mobile phone entries
        const telecom = Array.isArray(resource.telecom) ? resource.telecom : [];
        const remaining = telecom.filter(
          (item) => !(item && item.system === 'phone' && item.use === 'mobile'),
        );
        
        // Add new mobile phone entry at the beginning
        resource.telecom = [createTelecomEntry(update.normalizedPhone), ...remaining];
        
        // Update metadata
        const meta = Object.assign({}, resource.meta || {});
        meta.lastUpdated = formatJakartaTimestamp(update.sourceRow.last_updated_date);
        meta.versionId = incrementVersion(meta.versionId);
        resource.meta = meta;
        
        updatedNiks.add(nik);
        console.log(`Updated phone for NIK ${nik}: ${update.normalizedPhone}`);
      }
      
      copy.resource = resource;
      return copy;
    } catch (error) {
      const errorMsg = `Error processing patient entry ${index + 1}: ${error.message}`;
      console.error(errorMsg);
      errors.push(errorMsg);
      return entry; // Return original entry on error
    }
  });
  
  return {
    patients_after_phone_update: transformed,
    updatedCount: updatedNiks.size,
    total: patients.length,
    errors,
  };
}

async function updateBundle({ csvPath, inputPath, outputPath, lastUpdatedDate }) {
  // Validate input parameters
  if (!csvPath || typeof csvPath !== 'string') {
    throw new Error('CSV path is required and must be a string');
  }
  if (!inputPath || typeof inputPath !== 'string') {
    throw new Error('Input JSON path is required and must be a string');
  }
  if (!outputPath || typeof outputPath !== 'string') {
    throw new Error('Output JSON path is required and must be a string');
  }

  console.log(`Loading WhatsApp updates from: ${csvPath}`);
  console.log(`Loading patient bundle from: ${inputPath}`);
  if (lastUpdatedDate) {
    console.log(`Filtering by date: ${lastUpdatedDate}`);
  }

  const [updates, bundle] = await Promise.all([
    loadWhatsAppUpdates(csvPath, lastUpdatedDate),
    loadBundle(inputPath),
  ]);

  console.log(`Applying ${updates.size} phone updates to ${bundle.patients_before_phone_update.length} patients`);
  
  const result = applyUpdates(bundle, updates);
  
  // Create output bundle with updated patients
  const outputBundle = Object.assign({}, bundle, {
    patients_after_phone_update: result.patients_after_phone_update,
  });

  // Write output file
  if (outputPath) {
    try {
      const resolved = path.resolve(outputPath);
      await fs.mkdir(path.dirname(resolved), { recursive: true });
      await fs.writeFile(resolved, `${JSON.stringify(outputBundle, null, 2)}\n`, 'utf8');
      console.log(`Output written to: ${resolved}`);
    } catch (error) {
      throw new Error(`Failed to write output file: ${error.message}`);
    }
  }

  // Prepare summary with error details if any
  const summary = {
    csv_rows_processed: updates.size,
    patients_total: result.total,
    patients_with_updates: result.updatedCount,
  };

  if (result.errors && result.errors.length > 0) {
    summary.errors = result.errors;
  }

  return {
    summary,
    outputBundle,
  };
}

module.exports = {
  updateBundle,
  loadWhatsAppUpdates,
  applyUpdates,
};
