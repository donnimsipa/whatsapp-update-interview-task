#!/usr/bin/env node
/**
 * Flexible WhatsApp data generator.
 */
const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
const options = {
  output: 'outputs/samples/generated-whatsapp.csv',
  records: 1000,
  mode: 'valid',
  validRatio: 0.5,
  patientsJson: '',
  date: new Date().toLocaleDateString('en-GB').split('/').join('-'),
};

for (let i = 0; i < args.length; i += 1) {
  const key = args[i];
  const val = args[i + 1];
  switch (key) {
    case '--output':
      options.output = val; i += 1; break;
    case '--records':
      options.records = Number(val); i += 1; break;
    case '--mode':
      options.mode = (val || '').toLowerCase(); i += 1; break;
    case '--valid-ratio':
      options.validRatio = Number(val); i += 1; break;
    case '--patients-json':
      options.patientsJson = val; i += 1; break;
    case '--date':
      options.date = val; i += 1; break;
    case '--help':
    case '-h':
      console.log(`Usage: node generate-whatsapp-dataset.js [options]\n\n` +
        `--output PATH           Output CSV path (default ${options.output})\n` +
        `--records N             Number of rows (default ${options.records})\n` +
        `--mode MODE             valid|invalid|mixed|uniform (default ${options.mode})\n` +
        `--valid-ratio R         Ratio of valid rows for mixed mode (default ${options.validRatio})\n` +
        `--patients-json PATH    Optional patients JSON output\n` +
        `--date DD-MM-YYYY       Date stamp for CSV rows (default today)`);
      process.exit(0);
      break;
    default:
      break;
  }
}

const ensureDir = (filePath) => {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
};

const validPhones = ['081234567890', '085678901234', '082345678901', '083456789012', '087890123456'];
const uniformPhones = ['081234567890', '6285678901234', '082345678901', '0834-5678-9012', '85678901234'];
const invalidPhones = ['+630123456', '7123456789', '08123', 'abcde12345', '', '620123456789'];
const validNames = ['DEWI LESTARI SARI', 'MAYA SARI PUTRI', 'RINA PERMATA ANGGRAINI', 'LINDA MARLINA SIREGAR'];
const invalidNames = ['INVALID FORMAT ONE', 'INVALID FORMAT TWO', 'INVALID FORMAT THREE', 'INVALID FORMAT FOUR'];

const header = ['last_updated_date', 'nik_identifier', 'name', 'phone_number'];
const rows = [header.join(',')];
const validTarget = Math.round(options.records * options.validRatio);
let validCount = 0;

const makeNik = (base, index) => (base + index).toString().padStart(16, '0');

for (let i = 0; i < options.records; i += 1) {
  let row;
  switch (options.mode) {
    case 'invalid': {
      const nik = makeNik(9000000000000000, i);
      const phone = invalidPhones[i % invalidPhones.length];
      const nikValue = phone === '' ? '' : nik;
      row = [options.date, nikValue, invalidNames[i % invalidNames.length], phone];
      break;
    }
    case 'mixed': {
      const isValid = validCount < validTarget;
      if (isValid) {
        const nik = makeNik(3200000000000000, i);
        const phone = validPhones[i % validPhones.length];
        row = [options.date, nik, validNames[i % validNames.length], phone];
        validCount += 1;
      } else {
        const nik = makeNik(9000000000000000, i);
        const phone = invalidPhones[i % invalidPhones.length];
        const nikValue = phone === '' ? '' : nik;
        row = [options.date, nikValue, invalidNames[i % invalidNames.length], phone];
      }
      break;
    }
    case 'uniform': {
      const nik = makeNik(3100000000000000, i);
      const phone = uniformPhones[i % uniformPhones.length];
      row = [options.date, nik, `PATIENT_${i + 1}`, phone];
      break;
    }
    case 'valid':
    default: {
      const nik = makeNik(3300000000000000, i);
      const phone = validPhones[Math.floor(Math.random() * validPhones.length)];
      const name = validNames[Math.floor(Math.random() * validNames.length)];
      row = [options.date, nik, name, phone];
      break;
    }
  }
  rows.push(row.join(','));
}

ensureDir(options.output);
fs.writeFileSync(options.output, rows.join('\n'));
console.log(`[ok] CSV written to ${options.output} (${options.records} rows, mode=${options.mode})`);

if (options.patientsJson) {
  const patients = { patients_before_phone_update: [] };
  for (let i = 0; i < options.records; i += 1) {
    const nik = makeNik(3000000000000000, i);
    patients.patients_before_phone_update.push({
      resource: {
        resourceType: 'Patient',
        id: `patient-${i + 1}`,
        active: true,
        identifier: [
          {
            system: 'https://fhir.kemkes.go.id/id/nik',
            value: nik,
          },
        ],
        name: [
          {
            use: 'official',
            family: `PATIENT_${i + 1}`,
            given: ['TEST'],
          },
        ],
        telecom: [],
        meta: {
          versionId: 'v001',
          lastUpdated: '2025-08-22T10:15:30.123456+07:00',
        },
      },
    });
  }
  ensureDir(options.patientsJson);
  fs.writeFileSync(options.patientsJson, JSON.stringify(patients, null, 2));
  console.log(`[ok] Patients JSON written to ${options.patientsJson}`);
}
