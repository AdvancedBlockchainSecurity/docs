-- Scanner Version Tracking Schema
-- Purpose: Track scanner versions, releases, and updates for BlockSecOps platform
-- Created: 2025-10-30
-- Database: solidity_security (existing database)

-- ============================================================================
-- Table: scanner_versions
-- Tracks current and historical scanner version information
-- ============================================================================

CREATE TABLE IF NOT EXISTS scanner_versions (
    id SERIAL PRIMARY KEY,
    scanner_name VARCHAR(100) NOT NULL UNIQUE,
    scanner_type VARCHAR(50) NOT NULL, -- 'static-analysis', 'fuzzer', 'formal-verification'
    ecosystem VARCHAR(50) NOT NULL, -- 'evm', 'solana', 'cairo', 'move'
    language VARCHAR(50) NOT NULL, -- 'solidity', 'vyper', 'rust', 'cairo'

    -- Version information
    current_version VARCHAR(50) NOT NULL,
    latest_version VARCHAR(50),
    version_status VARCHAR(20) DEFAULT 'up-to-date', -- 'up-to-date', 'outdated', 'unknown'

    -- Image information
    image_tag VARCHAR(50) NOT NULL, -- e.g., '0.2.1'
    image_name VARCHAR(200) NOT NULL, -- e.g., 'scanner-aderyn:0.2.1'

    -- Developer and metadata
    developer VARCHAR(200),
    repository_url TEXT,
    documentation_url TEXT,

    -- Integration status
    detector_count INTEGER DEFAULT 0,
    integrated_detector_count INTEGER DEFAULT 0,
    integration_percentage DECIMAL(5,2) GENERATED ALWAYS AS (
        CASE
            WHEN detector_count > 0 THEN (integrated_detector_count::DECIMAL / detector_count * 100)
            ELSE 0
        END
    ) STORED,

    -- Timestamps
    last_checked_at TIMESTAMP WITH TIME ZONE,
    last_updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Notes
    notes TEXT,

    -- Constraints
    CONSTRAINT valid_version_status CHECK (version_status IN ('up-to-date', 'outdated', 'unknown', 'deprecated')),
    CONSTRAINT valid_scanner_type CHECK (scanner_type IN ('static-analysis', 'fuzzer', 'formal-verification')),
    CONSTRAINT valid_ecosystem CHECK (ecosystem IN ('evm', 'solana', 'cairo', 'move', 'multi')),
    CONSTRAINT valid_integration_counts CHECK (integrated_detector_count <= detector_count)
);

-- Index for frequent queries
CREATE INDEX IF NOT EXISTS idx_scanner_versions_ecosystem ON scanner_versions(ecosystem);
CREATE INDEX IF NOT EXISTS idx_scanner_versions_type ON scanner_versions(scanner_type);
CREATE INDEX IF NOT EXISTS idx_scanner_versions_status ON scanner_versions(version_status);

-- ============================================================================
-- Table: scanner_version_history
-- Tracks historical version changes for audit trail
-- ============================================================================

CREATE TABLE IF NOT EXISTS scanner_version_history (
    id SERIAL PRIMARY KEY,
    scanner_name VARCHAR(100) NOT NULL,

    -- Version change information
    old_version VARCHAR(50),
    new_version VARCHAR(50) NOT NULL,
    old_image_tag VARCHAR(50),
    new_image_tag VARCHAR(50) NOT NULL,

    -- Change metadata
    change_type VARCHAR(50) NOT NULL, -- 'major', 'minor', 'patch', 'image-only'
    breaking_changes BOOLEAN DEFAULT FALSE,
    detector_changes TEXT, -- Description of detector changes

    -- Update details
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_by VARCHAR(100), -- User or system that performed update

    -- Notes and documentation
    changelog_url TEXT,
    release_notes TEXT,

    -- Foreign key
    FOREIGN KEY (scanner_name) REFERENCES scanner_versions(scanner_name) ON DELETE CASCADE
);

-- Index for historical queries
CREATE INDEX IF NOT EXISTS idx_version_history_scanner ON scanner_version_history(scanner_name);
CREATE INDEX IF NOT EXISTS idx_version_history_date ON scanner_version_history(updated_at DESC);

-- ============================================================================
-- Table: scanner_release_tracking
-- Tracks upstream release information for comparison
-- ============================================================================

CREATE TABLE IF NOT EXISTS scanner_release_tracking (
    id SERIAL PRIMARY KEY,
    scanner_name VARCHAR(100) NOT NULL,

    -- Release information
    release_version VARCHAR(50) NOT NULL,
    release_date DATE,
    release_url TEXT,
    is_prerelease BOOLEAN DEFAULT FALSE,

    -- Status
    checked_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    applied_to_platform BOOLEAN DEFAULT FALSE,
    applied_at TIMESTAMP WITH TIME ZONE,

    -- Notes
    release_notes TEXT,

    -- Constraints
    UNIQUE(scanner_name, release_version),
    FOREIGN KEY (scanner_name) REFERENCES scanner_versions(scanner_name) ON DELETE CASCADE
);

-- Index for release queries
CREATE INDEX IF NOT EXISTS idx_release_tracking_scanner ON scanner_release_tracking(scanner_name);
CREATE INDEX IF NOT EXISTS idx_release_tracking_applied ON scanner_release_tracking(applied_to_platform);

-- ============================================================================
-- View: scanner_version_status
-- Convenient view for version status overview
-- ============================================================================

CREATE OR REPLACE VIEW scanner_version_status AS
SELECT
    sv.scanner_name,
    sv.scanner_type,
    sv.ecosystem,
    sv.current_version,
    sv.latest_version,
    sv.version_status,
    sv.image_tag,
    sv.developer,
    sv.detector_count,
    sv.integrated_detector_count,
    sv.integration_percentage,
    sv.last_checked_at,
    sv.last_updated_at,
    COALESCE(
        (SELECT COUNT(*)
         FROM scanner_release_tracking srt
         WHERE srt.scanner_name = sv.scanner_name
         AND srt.applied_to_platform = FALSE
         AND srt.is_prerelease = FALSE),
        0
    ) as pending_releases
FROM scanner_versions sv
ORDER BY sv.ecosystem, sv.scanner_type, sv.scanner_name;

-- ============================================================================
-- View: outdated_scanners
-- Shows scanners that need updating
-- ============================================================================

CREATE OR REPLACE VIEW outdated_scanners AS
SELECT
    scanner_name,
    scanner_type,
    ecosystem,
    current_version,
    latest_version,
    last_checked_at,
    notes
FROM scanner_versions
WHERE version_status = 'outdated'
ORDER BY ecosystem, scanner_type, scanner_name;

-- ============================================================================
-- Comments for documentation
-- ============================================================================

COMMENT ON TABLE scanner_versions IS 'Tracks current scanner versions and integration status for BlockSecOps platform';
COMMENT ON TABLE scanner_version_history IS 'Audit trail of all scanner version updates';
COMMENT ON TABLE scanner_release_tracking IS 'Tracks upstream releases for version monitoring';
COMMENT ON VIEW scanner_version_status IS 'Overview of scanner version status with pending releases';
COMMENT ON VIEW outdated_scanners IS 'Quick view of scanners needing updates';

COMMENT ON COLUMN scanner_versions.integration_percentage IS 'Automatically calculated percentage of integrated detectors';
COMMENT ON COLUMN scanner_versions.version_status IS 'Current version status: up-to-date, outdated, unknown, deprecated';
COMMENT ON COLUMN scanner_version_history.change_type IS 'Type of version change: major, minor, patch, image-only';
