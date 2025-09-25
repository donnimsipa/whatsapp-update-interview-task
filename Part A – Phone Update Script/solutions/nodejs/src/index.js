#!/usr/bin/env node

const path = require('path');
const fs = require('fs');
const { updateBundle } = require('./updatePatients');

const REQUIRED_ARGS = ['csv', 'input-json', 'output-json'];

function printUsage() {
  const scriptName = path.basename(process.argv[1]);
  console.log(`WhatsApp Patient Phone Sync Tool`);
  console.log(`Usage: ${scriptName} --csv <path> --input-json <path> --output-json <path> [--last-updated-date DD-MM-YYYY]`);
  console.log('');
  console.log('Arguments:');
  console.log('  --csv <path>              Path to CSV file with WhatsApp phone updates');
  console.log('  --input-json <path>       Path to input FHIR bundle JSON file');
  console.log('  --output-json <path>      Path for output FHIR bundle JSON file');
  console.log('  --last-updated-date <date> Optional date filter (DD-MM-YYYY format)');
  console.log('  --help, -h                Show this help message');
  console.log('');
  console.log('Examples:');
  console.log(`  ${scriptName} --csv data.csv --input-json patients.json --output-json updated.json`);
  console.log(`  ${scriptName} --csv data.csv --input-json patients.json --output-json updated.json --last-updated-date 23-09-2025`);
}

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    if (token === '--help' || token === '-h') {
      args.help = true;
      continue;
    }
    if (!token.startsWith('--')) {
      continue;
    }
    const key = token.slice(2);
    const next = argv[i + 1];
    if (!next || next.startsWith('--')) {
      args[key] = 'true';
    } else {
      args[key] = next;
      i += 1;
    }
  }
  return args;
}

function validateArgs(args) {
  // Check for required arguments
  const missing = REQUIRED_ARGS.filter((key) => !args[key] || args[key] === 'true');
  if (missing.length > 0) {
    throw new Error(`Missing required arguments: ${missing.join(', ')}`);
  }

  // Validate file paths exist for input files
  if (!fs.existsSync(args.csv)) {
    throw new Error(`CSV file does not exist: ${args.csv}`);
  }

  if (!fs.existsSync(args['input-json'])) {
    throw new Error(`Input JSON file does not exist: ${args['input-json']}`);
  }

  // Validate date format if provided
  if (args['last-updated-date'] && args['last-updated-date'] !== 'true') {
    const datePattern = /^(\d{2})-(\d{2})-(\d{4})$/;
    if (!datePattern.test(args['last-updated-date'])) {
      throw new Error(`Invalid date format for --last-updated-date. Expected DD-MM-YYYY, got: ${args['last-updated-date']}`);
    }
  }

  // Validate output path is writable (check parent directory exists or can be created)
  const outputDir = path.dirname(path.resolve(args['output-json']));
  try {
    fs.mkdirSync(outputDir, { recursive: true });
  } catch (error) {
    throw new Error(`Cannot create output directory: ${error.message}`);
  }
}

async function main() {
  const argv = process.argv.slice(2);
  
  // Handle no arguments case
  if (argv.length === 0) {
    console.error('Error: No arguments provided');
    printUsage();
    process.exit(1);
  }

  const args = parseArgs(argv);

  if (args.help) {
    printUsage();
    process.exit(0);
  }

  try {
    validateArgs(args);
  } catch (error) {
    console.error(`Error: ${error.message}`);
    console.error('');
    printUsage();
    process.exit(1);
  }

  const startTime = Date.now();
  
  try {
    const { summary } = await updateBundle({
      csvPath: args.csv,
      inputPath: args['input-json'],
      outputPath: args['output-json'],
      lastUpdatedDate: args['last-updated-date'] && args['last-updated-date'] !== 'true'
        ? args['last-updated-date']
        : undefined,
    });
    
    const endTime = Date.now();
    const executionTime = endTime - startTime;
    
    // Add execution time to summary
    const finalSummary = {
      ...summary,
      execution_time_ms: executionTime
    };
    
    console.log(JSON.stringify(finalSummary));
    process.exit(0);
  } catch (error) {
    console.error(`[whatsapp-sync] Failed: ${error.message}`);
    if (process.env.NODE_ENV === 'development') {
      console.error(error.stack);
    }
    process.exit(1);
  }
}

// Handle uncaught exceptions gracefully
process.on('uncaughtException', (error) => {
  console.error(`[whatsapp-sync] Uncaught exception: ${error.message}`);
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error(`[whatsapp-sync] Unhandled rejection at:`, promise, 'reason:', reason);
  process.exit(1);
});

main();
