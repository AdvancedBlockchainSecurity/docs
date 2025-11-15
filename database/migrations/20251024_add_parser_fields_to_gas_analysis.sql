-- Migration: Add parser enrichment fields to gas_analysis_findings
-- Date: October 24, 2025
-- Purpose: Add contract_id, detector_id, file_path, contract_name to gas_analysis_findings table
-- Related: Phase 4D Model Fix (v0.7.15-model-fix)

-- Add missing columns for gas analysis findings
ALTER TABLE gas_analysis_findings
ADD COLUMN IF NOT EXISTS contract_id UUID NOT NULL DEFAULT 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'::UUID,
ADD COLUMN IF NOT EXISTS detector_id VARCHAR(200),
ADD COLUMN IF NOT EXISTS file_path VARCHAR(500),
ADD COLUMN IF NOT EXISTS contract_name VARCHAR(200);

-- Remove default constraint after adding (UUID is just a placeholder)
ALTER TABLE gas_analysis_findings ALTER COLUMN contract_id DROP DEFAULT;

-- Create indexes for efficient querying
CREATE INDEX IF NOT EXISTS ix_gas_analysis_contract_id ON gas_analysis_findings(contract_id);
CREATE INDEX IF NOT EXISTS ix_gas_analysis_detector_id ON gas_analysis_findings(detector_id);
CREATE INDEX IF NOT EXISTS ix_gas_analysis_file_path ON gas_analysis_findings(file_path);
CREATE INDEX IF NOT EXISTS ix_gas_analysis_contract_name ON gas_analysis_findings(contract_name);

-- Document column purposes
COMMENT ON COLUMN gas_analysis_findings.contract_id IS 'Contract ID for this gas optimization finding';
COMMENT ON COLUMN gas_analysis_findings.detector_id IS 'Detector ID that found this optimization (extracted by parser)';
COMMENT ON COLUMN gas_analysis_findings.file_path IS 'Source file path where optimization applies (extracted by parser)';
COMMENT ON COLUMN gas_analysis_findings.contract_name IS 'Contract name where optimization applies (for enrichment context)';

-- Verify migration
SELECT
    column_name,
    data_type,
    character_maximum_length,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'gas_analysis_findings'
    AND column_name IN ('contract_id', 'detector_id', 'file_path', 'contract_name', 'function_name')
ORDER BY column_name;
