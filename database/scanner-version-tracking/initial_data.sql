-- Initial Scanner Version Data
-- Populated from scanner-versions-configmap.yaml as of 2025-10-30
-- Source: blocksecops-tool-integration/k8s/base/scanner-versions-configmap.yaml

BEGIN;

-- ============================================================================
-- EVM / Solidity Scanners
-- ============================================================================

INSERT INTO scanner_versions (
    scanner_name, scanner_type, ecosystem, language,
    current_version, latest_version, version_status,
    image_tag, image_name,
    developer, repository_url, documentation_url,
    detector_count, integrated_detector_count,
    last_checked_at, notes
) VALUES
-- Slither
('slither', 'static-analysis', 'evm', 'solidity',
 '0.11.3', '0.11.3', 'up-to-date',
 '0.2.0', 'scanner-slither:0.2.0',
 'Trail of Bits', 'https://github.com/crytic/slither', 'https://github.com/crytic/slither/wiki/Detector-Documentation',
 99, 18,
 '2025-10-30', 'Updated 2025-10-19. 18/99 detectors integrated (18.2%)'),

-- Aderyn
('aderyn', 'static-analysis', 'evm', 'solidity',
 '0.6.5', '0.6.5', 'up-to-date',
 '0.2.1', 'scanner-aderyn:0.2.1',
 'Cyfrin', 'https://github.com/Cyfrin/aderyn', 'https://github.com/Cyfrin/aderyn/tree/dev/aderyn_core/src/detect',
 87, 87,
 '2025-10-30', 'Updated 2025-10-30. 100% integration complete'),

-- Semgrep
('semgrep', 'static-analysis', 'evm', 'solidity',
 '1.141.0', '1.141.0', 'up-to-date',
 '0.2.1', 'scanner-semgrep:0.2.1',
 'Semgrep Inc', 'https://github.com/Decurity/semgrep-smart-contracts', 'https://github.com/Decurity/semgrep-smart-contracts',
 47, 43,
 '2025-10-30', 'Updated 2025-10-30. 19-version jump from 1.122.0. 43/47 detectors integrated (91.5%)'),

-- Solhint
('solhint', 'static-analysis', 'evm', 'solidity',
 '6.0.1', '6.0.1', 'up-to-date',
 '0.2.0', 'scanner-solhint:0.2.0',
 'Protofire', 'https://github.com/protofire/solhint', 'https://github.com/protofire/solhint/blob/master/docs/rules.md',
 20, 16,
 '2025-10-30', 'Updated 2025-10-19. 16/20 detectors integrated (80%)'),

-- Echidna
('echidna', 'fuzzer', 'evm', 'solidity',
 '2.2.7', '2.2.7', 'up-to-date',
 '0.2.1', 'scanner-echidna:0.2.1',
 'Trail of Bits', 'https://github.com/crytic/echidna', 'https://github.com/crytic/echidna',
 0, 0,
 '2025-10-30', 'Updated 2025-10-30. Property-based fuzzer, no fixed detectors'),

-- Halmos
('halmos', 'formal-verification', 'evm', 'solidity',
 '0.3.3', '0.3.3', 'up-to-date',
 '0.2.0', 'scanner-halmos:0.2.0',
 'a16z', 'https://github.com/a16z/halmos', 'https://github.com/a16z/halmos',
 0, 0,
 '2025-10-30', 'Updated 2025-10-19. Symbolic execution, user-defined properties'),

-- Certora
('certora', 'formal-verification', 'evm', 'solidity',
 '8.3.1', '8.3.1', 'up-to-date',
 '0.2.0', 'scanner-certora:0.2.0',
 'Certora', 'https://www.certora.com/', 'https://docs.certora.com/en/latest/docs/cvl/builtin.html',
 5, 0,
 '2025-10-30', 'Updated 2025-10-19. 5 built-in rules, 0 integrated'),

-- ============================================================================
-- EVM / Vyper Scanners
-- ============================================================================

('vyper', 'static-analysis', 'evm', 'vyper',
 '0.11.3', '0.11.3', 'up-to-date',
 '0.2.0', 'scanner-vyper:0.2.0',
 'Trail of Bits', 'https://github.com/crytic/slither', 'https://github.com/crytic/slither/wiki/Detector-Documentation',
 99, 0,
 '2025-10-30', 'Same as slither (slither-vyper). No detectors integrated yet'),

('moccasin', 'fuzzer', 'evm', 'vyper',
 '0.3.6', '0.3.6', 'up-to-date',
 '0.1.0', 'scanner-moccasin:0.1.0',
 'Cyfrin', 'https://github.com/Cyfrin/moccasin', 'https://github.com/Cyfrin/moccasin',
 0, 0,
 '2025-10-30', 'Updated 2025-10-19. Vyper fuzzing framework'),

-- ============================================================================
-- Solana Scanners
-- ============================================================================

('sol-azy', 'static-analysis', 'solana', 'rust',
 '0.2.0', '0.2.0', 'up-to-date',
 '0.2.0', 'scanner-sol-azy:0.2.0',
 'FuzzingLabs', 'https://github.com/FuzzingLabs/sol-azy', 'https://github.com/FuzzingLabs/sol-azy/tree/master/rules/syn_ast',
 14, 0,
 '2025-10-30', 'No formal releases, source version. 14 security rules'),

