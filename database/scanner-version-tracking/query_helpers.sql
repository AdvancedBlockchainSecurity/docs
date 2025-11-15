-- Scanner Version Tracking - Query Helpers
-- Common queries for managing scanner versions

-- ============================================================================
-- STATUS QUERIES
-- ============================================================================

-- View all scanner status
\echo '\n=== Scanner Version Status ==='
SELECT
    scanner_name,
    scanner_type,
    ecosystem,
    current_version,
    latest_version,
    version_status,
    image_tag,
    CONCAT(integrated_detector_count, '/', detector_count) as "detectors",
    ROUND(integration_percentage, 1) || '%' as "integration"
FROM scanner_version_status
ORDER BY ecosystem, scanner_type, scanner_name;

-- Outdated scanners
\echo '\n=== Outdated Scanners ==='
SELECT
    scanner_name,
    ecosystem,
    current_version,
    latest_version,
    last_checked_at
FROM outdated_scanners;

-- Integration progress by ecosystem
\echo '\n=== Integration Progress by Ecosystem ==='
SELECT
    ecosystem,
    COUNT(*) as scanners,
    SUM(detector_count) as total_detectors,
    SUM(integrated_detector_count) as integrated,
    ROUND(
        CASE
            WHEN SUM(detector_count) > 0
            THEN (SUM(integrated_detector_count)::DECIMAL / SUM(detector_count) * 100)
            ELSE 0
        END,
    2) || '%' as progress
FROM scanner_versions
WHERE detector_count > 0
GROUP BY ecosystem
ORDER BY ecosystem;

-- Integration progress by scanner type
\echo '\n=== Integration Progress by Scanner Type ==='
SELECT
    scanner_type,
    COUNT(*) as scanners,
    SUM(detector_count) as total_detectors,
    SUM(integrated_detector_count) as integrated,
    ROUND(
        CASE
            WHEN SUM(detector_count) > 0
            THEN (SUM(integrated_detector_count)::DECIMAL / SUM(detector_count) * 100)
            ELSE 0
        END,
    2) || '%' as progress
FROM scanner_versions
WHERE detector_count > 0
GROUP BY scanner_type
ORDER BY scanner_type;

-- ============================================================================
-- HISTORY QUERIES
-- ============================================================================

-- Recent version updates
\echo '\n=== Recent Version Updates (Last 10) ==='
SELECT
    scanner_name,
    old_version || ' → ' || new_version as version_change,
    old_image_tag || ' → ' || new_image_tag as image_change,
    change_type,
    TO_CHAR(updated_at, 'YYYY-MM-DD') as date,
    updated_by
FROM scanner_version_history
ORDER BY updated_at DESC
LIMIT 10;

-- Update history for specific scanner
-- Usage: \set scanner_name 'aderyn'
-- \echo '\n=== Update History for :scanner_name ==='
-- SELECT
--     old_version || ' → ' || new_version as version_change,
--     change_type,
--     breaking_changes,
--     detector_changes,
--     TO_CHAR(updated_at, 'YYYY-MM-DD HH24:MI') as updated_at,
--     updated_by,
--     release_notes
-- FROM scanner_version_history
-- WHERE scanner_name = :'scanner_name'
-- ORDER BY updated_at DESC;

-- ============================================================================
-- RELEASE TRACKING QUERIES
-- ============================================================================

-- Pending releases
\echo '\n=== Pending Releases (Not Yet Applied) ==='
SELECT
    srt.scanner_name,
    srt.release_version,
    sv.current_version as platform_version,
    TO_CHAR(srt.release_date, 'YYYY-MM-DD') as released,
    srt.is_prerelease
FROM scanner_release_tracking srt
JOIN scanner_versions sv ON srt.scanner_name = sv.scanner_name
WHERE srt.applied_to_platform = FALSE
ORDER BY srt.release_date DESC;

-- ============================================================================
-- FUNCTIONS FOR COMMON OPERATIONS
-- ============================================================================

-- Function to check for version updates
CREATE OR REPLACE FUNCTION check_scanner_version_update(
    p_scanner_name VARCHAR,
    p_new_version VARCHAR,
    p_new_image_tag VARCHAR
) RETURNS TEXT AS $$
DECLARE
    v_current_version VARCHAR;
    v_current_image VARCHAR;
BEGIN
    SELECT current_version, image_tag
    INTO v_current_version, v_current_image
    FROM scanner_versions
    WHERE scanner_name = p_scanner_name;

    IF v_current_version IS NULL THEN
        RETURN 'Scanner not found: ' || p_scanner_name;
    ELSIF v_current_version = p_new_version AND v_current_image = p_new_image_tag THEN
        RETURN 'Already up-to-date: ' || p_scanner_name || ' ' || v_current_version;
    ELSE
        RETURN 'Update available: ' || p_scanner_name || ' ' || v_current_version || ' → ' || p_new_version;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Function to record version update
CREATE OR REPLACE FUNCTION record_scanner_update(
    p_scanner_name VARCHAR,
    p_new_version VARCHAR,
    p_new_image_tag VARCHAR,
    p_change_type VARCHAR DEFAULT 'minor',
    p_breaking BOOLEAN DEFAULT FALSE,
    p_detector_changes TEXT DEFAULT NULL,
    p_release_notes TEXT DEFAULT NULL
) RETURNS TEXT AS $$
DECLARE
    v_old_version VARCHAR;
    v_old_image VARCHAR;
BEGIN
    -- Get current version
    SELECT current_version, image_tag
    INTO v_old_version, v_old_image
    FROM scanner_versions
    WHERE scanner_name = p_scanner_name;

    IF v_old_version IS NULL THEN
        RETURN 'Error: Scanner not found - ' || p_scanner_name;
    END IF;

    -- Insert history record
    INSERT INTO scanner_version_history (
        scanner_name, old_version, new_version,
        old_image_tag, new_image_tag,
        change_type, breaking_changes,
        detector_changes, release_notes,
        updated_by
    ) VALUES (
        p_scanner_name, v_old_version, p_new_version,
        v_old_image, p_new_image_tag,
        p_change_type, p_breaking,
        p_detector_changes, p_release_notes,
        'database-function'
    );

    -- Update current version
    UPDATE scanner_versions
    SET
        current_version = p_new_version,
        image_tag = p_new_image_tag,
        version_status = 'up-to-date',
        last_updated_at = NOW()
    WHERE scanner_name = p_scanner_name;

    RETURN 'Updated: ' || p_scanner_name || ' from ' || v_old_version || ' to ' || p_new_version;
END;
$$ LANGUAGE plpgsql;

-- Example usage:
-- SELECT record_scanner_update('slither', '0.11.4', '0.2.1', 'patch', FALSE, 'Bug fixes', 'Minor bug fixes');

COMMENT ON FUNCTION check_scanner_version_update IS 'Check if a scanner version update is available';
COMMENT ON FUNCTION record_scanner_update IS 'Record a scanner version update with history tracking';
