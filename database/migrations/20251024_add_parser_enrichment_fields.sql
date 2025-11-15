-- Migration: Add parser enrichment fields
-- Date: October 24, 2025
-- Purpose: Add file_path, function_name, contract_name fields that parsers now extract
-- Related: Phase 4D Parser Classification Fix (v0.7.14-parser-fix)

-- Add missing columns for parser enrichment
ALTER TABLE vulnerabilities
ADD COLUMN IF NOT EXISTS file_path VARCHAR(500),
ADD COLUMN IF NOT EXISTS function_name VARCHAR(200),
ADD COLUMN IF NOT EXISTS contract_name VARCHAR(200);

-- Create indexes for efficient querying
CREATE INDEX IF NOT EXISTS ix_vulnerabilities_file_path ON vulnerabilities(file_path);
CREATE INDEX IF NOT EXISTS ix_vulnerabilities_function_name ON vulnerabilities(function_name);
CREATE INDEX IF NOT EXISTS ix_vulnerabilities_contract_name ON vulnerabilities(contract_name);

-- Add composite index for location-based queries
CREATE INDEX IF NOT EXISTS ix_vulnerabilities_location_lookup
ON vulnerabilities(contract_name, file_path, function_name);

-- Document column purposes
COMMENT ON COLUMN vulnerabilities.file_path IS 'Source file path where vulnerability was detected (extracted by parser)';
COMMENT ON COLUMN vulnerabilities.function_name IS 'Function name where vulnerability exists (for enrichment context)';
COMMENT ON COLUMN vulnerabilities.contract_name IS 'Contract name where vulnerability exists (for enrichment context)';

-- Verify migration
SELECT
    column_name,
    data_type,
    character_maximum_length,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'vulnerabilities'
    AND column_name IN ('file_path', 'function_name', 'contract_name', 'detector_id')
ORDER BY column_name;