('sec3-xray', 'static-analysis', 'solana', 'rust',
 '0.0.6', '0.0.6', 'up-to-date',
 '0.1.0', 'scanner-sec3-xray:0.1.0',
 'Sec3', 'https://github.com/sec3-service/x-ray', 'https://github.com/sec3-service/x-ray',
 11, 0,
 '2025-10-30', 'Last release 2024. 11+ detector categories'),

('trident', 'fuzzer', 'solana', 'rust',
 '0.11.0', '0.11.0', 'up-to-date',
 '0.1.0', 'scanner-trident:0.1.0',
 'Ackee Blockchain', 'https://github.com/Ackee-Blockchain/trident', 'https://github.com/Ackee-Blockchain/trident',
 0, 0,
 '2025-10-30', 'Updated 2025-10-19. Solana fuzzing framework'),

('cargo-fuzz-solana', 'fuzzer', 'solana', 'rust',
 '0.13.1', '0.13.1', 'up-to-date',
 '0.1.0', 'scanner-cargo-fuzz-solana:0.1.0',
 'rust-fuzz', 'https://github.com/rust-fuzz/cargo-fuzz', 'https://github.com/rust-fuzz/cargo-fuzz',
 0, 0,
 '2025-10-30', 'Updated 2025-10-19. Rust fuzzing for Solana'),

-- ============================================================================
-- Cairo / StarkNet Scanners
-- ============================================================================

('caracal', 'static-analysis', 'cairo', 'cairo',
 '0.2.3', '0.2.3', 'up-to-date',
 '0.2.0', 'scanner-caracal:0.2.0',
 'Trail of Bits', 'https://github.com/crytic/caracal', 'https://github.com/crytic/caracal',
 14, 0,
 '2025-10-30', 'Updated 2025-10-19. 14 SIERRA-based detectors'),

('tayt', 'fuzzer', 'cairo', 'cairo',
 '0.1.0', '0.1.0', 'deprecated',
 '0.2.0', 'scanner-tayt:0.2.0',
 'Trail of Bits', 'https://github.com/crytic/tayt', 'https://github.com/crytic/tayt',
 0, 0,
 '2025-10-30', 'Repository archived Feb 2025, no releases'),

('starknet-foundry', 'fuzzer', 'cairo', 'cairo',
 '0.50.0', '0.50.0', 'up-to-date',
 '0.1.0', 'scanner-starknet-foundry:0.1.0',
 'Foundry', 'https://github.com/foundry-rs/starknet-foundry', 'https://github.com/foundry-rs/starknet-foundry',
 0, 0,
 '2025-10-30', 'Updated 2025-10-19. Cairo testing framework')

ON CONFLICT (scanner_name) DO UPDATE SET
    current_version = EXCLUDED.current_version,
    latest_version = EXCLUDED.latest_version,
    version_status = EXCLUDED.version_status,
    image_tag = EXCLUDED.image_tag,
    image_name = EXCLUDED.image_name,
    detector_count = EXCLUDED.detector_count,
    integrated_detector_count = EXCLUDED.integrated_detector_count,
    last_checked_at = EXCLUDED.last_checked_at,
    last_updated_at = NOW(),
    notes = EXCLUDED.notes;

-- ============================================================================
-- Initial Version History Entries
-- Record recent updates (2025-10-30)
-- ============================================================================

INSERT INTO scanner_version_history (
    scanner_name, old_version, new_version,
    old_image_tag, new_image_tag,
    change_type, breaking_changes, detector_changes,
    updated_at, updated_by, release_notes
) VALUES
('aderyn', '0.6.4', '0.6.5',
 '0.2.0', '0.2.1',
 'patch', FALSE, 'None - all 87/87 detector mappings remain valid',
 '2025-10-30', 'platform-team', 'Added grep API to MCP server'),

('semgrep', '1.122.0', '1.141.0',
 '0.2.0', '0.2.1',
 'minor', FALSE, 'TBD - needs verification after 19-version jump',
 '2025-10-30', 'platform-team', '19 versions jump. Pattern matching requires validation'),

('echidna', '2.2.4', '2.2.7',
 '0.2.0', '0.2.1',
 'patch', FALSE, 'N/A - fuzzer, no fixed detectors',
 '2025-10-30', 'platform-team', 'Performance improvements from upstream');

COMMIT;

-- ============================================================================
-- Query Examples
-- ============================================================================

-- View all scanner status
-- SELECT * FROM scanner_version_status ORDER BY ecosystem, scanner_type, scanner_name;

-- Check outdated scanners
-- SELECT * FROM outdated_scanners;

-- View recent updates
-- SELECT * FROM scanner_version_history ORDER BY updated_at DESC LIMIT 10;

-- Check integration progress by ecosystem
-- SELECT
--     ecosystem,
--     COUNT(*) as total_scanners,
--     SUM(detector_count) as total_detectors,
--     SUM(integrated_detector_count) as integrated_detectors,
--     ROUND(AVG(integration_percentage), 2) as avg_integration_pct
-- FROM scanner_versions
-- WHERE detector_count > 0
-- GROUP BY ecosystem
-- ORDER BY ecosystem;
