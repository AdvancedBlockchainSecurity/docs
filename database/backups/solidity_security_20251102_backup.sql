--
-- PostgreSQL database dump
--

-- Dumped from database version 15.4
-- Dumped by pg_dump version 15.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

ALTER TABLE IF EXISTS ONLY public.vulnerability_trends DROP CONSTRAINT IF EXISTS vulnerability_trends_user_id_fkey;
ALTER TABLE IF EXISTS ONLY public.vulnerability_trends DROP CONSTRAINT IF EXISTS vulnerability_trends_pattern_id_fkey;
ALTER TABLE IF EXISTS ONLY public.vulnerability_trends DROP CONSTRAINT IF EXISTS vulnerability_trends_contract_id_fkey;
ALTER TABLE IF EXISTS ONLY public.vulnerability_classifications DROP CONSTRAINT IF EXISTS vulnerability_classifications_vulnerability_id_fkey;
ALTER TABLE IF EXISTS ONLY public.vulnerability_classifications DROP CONSTRAINT IF EXISTS vulnerability_classifications_user_id_fkey;
ALTER TABLE IF EXISTS ONLY public.vulnerabilities DROP CONSTRAINT IF EXISTS vulnerabilities_scan_id_fkey;
ALTER TABLE IF EXISTS ONLY public.vulnerabilities DROP CONSTRAINT IF EXISTS vulnerabilities_contract_id_fkey;
ALTER TABLE IF EXISTS ONLY public.user_preferences DROP CONSTRAINT IF EXISTS user_preferences_user_id_fkey;
ALTER TABLE IF EXISTS ONLY public.scans DROP CONSTRAINT IF EXISTS scans_user_id_fkey;
ALTER TABLE IF EXISTS ONLY public.scans DROP CONSTRAINT IF EXISTS scans_contract_id_fkey;
ALTER TABLE IF EXISTS ONLY public.scanner_version_history DROP CONSTRAINT IF EXISTS scanner_version_history_scanner_name_fkey;
ALTER TABLE IF EXISTS ONLY public.scanner_release_tracking DROP CONSTRAINT IF EXISTS scanner_release_tracking_scanner_name_fkey;
ALTER TABLE IF EXISTS ONLY public.saved_searches DROP CONSTRAINT IF EXISTS saved_searches_user_id_fkey;
ALTER TABLE IF EXISTS ONLY public.projects DROP CONSTRAINT IF EXISTS projects_user_id_fkey;
ALTER TABLE IF EXISTS ONLY public.project_contracts DROP CONSTRAINT IF EXISTS project_contracts_project_id_fkey;
ALTER TABLE IF EXISTS ONLY public.project_contracts DROP CONSTRAINT IF EXISTS project_contracts_contract_id_fkey;
ALTER TABLE IF EXISTS ONLY public.pattern_tool_mappings DROP CONSTRAINT IF EXISTS pattern_tool_mappings_pattern_id_fkey;
ALTER TABLE IF EXISTS ONLY public.gas_analysis_findings DROP CONSTRAINT IF EXISTS gas_analysis_findings_scan_id_fkey;
ALTER TABLE IF EXISTS ONLY public.fuzzing_results DROP CONSTRAINT IF EXISTS fuzzing_results_scan_id_fkey;
ALTER TABLE IF EXISTS ONLY public.formal_verification_results DROP CONSTRAINT IF EXISTS formal_verification_results_scan_id_fkey;
ALTER TABLE IF EXISTS ONLY public.vulnerabilities DROP CONSTRAINT IF EXISTS fk_vulnerabilities_pattern_id;
ALTER TABLE IF EXISTS ONLY public.vulnerabilities DROP CONSTRAINT IF EXISTS fk_vulnerabilities_dedup_group_id;
ALTER TABLE IF EXISTS ONLY public.deduplication_groups DROP CONSTRAINT IF EXISTS deduplication_groups_verified_by_fkey;
ALTER TABLE IF EXISTS ONLY public.deduplication_groups DROP CONSTRAINT IF EXISTS deduplication_groups_primary_vulnerability_id_fkey;
ALTER TABLE IF EXISTS ONLY public.deduplication_groups DROP CONSTRAINT IF EXISTS deduplication_groups_pattern_id_fkey;
ALTER TABLE IF EXISTS ONLY public.deduplication_groups DROP CONSTRAINT IF EXISTS deduplication_groups_contract_id_fkey;
ALTER TABLE IF EXISTS ONLY public.deduplication_group_members DROP CONSTRAINT IF EXISTS deduplication_group_members_group_id_fkey;
ALTER TABLE IF EXISTS ONLY public.deduplication_group_members DROP CONSTRAINT IF EXISTS deduplication_group_members_finding_id_fkey;
ALTER TABLE IF EXISTS ONLY public.contracts DROP CONSTRAINT IF EXISTS contracts_user_id_fkey;
ALTER TABLE IF EXISTS ONLY public.contract_files DROP CONSTRAINT IF EXISTS contract_files_contract_id_fkey;
ALTER TABLE IF EXISTS ONLY public.code_quality_findings DROP CONSTRAINT IF EXISTS code_quality_findings_scan_id_fkey;
DROP TRIGGER IF EXISTS trigger_update_dedup_group_updated_at ON public.deduplication_groups;
DROP TRIGGER IF EXISTS trigger_update_dedup_group_stats ON public.deduplication_group_members;
DROP INDEX IF EXISTS public.ix_vulns_contract_severity_status;
DROP INDEX IF EXISTS public.ix_vulnerabilities_user_classification;
DROP INDEX IF EXISTS public.ix_vulnerabilities_severity;
DROP INDEX IF EXISTS public.ix_vulnerabilities_scanner_id;
DROP INDEX IF EXISTS public.ix_vulnerabilities_scan_severity;
DROP INDEX IF EXISTS public.ix_vulnerabilities_scan_id;
DROP INDEX IF EXISTS public.ix_vulnerabilities_pattern_id;
DROP INDEX IF EXISTS public.ix_vulnerabilities_pattern_code;
DROP INDEX IF EXISTS public.ix_vulnerabilities_open;
DROP INDEX IF EXISTS public.ix_vulnerabilities_location_lookup;
DROP INDEX IF EXISTS public.ix_vulnerabilities_last_seen;
DROP INDEX IF EXISTS public.ix_vulnerabilities_is_primary;
DROP INDEX IF EXISTS public.ix_vulnerabilities_historical_lookup;
DROP INDEX IF EXISTS public.ix_vulnerabilities_fuzzy_dedup_lookup;
DROP INDEX IF EXISTS public.ix_vulnerabilities_function_name;
DROP INDEX IF EXISTS public.ix_vulnerabilities_first_seen;
DROP INDEX IF EXISTS public.ix_vulnerabilities_fingerprint_location_fuzzy;
DROP INDEX IF EXISTS public.ix_vulnerabilities_fingerprint_composite;
DROP INDEX IF EXISTS public.ix_vulnerabilities_fingerprint_code;
DROP INDEX IF EXISTS public.ix_vulnerabilities_file_path;
DROP INDEX IF EXISTS public.ix_vulnerabilities_false_positive_score;
DROP INDEX IF EXISTS public.ix_vulnerabilities_detector_id;
DROP INDEX IF EXISTS public.ix_vulnerabilities_dedup_lookup;
DROP INDEX IF EXISTS public.ix_vulnerabilities_dedup_group_id;
DROP INDEX IF EXISTS public.ix_vulnerabilities_contract_name;
DROP INDEX IF EXISTS public.ix_vulnerabilities_contract_id;
DROP INDEX IF EXISTS public.ix_vulnerabilities_category;
DROP INDEX IF EXISTS public.ix_vuln_trends_user_time_series;
DROP INDEX IF EXISTS public.ix_vuln_trends_user_id;
DROP INDEX IF EXISTS public.ix_vuln_trends_period_type;
DROP INDEX IF EXISTS public.ix_vuln_trends_period_start;
DROP INDEX IF EXISTS public.ix_vuln_trends_period_end;
DROP INDEX IF EXISTS public.ix_vuln_trends_pattern_time_series;
DROP INDEX IF EXISTS public.ix_vuln_trends_pattern_id;
DROP INDEX IF EXISTS public.ix_vuln_trends_contract_time_series;
DROP INDEX IF EXISTS public.ix_vuln_trends_contract_id;
DROP INDEX IF EXISTS public.ix_vuln_patterns_swc_id;
DROP INDEX IF EXISTS public.ix_vuln_patterns_severity;
DROP INDEX IF EXISTS public.ix_vuln_patterns_languages;
DROP INDEX IF EXISTS public.ix_vuln_patterns_keywords;
DROP INDEX IF EXISTS public.ix_vuln_patterns_is_active;
DROP INDEX IF EXISTS public.ix_vuln_patterns_cwe_id;
DROP INDEX IF EXISTS public.ix_vuln_patterns_category;
DROP INDEX IF EXISTS public.ix_vuln_classifications_vuln_id;
DROP INDEX IF EXISTS public.ix_vuln_classifications_user_id;
DROP INDEX IF EXISTS public.ix_vuln_classifications_tags;
DROP INDEX IF EXISTS public.ix_vuln_classifications_latest_lookup;
DROP INDEX IF EXISTS public.ix_vuln_classifications_is_latest;
DROP INDEX IF EXISTS public.ix_vuln_classifications_fix_status;
DROP INDEX IF EXISTS public.ix_vuln_classifications_created_at;
DROP INDEX IF EXISTS public.ix_vuln_classifications_classification;
DROP INDEX IF EXISTS public.ix_users_email;
DROP INDEX IF EXISTS public.ix_sessions_user_id;
DROP INDEX IF EXISTS public.ix_sessions_token;
DROP INDEX IF EXISTS public.ix_sessions_refresh_token;
DROP INDEX IF EXISTS public.ix_scans_user_status_created;
DROP INDEX IF EXISTS public.ix_scans_user_id;
DROP INDEX IF EXISTS public.ix_scans_user_completed;
DROP INDEX IF EXISTS public.ix_scans_scanners_used;
DROP INDEX IF EXISTS public.ix_scans_failed;
DROP INDEX IF EXISTS public.ix_scans_contract_id;
DROP INDEX IF EXISTS public.ix_saved_searches_user_id;
DROP INDEX IF EXISTS public.ix_saved_searches_created_at;
DROP INDEX IF EXISTS public.ix_projects_user_id;
DROP INDEX IF EXISTS public.ix_projects_name;
DROP INDEX IF EXISTS public.ix_projects_created_at;
DROP INDEX IF EXISTS public.ix_project_contracts_added;
DROP INDEX IF EXISTS public.ix_pattern_tool_mappings_scanner_id;
DROP INDEX IF EXISTS public.ix_pattern_tool_mappings_pattern_id;
DROP INDEX IF EXISTS public.ix_pattern_tool_mappings_is_active;
DROP INDEX IF EXISTS public.ix_pattern_tool_mappings_detector_id;
DROP INDEX IF EXISTS public.ix_gas_analysis_findings_scanner_id;
DROP INDEX IF EXISTS public.ix_gas_analysis_findings_scan_id;
DROP INDEX IF EXISTS public.ix_gas_analysis_findings_optimization_level;
DROP INDEX IF EXISTS public.ix_gas_analysis_findings_function_name;
DROP INDEX IF EXISTS public.ix_gas_analysis_file_path;
DROP INDEX IF EXISTS public.ix_gas_analysis_detector_id;
DROP INDEX IF EXISTS public.ix_gas_analysis_contract_name;
DROP INDEX IF EXISTS public.ix_gas_analysis_contract_id;
DROP INDEX IF EXISTS public.ix_fuzzing_results_test_name;
DROP INDEX IF EXISTS public.ix_fuzzing_results_status;
DROP INDEX IF EXISTS public.ix_fuzzing_results_scanner_id;
DROP INDEX IF EXISTS public.ix_fuzzing_results_scan_id;
DROP INDEX IF EXISTS public.ix_formal_verification_results_status;
DROP INDEX IF EXISTS public.ix_formal_verification_results_scanner_id;
DROP INDEX IF EXISTS public.ix_formal_verification_results_scan_id;
DROP INDEX IF EXISTS public.ix_formal_verification_results_proof_type;
DROP INDEX IF EXISTS public.ix_dedup_groups_verified;
DROP INDEX IF EXISTS public.ix_dedup_groups_strategy;
DROP INDEX IF EXISTS public.ix_dedup_groups_primary_vuln_id;
DROP INDEX IF EXISTS public.ix_dedup_groups_pattern_id;
DROP INDEX IF EXISTS public.ix_dedup_groups_first_detected;
DROP INDEX IF EXISTS public.ix_dedup_groups_fingerprint_lookup;
DROP INDEX IF EXISTS public.ix_dedup_groups_fingerprint_code;
DROP INDEX IF EXISTS public.ix_dedup_groups_contract_id;
DROP INDEX IF EXISTS public.ix_contracts_user_language_created;
DROP INDEX IF EXISTS public.ix_contracts_user_id;
DROP INDEX IF EXISTS public.ix_contracts_language;
DROP INDEX IF EXISTS public.ix_contracts_address;
DROP INDEX IF EXISTS public.ix_contract_files_contract_id;
DROP INDEX IF EXISTS public.ix_code_quality_findings_severity;
DROP INDEX IF EXISTS public.ix_code_quality_findings_scanner_id;
DROP INDEX IF EXISTS public.ix_code_quality_findings_scan_id;
DROP INDEX IF EXISTS public.ix_code_quality_findings_category;
DROP INDEX IF EXISTS public.idx_version_history_scanner;
DROP INDEX IF EXISTS public.idx_version_history_date;
DROP INDEX IF EXISTS public.idx_scanner_versions_type;
DROP INDEX IF EXISTS public.idx_scanner_versions_status;
DROP INDEX IF EXISTS public.idx_scanner_versions_ecosystem;
DROP INDEX IF EXISTS public.idx_release_tracking_scanner;
DROP INDEX IF EXISTS public.idx_release_tracking_applied;
DROP INDEX IF EXISTS public.idx_dedup_members_group;
DROP INDEX IF EXISTS public.idx_dedup_members_finding;
DROP INDEX IF EXISTS public.idx_dedup_members_canonical;
ALTER TABLE IF EXISTS ONLY public.vulnerability_trends DROP CONSTRAINT IF EXISTS vulnerability_trends_pkey;
ALTER TABLE IF EXISTS ONLY public.vulnerability_patterns DROP CONSTRAINT IF EXISTS vulnerability_patterns_pkey;
ALTER TABLE IF EXISTS ONLY public.vulnerability_classifications DROP CONSTRAINT IF EXISTS vulnerability_classifications_pkey;
ALTER TABLE IF EXISTS ONLY public.vulnerabilities DROP CONSTRAINT IF EXISTS vulnerabilities_pkey;
ALTER TABLE IF EXISTS ONLY public.users DROP CONSTRAINT IF EXISTS users_pkey;
ALTER TABLE IF EXISTS ONLY public.user_preferences DROP CONSTRAINT IF EXISTS user_preferences_pkey;
ALTER TABLE IF EXISTS ONLY public.vulnerability_trends DROP CONSTRAINT IF EXISTS uq_vuln_trends_pattern_contract_period;
ALTER TABLE IF EXISTS ONLY public.pattern_tool_mappings DROP CONSTRAINT IF EXISTS uq_pattern_tool_scanner_detector;
ALTER TABLE IF EXISTS ONLY public.sessions DROP CONSTRAINT IF EXISTS sessions_pkey;
ALTER TABLE IF EXISTS ONLY public.scans DROP CONSTRAINT IF EXISTS scans_pkey;
ALTER TABLE IF EXISTS ONLY public.scanner_versions DROP CONSTRAINT IF EXISTS scanner_versions_scanner_name_key;
ALTER TABLE IF EXISTS ONLY public.scanner_versions DROP CONSTRAINT IF EXISTS scanner_versions_pkey;
ALTER TABLE IF EXISTS ONLY public.scanner_version_history DROP CONSTRAINT IF EXISTS scanner_version_history_pkey;
ALTER TABLE IF EXISTS ONLY public.scanner_release_tracking DROP CONSTRAINT IF EXISTS scanner_release_tracking_scanner_name_release_version_key;
ALTER TABLE IF EXISTS ONLY public.scanner_release_tracking DROP CONSTRAINT IF EXISTS scanner_release_tracking_pkey;
ALTER TABLE IF EXISTS ONLY public.saved_searches DROP CONSTRAINT IF EXISTS saved_searches_pkey;
ALTER TABLE IF EXISTS ONLY public.projects DROP CONSTRAINT IF EXISTS projects_pkey;
ALTER TABLE IF EXISTS ONLY public.project_contracts DROP CONSTRAINT IF EXISTS project_contracts_pkey;
ALTER TABLE IF EXISTS ONLY public.pattern_tool_mappings DROP CONSTRAINT IF EXISTS pattern_tool_mappings_pkey;
ALTER TABLE IF EXISTS ONLY public.gas_analysis_findings DROP CONSTRAINT IF EXISTS gas_analysis_findings_pkey;
ALTER TABLE IF EXISTS ONLY public.fuzzing_results DROP CONSTRAINT IF EXISTS fuzzing_results_pkey;
ALTER TABLE IF EXISTS ONLY public.formal_verification_results DROP CONSTRAINT IF EXISTS formal_verification_results_pkey;
ALTER TABLE IF EXISTS ONLY public.deduplication_groups DROP CONSTRAINT IF EXISTS deduplication_groups_pkey;
ALTER TABLE IF EXISTS ONLY public.deduplication_group_members DROP CONSTRAINT IF EXISTS deduplication_group_members_pkey;
ALTER TABLE IF EXISTS ONLY public.deduplication_group_members DROP CONSTRAINT IF EXISTS deduplication_group_members_group_id_finding_id_key;
ALTER TABLE IF EXISTS ONLY public.contracts DROP CONSTRAINT IF EXISTS contracts_pkey;
ALTER TABLE IF EXISTS ONLY public.contract_files DROP CONSTRAINT IF EXISTS contract_files_pkey;
ALTER TABLE IF EXISTS ONLY public.code_quality_findings DROP CONSTRAINT IF EXISTS code_quality_findings_pkey;
ALTER TABLE IF EXISTS ONLY public.alembic_version DROP CONSTRAINT IF EXISTS alembic_version_pkc;
ALTER TABLE IF EXISTS public.scanner_versions ALTER COLUMN id DROP DEFAULT;
ALTER TABLE IF EXISTS public.scanner_version_history ALTER COLUMN id DROP DEFAULT;
ALTER TABLE IF EXISTS public.scanner_release_tracking ALTER COLUMN id DROP DEFAULT;
DROP TABLE IF EXISTS public.vulnerability_trends;
DROP TABLE IF EXISTS public.vulnerability_patterns;
DROP TABLE IF EXISTS public.vulnerability_classifications;
DROP TABLE IF EXISTS public.vulnerabilities;
DROP TABLE IF EXISTS public.users;
DROP TABLE IF EXISTS public.user_preferences;
DROP TABLE IF EXISTS public.sessions;
DROP TABLE IF EXISTS public.scans;
DROP SEQUENCE IF EXISTS public.scanner_versions_id_seq;
DROP VIEW IF EXISTS public.scanner_version_status;
DROP SEQUENCE IF EXISTS public.scanner_version_history_id_seq;
DROP TABLE IF EXISTS public.scanner_version_history;
DROP SEQUENCE IF EXISTS public.scanner_release_tracking_id_seq;
DROP TABLE IF EXISTS public.scanner_release_tracking;
DROP TABLE IF EXISTS public.saved_searches;
DROP TABLE IF EXISTS public.projects;
DROP TABLE IF EXISTS public.project_contracts;
DROP TABLE IF EXISTS public.pattern_tool_mappings;
DROP VIEW IF EXISTS public.outdated_scanners;
DROP TABLE IF EXISTS public.scanner_versions;
DROP TABLE IF EXISTS public.gas_analysis_findings;
DROP TABLE IF EXISTS public.fuzzing_results;
DROP TABLE IF EXISTS public.formal_verification_results;
DROP TABLE IF EXISTS public.deduplication_groups;
DROP TABLE IF EXISTS public.deduplication_group_members;
DROP TABLE IF EXISTS public.contracts;
DROP TABLE IF EXISTS public.contract_files;
DROP TABLE IF EXISTS public.code_quality_findings;
DROP TABLE IF EXISTS public.alembic_version;
DROP FUNCTION IF EXISTS public.update_deduplication_group_updated_at();
DROP FUNCTION IF EXISTS public.update_deduplication_group_stats();
DROP FUNCTION IF EXISTS public.record_scanner_update(p_scanner_name character varying, p_new_version character varying, p_new_image_tag character varying, p_change_type character varying, p_breaking boolean, p_detector_changes text, p_release_notes text);
DROP FUNCTION IF EXISTS public.check_scanner_version_update(p_scanner_name character varying, p_new_version character varying, p_new_image_tag character varying);
DROP TYPE IF EXISTS public.vulnerability_status;
DROP TYPE IF EXISTS public.vulnerability_severity;
DROP TYPE IF EXISTS public.scan_status;
DROP TYPE IF EXISTS public.contract_status;
DROP TYPE IF EXISTS public.contract_language;
-- *not* dropping schema, since initdb creates it
--
-- Name: public; Type: SCHEMA; Schema: -; Owner: postgres
--

-- *not* creating schema, since initdb creates it


ALTER SCHEMA public OWNER TO postgres;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA public IS '';


--
-- Name: contract_language; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.contract_language AS ENUM (
    'solidity',
    'vyper',
    'rust',
    'move',
    'cairo'
);


ALTER TYPE public.contract_language OWNER TO postgres;

--
-- Name: contract_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.contract_status AS ENUM (
    'uploaded',
    'pending',
    'scanning',
    'scanned',
    'failed'
);


ALTER TYPE public.contract_status OWNER TO postgres;

--
-- Name: scan_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.scan_status AS ENUM (
    'queued',
    'running',
    'completed',
    'failed'
);


ALTER TYPE public.scan_status OWNER TO postgres;

--
-- Name: vulnerability_severity; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.vulnerability_severity AS ENUM (
    'critical',
    'high',
    'medium',
    'low'
);


ALTER TYPE public.vulnerability_severity OWNER TO postgres;

--
-- Name: vulnerability_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.vulnerability_status AS ENUM (
    'open',
    'acknowledged',
    'fixed',
    'false_positive'
);


ALTER TYPE public.vulnerability_status OWNER TO postgres;

--
-- Name: check_scanner_version_update(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_scanner_version_update(p_scanner_name character varying, p_new_version character varying, p_new_image_tag character varying) RETURNS text
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.check_scanner_version_update(p_scanner_name character varying, p_new_version character varying, p_new_image_tag character varying) OWNER TO postgres;

--
-- Name: FUNCTION check_scanner_version_update(p_scanner_name character varying, p_new_version character varying, p_new_image_tag character varying); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.check_scanner_version_update(p_scanner_name character varying, p_new_version character varying, p_new_image_tag character varying) IS 'Check if a scanner version update is available';


--
-- Name: record_scanner_update(character varying, character varying, character varying, character varying, boolean, text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.record_scanner_update(p_scanner_name character varying, p_new_version character varying, p_new_image_tag character varying, p_change_type character varying DEFAULT 'minor'::character varying, p_breaking boolean DEFAULT false, p_detector_changes text DEFAULT NULL::text, p_release_notes text DEFAULT NULL::text) RETURNS text
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.record_scanner_update(p_scanner_name character varying, p_new_version character varying, p_new_image_tag character varying, p_change_type character varying, p_breaking boolean, p_detector_changes text, p_release_notes text) OWNER TO postgres;

--
-- Name: FUNCTION record_scanner_update(p_scanner_name character varying, p_new_version character varying, p_new_image_tag character varying, p_change_type character varying, p_breaking boolean, p_detector_changes text, p_release_notes text); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.record_scanner_update(p_scanner_name character varying, p_new_version character varying, p_new_image_tag character varying, p_change_type character varying, p_breaking boolean, p_detector_changes text, p_release_notes text) IS 'Record a scanner version update with history tracking';


--
-- Name: update_deduplication_group_stats(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_deduplication_group_stats() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        -- Update finding_count and scanner_count
        UPDATE deduplication_groups
        SET
            finding_count = (
                SELECT COUNT(*)
                FROM deduplication_group_members
                WHERE group_id = NEW.group_id
            ),
            scanner_count = (
                SELECT COUNT(DISTINCT v.scanner_id)
                FROM deduplication_group_members dgm
                JOIN vulnerabilities v ON dgm.finding_id = v.id
                WHERE dgm.group_id = NEW.group_id
            ),
            last_seen = NOW()
        WHERE id = NEW.group_id;
    ELSIF TG_OP = 'DELETE' THEN
        -- Update finding_count and scanner_count after deletion
        UPDATE deduplication_groups
        SET
            finding_count = (
                SELECT COUNT(*)
                FROM deduplication_group_members
                WHERE group_id = OLD.group_id
            ),
            scanner_count = (
                SELECT COUNT(DISTINCT v.scanner_id)
                FROM deduplication_group_members dgm
                JOIN vulnerabilities v ON dgm.finding_id = v.id
                WHERE dgm.group_id = OLD.group_id
            )
        WHERE id = OLD.group_id;
    END IF;

    RETURN NULL;
END;
$$;


ALTER FUNCTION public.update_deduplication_group_stats() OWNER TO postgres;

--
-- Name: update_deduplication_group_updated_at(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_deduplication_group_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_deduplication_group_updated_at() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: alembic_version; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.alembic_version (
    version_num character varying(32) NOT NULL
);


ALTER TABLE public.alembic_version OWNER TO postgres;

--
-- Name: code_quality_findings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.code_quality_findings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    scan_id uuid NOT NULL,
    scanner_id character varying(50) NOT NULL,
    severity character varying(20) NOT NULL,
    category character varying(50) NOT NULL,
    title text NOT NULL,
    description text NOT NULL,
    location jsonb NOT NULL,
    fix_suggestion text,
    rule_id character varying(100) NOT NULL,
    rule_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.code_quality_findings OWNER TO postgres;

--
-- Name: contract_files; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.contract_files (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    contract_id uuid NOT NULL,
    file_path character varying(500) NOT NULL,
    file_content text NOT NULL,
    is_main_file boolean DEFAULT false NOT NULL,
    file_size integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.contract_files OWNER TO postgres;

--
-- Name: contracts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.contracts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    name character varying(255) NOT NULL,
    address character varying(42),
    network character varying(50) NOT NULL,
    source_code text,
    bytecode text,
    lines_of_code integer NOT NULL,
    is_multi_file boolean DEFAULT false NOT NULL,
    main_file_path character varying(500),
    file_count integer DEFAULT 1 NOT NULL,
    total_lines_of_code integer DEFAULT 0 NOT NULL,
    language public.contract_language NOT NULL,
    compiler_version character varying(50),
    language_metadata jsonb,
    status public.contract_status NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.contracts OWNER TO postgres;

--
-- Name: deduplication_group_members; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.deduplication_group_members (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    group_id uuid NOT NULL,
    finding_id uuid NOT NULL,
    match_confidence character varying(20) NOT NULL,
    matched_fingerprints text,
    is_canonical boolean DEFAULT false NOT NULL,
    added_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT deduplication_group_members_match_confidence_check CHECK (((match_confidence)::text = ANY ((ARRAY['exact'::character varying, 'high'::character varying, 'medium'::character varying, 'low'::character varying])::text[])))
);


ALTER TABLE public.deduplication_group_members OWNER TO postgres;

--
-- Name: TABLE deduplication_group_members; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.deduplication_group_members IS 'Phase 4E: Many-to-many relationship between deduplication groups and vulnerabilities';


--
-- Name: COLUMN deduplication_group_members.match_confidence; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.deduplication_group_members.match_confidence IS 'Confidence level of this specific finding match (exact, high, medium, low)';


--
-- Name: COLUMN deduplication_group_members.matched_fingerprints; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.deduplication_group_members.matched_fingerprints IS 'JSON array of fingerprint fields that matched for this specific finding';


--
-- Name: COLUMN deduplication_group_members.is_canonical; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.deduplication_group_members.is_canonical IS 'Whether this is the canonical (primary) finding for the group';


--
-- Name: deduplication_groups; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.deduplication_groups (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    primary_vulnerability_id uuid NOT NULL,
    contract_id uuid NOT NULL,
    pattern_id character varying(20),
    group_size integer DEFAULT 1 NOT NULL,
    strategy character varying(20) NOT NULL,
    confidence double precision NOT NULL,
    fingerprint_code character varying(64),
    fingerprint_ast character varying(64),
    fingerprint_semantic character varying(64),
    severity_distribution jsonb,
    scanner_distribution jsonb,
    first_detected timestamp with time zone DEFAULT now() NOT NULL,
    last_updated timestamp with time zone DEFAULT now() NOT NULL,
    verified boolean DEFAULT false NOT NULL,
    verified_by uuid,
    verified_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.deduplication_groups OWNER TO postgres;

--
-- Name: TABLE deduplication_groups; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.deduplication_groups IS 'Phase 4E: Groups of duplicate vulnerability findings across different scanners';


--
-- Name: formal_verification_results; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.formal_verification_results (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    scan_id uuid NOT NULL,
    scanner_id character varying(50) NOT NULL,
    property_name character varying(255) NOT NULL,
    status character varying(20) NOT NULL,
    proof_type character varying(50) NOT NULL,
    description text NOT NULL,
    counterexample text,
    verification_time double precision NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.formal_verification_results OWNER TO postgres;

--
-- Name: fuzzing_results; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.fuzzing_results (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    scan_id uuid NOT NULL,
    scanner_id character varying(50) NOT NULL,
    test_name character varying(255) NOT NULL,
    status character varying(20) NOT NULL,
    executions integer NOT NULL,
    coverage_percentage double precision NOT NULL,
    edge_cases_found jsonb DEFAULT '[]'::jsonb NOT NULL,
    failure_trace text,
    seed integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.fuzzing_results OWNER TO postgres;

--
-- Name: gas_analysis_findings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.gas_analysis_findings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    scan_id uuid NOT NULL,
    scanner_id character varying(50) NOT NULL,
    function_name character varying(255) NOT NULL,
    gas_cost integer NOT NULL,
    optimization_level character varying(20) NOT NULL,
    optimization_suggestion text NOT NULL,
    potential_savings integer NOT NULL,
    location jsonb NOT NULL,
    code_example text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    contract_id uuid NOT NULL,
    detector_id character varying(200),
    file_path character varying(500),
    contract_name character varying(200)
);


ALTER TABLE public.gas_analysis_findings OWNER TO postgres;

--
-- Name: COLUMN gas_analysis_findings.contract_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.gas_analysis_findings.contract_id IS 'Contract ID for this gas optimization finding';


--
-- Name: COLUMN gas_analysis_findings.detector_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.gas_analysis_findings.detector_id IS 'Detector ID that found this optimization (extracted by parser)';


--
-- Name: COLUMN gas_analysis_findings.file_path; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.gas_analysis_findings.file_path IS 'Source file path where optimization applies (extracted by parser)';


--
-- Name: COLUMN gas_analysis_findings.contract_name; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.gas_analysis_findings.contract_name IS 'Contract name where optimization applies (for enrichment context)';


--
-- Name: scanner_versions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.scanner_versions (
    id integer NOT NULL,
    scanner_name character varying(100) NOT NULL,
    scanner_type character varying(50) NOT NULL,
    ecosystem character varying(50) NOT NULL,
    language character varying(50) NOT NULL,
    current_version character varying(50) NOT NULL,
    latest_version character varying(50),
    version_status character varying(20) DEFAULT 'up-to-date'::character varying,
    image_tag character varying(50) NOT NULL,
    image_name character varying(200) NOT NULL,
    developer character varying(200),
    repository_url text,
    documentation_url text,
    detector_count integer DEFAULT 0,
    integrated_detector_count integer DEFAULT 0,
    integration_percentage numeric(5,2) GENERATED ALWAYS AS (
CASE
    WHEN (detector_count > 0) THEN (((integrated_detector_count)::numeric / (detector_count)::numeric) * (100)::numeric)
    ELSE (0)::numeric
END) STORED,
    last_checked_at timestamp with time zone,
    last_updated_at timestamp with time zone DEFAULT now(),
    created_at timestamp with time zone DEFAULT now(),
    notes text,
    CONSTRAINT valid_ecosystem CHECK (((ecosystem)::text = ANY ((ARRAY['evm'::character varying, 'solana'::character varying, 'cairo'::character varying, 'move'::character varying, 'multi'::character varying])::text[]))),
    CONSTRAINT valid_integration_counts CHECK ((integrated_detector_count <= detector_count)),
    CONSTRAINT valid_scanner_type CHECK (((scanner_type)::text = ANY ((ARRAY['static-analysis'::character varying, 'fuzzer'::character varying, 'formal-verification'::character varying])::text[]))),
    CONSTRAINT valid_version_status CHECK (((version_status)::text = ANY ((ARRAY['up-to-date'::character varying, 'outdated'::character varying, 'unknown'::character varying, 'deprecated'::character varying])::text[])))
);


ALTER TABLE public.scanner_versions OWNER TO postgres;

--
-- Name: TABLE scanner_versions; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.scanner_versions IS 'Tracks current scanner versions and integration status for BlockSecOps platform';


--
-- Name: COLUMN scanner_versions.version_status; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.scanner_versions.version_status IS 'Current version status: up-to-date, outdated, unknown, deprecated';


--
-- Name: COLUMN scanner_versions.integration_percentage; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.scanner_versions.integration_percentage IS 'Automatically calculated percentage of integrated detectors';


--
-- Name: outdated_scanners; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.outdated_scanners AS
 SELECT scanner_versions.scanner_name,
    scanner_versions.scanner_type,
    scanner_versions.ecosystem,
    scanner_versions.current_version,
    scanner_versions.latest_version,
    scanner_versions.last_checked_at,
    scanner_versions.notes
   FROM public.scanner_versions
  WHERE ((scanner_versions.version_status)::text = 'outdated'::text)
  ORDER BY scanner_versions.ecosystem, scanner_versions.scanner_type, scanner_versions.scanner_name;


ALTER TABLE public.outdated_scanners OWNER TO postgres;

--
-- Name: VIEW outdated_scanners; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON VIEW public.outdated_scanners IS 'Quick view of scanners needing updates';


--
-- Name: pattern_tool_mappings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pattern_tool_mappings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    pattern_id character varying(20) NOT NULL,
    scanner_id character varying(50) NOT NULL,
    detector_id character varying(200) NOT NULL,
    confidence_threshold double precision,
    match_type character varying(20) DEFAULT 'exact'::character varying NOT NULL,
    keywords_override text[],
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


ALTER TABLE public.pattern_tool_mappings OWNER TO postgres;

--
-- Name: project_contracts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.project_contracts (
    project_id uuid NOT NULL,
    contract_id uuid NOT NULL,
    added_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.project_contracts OWNER TO postgres;

--
-- Name: projects; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.projects (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    user_id uuid NOT NULL,
    settings jsonb DEFAULT '{}'::jsonb NOT NULL,
    default_scan_profile character varying(50) DEFAULT 'standard'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.projects OWNER TO postgres;

--
-- Name: saved_searches; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.saved_searches (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    search_params jsonb NOT NULL,
    last_executed_at timestamp with time zone,
    execution_count integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.saved_searches OWNER TO postgres;

--
-- Name: TABLE saved_searches; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.saved_searches IS 'User-saved search queries for quick re-execution';


--
-- Name: COLUMN saved_searches.search_params; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.saved_searches.search_params IS 'JSON object containing SearchRequest parameters';


--
-- Name: scanner_release_tracking; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.scanner_release_tracking (
    id integer NOT NULL,
    scanner_name character varying(100) NOT NULL,
    release_version character varying(50) NOT NULL,
    release_date date,
    release_url text,
    is_prerelease boolean DEFAULT false,
    checked_at timestamp with time zone DEFAULT now(),
    applied_to_platform boolean DEFAULT false,
    applied_at timestamp with time zone,
    release_notes text
);


ALTER TABLE public.scanner_release_tracking OWNER TO postgres;

--
-- Name: TABLE scanner_release_tracking; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.scanner_release_tracking IS 'Tracks upstream releases for version monitoring';


--
-- Name: scanner_release_tracking_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.scanner_release_tracking_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.scanner_release_tracking_id_seq OWNER TO postgres;

--
-- Name: scanner_release_tracking_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.scanner_release_tracking_id_seq OWNED BY public.scanner_release_tracking.id;


--
-- Name: scanner_version_history; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.scanner_version_history (
    id integer NOT NULL,
    scanner_name character varying(100) NOT NULL,
    old_version character varying(50),
    new_version character varying(50) NOT NULL,
    old_image_tag character varying(50),
    new_image_tag character varying(50) NOT NULL,
    change_type character varying(50) NOT NULL,
    breaking_changes boolean DEFAULT false,
    detector_changes text,
    updated_at timestamp with time zone DEFAULT now(),
    updated_by character varying(100),
    changelog_url text,
    release_notes text
);


ALTER TABLE public.scanner_version_history OWNER TO postgres;

--
-- Name: TABLE scanner_version_history; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.scanner_version_history IS 'Audit trail of all scanner version updates';


--
-- Name: COLUMN scanner_version_history.change_type; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.scanner_version_history.change_type IS 'Type of version change: major, minor, patch, image-only';


--
-- Name: scanner_version_history_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.scanner_version_history_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.scanner_version_history_id_seq OWNER TO postgres;

--
-- Name: scanner_version_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.scanner_version_history_id_seq OWNED BY public.scanner_version_history.id;


--
-- Name: scanner_version_status; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.scanner_version_status AS
 SELECT sv.scanner_name,
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
    COALESCE(( SELECT count(*) AS count
           FROM public.scanner_release_tracking srt
          WHERE (((srt.scanner_name)::text = (sv.scanner_name)::text) AND (srt.applied_to_platform = false) AND (srt.is_prerelease = false))), (0)::bigint) AS pending_releases
   FROM public.scanner_versions sv
  ORDER BY sv.ecosystem, sv.scanner_type, sv.scanner_name;


ALTER TABLE public.scanner_version_status OWNER TO postgres;

--
-- Name: VIEW scanner_version_status; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON VIEW public.scanner_version_status IS 'Overview of scanner version status with pending releases';


--
-- Name: scanner_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.scanner_versions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.scanner_versions_id_seq OWNER TO postgres;

--
-- Name: scanner_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.scanner_versions_id_seq OWNED BY public.scanner_versions.id;


--
-- Name: scans; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.scans (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    contract_id uuid NOT NULL,
    user_id uuid NOT NULL,
    scan_type character varying(50) NOT NULL,
    status public.scan_status NOT NULL,
    started_at timestamp with time zone,
    completed_at timestamp with time zone,
    error_message text,
    critical_count integer NOT NULL,
    high_count integer NOT NULL,
    medium_count integer NOT NULL,
    low_count integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    scanners_used character varying(50)[],
    scan_config jsonb DEFAULT '{}'::jsonb,
    duration_seconds integer
);


ALTER TABLE public.scans OWNER TO postgres;

--
-- Name: COLUMN scans.scanners_used; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.scans.scanners_used IS 'Array of scanner IDs used in this scan (e.g., {slither, mythril})';


--
-- Name: COLUMN scans.scan_config; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.scans.scan_config IS 'Scanner configuration and parameters used for this scan';


--
-- Name: COLUMN scans.duration_seconds; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.scans.duration_seconds IS 'Scan duration in seconds (completed_at - started_at)';


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sessions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    token character varying(500) NOT NULL,
    refresh_token character varying(500),
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    is_revoked boolean DEFAULT false NOT NULL
);


ALTER TABLE public.sessions OWNER TO postgres;

--
-- Name: user_preferences; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.user_preferences (
    user_id uuid NOT NULL,
    email_notifications boolean DEFAULT true NOT NULL,
    scan_completion_notifications boolean DEFAULT true NOT NULL,
    critical_vulnerability_alerts boolean DEFAULT true NOT NULL,
    weekly_digest boolean DEFAULT false NOT NULL,
    theme character varying(20) DEFAULT 'light'::character varying NOT NULL,
    timezone character varying(50) DEFAULT 'UTC'::character varying NOT NULL,
    language character varying(10) DEFAULT 'en'::character varying NOT NULL,
    preferences jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.user_preferences OWNER TO postgres;

--
-- Name: TABLE user_preferences; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.user_preferences IS 'User-specific settings and preferences';


--
-- Name: COLUMN user_preferences.preferences; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.user_preferences.preferences IS 'Additional user preferences as JSON';


--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    email character varying(255) NOT NULL,
    hashed_password character varying(255) NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    is_superuser boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: vulnerabilities; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.vulnerabilities (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    scan_id uuid NOT NULL,
    contract_id uuid NOT NULL,
    title character varying(255) NOT NULL,
    description text NOT NULL,
    severity public.vulnerability_severity NOT NULL,
    status public.vulnerability_status NOT NULL,
    swc_id character varying(20),
    line_number integer,
    code_snippet text,
    recommendation text,
    detected_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    category character varying(100),
    confidence numeric(3,2),
    pattern_id character varying(20),
    classification_confidence double precision,
    classification_method character varying(20),
    fingerprint_code character varying(64),
    fingerprint_ast character varying(64),
    fingerprint_location character varying(64),
    fingerprint_semantic character varying(64),
    fingerprint_composite character varying(64),
    deduplication_group_id uuid,
    is_primary boolean DEFAULT true NOT NULL,
    duplicate_count integer DEFAULT 0 NOT NULL,
    deduplication_strategy character varying(20),
    similarity_score double precision,
    false_positive_score double precision,
    false_positive_reasons text[],
    scanner_confidence double precision,
    tool_consensus_score double precision,
    first_seen timestamp with time zone,
    last_seen timestamp with time zone,
    occurrence_count integer DEFAULT 1 NOT NULL,
    was_fixed boolean DEFAULT false NOT NULL,
    reintroduced boolean DEFAULT false NOT NULL,
    user_classification character varying(20),
    user_feedback text,
    fix_verified boolean DEFAULT false NOT NULL,
    fix_verified_at timestamp with time zone,
    fix_verified_by uuid,
    scanner_id character varying(50),
    detector_id character varying(200),
    raw_output jsonb,
    normalization_version character varying(20),
    file_path character varying(500),
    function_name character varying(200),
    contract_name character varying(200),
    fingerprint_location_fuzzy character varying(64),
    pattern_code character varying(20)
);


ALTER TABLE public.vulnerabilities OWNER TO postgres;

--
-- Name: COLUMN vulnerabilities.category; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.vulnerabilities.category IS 'Vulnerability type category (e.g., reentrancy, access_control, arithmetic)';


--
-- Name: COLUMN vulnerabilities.confidence; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.vulnerabilities.confidence IS 'Scanner confidence score (0.0 to 1.0, where 1.0 is highest confidence)';


--
-- Name: COLUMN vulnerabilities.file_path; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.vulnerabilities.file_path IS 'Source file path where vulnerability was detected (extracted by parser)';


--
-- Name: COLUMN vulnerabilities.function_name; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.vulnerabilities.function_name IS 'Function name where vulnerability exists (for enrichment context)';


--
-- Name: COLUMN vulnerabilities.contract_name; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.vulnerabilities.contract_name IS 'Contract name where vulnerability exists (for enrichment context)';


--
-- Name: vulnerability_classifications; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.vulnerability_classifications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    vulnerability_id uuid NOT NULL,
    user_id uuid,
    classification character varying(20) NOT NULL,
    previous_classification character varying(20),
    confidence double precision,
    feedback_text text,
    tags character varying(50)[],
    fix_status character varying(20),
    fix_commit_hash character varying(64),
    fix_verified boolean DEFAULT false NOT NULL,
    fix_verified_at timestamp with time zone,
    was_actually_vulnerable boolean,
    exploitability_score double precision,
    business_impact character varying(20),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    is_latest boolean DEFAULT true NOT NULL
);


ALTER TABLE public.vulnerability_classifications OWNER TO postgres;

--
-- Name: vulnerability_patterns; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.vulnerability_patterns (
    id character varying(20) NOT NULL,
    name character varying(200) NOT NULL,
    description text NOT NULL,
    category character varying(50) NOT NULL,
    severity character varying(20) NOT NULL,
    swc_id character varying(20),
    cwe_id character varying(20),
    owasp_category character varying(100),
    remediation text,
    fix_examples jsonb,
    "references" jsonb,
    detection_methods character varying(50)[],
    false_positive_rate double precision DEFAULT '0'::double precision,
    affected_languages character varying(20)[] NOT NULL,
    semantic_description text,
    keywords text[],
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


ALTER TABLE public.vulnerability_patterns OWNER TO postgres;

--
-- Name: vulnerability_trends; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.vulnerability_trends (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    pattern_id character varying(20) NOT NULL,
    contract_id uuid,
    user_id uuid,
    period_start timestamp with time zone NOT NULL,
    period_end timestamp with time zone NOT NULL,
    period_type character varying(20) NOT NULL,
    total_occurrences integer DEFAULT 0 NOT NULL,
    unique_contracts integer DEFAULT 0 NOT NULL,
    new_occurrences integer DEFAULT 0 NOT NULL,
    reintroduced_occurrences integer DEFAULT 0 NOT NULL,
    critical_count integer DEFAULT 0 NOT NULL,
    high_count integer DEFAULT 0 NOT NULL,
    medium_count integer DEFAULT 0 NOT NULL,
    low_count integer DEFAULT 0 NOT NULL,
    open_count integer DEFAULT 0 NOT NULL,
    fixed_count integer DEFAULT 0 NOT NULL,
    false_positive_count integer DEFAULT 0 NOT NULL,
    acknowledged_count integer DEFAULT 0 NOT NULL,
    scanner_distribution jsonb,
    avg_time_to_fix double precision,
    fix_rate double precision,
    reintroduction_rate double precision,
    avg_false_positive_score double precision,
    avg_confidence double precision,
    duplicate_rate double precision,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.vulnerability_trends OWNER TO postgres;

--
-- Name: scanner_release_tracking id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.scanner_release_tracking ALTER COLUMN id SET DEFAULT nextval('public.scanner_release_tracking_id_seq'::regclass);


--
-- Name: scanner_version_history id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.scanner_version_history ALTER COLUMN id SET DEFAULT nextval('public.scanner_version_history_id_seq'::regclass);


--
-- Name: scanner_versions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.scanner_versions ALTER COLUMN id SET DEFAULT nextval('public.scanner_versions_id_seq'::regclass);


--
-- Data for Name: alembic_version; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.alembic_version (version_num) FROM stdin;
011
\.


--
-- Data for Name: code_quality_findings; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.code_quality_findings (id, scan_id, scanner_id, severity, category, title, description, location, fix_suggestion, rule_id, rule_url, created_at) FROM stdin;
\.


--
-- Data for Name: contract_files; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.contract_files (id, contract_id, file_path, file_content, is_main_file, file_size, created_at) FROM stdin;
\.


--
-- Data for Name: contracts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.contracts (id, user_id, name, address, network, source_code, bytecode, lines_of_code, is_multi_file, main_file_path, file_count, total_lines_of_code, language, compiler_version, language_metadata, status, created_at, updated_at) FROM stdin;
86f9a16f-7896-4115-b321-adf9db382682	ab45210a-44a1-490e-bd5f-18135cdc3c91	ReEntrancy Contract	\N	ethereum	// SPDX-License-Identifier: MIT\npragma solidity ^0.8.0;\n\n/**\n * @title Reentrancy Vulnerability Example\n * @dev VULNERABLE - DO NOT USE IN PRODUCTION\n *\n * This contract is vulnerable to reentrancy attacks.\n * An attacker can recursively call withdraw() before the balance is updated.\n */\ncontract VulnerableBank {\n    mapping(address => uint256) public balances;\n\n    function deposit() public payable {\n        balances[msg.sender] += msg.value;\n    }\n\n    // VULNERABLE: State update happens after external call\n    function withdraw() public {\n        uint256 amount = balances[msg.sender];\n        require(amount > 0, "Insufficient balance");\n\n        // VULNERABILITY: External call before state update\n        (bool success, ) = msg.sender.call{value: amount}("");\n        require(success, "Transfer failed");\n\n        // State update happens too late\n        balances[msg.sender] = 0;\n    }\n\n    function getBalance() public view returns (uint256) {\n        return address(this).balance;\n    }\n}\n\n/**\n * @title Reentrancy Attacker\n * @dev Example attacker contract that exploits the reentrancy vulnerability\n */\ncontract ReentrancyAttacker {\n    VulnerableBank public vulnerableBank;\n    uint256 public attackCount;\n\n    constructor(address _vulnerableBankAddress) {\n        vulnerableBank = VulnerableBank(_vulnerableBankAddress);\n    }\n\n    function attack() public payable {\n        require(msg.value >= 1 ether, "Need at least 1 ether to attack");\n        vulnerableBank.deposit{value: msg.value}();\n        vulnerableBank.withdraw();\n    }\n\n    // Fallback function that re-enters the withdraw function\n    receive() external payable {\n        if (address(vulnerableBank).balance >= 1 ether && attackCount < 5) {\n            attackCount++;\n            vulnerableBank.withdraw();\n        }\n    }\n\n    function getBalance() public view returns (uint256) {\n        return address(this).balance;\n    }\n}\n	\N	65	f	\N	1	0	solidity	\N	\N	scanned	2025-10-16 21:57:40.548351+00	2025-10-16 22:15:51.755661+00
af250661-1a6a-4989-985b-7e73b6e8f306	27850871-1cd4-4804-9c1d-6cf8fb90fbd2	TestPDFContract	\N	ethereum	pragma solidity ^0.8.0;\n\ncontract Test {\n    function test() public {\n        // test\n    }\n}	\N	7	f	\N	1	0	solidity	\N	null	scanned	2025-10-17 14:51:40.447323+00	2025-10-17 14:52:06.322439+00
fc783138-6c5a-4dce-b469-9fdf46020f14	ab45210a-44a1-490e-bd5f-18135cdc3c91	Denial of Service	\N	ethereum	// SPDX-License-Identifier: MIT\npragma solidity ^0.8.0;\n\n/**\n * @title Denial of Service Vulnerability Examples\n * @dev VULNERABLE - DO NOT USE IN PRODUCTION\n *\n * This contract demonstrates various DoS attack vectors.\n */\ncontract VulnerableAuction {\n    address public currentLeader;\n    uint256 public currentBid;\n\n    // VULNERABLE: DoS by refusing payment\n    function bid() public payable {\n        require(msg.value > currentBid, "Bid too low");\n\n        // VULNERABILITY: Refund can fail, blocking new bids\n        if (currentLeader != address(0)) {\n            payable(currentLeader).transfer(currentBid);\n        }\n\n        currentLeader = msg.sender;\n        currentBid = msg.value;\n    }\n}\n\n/**\n * @title DoS by Gas Limit\n * @dev Shows unbounded loop vulnerability\n */\ncontract VulnerableDistributor {\n    address[] public shareholders;\n    mapping(address => uint256) public shares;\n\n    function addShareholder(address _shareholder, uint256 _shares) public {\n        shareholders.push(_shareholder);\n        shares[_shareholder] = _shares;\n    }\n\n    // VULNERABLE: Unbounded loop can exceed gas limit\n    function distributeRewards() public payable {\n        uint256 totalShares = 0;\n\n        // VULNERABILITY: As shareholders array grows, this can exceed gas limit\n        for (uint256 i = 0; i < shareholders.length; i++) {\n            totalShares += shares[shareholders[i]];\n        }\n\n        for (uint256 i = 0; i < shareholders.length; i++) {\n            uint256 reward = (msg.value * shares[shareholders[i]]) / totalShares;\n            payable(shareholders[i]).transfer(reward);\n        }\n    }\n}\n\n/**\n * @title DoS by Block Gas Limit\n * @dev Shows vulnerability with array operations\n */\ncontract VulnerableRegistry {\n    address[] public users;\n    mapping(address => bool) public registered;\n\n    function register() public {\n        require(!registered[msg.sender], "Already registered");\n        users.push(msg.sender);\n        registered[msg.sender] = true;\n    }\n\n    // VULNERABLE: Deleting large arrays consumes massive gas\n    function reset() public {\n        // VULNERABILITY: Can exceed block gas limit with large arrays\n        for (uint256 i = 0; i < users.length; i++) {\n            registered[users[i]] = false;\n        }\n        delete users;\n    }\n\n    // VULNERABLE: Unbounded iteration\n    function getUserCount() public view returns (uint256) {\n        uint256 count = 0;\n        // VULNERABILITY: Reading entire array can exceed gas limit\n        for (uint256 i = 0; i < users.length; i++) {\n            if (registered[users[i]]) {\n                count++;\n            }\n        }\n        return count;\n    }\n}\n\n/**\n * @title DoS by External Contract\n * @dev Shows vulnerability from calling malicious contracts\n */\ncontract VulnerablePaymentSplitter {\n    address[] public recipients;\n\n    function addRecipient(address _recipient) public {\n        recipients.push(_recipient);\n    }\n\n    // VULNERABLE: One malicious recipient can block all payments\n    function splitPayment() public payable {\n        uint256 share = msg.value / recipients.length;\n\n        // VULNERABILITY: If any recipient reverts, all payments fail\n        for (uint256 i = 0; i < recipients.length; i++) {\n            payable(recipients[i]).transfer(share);\n        }\n    }\n}\n\n/**\n * @title Malicious Recipient for DoS Attack\n * @dev Contract that rejects payments to cause DoS\n */\ncontract MaliciousBidder {\n    VulnerableAuction public auction;\n\n    constructor(address _auctionAddress) {\n        auction = VulnerableAuction(_auctionAddress);\n    }\n\n    function attack() public payable {\n        auction.bid{value: msg.value}();\n    }\n\n    // Reject all payments - this prevents anyone else from bidding\n    receive() external payable {\n        revert("I will never give up my lead!");\n    }\n}\n	\N	134	f	\N	1	0	solidity	\N	\N	scanned	2025-10-16 23:33:46.167994+00	2025-10-17 18:21:41.482781+00
43195d13-0923-4e91-9008-cb6ccd854b66	56bc0604-49bc-4a73-8b4f-69fc3386a0f8	ReEntrancy Contract	\N	ethereum	// SPDX-License-Identifier: MIT\npragma solidity ^0.8.0;\n\n/**\n * @title Reentrancy Vulnerability Example\n * @dev VULNERABLE - DO NOT USE IN PRODUCTION\n *\n * This contract is vulnerable to reentrancy attacks.\n * An attacker can recursively call withdraw() before the balance is updated.\n */\ncontract VulnerableBank {\n    mapping(address => uint256) public balances;\n\n    function deposit() public payable {\n        balances[msg.sender] += msg.value;\n    }\n\n    // VULNERABLE: State update happens after external call\n    function withdraw() public {\n        uint256 amount = balances[msg.sender];\n        require(amount > 0, "Insufficient balance");\n\n        // VULNERABILITY: External call before state update\n        (bool success, ) = msg.sender.call{value: amount}("");\n        require(success, "Transfer failed");\n\n        // State update happens too late\n        balances[msg.sender] = 0;\n    }\n\n    function getBalance() public view returns (uint256) {\n        return address(this).balance;\n    }\n}\n\n/**\n * @title Reentrancy Attacker\n * @dev Example attacker contract that exploits the reentrancy vulnerability\n */\ncontract ReentrancyAttacker {\n    VulnerableBank public vulnerableBank;\n    uint256 public attackCount;\n\n    constructor(address _vulnerableBankAddress) {\n        vulnerableBank = VulnerableBank(_vulnerableBankAddress);\n    }\n\n    function attack() public payable {\n        require(msg.value >= 1 ether, "Need at least 1 ether to attack");\n        vulnerableBank.deposit{value: msg.value}();\n        vulnerableBank.withdraw();\n    }\n\n    // Fallback function that re-enters the withdraw function\n    receive() external payable {\n        if (address(vulnerableBank).balance >= 1 ether && attackCount < 5) {\n            attackCount++;\n            vulnerableBank.withdraw();\n        }\n    }\n\n    function getBalance() public view returns (uint256) {\n        return address(this).balance;\n    }\n}\n	\N	65	f	\N	1	0	solidity	0.8.0	{"license": "MIT", "detection_method": "extension", "detection_confidence": 0.95}	scanned	2025-10-17 21:14:17.340604+00	2025-10-17 21:15:16.150978+00
4557d54f-bc37-4e82-819f-32a9a5137315	56bc0604-49bc-4a73-8b4f-69fc3386a0f8	Front Running	\N	ethereum	// SPDX-License-Identifier: MIT\npragma solidity ^0.8.0;\n\n/**\n * @title Front-Running Vulnerability Example\n * @dev VULNERABLE - DO NOT USE IN PRODUCTION\n *\n * This contract is vulnerable to front-running attacks where attackers\n * can see pending transactions and submit their own with higher gas fees.\n */\ncontract VulnerablePuzzle {\n    bytes32 public solutionHash;\n    uint256 public reward = 10 ether;\n    address public owner;\n    bool public solved;\n\n    constructor(bytes32 _solutionHash) payable {\n        solutionHash = _solutionHash;\n        owner = msg.sender;\n    }\n\n    // VULNERABLE: Solution is visible in mempool before confirmation\n    function submitSolution(string memory _solution) public {\n        require(!solved, "Already solved");\n\n        // VULNERABILITY: Anyone can see the solution in the mempool and front-run it\n        require(keccak256(abi.encodePacked(_solution)) == solutionHash, "Incorrect solution");\n\n        solved = true;\n        payable(msg.sender).transfer(reward);\n    }\n\n    receive() external payable {}\n}\n\n/**\n * @title Front-Running in DEX\n * @dev Shows front-running vulnerability in token swaps\n */\ncontract VulnerableDEX {\n    mapping(address => uint256) public tokenABalance;\n    mapping(address => uint256) public tokenBBalance;\n    uint256 public tokenAReserve = 1000 ether;\n    uint256 public tokenBReserve = 1000 ether;\n\n    // Simplified constant product AMM\n    function getSwapAmount(uint256 _tokenAAmount) public view returns (uint256) {\n        // x * y = k\n        uint256 k = tokenAReserve * tokenBReserve;\n        uint256 newTokenAReserve = tokenAReserve + _tokenAAmount;\n        uint256 newTokenBReserve = k / newTokenAReserve;\n        return tokenBReserve - newTokenBReserve;\n    }\n\n    // VULNERABLE: Transaction ordering dependency\n    function swapAforB(uint256 _tokenAAmount, uint256 _minTokenBAmount) public {\n        uint256 tokenBAmount = getSwapAmount(_tokenAAmount);\n\n        // VULNERABILITY: Front-runner can see this transaction and swap before it,\n        // causing the price to move and potentially causing this transaction to fail\n        // or execute at a worse rate\n        require(tokenBAmount >= _minTokenBAmount, "Slippage too high");\n\n        tokenABalance[msg.sender] -= _tokenAAmount;\n        tokenBBalance[msg.sender] += tokenBAmount;\n\n        tokenAReserve += _tokenAAmount;\n        tokenBReserve -= tokenBAmount;\n    }\n\n    function deposit(uint256 _tokenA, uint256 _tokenB) public {\n        tokenABalance[msg.sender] += _tokenA;\n        tokenBBalance[msg.sender] += _tokenB;\n    }\n}\n\n/**\n * @title Transaction Ordering Dependence\n * @dev Shows vulnerability where transaction order affects outcome\n */\ncontract VulnerableICO {\n    uint256 public price = 1 ether;\n    uint256 public tokensAvailable = 1000;\n    mapping(address => uint256) public balances;\n    address public owner;\n\n    constructor() {\n        owner = msg.sender;\n    }\n\n    // VULNERABLE: Price can be front-run\n    function updatePrice(uint256 _newPrice) public {\n        require(msg.sender == owner, "Not owner");\n        // VULNERABILITY: Users buying tokens can be front-run by owner increasing price\n        price = _newPrice;\n    }\n\n    function buyTokens(uint256 _amount) public payable {\n        require(tokensAvailable >= _amount, "Not enough tokens");\n        // VULNERABILITY: Price might change between when user submits transaction\n        // and when it's mined\n        require(msg.value >= price * _amount, "Insufficient payment");\n\n        tokensAvailable -= _amount;\n        balances[msg.sender] += _amount;\n    }\n}\n\n/**\n * @title ERC20 Approval Front-Running\n * @dev Shows approve/transferFrom race condition\n */\ncontract VulnerableERC20 {\n    mapping(address => uint256) public balances;\n    mapping(address => mapping(address => uint256)) public allowances;\n\n    string public name = "Vulnerable Token";\n    string public symbol = "VULN";\n\n    constructor(uint256 _initialSupply) {\n        balances[msg.sender] = _initialSupply;\n    }\n\n    // VULNERABLE: Changing allowance can be front-run\n    function approve(address _spender, uint256 _amount) public returns (bool) {\n        // VULNERABILITY: If user tries to change allowance from N to M,\n        // spender can front-run by:\n        // 1. transferFrom N tokens (old allowance)\n        // 2. Let approve transaction execute\n        // 3. transferFrom M tokens (new allowance)\n        // Result: spender transferred N+M tokens instead of M\n        allowances[msg.sender][_spender] = _amount;\n        return true;\n    }\n\n    function transferFrom(address _from, address _to, uint256 _amount) public returns (bool) {\n        require(balances[_from] >= _amount, "Insufficient balance");\n        require(allowances[_from][msg.sender] >= _amount, "Insufficient allowance");\n\n        balances[_from] -= _amount;\n        balances[_to] += _amount;\n        allowances[_from][msg.sender] -= _amount;\n\n        return true;\n    }\n}\n	\N	146	f	\N	1	0	solidity	0.8.0	{"license": "MIT", "detection_method": "extension", "detection_confidence": 0.95}	scanned	2025-10-17 21:31:19.196765+00	2025-10-17 21:31:34.262851+00
e29b1d07-26aa-4f45-bee2-83040bf5745e	56bc0604-49bc-4a73-8b4f-69fc3386a0f8	Short Address	\N	ethereum	// SPDX-License-Identifier: MIT\npragma solidity ^0.8.0;\n\n/**\n * @title Short Address Attack Vulnerability Example\n * @dev VULNERABLE - DO NOT USE IN PRODUCTION\n *\n * This vulnerability occurs when an ERC20 token contract doesn't validate\n * the length of the address parameter, allowing attackers to manipulate\n * the amount by sending a shorter address.\n *\n * Note: This is primarily a client-side vulnerability but contracts should\n * implement proper validation.\n */\ncontract VulnerableToken {\n    mapping(address => uint256) public balances;\n    string public name = "Vulnerable Token";\n    string public symbol = "VULN";\n    uint8 public decimals = 18;\n    uint256 public totalSupply;\n\n    event Transfer(address indexed from, address indexed to, uint256 value);\n\n    constructor(uint256 _initialSupply) {\n        totalSupply = _initialSupply;\n        balances[msg.sender] = _initialSupply;\n    }\n\n    // VULNERABLE: No length validation on address parameters\n    function transfer(address _to, uint256 _value) public returns (bool) {\n        // VULNERABILITY: If _to address is short (missing trailing zeros),\n        // the EVM will pad it, and _value might get shifted\n        require(balances[msg.sender] >= _value, "Insufficient balance");\n\n        balances[msg.sender] -= _value;\n        balances[_to] += _value;\n\n        emit Transfer(msg.sender, _to, _value);\n        return true;\n    }\n\n    // VULNERABLE: Batch transfer without proper validation\n    function batchTransfer(address[] memory _receivers, uint256 _value) public returns (bool) {\n        // VULNERABILITY: No validation on address array length\n        uint256 count = _receivers.length;\n        uint256 amount = _value * count;\n\n        require(balances[msg.sender] >= amount, "Insufficient balance");\n\n        balances[msg.sender] -= amount;\n\n        for (uint256 i = 0; i < count; i++) {\n            balances[_receivers[i]] += _value;\n            emit Transfer(msg.sender, _receivers[i], _value);\n        }\n\n        return true;\n    }\n}\n\n/**\n * @title Missing Input Validation\n * @dev Shows various input validation vulnerabilities\n */\ncontract VulnerableExchange {\n    mapping(address => mapping(address => uint256)) public tokens;\n\n    // VULNERABLE: No zero address check\n    function deposit(address _token, uint256 _amount) public {\n        // VULNERABILITY: Doesn't check for zero address\n        require(_amount > 0, "Amount must be positive");\n        tokens[_token][msg.sender] += _amount;\n    }\n\n    // VULNERABLE: No validation on addresses\n    function withdraw(address _token, uint256 _amount) public {\n        // VULNERABILITY: No address validation\n        require(tokens[_token][msg.sender] >= _amount, "Insufficient balance");\n        tokens[_token][msg.sender] -= _amount;\n    }\n\n    // VULNERABLE: Missing array length check\n    function batchDeposit(\n        address[] memory _tokens,\n        uint256[] memory _amounts\n    ) public {\n        // VULNERABILITY: Assumes arrays have same length\n        for (uint256 i = 0; i < _tokens.length; i++) {\n            tokens[_tokens[i]][msg.sender] += _amounts[i];\n        }\n    }\n\n    // VULNERABLE: No validation on transfer parameters\n    function transferBetweenUsers(\n        address _token,\n        address _from,\n        address _to,\n        uint256 _amount\n    ) public {\n        // VULNERABILITY: No checks on addresses (zero address, same address, etc.)\n        require(tokens[_token][_from] >= _amount, "Insufficient balance");\n        tokens[_token][_from] -= _amount;\n        tokens[_token][_to] += _amount;\n    }\n}\n\n/**\n * @title Missing Data Length Validation\n * @dev Shows vulnerability in handling dynamic data\n */\ncontract VulnerableMultisig {\n    address[] public owners;\n    mapping(bytes32 => bool) public executed;\n\n    constructor(address[] memory _owners) {\n        // VULNERABLE: No validation on array length or addresses\n        owners = _owners;\n    }\n\n    // VULNERABLE: No validation on data length\n    function execute(\n        address _target,\n        bytes memory _data,\n        bytes[] memory _signatures\n    ) public {\n        bytes32 txHash = keccak256(abi.encodePacked(_target, _data));\n        require(!executed[txHash], "Already executed");\n\n        // VULNERABILITY: No validation on signatures array length\n        // VULNERABILITY: No validation that signatures is not empty\n        require(_signatures.length >= owners.length / 2 + 1, "Not enough signatures");\n\n        // Simplified signature verification (also vulnerable)\n        executed[txHash] = true;\n\n        (bool success, ) = _target.call(_data);\n        require(success, "Execution failed");\n    }\n}\n\n/**\n * @title Parameter Validation Bypass\n * @dev Shows how missing parameter validation can be exploited\n */\ncontract VulnerableAirdrop {\n    mapping(address => uint256) public claimed;\n    address public token;\n\n    constructor(address _token) {\n        token = _token;\n    }\n\n    // VULNERABLE: No validation on parameters\n    function claimTokens(address _recipient, uint256 _amount) public {\n        // VULNERABILITY: No check that _recipient is not zero address\n        // VULNERABILITY: No check that _amount is reasonable\n        // VULNERABILITY: No check that caller hasn't claimed before\n\n        require(claimed[_recipient] == 0, "Already claimed");\n        claimed[_recipient] = _amount;\n\n        // Simplified token transfer\n        (bool success, ) = token.call(\n            abi.encodeWithSignature("transfer(address,uint256)", _recipient, _amount)\n        );\n        require(success, "Transfer failed");\n    }\n}\n	\N	168	f	\N	1	0	solidity	0.8.0	{"license": "MIT", "detection_method": "extension", "detection_confidence": 0.95}	scanned	2025-10-17 21:33:51.059915+00	2025-10-17 21:34:18.509924+00
526f3007-70d4-4bf2-a53e-2d99ead52669	56bc0604-49bc-4a73-8b4f-69fc3386a0f8	Delegate Call	\N	ethereum	// SPDX-License-Identifier: MIT\npragma solidity ^0.8.0;\n\n/**\n * @title Delegatecall Vulnerability Examples\n * @dev VULNERABLE - DO NOT USE IN PRODUCTION\n *\n * Delegatecall executes code in the context of the calling contract,\n * which can lead to storage collision and unauthorized access.\n */\ncontract VulnerableProxy {\n    address public owner;  // Slot 0\n    address public implementation;  // Slot 1\n\n    constructor(address _implementation) {\n        owner = msg.sender;\n        implementation = _implementation;\n    }\n\n    // VULNERABLE: Unprotected delegatecall\n    function forward(bytes memory _data) public {\n        // VULNERABILITY: Anyone can delegatecall to any contract\n        // Malicious contract can overwrite storage slots\n        (bool success, ) = implementation.delegatecall(_data);\n        require(success, "Delegatecall failed");\n    }\n\n    // VULNERABLE: Delegatecall to user-supplied address\n    function execute(address _target, bytes memory _data) public {\n        // VULNERABILITY: User controls the target contract\n        (bool success, ) = _target.delegatecall(_data);\n        require(success, "Execution failed");\n    }\n}\n\n/**\n * @title Malicious Implementation\n * @dev Contract designed to exploit delegatecall vulnerability\n */\ncontract MaliciousImplementation {\n    address public owner;  // Slot 0 - will overwrite VulnerableProxy.owner\n    address public implementation;  // Slot 1\n\n    // This function will overwrite the owner in VulnerableProxy\n    function becomeOwner() public {\n        owner = msg.sender;\n    }\n\n    function destroy() public {\n        selfdestruct(payable(msg.sender));\n    }\n}\n\n/**\n * @title Storage Collision Vulnerability\n * @dev Shows how storage layout mismatches cause vulnerabilities\n */\ncontract VulnerableWallet {\n    address public owner;  // Slot 0\n    mapping(address => uint256) public balances;  // Slot 1\n    address public libAddress;  // Slot 2\n\n    constructor(address _libAddress) {\n        owner = msg.sender;\n        libAddress = _libAddress;\n    }\n\n    function deposit() public payable {\n        balances[msg.sender] += msg.value;\n    }\n\n    // VULNERABLE: Delegatecall to library with different storage layout\n    function withdraw(uint256 _amount) public {\n        // VULNERABILITY: If library has different storage layout,\n        // it can corrupt this contract's storage\n        (bool success, ) = libAddress.delegatecall(\n            abi.encodeWithSignature("withdraw(uint256)", _amount)\n        );\n        require(success, "Withdrawal failed");\n    }\n\n    fallback() external payable {\n        // VULNERABLE: Fallback forwards all calls to library\n        (bool success, ) = libAddress.delegatecall(msg.data);\n        require(success, "Fallback failed");\n    }\n}\n\n/**\n * @title Malicious Library\n * @dev Library with different storage layout that exploits the wallet\n */\ncontract MaliciousLibrary {\n    address public maliciousOwner;  // Slot 0 - will overwrite VulnerableWallet.owner\n\n    function withdraw(uint256 _amount) public {\n        // This actually changes the owner!\n        maliciousOwner = msg.sender;\n        // Could also send funds to attacker\n    }\n\n    function setOwner(address _newOwner) public {\n        maliciousOwner = _newOwner;\n    }\n}\n\n/**\n * @title Delegatecall with Selfdestruct\n * @dev Shows how delegatecall can be used to destroy a contract\n */\ncontract VulnerableRegistry {\n    mapping(address => bool) public registered;\n    address public logicContract;\n\n    constructor(address _logicContract) {\n        logicContract = _logicContract;\n    }\n\n    function register() public {\n        registered[msg.sender] = true;\n    }\n\n    // VULNERABLE: If logic contract has selfdestruct, this contract can be destroyed\n    function executeLogic(bytes memory _data) public {\n        (bool success, ) = logicContract.delegatecall(_data);\n        require(success, "Logic execution failed");\n    }\n}\n\n/**\n * @title Malicious Logic with Selfdestruct\n * @dev Contract that can destroy the calling contract\n */\ncontract MaliciousLogic {\n    function destroy(address payable _recipient) public {\n        // When called via delegatecall, this destroys the calling contract!\n        selfdestruct(_recipient);\n    }\n}\n\n/**\n * @title Uninitialized Proxy\n * @dev Shows initialization vulnerability in proxy pattern\n */\ncontract UninitializedProxy {\n    address public implementation;\n    address public owner;\n    bool public initialized;\n\n    // VULNERABLE: Constructor doesn't initialize properly\n    constructor(address _implementation) {\n        implementation = _implementation;\n        // Missing: initialized = true and owner = msg.sender\n    }\n\n    // VULNERABLE: Can be called by anyone if not initialized\n    function initialize(address _owner) public {\n        require(!initialized, "Already initialized");\n        owner = _owner;\n        initialized = true;\n    }\n\n    fallback() external payable {\n        (bool success, ) = implementation.delegatecall(msg.data);\n        require(success, "Delegatecall failed");\n    }\n}\n	\N	167	f	\N	1	0	solidity	0.8.0	{"license": "MIT", "detection_method": "extension", "detection_confidence": 0.95}	scanned	2025-10-17 21:35:31.735647+00	2025-10-17 21:35:51.463832+00
0e2ea42e-a14d-446a-a193-04a3fbefbd6c	56bc0604-49bc-4a73-8b4f-69fc3386a0f8	Uninitialized Storage	\N	ethereum	// SPDX-License-Identifier: MIT\npragma solidity ^0.7.6;\n\n/**\n * @title Uninitialized Storage Pointer Vulnerability Example\n * @dev VULNERABLE - DO NOT USE IN PRODUCTION\n *\n * This vulnerability was more prevalent in older Solidity versions (< 0.5.0)\n * where storage pointers could be uninitialized, pointing to slot 0.\n *\n * In Solidity 0.5.0+, this produces a compiler warning/error, but the\n * vulnerability can still occur with improper struct usage.\n */\ncontract VulnerableStorage {\n    address public owner;  // Slot 0\n    uint256 public totalSupply;  // Slot 1\n    mapping(address => uint256) public balances;  // Slot 2\n\n    struct User {\n        address addr;\n        uint256 balance;\n        bool active;\n    }\n\n    User[] public users;\n\n    constructor() {\n        owner = msg.sender;\n        totalSupply = 1000000;\n    }\n\n    // VULNERABLE: Uninitialized struct in memory defaults to storage slot 0\n    function addUser(address _addr, uint256 _balance) public {\n        // In older Solidity, this would point to slot 0 (owner)\n        User memory newUser;\n        newUser.addr = _addr;\n        newUser.balance = _balance;\n        newUser.active = true;\n\n        users.push(newUser);\n    }\n\n    // VULNERABLE: Array manipulation without proper bounds checking\n    function updateUser(uint256 _index, address _addr) public {\n        // VULNERABILITY: No bounds checking\n        User storage user = users[_index];\n        user.addr = _addr;\n    }\n}\n\n/**\n * @title Uninitialized Storage in Loop\n * @dev Shows vulnerability with storage pointers in loops\n */\ncontract VulnerableArray {\n    address public owner;\n    uint256 public value;\n\n    struct Item {\n        address owner;\n        uint256 amount;\n    }\n\n    Item[] public items;\n\n    constructor() {\n        owner = msg.sender;\n        value = 100;\n    }\n\n    // VULNERABLE: Storage pointer in loop\n    function processItems() public {\n        // VULNERABILITY: If items array is empty, this could cause issues\n        for (uint256 i = 0; i < items.length; i++) {\n            Item storage item = items[i];\n            // In certain conditions, this could access wrong storage slots\n            item.amount += 10;\n        }\n    }\n\n    function addItem(address _owner, uint256 _amount) public {\n        items.push(Item(_owner, _amount));\n    }\n}\n\n/**\n * @title Default Visibility Vulnerability\n * @dev Shows how default visibility can cause security issues\n */\ncontract VulnerableVisibility {\n    address owner;  // Default internal visibility in Solidity 0.5.0+, public before\n    uint256 secret;  // Default internal\n\n    constructor() {\n        owner = msg.sender;\n        secret = 12345;\n    }\n\n    // VULNERABLE: State variable with implicit visibility\n    // In older versions, this would be public by default\n\n    // VULNERABLE: Function without explicit visibility (pre 0.5.0 defaults to public)\n    function changeOwner(address _newOwner) public {\n        // In Solidity < 0.5.0, forgetting 'public' keyword made this public anyway\n        owner = _newOwner;\n    }\n\n    // VULNERABLE: This should probably be internal or private\n    function resetSecret() public {\n        secret = 0;\n    }\n}\n\n/**\n * @title Uninitialized Storage Pointer Exploit Example\n * @dev Historic vulnerability showing storage collision\n */\ncontract StorageCollision {\n    address public owner;  // Slot 0\n    uint256 public balance;  // Slot 1\n\n    struct Transaction {\n        address recipient;\n        uint256 amount;\n    }\n\n    Transaction[] public transactions;\n\n    constructor() {\n        owner = msg.sender;\n        balance = 1000;\n    }\n\n    // VULNERABLE: In Solidity < 0.5.0, uninitialized storage pointers\n    // could overwrite critical state variables\n    function createTransaction(address _recipient, uint256 _amount) public {\n        // Old vulnerability: This could point to slot 0 and overwrite owner\n        Transaction memory txn;\n        txn.recipient = _recipient;\n        txn.amount = _amount;\n        transactions.push(txn);\n    }\n}\n\n/**\n * @title Delete Mapping Vulnerability\n * @dev Shows that deleting a struct with mappings doesn't clear the mapping\n */\ncontract VulnerableMapping {\n    struct User {\n        uint256 id;\n        mapping(address => uint256) approvals;\n    }\n\n    mapping(address => User) public users;\n\n    function createUser(uint256 _id) public {\n        users[msg.sender].id = _id;\n    }\n\n    function approve(address _spender, uint256 _amount) public {\n        users[msg.sender].approvals[_spender] = _amount;\n    }\n\n    // VULNERABLE: Delete doesn't clear nested mappings\n    function deleteUser() public {\n        // VULNERABILITY: The approvals mapping is NOT deleted\n        // _spender can still access their approval even after user is "deleted"\n        delete users[msg.sender];\n    }\n\n    function getApproval(address _user, address _spender) public view returns (uint256) {\n        return users[_user].approvals[_spender];\n    }\n}\n\n/**\n * @title Storage Array Deletion\n * @dev Shows issues with deleting array elements\n */\ncontract VulnerableArrayDeletion {\n    address public owner;\n    uint256[] public values;\n\n    constructor() {\n        owner = msg.sender;\n    }\n\n    function addValue(uint256 _value) public {\n        values.push(_value);\n    }\n\n    // VULNERABLE: Delete on array element leaves a gap\n    function deleteValue(uint256 _index) public {\n        require(_index < values.length, "Index out of bounds");\n        // VULNERABILITY: This sets values[_index] to 0 but doesn't remove it\n        // Array length stays the same, creating a "hole"\n        delete values[_index];\n    }\n\n    // VULNERABLE: Accessing deleted elements\n    function getValue(uint256 _index) public view returns (uint256) {\n        // Will return 0 for deleted elements, but index is still valid\n        return values[_index];\n    }\n}\n	\N	206	f	\N	1	0	solidity	0.7.6	{"license": "MIT", "detection_method": "extension", "detection_confidence": 0.95}	scanned	2025-10-17 21:36:07.223479+00	2025-10-17 22:27:30.237187+00
97970ea9-196b-4643-95e6-f1aa019bcf6f	56bc0604-49bc-4a73-8b4f-69fc3386a0f8	Unchecked Call	\N	ethereum	// SPDX-License-Identifier: MIT\npragma solidity ^0.8.0;\n\n/**\n * @title Unchecked External Call Vulnerability Example\n * @dev VULNERABLE - DO NOT USE IN PRODUCTION\n *\n * This contract fails to check return values of external calls.\n */\ncontract VulnerablePayment {\n    mapping(address => uint256) public balances;\n\n    function deposit() public payable {\n        balances[msg.sender] += msg.value;\n    }\n\n    // VULNERABLE: Unchecked low-level call\n    function withdrawUnchecked(address payable _recipient, uint256 _amount) public {\n        require(balances[msg.sender] >= _amount, "Insufficient balance");\n        balances[msg.sender] -= _amount;\n\n        // VULNERABILITY: Return value not checked\n        _recipient.call{value: _amount}("");\n        // If the call fails, the user loses their balance!\n    }\n\n    // VULNERABLE: Unchecked send\n    function withdrawWithSend(address payable _recipient, uint256 _amount) public {\n        require(balances[msg.sender] >= _amount, "Insufficient balance");\n        balances[msg.sender] -= _amount;\n\n        // VULNERABILITY: send() returns false on failure but we don't check it\n        _recipient.send(_amount);\n    }\n\n    // VULNERABLE: Multiple unchecked calls\n    function batchPayout(address payable[] memory _recipients, uint256[] memory _amounts) public {\n        require(_recipients.length == _amounts.length, "Length mismatch");\n\n        for (uint256 i = 0; i < _recipients.length; i++) {\n            // VULNERABILITY: If one call fails, the loop continues\n            _recipients[i].call{value: _amounts[i]}("");\n        }\n    }\n}\n\n/**\n * @title Unchecked External Contract Call\n * @dev Shows vulnerability with external contract interactions\n */\ninterface IExternalContract {\n    function executeAction(address user) external returns (bool);\n}\n\ncontract VulnerableIntegration {\n    IExternalContract public externalContract;\n    mapping(address => uint256) public rewards;\n\n    constructor(address _externalContract) {\n        externalContract = IExternalContract(_externalContract);\n    }\n\n    // VULNERABLE: Assumes external call succeeds\n    function claimReward() public {\n        uint256 reward = rewards[msg.sender];\n        require(reward > 0, "No reward");\n\n        // VULNERABILITY: Doesn't check return value\n        externalContract.executeAction(msg.sender);\n\n        // Reward is cleared even if external call failed\n        rewards[msg.sender] = 0;\n        payable(msg.sender).transfer(reward);\n    }\n\n    function setReward(address _user, uint256 _amount) public {\n        rewards[_user] = _amount;\n    }\n\n    receive() external payable {}\n}\n\n/**\n * @title Malicious Receiver\n * @dev Contract that always rejects payments to exploit unchecked calls\n */\ncontract MaliciousReceiver {\n    // Always rejects payments\n    receive() external payable {\n        revert("Payment rejected");\n    }\n\n    // This function can drain the VulnerablePayment contract\n    function attack(address _vulnerableContract, uint256 _amount) public {\n        VulnerablePayment vulnerable = VulnerablePayment(_vulnerableContract);\n\n        // Deposit funds\n        vulnerable.deposit{value: _amount}();\n\n        // Withdraw using unchecked call - balance will be deducted\n        // but payment will fail, and we can do it again\n        vulnerable.withdrawUnchecked(payable(address(this)), _amount);\n    }\n}\n	\N	104	f	\N	1	0	solidity	0.8.0	{"license": "MIT", "detection_method": "extension", "detection_confidence": 0.95}	scanned	2025-10-17 22:29:49.63294+00	2025-10-17 22:29:56.089651+00
48fe8623-d7fb-40a3-90a9-1ee1ee96fd89	56bc0604-49bc-4a73-8b4f-69fc3386a0f8	Bridge Vault	\N	ethereum	// SPDX-License-Identifier: MIT\npragma solidity ^0.8.20;\n\nimport "@openzeppelin/contracts/access/Ownable.sol";\nimport "@openzeppelin/contracts/security/Pausable.sol";\n\ninterface IERC20 {\n    function transfer(address to, uint256 amount) external returns (bool);\n    function transferFrom(address from, address to, uint256 amount) external returns (bool);\n    function balanceOf(address account) external view returns (uint256);\n}\n\n/**\n * @title BridgeVault\n * @dev Cross-chain bridge contract with modern vulnerabilities\n *\n * VULNERABILITIES:\n * 1. Signature replay attacks across chains\n * 2. Chain ID manipulation vulnerabilities\n * 3. Race conditions in cross-chain message verification\n * 4. Insufficient validation of bridge operators\n * 5. Time-based oracle manipulation\n * 6. Cross-chain MEV extraction\n * 7. Liquidity sandwich attacks during bridging\n * 8. Validator set manipulation\n * 9. Emergency pause bypass\n * 10. Double spending via chain reorganization\n */\ncontract BridgeVault is Ownable, Pausable {\n\n    struct BridgeRequest {\n        address user;\n        address token;\n        uint256 amount;\n        uint256 targetChain;\n        address targetAddress;\n        uint256 nonce;\n        uint256 deadline;\n        bytes32 requestHash;\n    }\n\n    struct ValidatorSignature {\n        address validator;\n        bytes signature;\n        uint256 timestamp;\n    }\n\n    // VULNERABILITY: No chain ID in mapping, allows cross-chain replay\n    mapping(bytes32 => bool) public processedRequests;\n    mapping(address => uint256) public userNonces;\n    mapping(address => bool) public validators;\n    mapping(uint256 => uint256) public chainGasLimits;\n    mapping(address => mapping(uint256 => uint256)) public userChainNonces;\n\n    // VULNERABILITY: Single admin controls validator set\n    address[] public validatorsList;\n    uint256 public requiredSignatures;\n    uint256 public constant MAX_VALIDATORS = 100;\n    uint256 public bridgeFee = 100; // 1%\n\n    // VULNERABILITY: Time-based validation window\n    uint256 public validationWindow = 300; // 5 minutes\n    uint256 public emergencyDelay = 3600; // 1 hour\n\n    // VULNERABILITY: Mutable chain configuration\n    mapping(uint256 => bool) public supportedChains;\n    mapping(uint256 => address) public chainBridgeAddresses;\n\n    event BridgeInitiated(\n        bytes32 indexed requestHash,\n        address indexed user,\n        address indexed token,\n        uint256 amount,\n        uint256 targetChain\n    );\n\n    event BridgeCompleted(\n        bytes32 indexed requestHash,\n        address indexed user,\n        uint256 amount\n    );\n\n    modifier onlyValidator() {\n        require(validators[msg.sender], "Not a validator");\n        _;\n    }\n\n    modifier validChain(uint256 chainId) {\n        require(supportedChains[chainId], "Unsupported chain");\n        _;\n    }\n\n    constructor(address[] memory _validators, uint256 _requiredSignatures) Ownable(msg.sender) {\n        require(_validators.length <= MAX_VALIDATORS, "Too many validators");\n        require(_requiredSignatures <= _validators.length, "Invalid signature requirement");\n        require(_requiredSignatures > 0, "Must require at least one signature");\n\n        for (uint256 i = 0; i < _validators.length; i++) {\n            validators[_validators[i]] = true;\n            validatorsList.push(_validators[i]);\n        }\n        requiredSignatures = _requiredSignatures;\n    }\n\n    /**\n     * @dev Initiate bridge transfer - VULNERABLE to multiple attacks\n     */\n    function initiateBridge(\n        address token,\n        uint256 amount,\n        uint256 targetChain,\n        address targetAddress,\n        uint256 deadline\n    ) external payable whenNotPaused validChain(targetChain) {\n        require(amount > 0, "Invalid amount");\n        require(deadline > block.timestamp, "Deadline passed");\n        require(targetAddress != address(0), "Invalid target address");\n\n        // VULNERABILITY: No validation of target chain bridge address\n        // VULNERABILITY: Using predictable nonce generation\n        uint256 nonce = userNonces[msg.sender]++;\n\n        // VULNERABILITY: Hash doesn't include chain ID, enabling replay attacks\n        bytes32 requestHash = keccak256(abi.encodePacked(\n            msg.sender,\n            token,\n            amount,\n            targetChain,\n            targetAddress,\n            nonce,\n            deadline\n            // Missing: block.chainid to prevent cross-chain replay\n        ));\n\n        require(!processedRequests[requestHash], "Request already processed");\n\n        // VULNERABILITY: Fee calculation susceptible to overflow/underflow\n        uint256 fee = (amount * bridgeFee) / 10000;\n        uint256 bridgeAmount = amount - fee;\n\n        // Transfer tokens to vault\n        IERC20(token).transferFrom(msg.sender, address(this), amount);\n\n        // VULNERABILITY: State update after external call\n        processedRequests[requestHash] = true;\n\n        emit BridgeInitiated(requestHash, msg.sender, token, bridgeAmount, targetChain);\n    }\n\n    /**\n     * @dev Complete bridge transfer with validator signatures - VULNERABLE\n     */\n    function completeBridge(\n        BridgeRequest calldata request,\n        ValidatorSignature[] calldata signatures\n    ) external whenNotPaused {\n        require(signatures.length >= requiredSignatures, "Insufficient signatures");\n        require(request.deadline > block.timestamp, "Request expired");\n\n        // VULNERABILITY: No verification that request came from supported chain\n        bytes32 requestHash = keccak256(abi.encodePacked(\n            request.user,\n            request.token,\n            request.amount,\n            request.targetChain,\n            request.targetAddress,\n            request.nonce,\n            request.deadline\n        ));\n\n        require(request.requestHash == requestHash, "Invalid request hash");\n        require(!processedRequests[requestHash], "Already processed");\n\n        // VULNERABILITY: Signature validation doesn't prevent replay attacks\n        address[] memory signers = new address[](signatures.length);\n        for (uint256 i = 0; i < signatures.length; i++) {\n            require(validators[signatures[i].validator], "Invalid validator");\n\n            // VULNERABILITY: No timestamp validation allows old signatures\n            require(\n                block.timestamp - signatures[i].timestamp <= validationWindow,\n                "Signature too old"\n            );\n\n            bytes32 messageHash = getMessageHash(request);\n            address signer = recoverSigner(messageHash, signatures[i].signature);\n            require(signer == signatures[i].validator, "Invalid signature");\n\n            // VULNERABILITY: No check for duplicate signers\n            signers[i] = signer;\n        }\n\n        // VULNERABILITY: State update allows reentrancy\n        processedRequests[requestHash] = true;\n\n        // VULNERABILITY: No slippage protection during token transfer\n        uint256 availableBalance = IERC20(request.token).balanceOf(address(this));\n        require(availableBalance >= request.amount, "Insufficient vault balance");\n\n        IERC20(request.token).transfer(request.targetAddress, request.amount);\n\n        emit BridgeCompleted(requestHash, request.user, request.amount);\n    }\n\n    /**\n     * @dev Emergency withdraw - VULNERABLE to admin abuse\n     */\n    function emergencyWithdraw(\n        address token,\n        uint256 amount,\n        address to\n    ) external onlyOwner {\n        // VULNERABILITY: No time lock, immediate withdrawal possible\n        // VULNERABILITY: No validation of withdrawal legitimacy\n        IERC20(token).transfer(to, amount);\n    }\n\n    /**\n     * @dev Update validator set - VULNERABLE to centralization\n     */\n    function updateValidators(\n        address[] calldata newValidators,\n        uint256 newRequiredSignatures\n    ) external onlyOwner {\n        // VULNERABILITY: Immediate validator set change without timelock\n        require(newValidators.length <= MAX_VALIDATORS, "Too many validators");\n        require(newRequiredSignatures <= newValidators.length, "Invalid requirement");\n\n        // Clear existing validators\n        for (uint256 i = 0; i < validatorsList.length; i++) {\n            validators[validatorsList[i]] = false;\n        }\n        delete validatorsList;\n\n        // VULNERABILITY: No validation of new validators\n        for (uint256 i = 0; i < newValidators.length; i++) {\n            validators[newValidators[i]] = true;\n            validatorsList.push(newValidators[i]);\n        }\n\n        requiredSignatures = newRequiredSignatures;\n    }\n\n    /**\n     * @dev Add supported chain - VULNERABLE to misconfiguration\n     */\n    function addSupportedChain(\n        uint256 chainId,\n        address bridgeAddress\n    ) external onlyOwner {\n        // VULNERABILITY: No validation of chain ID or bridge address\n        supportedChains[chainId] = true;\n        chainBridgeAddresses[chainId] = bridgeAddress;\n    }\n\n    /**\n     * @dev Update bridge fee - VULNERABLE to immediate changes\n     */\n    function updateBridgeFee(uint256 newFee) external onlyOwner {\n        // VULNERABILITY: No maximum fee limit, could be set to 100%\n        // VULNERABILITY: No timelock for fee changes\n        bridgeFee = newFee;\n    }\n\n    /**\n     * @dev Get message hash for signing\n     */\n    function getMessageHash(BridgeRequest memory request) public pure returns (bytes32) {\n        return keccak256(abi.encodePacked(\n            "\\x19Ethereum Signed Message:\\n32",\n            keccak256(abi.encode(request))\n        ));\n    }\n\n    /**\n     * @dev Recover signer from signature\n     */\n    function recoverSigner(bytes32 messageHash, bytes memory signature) public pure returns (address) {\n        require(signature.length == 65, "Invalid signature length");\n\n        bytes32 r;\n        bytes32 s;\n        uint8 v;\n\n        assembly {\n            r := mload(add(signature, 32))\n            s := mload(add(signature, 64))\n            v := byte(0, mload(add(signature, 96)))\n        }\n\n        return ecrecover(messageHash, v, r, s);\n    }\n\n    /**\n     * @dev Pause contract - VULNERABLE to admin abuse\n     */\n    function pause() external onlyOwner {\n        _pause();\n    }\n\n    /**\n     * @dev Unpause contract\n     */\n    function unpause() external onlyOwner {\n        _unpause();\n    }\n\n    /**\n     * @dev Get validator count\n     */\n    function getValidatorCount() external view returns (uint256) {\n        return validatorsList.length;\n    }\n\n    /**\n     * @dev Check if chain is supported\n     */\n    function isChainSupported(uint256 chainId) external view returns (bool) {\n        return supportedChains[chainId];\n    }\n\n    // VULNERABILITY: Fallback function accepts Ether without validation\n    receive() external payable {\n        // Could be exploited for unexpected ETH handling\n    }\n\n    // VULNERABILITY: Fallback allows arbitrary calls\n    fallback() external payable {\n        // Dangerous fallback that could be exploited\n    }\n}	\N	331	f	\N	1	0	solidity	0.8.20	{"license": "MIT", "detection_method": "extension", "detection_confidence": 0.95}	scanned	2025-10-18 01:17:03.080231+00	2025-10-18 01:28:05.06418+00
98593981-74f4-43f4-b7f6-3d795f4a488c	ab45210a-44a1-490e-bd5f-18135cdc3c91	Timestamp Dep	\N	ethereum	// SPDX-License-Identifier: MIT\npragma solidity ^0.8.0;\n\n/**\n * @title Timestamp Dependence Vulnerability Example\n * @dev VULNERABLE - DO NOT USE IN PRODUCTION\n *\n * This contract uses block.timestamp for critical logic, which can be manipulated\n * by miners within a ~15 second window.\n */\ncontract VulnerableLottery {\n    address public owner;\n    uint256 public lotteryEndTime;\n    address[] public players;\n    uint256 public ticketPrice = 0.1 ether;\n\n    constructor(uint256 _duration) {\n        owner = msg.sender;\n        lotteryEndTime = block.timestamp + _duration;\n    }\n\n    function buyTicket() public payable {\n        require(msg.value == ticketPrice, "Incorrect ticket price");\n        require(block.timestamp < lotteryEndTime, "Lottery ended");\n        players.push(msg.sender);\n    }\n\n    // VULNERABLE: Uses block.timestamp for random number generation\n    function drawWinner() public {\n        require(block.timestamp >= lotteryEndTime, "Lottery not ended yet");\n        require(players.length > 0, "No players");\n\n        // VULNERABILITY: Miners can manipulate block.timestamp\n        uint256 randomIndex = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty))) % players.length;\n        address winner = players[randomIndex];\n\n        payable(winner).transfer(address(this).balance);\n        delete players;\n        lotteryEndTime = block.timestamp + 1 days;\n    }\n}\n\n/**\n * @title Time-Based Access Control Vulnerability\n * @dev Shows timestamp manipulation for access control\n */\ncontract VulnerableTimelock {\n    mapping(address => uint256) public lockTime;\n    mapping(address => uint256) public balances;\n\n    function deposit() public payable {\n        balances[msg.sender] += msg.value;\n        // Lock for 1 week\n        lockTime[msg.sender] = block.timestamp + 1 weeks;\n    }\n\n    // VULNERABLE: Relies on block.timestamp for security\n    function withdraw() public {\n        require(balances[msg.sender] > 0, "No balance");\n        // VULNERABILITY: Miner can manipulate timestamp by ~15 seconds\n        require(block.timestamp >= lockTime[msg.sender], "Funds locked");\n\n        uint256 amount = balances[msg.sender];\n        balances[msg.sender] = 0;\n        payable(msg.sender).transfer(amount);\n    }\n\n    // VULNERABLE: Time-based access control\n    function emergencyWithdraw() public {\n        // VULNERABILITY: Attacker miner can manipulate timing\n        require(block.timestamp % 2 == 0, "Can only withdraw on even seconds");\n        payable(msg.sender).transfer(balances[msg.sender]);\n        balances[msg.sender] = 0;\n    }\n}\n\n/**\n * @title Randomness from Block Variables\n * @dev Shows vulnerability in using block variables for randomness\n */\ncontract VulnerableRandomness {\n    uint256 public lastWinningNumber;\n\n    // VULNERABLE: Predictable random number generation\n    function generateRandomNumber() public returns (uint256) {\n        // VULNERABILITY: All block variables are known/predictable\n        uint256 random = uint256(keccak256(abi.encodePacked(\n            block.timestamp,\n            block.difficulty,\n            block.number,\n            msg.sender\n        ))) % 100;\n\n        lastWinningNumber = random;\n        return random;\n    }\n\n    function playGame() public payable returns (bool) {\n        require(msg.value == 0.01 ether, "Must bet 0.01 ether");\n\n        uint256 winningNumber = generateRandomNumber();\n\n        // If number is > 50, player wins\n        if (winningNumber > 50) {\n            payable(msg.sender).transfer(0.02 ether);\n            return true;\n        }\n        return false;\n    }\n\n    receive() external payable {}\n}\n	\N	112	f	\N	1	0	solidity	0.8.0	{"license": "MIT", "detection_method": "extension", "detection_confidence": 0.95}	scanning	2025-10-17 19:10:26.483499+00	2025-10-18 17:03:28.843164+00
39ff6067-d614-4017-8c01-896029a2729a	ab45210a-44a1-490e-bd5f-18135cdc3c91	Bridge Vault	\N	ethereum	// SPDX-License-Identifier: MIT\npragma solidity ^0.8.20;\n\nimport "@openzeppelin/contracts/access/Ownable.sol";\nimport "@openzeppelin/contracts/security/Pausable.sol";\n\ninterface IERC20 {\n    function transfer(address to, uint256 amount) external returns (bool);\n    function transferFrom(address from, address to, uint256 amount) external returns (bool);\n    function balanceOf(address account) external view returns (uint256);\n}\n\n/**\n * @title BridgeVault\n * @dev Cross-chain bridge contract with modern vulnerabilities\n *\n * VULNERABILITIES:\n * 1. Signature replay attacks across chains\n * 2. Chain ID manipulation vulnerabilities\n * 3. Race conditions in cross-chain message verification\n * 4. Insufficient validation of bridge operators\n * 5. Time-based oracle manipulation\n * 6. Cross-chain MEV extraction\n * 7. Liquidity sandwich attacks during bridging\n * 8. Validator set manipulation\n * 9. Emergency pause bypass\n * 10. Double spending via chain reorganization\n */\ncontract BridgeVault is Ownable, Pausable {\n\n    struct BridgeRequest {\n        address user;\n        address token;\n        uint256 amount;\n        uint256 targetChain;\n        address targetAddress;\n        uint256 nonce;\n        uint256 deadline;\n        bytes32 requestHash;\n    }\n\n    struct ValidatorSignature {\n        address validator;\n        bytes signature;\n        uint256 timestamp;\n    }\n\n    // VULNERABILITY: No chain ID in mapping, allows cross-chain replay\n    mapping(bytes32 => bool) public processedRequests;\n    mapping(address => uint256) public userNonces;\n    mapping(address => bool) public validators;\n    mapping(uint256 => uint256) public chainGasLimits;\n    mapping(address => mapping(uint256 => uint256)) public userChainNonces;\n\n    // VULNERABILITY: Single admin controls validator set\n    address[] public validatorsList;\n    uint256 public requiredSignatures;\n    uint256 public constant MAX_VALIDATORS = 100;\n    uint256 public bridgeFee = 100; // 1%\n\n    // VULNERABILITY: Time-based validation window\n    uint256 public validationWindow = 300; // 5 minutes\n    uint256 public emergencyDelay = 3600; // 1 hour\n\n    // VULNERABILITY: Mutable chain configuration\n    mapping(uint256 => bool) public supportedChains;\n    mapping(uint256 => address) public chainBridgeAddresses;\n\n    event BridgeInitiated(\n        bytes32 indexed requestHash,\n        address indexed user,\n        address indexed token,\n        uint256 amount,\n        uint256 targetChain\n    );\n\n    event BridgeCompleted(\n        bytes32 indexed requestHash,\n        address indexed user,\n        uint256 amount\n    );\n\n    modifier onlyValidator() {\n        require(validators[msg.sender], "Not a validator");\n        _;\n    }\n\n    modifier validChain(uint256 chainId) {\n        require(supportedChains[chainId], "Unsupported chain");\n        _;\n    }\n\n    constructor(address[] memory _validators, uint256 _requiredSignatures) Ownable(msg.sender) {\n        require(_validators.length <= MAX_VALIDATORS, "Too many validators");\n        require(_requiredSignatures <= _validators.length, "Invalid signature requirement");\n        require(_requiredSignatures > 0, "Must require at least one signature");\n\n        for (uint256 i = 0; i < _validators.length; i++) {\n            validators[_validators[i]] = true;\n            validatorsList.push(_validators[i]);\n        }\n        requiredSignatures = _requiredSignatures;\n    }\n\n    /**\n     * @dev Initiate bridge transfer - VULNERABLE to multiple attacks\n     */\n    function initiateBridge(\n        address token,\n        uint256 amount,\n        uint256 targetChain,\n        address targetAddress,\n        uint256 deadline\n    ) external payable whenNotPaused validChain(targetChain) {\n        require(amount > 0, "Invalid amount");\n        require(deadline > block.timestamp, "Deadline passed");\n        require(targetAddress != address(0), "Invalid target address");\n\n        // VULNERABILITY: No validation of target chain bridge address\n        // VULNERABILITY: Using predictable nonce generation\n        uint256 nonce = userNonces[msg.sender]++;\n\n        // VULNERABILITY: Hash doesn't include chain ID, enabling replay attacks\n        bytes32 requestHash = keccak256(abi.encodePacked(\n            msg.sender,\n            token,\n            amount,\n            targetChain,\n            targetAddress,\n            nonce,\n            deadline\n            // Missing: block.chainid to prevent cross-chain replay\n        ));\n\n        require(!processedRequests[requestHash], "Request already processed");\n\n        // VULNERABILITY: Fee calculation susceptible to overflow/underflow\n        uint256 fee = (amount * bridgeFee) / 10000;\n        uint256 bridgeAmount = amount - fee;\n\n        // Transfer tokens to vault\n        IERC20(token).transferFrom(msg.sender, address(this), amount);\n\n        // VULNERABILITY: State update after external call\n        processedRequests[requestHash] = true;\n\n        emit BridgeInitiated(requestHash, msg.sender, token, bridgeAmount, targetChain);\n    }\n\n    /**\n     * @dev Complete bridge transfer with validator signatures - VULNERABLE\n     */\n    function completeBridge(\n        BridgeRequest calldata request,\n        ValidatorSignature[] calldata signatures\n    ) external whenNotPaused {\n        require(signatures.length >= requiredSignatures, "Insufficient signatures");\n        require(request.deadline > block.timestamp, "Request expired");\n\n        // VULNERABILITY: No verification that request came from supported chain\n        bytes32 requestHash = keccak256(abi.encodePacked(\n            request.user,\n            request.token,\n            request.amount,\n            request.targetChain,\n            request.targetAddress,\n            request.nonce,\n            request.deadline\n        ));\n\n        require(request.requestHash == requestHash, "Invalid request hash");\n        require(!processedRequests[requestHash], "Already processed");\n\n        // VULNERABILITY: Signature validation doesn't prevent replay attacks\n        address[] memory signers = new address[](signatures.length);\n        for (uint256 i = 0; i < signatures.length; i++) {\n            require(validators[signatures[i].validator], "Invalid validator");\n\n            // VULNERABILITY: No timestamp validation allows old signatures\n            require(\n                block.timestamp - signatures[i].timestamp <= validationWindow,\n                "Signature too old"\n            );\n\n            bytes32 messageHash = getMessageHash(request);\n            address signer = recoverSigner(messageHash, signatures[i].signature);\n            require(signer == signatures[i].validator, "Invalid signature");\n\n            // VULNERABILITY: No check for duplicate signers\n            signers[i] = signer;\n        }\n\n        // VULNERABILITY: State update allows reentrancy\n        processedRequests[requestHash] = true;\n\n        // VULNERABILITY: No slippage protection during token transfer\n        uint256 availableBalance = IERC20(request.token).balanceOf(address(this));\n        require(availableBalance >= request.amount, "Insufficient vault balance");\n\n        IERC20(request.token).transfer(request.targetAddress, request.amount);\n\n        emit BridgeCompleted(requestHash, request.user, request.amount);\n    }\n\n    /**\n     * @dev Emergency withdraw - VULNERABLE to admin abuse\n     */\n    function emergencyWithdraw(\n        address token,\n        uint256 amount,\n        address to\n    ) external onlyOwner {\n        // VULNERABILITY: No time lock, immediate withdrawal possible\n        // VULNERABILITY: No validation of withdrawal legitimacy\n        IERC20(token).transfer(to, amount);\n    }\n\n    /**\n     * @dev Update validator set - VULNERABLE to centralization\n     */\n    function updateValidators(\n        address[] calldata newValidators,\n        uint256 newRequiredSignatures\n    ) external onlyOwner {\n        // VULNERABILITY: Immediate validator set change without timelock\n        require(newValidators.length <= MAX_VALIDATORS, "Too many validators");\n        require(newRequiredSignatures <= newValidators.length, "Invalid requirement");\n\n        // Clear existing validators\n        for (uint256 i = 0; i < validatorsList.length; i++) {\n            validators[validatorsList[i]] = false;\n        }\n        delete validatorsList;\n\n        // VULNERABILITY: No validation of new validators\n        for (uint256 i = 0; i < newValidators.length; i++) {\n            validators[newValidators[i]] = true;\n            validatorsList.push(newValidators[i]);\n        }\n\n        requiredSignatures = newRequiredSignatures;\n    }\n\n    /**\n     * @dev Add supported chain - VULNERABLE to misconfiguration\n     */\n    function addSupportedChain(\n        uint256 chainId,\n        address bridgeAddress\n    ) external onlyOwner {\n        // VULNERABILITY: No validation of chain ID or bridge address\n        supportedChains[chainId] = true;\n        chainBridgeAddresses[chainId] = bridgeAddress;\n    }\n\n    /**\n     * @dev Update bridge fee - VULNERABLE to immediate changes\n     */\n    function updateBridgeFee(uint256 newFee) external onlyOwner {\n        // VULNERABILITY: No maximum fee limit, could be set to 100%\n        // VULNERABILITY: No timelock for fee changes\n        bridgeFee = newFee;\n    }\n\n    /**\n     * @dev Get message hash for signing\n     */\n    function getMessageHash(BridgeRequest memory request) public pure returns (bytes32) {\n        return keccak256(abi.encodePacked(\n            "\\x19Ethereum Signed Message:\\n32",\n            keccak256(abi.encode(request))\n        ));\n    }\n\n    /**\n     * @dev Recover signer from signature\n     */\n    function recoverSigner(bytes32 messageHash, bytes memory signature) public pure returns (address) {\n        require(signature.length == 65, "Invalid signature length");\n\n        bytes32 r;\n        bytes32 s;\n        uint8 v;\n\n        assembly {\n            r := mload(add(signature, 32))\n            s := mload(add(signature, 64))\n            v := byte(0, mload(add(signature, 96)))\n        }\n\n        return ecrecover(messageHash, v, r, s);\n    }\n\n    /**\n     * @dev Pause contract - VULNERABLE to admin abuse\n     */\n    function pause() external onlyOwner {\n        _pause();\n    }\n\n    /**\n     * @dev Unpause contract\n     */\n    function unpause() external onlyOwner {\n        _unpause();\n    }\n\n    /**\n     * @dev Get validator count\n     */\n    function getValidatorCount() external view returns (uint256) {\n        return validatorsList.length;\n    }\n\n    /**\n     * @dev Check if chain is supported\n     */\n    function isChainSupported(uint256 chainId) external view returns (bool) {\n        return supportedChains[chainId];\n    }\n\n    // VULNERABILITY: Fallback function accepts Ether without validation\n    receive() external payable {\n        // Could be exploited for unexpected ETH handling\n    }\n\n    // VULNERABILITY: Fallback allows arbitrary calls\n    fallback() external payable {\n        // Dangerous fallback that could be exploited\n    }\n}	\N	331	f	\N	1	0	solidity	0.8.20	{"license": "MIT", "detection_method": "extension", "detection_confidence": 0.95}	scanned	2025-10-18 01:13:27.008372+00	2025-10-18 22:21:39.37218+00
8af6de60-912a-4eff-aa1f-96779a3bac91	ab45210a-44a1-490e-bd5f-18135cdc3c91	Vulnerable Complex	\N	ethereum	// SPDX-License-Identifier: MIT\npragma solidity ^0.8.0;\n\n/// @title Complex Vulnerable Bridge - Has Signature Verification but Missing Replay Protection\n/// @notice Demonstrates signature verification without replay protection\n/// @dev Should trigger: bridge-message-verification detector (missing replay protection)\n\ncontract ComplexBridge {\n    address public trustedSigner;\n\n    event MessageExecuted(bytes32 indexed messageHash);\n\n    constructor(address _signer) {\n        trustedSigner = _signer;\n    }\n\n    /// @notice Process message with signature verification but NO replay protection\n    /// @dev VULNERABILITY: Valid signatures can be replayed multiple times\n    function processMessage(\n        bytes32 messageHash,\n        bytes calldata message,\n        uint8 v,\n        bytes32 r,\n        bytes32 s\n    ) external {\n        // Good: Has signature verification\n        address signer = ecrecover(messageHash, v, r, s);\n        require(signer == trustedSigner, "Invalid signature");\n\n        // VULNERABILITY: Missing replay protection\n        // Should have: require(!processedMessages[messageHash]);\n\n        _executeMessage(message);\n\n        // Missing: processedMessages[messageHash] = true;\n\n        emit MessageExecuted(messageHash);\n    }\n\n    /// @notice Merkle proof verification without replay protection\n    /// @dev VULNERABILITY: Proofs can be reused\n    function executeWithProof(\n        bytes32 root,\n        bytes32 leaf,\n        bytes32[] calldata proof,\n        bytes calldata payload\n    ) external {\n        // Good: Has Merkle verification\n        require(verifyMerkleProof(root, leaf, proof), "Invalid proof");\n\n        // VULNERABILITY: No replay protection\n\n        (bool success,) = address(this).call(payload);\n        require(success, "Execution failed");\n\n        emit MessageExecuted(leaf);\n    }\n\n    function verifyMerkleProof(\n        bytes32 root,\n        bytes32 leaf,\n        bytes32[] calldata proof\n    ) internal pure returns (bool) {\n        bytes32 computedHash = leaf;\n        for (uint256 i = 0; i < proof.length; i++) {\n            computedHash = keccak256(abi.encodePacked(computedHash, proof[i]));\n        }\n        return computedHash == root;\n    }\n\n    function _executeMessage(bytes calldata message) internal {\n        // Execution logic\n    }\n}\n	\N	74	f	\N	1	0	solidity	0.8.0	{"license": "MIT", "detection_method": "extension", "detection_confidence": 0.95}	scanned	2025-10-23 15:26:56.680572+00	2025-10-23 15:27:13.312352+00
f2f3239b-3d5e-4299-a45f-924b5761a0dc	ab45210a-44a1-490e-bd5f-18135cdc3c91	LiquidityMining	\N	ethereum	// SPDX-License-Identifier: MIT\npragma solidity ^0.8.20;\n\nimport "@openzeppelin/contracts/access/Ownable.sol";\nimport "@openzeppelin/contracts/security/ReentrancyGuard.sol";\nimport "@openzeppelin/contracts/utils/math/SafeMath.sol";\n\ninterface IERC20 {\n    function transfer(address to, uint256 amount) external returns (bool);\n    function transferFrom(address from, address to, uint256 amount) external returns (bool);\n    function balanceOf(address account) external view returns (uint256);\n    function approve(address spender, uint256 amount) external returns (bool);\n}\n\ninterface IUniswapV2Pair {\n    function totalSupply() external view returns (uint256);\n    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);\n    function token0() external view returns (address);\n    function token1() external view returns (address);\n}\n\ninterface IOracle {\n    function getPrice(address token) external view returns (uint256);\n    function getTWAP(address token, uint256 period) external view returns (uint256);\n}\n\n/**\n * @title LiquidityMining\n * @dev Advanced yield farming contract with 2025-era vulnerabilities\n *\n * VULNERABILITIES:\n * 1. Reward calculation manipulation via timestamp attacks\n * 2. Flash loan attacks on staking/unstaking\n * 3. Impermanent loss farming (IL farming)\n * 4. Reward token inflation attacks\n * 5. Multi-block MEV attacks\n * 6. Liquidity pool manipulation for reward boost\n * 7. Time-weighted reward gaming\n * 8. Emergency withdrawal bypass\n * 9. Reward multiplier manipulation\n * 10. Cross-pool arbitrage exploitation\n */\ncontract LiquidityMining is Ownable, ReentrancyGuard {\n    using SafeMath for uint256;\n\n    struct UserInfo {\n        uint256 amount; // Staked LP token amount\n        uint256 rewardDebt; // Reward debt for calculations\n        uint256 lastStakeTime; // Last stake timestamp\n        uint256 lastRewardTime; // Last reward claim timestamp\n        uint256 accumulatedRewards; // Total accumulated rewards\n        uint256 boostMultiplier; // User-specific boost (1000 = 1x)\n        uint256 lockEndTime; // Lock period end time\n        bool isVIP; // VIP status for bonus rewards\n    }\n\n    struct PoolInfo {\n        IERC20 lpToken; // LP token contract\n        uint256 allocPoint; // Allocation points for this pool\n        uint256 lastRewardBlock; // Last block number where rewards were calculated\n        uint256 accRewardPerShare; // Accumulated rewards per share\n        uint256 totalStaked; // Total amount staked in pool\n        uint256 minimumStake; // Minimum stake amount\n        uint256 lockPeriod; // Lock period in seconds\n        uint256 withdrawalFee; // Early withdrawal fee (basis points)\n        bool emergencyWithdrawEnabled; // Emergency withdrawal status\n        address oracle; // Price oracle for this pool\n        uint256 lastPriceUpdate; // Last oracle price update\n    }\n\n    struct RewardBoost {\n        uint256 duration; // Boost duration in blocks\n        uint256 multiplier; // Boost multiplier (1000 = 1x)\n        uint256 startBlock; // Boost start block\n        uint256 endBlock; // Boost end block\n        bool active; // Boost status\n    }\n\n    // Core state variables\n    IERC20 public rewardToken;\n    address public treasury;\n\n    PoolInfo[] public poolInfo;\n    mapping(uint256 => mapping(address => UserInfo)) public userInfo;\n    mapping(address => bool) public authorizedUpdaters;\n    mapping(uint256 => RewardBoost) public poolBoosts;\n\n    // Reward parameters\n    uint256 public rewardPerBlock = 10e18; // Base reward per block\n    uint256 public totalAllocPoint = 0;\n    uint256 public startBlock;\n    uint256 public bonusEndBlock;\n\n    // Advanced features\n    uint256 public globalBoostMultiplier = 1000; // 1x by default\n    uint256 public vipBoostMultiplier = 1500; // 1.5x for VIP users\n    uint256 public emergencyFee = 1000; // 10% emergency withdrawal fee\n    uint256 public maxLockPeriod = 365 days;\n\n    // VULNERABILITY: Time-based parameters that can be manipulated\n    uint256 public rewardCalculationWindow = 1 hours;\n    uint256 public priceUpdateThreshold = 300; // 5 minutes\n    uint256 public constant PRECISION_FACTOR = 1e12;\n\n    // VULNERABILITY: Mutable fee structure\n    mapping(address => uint256) public userWithdrawalFees;\n    mapping(uint256 => uint256) public poolDepositFees;\n\n    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);\n    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);\n    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);\n    event RewardPaid(address indexed user, uint256 amount);\n    event PoolAdded(uint256 indexed pid, address lpToken, uint256 allocPoint);\n    event BoostActivated(uint256 indexed pid, uint256 multiplier, uint256 duration);\n\n    modifier onlyAuthorized() {\n        require(authorizedUpdaters[msg.sender] || msg.sender == owner(), "Not authorized");\n        _;\n    }\n\n    modifier validPool(uint256 _pid) {\n        require(_pid < poolInfo.length, "Invalid pool");\n        _;\n    }\n\n    constructor(\n        IERC20 _rewardToken,\n        address _treasury,\n        uint256 _startBlock\n    ) Ownable(msg.sender) {\n        rewardToken = _rewardToken;\n        treasury = _treasury;\n        startBlock = _startBlock;\n        bonusEndBlock = _startBlock.add(200000); // ~30 days assuming 13s blocks\n\n        authorizedUpdaters[msg.sender] = true;\n    }\n\n    /**\n     * @dev Add new staking pool - VULNERABLE to misconfiguration\n     */\n    function addPool(\n        uint256 _allocPoint,\n        IERC20 _lpToken,\n        uint256 _minimumStake,\n        uint256 _lockPeriod,\n        uint256 _withdrawalFee,\n        address _oracle,\n        bool _withUpdate\n    ) external onlyOwner {\n        if (_withUpdate) {\n            massUpdatePools();\n        }\n\n        // VULNERABILITY: No validation of parameters\n        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;\n        totalAllocPoint = totalAllocPoint.add(_allocPoint);\n\n        poolInfo.push(PoolInfo({\n            lpToken: _lpToken,\n            allocPoint: _allocPoint,\n            lastRewardBlock: lastRewardBlock,\n            accRewardPerShare: 0,\n            totalStaked: 0,\n            minimumStake: _minimumStake,\n            lockPeriod: _lockPeriod,\n            withdrawalFee: _withdrawalFee,\n            emergencyWithdrawEnabled: true,\n            oracle: _oracle,\n            lastPriceUpdate: block.timestamp\n        }));\n\n        emit PoolAdded(poolInfo.length.sub(1), address(_lpToken), _allocPoint);\n    }\n\n    /**\n     * @dev Stake LP tokens - VULNERABLE to flash loan attacks\n     */\n    function deposit(uint256 _pid, uint256 _amount) external nonReentrant validPool(_pid) {\n        PoolInfo storage pool = poolInfo[_pid];\n        UserInfo storage user = userInfo[_pid][msg.sender];\n\n        require(_amount >= pool.minimumStake, "Below minimum stake");\n\n        updatePool(_pid);\n\n        // VULNERABILITY: Reward calculation before new deposit is considered\n        if (user.amount > 0) {\n            uint256 pending = user.amount.mul(pool.accRewardPerShare).div(PRECISION_FACTOR).sub(user.rewardDebt);\n            if (pending > 0) {\n                user.accumulatedRewards = user.accumulatedRewards.add(pending);\n            }\n        }\n\n        // VULNERABILITY: External call before state update\n        pool.lpToken.transferFrom(msg.sender, address(this), _amount);\n\n        // VULNERABILITY: Deposit fee calculated after transfer\n        uint256 depositFee = _amount.mul(poolDepositFees[_pid]).div(10000);\n        uint256 actualAmount = _amount.sub(depositFee);\n\n        if (depositFee > 0) {\n            pool.lpToken.transfer(treasury, depositFee);\n        }\n\n        user.amount = user.amount.add(actualAmount);\n        user.lastStakeTime = block.timestamp;\n        user.lockEndTime = block.timestamp.add(pool.lockPeriod);\n        pool.totalStaked = pool.totalStaked.add(actualAmount);\n\n        user.rewardDebt = user.amount.mul(pool.accRewardPerShare).div(PRECISION_FACTOR);\n\n        emit Deposit(msg.sender, _pid, actualAmount);\n    }\n\n    /**\n     * @dev Withdraw LP tokens - VULNERABLE to timing manipulation\n     */\n    function withdraw(uint256 _pid, uint256 _amount) external nonReentrant validPool(_pid) {\n        PoolInfo storage pool = poolInfo[_pid];\n        UserInfo storage user = userInfo[_pid][msg.sender];\n\n        require(user.amount >= _amount, "Insufficient balance");\n\n        updatePool(_pid);\n\n        // VULNERABILITY: Lock period can be bypassed with emergency withdrawal\n        require(block.timestamp >= user.lockEndTime, "Still locked");\n\n        uint256 pending = user.amount.mul(pool.accRewardPerShare).div(PRECISION_FACTOR).sub(user.rewardDebt);\n        if (pending > 0) {\n            user.accumulatedRewards = user.accumulatedRewards.add(pending);\n        }\n\n        user.amount = user.amount.sub(_amount);\n        pool.totalStaked = pool.totalStaked.sub(_amount);\n\n        // VULNERABILITY: Withdrawal fee calculation can be manipulated\n        uint256 withdrawalFee = 0;\n        if (block.timestamp < user.lastStakeTime.add(7 days)) {\n            withdrawalFee = _amount.mul(pool.withdrawalFee).div(10000);\n        }\n\n        uint256 withdrawAmount = _amount.sub(withdrawalFee);\n\n        if (withdrawalFee > 0) {\n            pool.lpToken.transfer(treasury, withdrawalFee);\n        }\n\n        pool.lpToken.transfer(msg.sender, withdrawAmount);\n\n        user.rewardDebt = user.amount.mul(pool.accRewardPerShare).div(PRECISION_FACTOR);\n\n        emit Withdraw(msg.sender, _pid, withdrawAmount);\n    }\n\n    /**\n     * @dev Emergency withdraw - VULNERABLE to abuse\n     */\n    function emergencyWithdraw(uint256 _pid) external nonReentrant validPool(_pid) {\n        PoolInfo storage pool = poolInfo[_pid];\n        UserInfo storage user = userInfo[_pid][msg.sender];\n\n        require(pool.emergencyWithdrawEnabled, "Emergency withdraw disabled");\n\n        uint256 amount = user.amount;\n        user.amount = 0;\n        user.rewardDebt = 0;\n        user.accumulatedRewards = 0; // VULNERABILITY: Loses all accumulated rewards\n\n        pool.totalStaked = pool.totalStaked.sub(amount);\n\n        // VULNERABILITY: Emergency fee can be bypassed by admin\n        uint256 fee = amount.mul(emergencyFee).div(10000);\n        uint256 withdrawAmount = amount.sub(fee);\n\n        if (fee > 0) {\n            pool.lpToken.transfer(treasury, fee);\n        }\n\n        pool.lpToken.transfer(msg.sender, withdrawAmount);\n\n        emit EmergencyWithdraw(msg.sender, _pid, withdrawAmount);\n    }\n\n    /**\n     * @dev Claim accumulated rewards - VULNERABLE to MEV attacks\n     */\n    function claimRewards(uint256 _pid) external nonReentrant validPool(_pid) {\n        updatePool(_pid);\n\n        UserInfo storage user = userInfo[_pid][msg.sender];\n        PoolInfo storage pool = poolInfo[_pid];\n\n        uint256 pending = user.amount.mul(pool.accRewardPerShare).div(PRECISION_FACTOR).sub(user.rewardDebt);\n        uint256 totalRewards = user.accumulatedRewards.add(pending);\n\n        require(totalRewards > 0, "No rewards to claim");\n\n        // VULNERABILITY: Time-based boost calculation can be gamed\n        uint256 boost = calculateTimeBoost(user.lastRewardTime);\n        uint256 vipBoost = user.isVIP ? vipBoostMultiplier : 1000;\n        uint256 globalBoost = globalBoostMultiplier;\n\n        uint256 finalRewards = totalRewards\n            .mul(boost).div(1000)\n            .mul(vipBoost).div(1000)\n            .mul(globalBoost).div(1000);\n\n        user.accumulatedRewards = 0;\n        user.lastRewardTime = block.timestamp;\n        user.rewardDebt = user.amount.mul(pool.accRewardPerShare).div(PRECISION_FACTOR);\n\n        // VULNERABILITY: External call to transfer rewards\n        safeRewardTransfer(msg.sender, finalRewards);\n\n        emit RewardPaid(msg.sender, finalRewards);\n    }\n\n    /**\n     * @dev Update pool rewards - VULNERABLE to manipulation\n     */\n    function updatePool(uint256 _pid) public validPool(_pid) {\n        PoolInfo storage pool = poolInfo[_pid];\n\n        if (block.number <= pool.lastRewardBlock) {\n            return;\n        }\n\n        uint256 lpSupply = pool.totalStaked;\n        if (lpSupply == 0) {\n            pool.lastRewardBlock = block.number;\n            return;\n        }\n\n        // VULNERABILITY: Reward calculation based on current price, can be manipulated\n        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);\n        uint256 baseReward = multiplier.mul(rewardPerBlock).mul(pool.allocPoint).div(totalAllocPoint);\n\n        // VULNERABILITY: Oracle price used without staleness check\n        uint256 priceMultiplier = getPriceMultiplier(_pid);\n        uint256 reward = baseReward.mul(priceMultiplier).div(1000);\n\n        // Apply pool-specific boost if active\n        RewardBoost storage boost = poolBoosts[_pid];\n        if (boost.active && block.number >= boost.startBlock && block.number <= boost.endBlock) {\n            reward = reward.mul(boost.multiplier).div(1000);\n        }\n\n        pool.accRewardPerShare = pool.accRewardPerShare.add(reward.mul(PRECISION_FACTOR).div(lpSupply));\n        pool.lastRewardBlock = block.number;\n    }\n\n    /**\n     * @dev Calculate price multiplier - VULNERABLE to oracle manipulation\n     */\n    function getPriceMultiplier(uint256 _pid) public view returns (uint256) {\n        PoolInfo storage pool = poolInfo[_pid];\n\n        if (pool.oracle == address(0)) {\n            return 1000; // 1x multiplier if no oracle\n        }\n\n        // VULNERABILITY: Using spot price without TWAP validation\n        try IOracle(pool.oracle).getPrice(address(pool.lpToken)) returns (uint256 currentPrice) {\n            try IOracle(pool.oracle).getTWAP(address(pool.lpToken), 1 hours) returns (uint256 twapPrice) {\n                // VULNERABILITY: Price deviation calculation can overflow\n                uint256 deviation = currentPrice > twapPrice ?\n                    currentPrice.sub(twapPrice).mul(1000).div(twapPrice) :\n                    twapPrice.sub(currentPrice).mul(1000).div(twapPrice);\n\n                // Higher deviation = higher rewards (VULNERABILITY: Incentivizes manipulation)\n                if (deviation > 100) { // >10% deviation\n                    return 1500; // 1.5x multiplier\n                } else if (deviation > 50) { // >5% deviation\n                    return 1200; // 1.2x multiplier\n                }\n                return 1000; // 1x multiplier\n            } catch {\n                return 1000;\n            }\n        } catch {\n            return 1000;\n        }\n    }\n\n    /**\n     * @dev Calculate time-based boost - VULNERABLE to timestamp manipulation\n     */\n    function calculateTimeBoost(uint256 lastRewardTime) public view returns (uint256) {\n        if (lastRewardTime == 0) {\n            return 1000; // No previous claim\n        }\n\n        uint256 timeSinceLastClaim = block.timestamp.sub(lastRewardTime);\n\n        // VULNERABILITY: Longer periods = higher boost (incentivizes timing games)\n        if (timeSinceLastClaim >= 30 days) {\n            return 2000; // 2x boost\n        } else if (timeSinceLastClaim >= 7 days) {\n            return 1500; // 1.5x boost\n        } else if (timeSinceLastClaim >= 1 days) {\n            return 1200; // 1.2x boost\n        }\n\n        return 1000; // 1x boost\n    }\n\n    /**\n     * @dev Mass update all pools\n     */\n    function massUpdatePools() public {\n        uint256 length = poolInfo.length;\n        for (uint256 pid = 0; pid < length; ++pid) {\n            updatePool(pid);\n        }\n    }\n\n    /**\n     * @dev Set VIP status - VULNERABLE to admin abuse\n     */\n    function setVIPStatus(address user, bool isVIP) external onlyAuthorized {\n        // VULNERABILITY: VIP status can be changed instantly\n        userInfo[0][user].isVIP = isVIP; // Simplified - should be per pool\n    }\n\n    /**\n     * @dev Activate boost for pool - VULNERABLE to timing manipulation\n     */\n    function activateBoost(\n        uint256 _pid,\n        uint256 _multiplier,\n        uint256 _duration\n    ) external onlyAuthorized validPool(_pid) {\n        // VULNERABILITY: Boost can be activated instantly\n        require(_multiplier >= 1000 && _multiplier <= 5000, "Invalid multiplier");\n\n        poolBoosts[_pid] = RewardBoost({\n            duration: _duration,\n            multiplier: _multiplier,\n            startBlock: block.number,\n            endBlock: block.number.add(_duration),\n            active: true\n        });\n\n        emit BoostActivated(_pid, _multiplier, _duration);\n    }\n\n    /**\n     * @dev Emergency functions - VULNERABLE to admin abuse\n     */\n    function emergencyRewardWithdraw(uint256 _amount) external onlyOwner {\n        // VULNERABILITY: Owner can drain all rewards\n        rewardToken.transfer(owner(), _amount);\n    }\n\n    function setEmergencyWithdraw(uint256 _pid, bool _enabled) external onlyOwner validPool(_pid) {\n        poolInfo[_pid].emergencyWithdrawEnabled = _enabled;\n    }\n\n    /**\n     * @dev Get multiplier between blocks\n     */\n    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {\n        if (_to <= bonusEndBlock) {\n            return _to.sub(_from);\n        } else if (_from >= bonusEndBlock) {\n            return _to.sub(_from).div(2); // Half rewards after bonus period\n        } else {\n            return bonusEndBlock.sub(_from).add(_to.sub(bonusEndBlock).div(2));\n        }\n    }\n\n    /**\n     * @dev Safe reward transfer with supply check\n     */\n    function safeRewardTransfer(address _to, uint256 _amount) internal {\n        uint256 rewardBal = rewardToken.balanceOf(address(this));\n        if (_amount > rewardBal) {\n            rewardToken.transfer(_to, rewardBal);\n        } else {\n            rewardToken.transfer(_to, _amount);\n        }\n    }\n\n    /**\n     * @dev View functions\n     */\n    function poolLength() external view returns (uint256) {\n        return poolInfo.length;\n    }\n\n    function pendingRewards(uint256 _pid, address _user) external view validPool(_pid) returns (uint256) {\n        PoolInfo storage pool = poolInfo[_pid];\n        UserInfo storage user = userInfo[_pid][_user];\n        uint256 accRewardPerShare = pool.accRewardPerShare;\n        uint256 lpSupply = pool.totalStaked;\n\n        if (block.number > pool.lastRewardBlock && lpSupply != 0) {\n            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);\n            uint256 reward = multiplier.mul(rewardPerBlock).mul(pool.allocPoint).div(totalAllocPoint);\n            accRewardPerShare = accRewardPerShare.add(reward.mul(PRECISION_FACTOR).div(lpSupply));\n        }\n\n        return user.amount.mul(accRewardPerShare).div(PRECISION_FACTOR).sub(user.rewardDebt).add(user.accumulatedRewards);\n    }\n\n    // VULNERABILITY: Fallback function accepts ETH\n    receive() external payable {}\n}	\N	510	f	\N	1	0	solidity	0.8.20	{"license": "MIT", "detection_method": "extension", "detection_confidence": 0.95}	scanned	2025-10-19 03:49:27.264385+00	2025-10-24 22:59:43.179368+00
70b27594-33ef-4d19-b443-1906060c5cc6	fd01ee0b-02c6-48c3-8d2e-fa150a152d2e	Phase4-Pipeline-Test	\N	ethereum	// SPDX-License-Identifier: MIT\npragma solidity ^0.8.0;\n\n/**\n * @title ReentrancyTest\n * @notice Test contract with known vulnerabilities for pipeline validation\n * @dev Contains reentrancy, missing access control, and unchecked return values\n */\ncontract ReentrancyTest {\n    mapping(address => uint256) public balances;\n    address public owner;\n\n    constructor() {\n        owner = msg.sender;\n    }\n\n    function deposit() public payable {\n        balances[msg.sender] += msg.value;\n    }\n\n    // VULNERABILITY: Classic reentrancy - external call before state update\n    function withdraw() public {\n        uint256 balance = balances[msg.sender];\n        require(balance > 0, "No balance");\n        (bool success, ) = msg.sender.call{value: balance}("");\n        require(success, "Transfer failed");\n        balances[msg.sender] = 0; // State update AFTER external call\n    }\n\n    // VULNERABILITY: Missing access control\n    function setOwner(address newOwner) public {\n        owner = newOwner;\n    }\n\n    // VULNERABILITY: Unchecked return value\n    function withdrawTo(address payable recipient) public {\n        uint256 balance = balances[msg.sender];\n        require(balance > 0, "No balance");\n        recipient.send(balance); // Return value not checked\n        balances[msg.sender] = 0;\n    }\n\n    // VULNERABILITY: Integer overflow (if using older Solidity)\n    function unsafeDeposit() public payable {\n        balances[msg.sender] += msg.value;\n    }\n\n    function getBalance() public view returns (uint256) {\n        return balances[msg.sender];\n    }\n}\n	\N	51	f	\N	1	0	solidity	\N	null	scanned	2025-10-27 21:33:41.776157+00	2025-10-27 21:34:10.729038+00
c065cb49-0a9e-465c-9944-2ba193513c97	ab45210a-44a1-490e-bd5f-18135cdc3c91	Bridge Token Minting Complex	\N	ethereum	// SPDX-License-Identifier: MIT\npragma solidity ^0.8.0;\n\n/// @title Bridge Token with Access Control but Missing Validation & Limits\n/// @notice Has access control but missing message validation and amount limits\n/// @dev Should trigger multiple findings from bridge-token-mint-control detector\n\ncontract BridgeToken {\n    mapping(address => uint256) public balances;\n    uint256 public totalSupply;\n    address public bridge;\n\n    event Minted(address indexed to, uint256 amount);\n\n    modifier onlyBridge() {\n        require(msg.sender == bridge, "Only bridge");\n        _;\n    }\n\n    constructor(address _bridge) {\n        bridge = _bridge;\n    }\n\n    /// @notice Mint with access control but NO message validation\n    /// @dev VULNERABILITY: Missing cross-chain message verification\n    function mint(address to, uint256 amount) external onlyBridge {\n        balances[to] += amount;\n        totalSupply += amount;\n        emit Minted(to, amount);\n    }\n\n    /// @notice Mint with access control and message verification but NO limits\n    /// @dev VULNERABILITY: Missing maximum mint amount limits\n    function mintVerified(\n        address to,\n        uint256 amount,\n        bytes32 messageHash,\n        bytes calldata signature\n    ) external onlyBridge {\n        require(verifyMessage(messageHash, signature), "Invalid message");\n\n        balances[to] += amount;\n        totalSupply += amount;\n        emit Minted(to, amount);\n    }\n\n    function verifyMessage(bytes32, bytes calldata) internal pure returns (bool) {\n        return true;\n    }\n}\n	\N	50	f	\N	1	0	solidity	0.8.0	{"license": "MIT", "detection_method": "extension", "detection_confidence": 0.95}	scanned	2025-10-28 03:53:28.769723+00	2025-10-28 04:21:42.123178+00
\.


--
-- Data for Name: deduplication_group_members; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.deduplication_group_members (id, group_id, finding_id, match_confidence, matched_fingerprints, is_canonical, added_at) FROM stdin;
\.


--
-- Data for Name: deduplication_groups; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.deduplication_groups (id, primary_vulnerability_id, contract_id, pattern_id, group_size, strategy, confidence, fingerprint_code, fingerprint_ast, fingerprint_semantic, severity_distribution, scanner_distribution, first_detected, last_updated, verified, verified_by, verified_at, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: formal_verification_results; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.formal_verification_results (id, scan_id, scanner_id, property_name, status, proof_type, description, counterexample, verification_time, created_at) FROM stdin;
\.


--
-- Data for Name: fuzzing_results; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.fuzzing_results (id, scan_id, scanner_id, test_name, status, executions, coverage_percentage, edge_cases_found, failure_trace, seed, created_at) FROM stdin;
\.


--
-- Data for Name: gas_analysis_findings; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.gas_analysis_findings (id, scan_id, scanner_id, function_name, gas_cost, optimization_level, optimization_suggestion, potential_savings, location, code_example, created_at, contract_id, detector_id, file_path, contract_name) FROM stdin;
107354aa-8b63-4c98-9712-46aaaf6754e9	bc87370e-ee8d-4251-b30a-3a0ad54fd735	slither	vulnerableBank	0	critical	ReentrancyAttacker.vulnerableBank (ReEntrancy Contract.sol#41) should be immutable \n	15000	{"file": "ReEntrancy Contract.sol", "line": 41}	\N	2025-10-24 03:57:01.968641+00	a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11	\N	\N	\N
d97b4d7f-b19d-432a-9ff1-7819e8fe19e7	7cbbfacf-e078-4aa5-87da-ca5b8c9d578b	slither	vulnerableBank	0	critical	ReentrancyAttacker.vulnerableBank (ReEntrancy Contract.sol#41) should be immutable \n	15000	{"file": "ReEntrancy Contract.sol", "line": 41}	\N	2025-10-24 05:07:39.751471+00	a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11	\N	\N	\N
731eac94-36c6-4cbc-831b-16a19ddf9a21	0746ab0f-fbb3-485a-86f1-098f20fad4a1	slither	vulnerableBank	0	critical	ReentrancyAttacker.vulnerableBank (ReEntrancy Contract.sol#41) should be immutable \n	15000	{"file": "ReEntrancy Contract.sol", "line": 41}	\N	2025-10-24 17:57:51.199903+00	a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11	\N	\N	\N
f9cc4380-9dc4-4807-8d39-fd88388efeda	6baaca28-a409-4c4d-802a-c0c56a170890	slither	vulnerableBank	0	critical	ReentrancyAttacker.vulnerableBank (ReEntrancy Contract.sol#41) should be immutable \n	15000	{"file": "ReEntrancy Contract.sol", "line": 41}	\N	2025-10-25 15:55:48.362614+00	86f9a16f-7896-4115-b321-adf9db382682	\N	\N	\N
809be15d-6ea4-45fb-9974-dca282a67519	3a0084eb-8cac-457e-80a3-c2b68269e224	slither	vulnerableBank	0	critical	ReentrancyAttacker.vulnerableBank (ReEntrancy Contract.sol#41) should be immutable \n	15000	{"file": "ReEntrancy Contract.sol", "line": 41}	\N	2025-10-25 15:56:21.263299+00	86f9a16f-7896-4115-b321-adf9db382682	\N	\N	\N
4d4d97e4-9c27-4254-a105-4f4c1944ca78	1c237e1a-5a68-47f1-aa48-05b9ff872c50	slither	vulnerableBank	0	critical	ReentrancyAttacker.vulnerableBank (ReEntrancy Contract.sol#41) should be immutable \n	15000	{"file": "ReEntrancy Contract.sol", "line": 41}	\N	2025-10-25 17:50:29.976832+00	86f9a16f-7896-4115-b321-adf9db382682	immutable-states	ReEntrancy Contract.sol	ReentrancyAttacker
f4d41be7-16ff-4f89-afd1-9f29c5730b19	1018d5b1-0265-4096-b2e1-87e664298284	slither	vulnerableBank	0	critical	ReentrancyAttacker.vulnerableBank (ReEntrancy Contract.sol#41) should be immutable \n	15000	{"file": "ReEntrancy Contract.sol", "line": 41}	\N	2025-10-25 18:14:00.396652+00	86f9a16f-7896-4115-b321-adf9db382682	immutable-states	ReEntrancy Contract.sol	ReentrancyAttacker
2af17f7f-e136-46b0-8ef7-bc2e9e21200e	9c4b1006-5d71-48da-b416-18f3684d4572	slither	vulnerableBank	0	critical	ReentrancyAttacker.vulnerableBank (ReEntrancy Contract.sol#41) should be immutable \n	15000	{"file": "ReEntrancy Contract.sol", "line": 41}	\N	2025-10-25 18:29:32.659193+00	86f9a16f-7896-4115-b321-adf9db382682	immutable-states	ReEntrancy Contract.sol	ReentrancyAttacker
133614d2-a4df-4cf4-b8c9-5bf6bb57fca5	f2201b28-2a42-4d87-9ebd-ba094580f571	slither	vulnerableBank	0	critical	ReentrancyAttacker.vulnerableBank (ReEntrancy Contract.sol#41) should be immutable \n	15000	{"file": "ReEntrancy Contract.sol", "line": 41}	\N	2025-10-25 18:29:32.664953+00	86f9a16f-7896-4115-b321-adf9db382682	immutable-states	ReEntrancy Contract.sol	ReentrancyAttacker
e8d22e13-b515-40a8-b3e0-5ebe6fb27315	d4d01fd8-ced4-4209-b8f2-659cdabf3a67	slither	i < shareholders.length	0	low	Loop condition i < shareholders.length (Denial of Service.sol#46) should use cached array length instead of referencing `length` member of the storage array.\n 	100	{"file": "Denial of Service.sol", "line": 46}	\N	2025-10-25 20:55:22.812031+00	fc783138-6c5a-4dce-b469-9fdf46020f14	cache-array-length	Denial of Service.sol	\N
a67582e8-9bb0-4077-aa1d-bd7b469ee76a	d4d01fd8-ced4-4209-b8f2-659cdabf3a67	slither	i < recipients.length	0	low	Loop condition i < recipients.length (Denial of Service.sol#109) should use cached array length instead of referencing `length` member of the storage array.\n 	100	{"file": "Denial of Service.sol", "line": 109}	\N	2025-10-25 20:55:22.812041+00	fc783138-6c5a-4dce-b469-9fdf46020f14	cache-array-length	Denial of Service.sol	\N
818bac19-33d2-4da8-8831-46a735905004	d4d01fd8-ced4-4209-b8f2-659cdabf3a67	slither	i < users.length	0	low	Loop condition i < users.length (Denial of Service.sol#84) should use cached array length instead of referencing `length` member of the storage array.\n 	100	{"file": "Denial of Service.sol", "line": 84}	\N	2025-10-25 20:55:22.812047+00	fc783138-6c5a-4dce-b469-9fdf46020f14	cache-array-length	Denial of Service.sol	\N
caee542a-2bc9-4646-be8b-5facee15b95e	d4d01fd8-ced4-4209-b8f2-659cdabf3a67	slither	i_scope_0 < shareholders.length	0	low	Loop condition i_scope_0 < shareholders.length (Denial of Service.sol#50) should use cached array length instead of referencing `length` member of the storage array.\n 	100	{"file": "Denial of Service.sol", "line": 50}	\N	2025-10-25 20:55:22.812051+00	fc783138-6c5a-4dce-b469-9fdf46020f14	cache-array-length	Denial of Service.sol	\N
0a366f8c-d082-4759-b729-ff795b9fedf9	d4d01fd8-ced4-4209-b8f2-659cdabf3a67	slither	i < users.length	0	low	Loop condition i < users.length (Denial of Service.sol#74) should use cached array length instead of referencing `length` member of the storage array.\n 	100	{"file": "Denial of Service.sol", "line": 74}	\N	2025-10-25 20:55:22.812055+00	fc783138-6c5a-4dce-b469-9fdf46020f14	cache-array-length	Denial of Service.sol	\N
f3b3dae2-3dd0-41b5-b907-99bc70bd4cb8	d4d01fd8-ced4-4209-b8f2-659cdabf3a67	slither	auction	0	critical	MaliciousBidder.auction (Denial of Service.sol#120) should be immutable \n	15000	{"file": "Denial of Service.sol", "line": 120}	\N	2025-10-25 20:55:22.812059+00	fc783138-6c5a-4dce-b469-9fdf46020f14	immutable-states	Denial of Service.sol	MaliciousBidder
a0d6ee1b-8e51-4d10-bd66-41f413d5776d	00658c8e-a359-426c-90a0-31f9489c3759	slither	externalContract	0	critical	VulnerableIntegration.externalContract (Unchecked Call.sol#56) should be immutable \n	15000	{"file": "Unchecked Call.sol", "line": 56}	\N	2025-10-25 21:03:19.725692+00	97970ea9-196b-4643-95e6-f1aa019bcf6f	immutable-states	Unchecked Call.sol	VulnerableIntegration
8abf69c6-5be9-4313-b8b9-5bb62a78d0e1	2f987517-ca20-43c5-aabc-0246f8973d2e	slither	name	0	critical	VulnerableERC20.name (Front Running.sol#117) should be constant \n	20000	{"file": "Front Running.sol", "line": 117}	\N	2025-10-25 22:35:03.551899+00	4557d54f-bc37-4e82-819f-32a9a5137315	constable-states	Front Running.sol	VulnerableERC20
3fea5e5f-9b8a-4d28-a626-8f4fe4f0f1b2	2f987517-ca20-43c5-aabc-0246f8973d2e	slither	symbol	0	critical	VulnerableERC20.symbol (Front Running.sol#118) should be constant \n	20000	{"file": "Front Running.sol", "line": 118}	\N	2025-10-25 22:35:03.551904+00	4557d54f-bc37-4e82-819f-32a9a5137315	constable-states	Front Running.sol	VulnerableERC20
0c66517e-df1a-41e0-b974-8ddb4f346d3f	2f987517-ca20-43c5-aabc-0246f8973d2e	slither	reward	0	critical	VulnerablePuzzle.reward (Front Running.sol#13) should be constant \n	20000	{"file": "Front Running.sol", "line": 13}	\N	2025-10-25 22:35:03.551908+00	4557d54f-bc37-4e82-819f-32a9a5137315	constable-states	Front Running.sol	VulnerablePuzzle
096d9454-9b9f-4f7d-b250-674b944a6c9b	2f987517-ca20-43c5-aabc-0246f8973d2e	slither	owner	0	critical	VulnerableICO.owner (Front Running.sol#85) should be immutable \n	15000	{"file": "Front Running.sol", "line": 85}	\N	2025-10-25 22:35:03.551911+00	4557d54f-bc37-4e82-819f-32a9a5137315	immutable-states	Front Running.sol	VulnerableICO
73fe8251-f693-457c-abc3-3464fe4dbf01	2f987517-ca20-43c5-aabc-0246f8973d2e	slither	solutionHash	0	critical	VulnerablePuzzle.solutionHash (Front Running.sol#12) should be immutable \n	15000	{"file": "Front Running.sol", "line": 12}	\N	2025-10-25 22:35:03.551913+00	4557d54f-bc37-4e82-819f-32a9a5137315	immutable-states	Front Running.sol	VulnerablePuzzle
596afe27-d883-4901-8de2-5f411289046b	2f987517-ca20-43c5-aabc-0246f8973d2e	slither	owner	0	critical	VulnerablePuzzle.owner (Front Running.sol#14) should be immutable \n	15000	{"file": "Front Running.sol", "line": 14}	\N	2025-10-25 22:35:03.551916+00	4557d54f-bc37-4e82-819f-32a9a5137315	immutable-states	Front Running.sol	VulnerablePuzzle
3b30bcaa-d016-461b-a33d-5d0b165b9895	fe153dad-4c0b-4165-b529-6cec12692b34	slither	name	0	critical	VulnerableERC20.name (Front Running.sol#117) should be constant \n	20000	{"file": "Front Running.sol", "line": 117}	\N	2025-10-25 23:18:36.64186+00	4557d54f-bc37-4e82-819f-32a9a5137315	constable-states	Front Running.sol	VulnerableERC20
44352fe0-bfe3-4ec3-98d6-fcef3d152558	fe153dad-4c0b-4165-b529-6cec12692b34	slither	symbol	0	critical	VulnerableERC20.symbol (Front Running.sol#118) should be constant \n	20000	{"file": "Front Running.sol", "line": 118}	\N	2025-10-25 23:18:36.641869+00	4557d54f-bc37-4e82-819f-32a9a5137315	constable-states	Front Running.sol	VulnerableERC20
0f040f77-cf64-49b8-a6d3-091900102bf8	fe153dad-4c0b-4165-b529-6cec12692b34	slither	reward	0	critical	VulnerablePuzzle.reward (Front Running.sol#13) should be constant \n	20000	{"file": "Front Running.sol", "line": 13}	\N	2025-10-25 23:18:36.641873+00	4557d54f-bc37-4e82-819f-32a9a5137315	constable-states	Front Running.sol	VulnerablePuzzle
2b7b4719-4f0b-457c-82fa-fe5e41f91413	fe153dad-4c0b-4165-b529-6cec12692b34	slither	owner	0	critical	VulnerableICO.owner (Front Running.sol#85) should be immutable \n	15000	{"file": "Front Running.sol", "line": 85}	\N	2025-10-25 23:18:36.641877+00	4557d54f-bc37-4e82-819f-32a9a5137315	immutable-states	Front Running.sol	VulnerableICO
53b4ae69-7570-467d-84ad-df56a4eecbbf	fe153dad-4c0b-4165-b529-6cec12692b34	slither	solutionHash	0	critical	VulnerablePuzzle.solutionHash (Front Running.sol#12) should be immutable \n	15000	{"file": "Front Running.sol", "line": 12}	\N	2025-10-25 23:18:36.641881+00	4557d54f-bc37-4e82-819f-32a9a5137315	immutable-states	Front Running.sol	VulnerablePuzzle
a6544b91-c8ac-4e77-81be-781dedfa840a	fe153dad-4c0b-4165-b529-6cec12692b34	slither	owner	0	critical	VulnerablePuzzle.owner (Front Running.sol#14) should be immutable \n	15000	{"file": "Front Running.sol", "line": 14}	\N	2025-10-25 23:18:36.641884+00	4557d54f-bc37-4e82-819f-32a9a5137315	immutable-states	Front Running.sol	VulnerablePuzzle
827ae2a7-6712-4a24-a767-a8fc1b46b6e9	b5b1f73c-53b8-4567-ae23-3e25c00143af	slither	name	0	critical	VulnerableERC20.name (Front Running.sol#117) should be constant \n	20000	{"file": "Front Running.sol", "line": 117}	\N	2025-10-25 23:44:29.43018+00	4557d54f-bc37-4e82-819f-32a9a5137315	constable-states	Front Running.sol	VulnerableERC20
6e742f19-28aa-4203-b3e3-f8c3cbad23e6	b5b1f73c-53b8-4567-ae23-3e25c00143af	slither	symbol	0	critical	VulnerableERC20.symbol (Front Running.sol#118) should be constant \n	20000	{"file": "Front Running.sol", "line": 118}	\N	2025-10-25 23:44:29.430187+00	4557d54f-bc37-4e82-819f-32a9a5137315	constable-states	Front Running.sol	VulnerableERC20
9634b1fe-ed19-4406-810c-ec4a8acf617c	b5b1f73c-53b8-4567-ae23-3e25c00143af	slither	reward	0	critical	VulnerablePuzzle.reward (Front Running.sol#13) should be constant \n	20000	{"file": "Front Running.sol", "line": 13}	\N	2025-10-25 23:44:29.430191+00	4557d54f-bc37-4e82-819f-32a9a5137315	constable-states	Front Running.sol	VulnerablePuzzle
122b46fb-8f82-46db-a164-bdb7ee8296f4	b5b1f73c-53b8-4567-ae23-3e25c00143af	slither	owner	0	critical	VulnerableICO.owner (Front Running.sol#85) should be immutable \n	15000	{"file": "Front Running.sol", "line": 85}	\N	2025-10-25 23:44:29.430194+00	4557d54f-bc37-4e82-819f-32a9a5137315	immutable-states	Front Running.sol	VulnerableICO
4c318adc-a22c-4405-9931-f3a70ab2ae08	b5b1f73c-53b8-4567-ae23-3e25c00143af	slither	solutionHash	0	critical	VulnerablePuzzle.solutionHash (Front Running.sol#12) should be immutable \n	15000	{"file": "Front Running.sol", "line": 12}	\N	2025-10-25 23:44:29.430197+00	4557d54f-bc37-4e82-819f-32a9a5137315	immutable-states	Front Running.sol	VulnerablePuzzle
e90d450f-d067-45d8-97db-5b90db7999ca	b5b1f73c-53b8-4567-ae23-3e25c00143af	slither	owner	0	critical	VulnerablePuzzle.owner (Front Running.sol#14) should be immutable \n	15000	{"file": "Front Running.sol", "line": 14}	\N	2025-10-25 23:44:29.430201+00	4557d54f-bc37-4e82-819f-32a9a5137315	immutable-states	Front Running.sol	VulnerablePuzzle
f002818e-34b2-4bde-9202-de97ac716e4e	d99fd397-e73d-4103-af77-6848b1212476	slither	vulnerableBank	0	critical	ReentrancyAttacker.vulnerableBank (ReEntrancy Contract.sol#41) should be immutable \n	15000	{"file": "ReEntrancy Contract.sol", "line": 41}	\N	2025-10-26 00:23:46.899074+00	86f9a16f-7896-4115-b321-adf9db382682	immutable-states	ReEntrancy Contract.sol	ReentrancyAttacker
ae4bbd01-7e63-4a5f-bec9-cc33b7ab4fa9	f6723229-7b79-4fe3-bb94-42f4b5f18369	slither	vulnerableBank	0	critical	ReentrancyAttacker.vulnerableBank (ReEntrancy Contract.sol#41) should be immutable \n	15000	{"file": "ReEntrancy Contract.sol", "line": 41}	\N	2025-10-26 00:44:57.017758+00	86f9a16f-7896-4115-b321-adf9db382682	immutable-states	ReEntrancy Contract.sol	ReentrancyAttacker
4c05e9da-5da9-4302-8b70-8d43b58019fd	9263afbb-6723-4249-a3c0-b59bab200f43	slither	bridge	0	critical	BridgeToken.bridge (Bridge Token Minting Complex.sol#11) should be immutable \n	15000	{"file": "Bridge Token Minting Complex.sol", "line": 11}	\N	2025-10-28 03:55:14.839673+00	c065cb49-0a9e-465c-9944-2ba193513c97	immutable-states	Bridge Token Minting Complex.sol	BridgeToken
\.


--
-- Data for Name: pattern_tool_mappings; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.pattern_tool_mappings (id, pattern_id, scanner_id, detector_id, confidence_threshold, match_type, keywords_override, created_at, updated_at, is_active) FROM stdin;
1b7b9b97-6e67-4e33-a592-76a85e5d6e86	REE-001	slither	reentrancy-eth	\N	exact	\N	2025-10-22 20:04:34.94463+00	2025-10-22 20:04:34.944633+00	t
585e546f-e8d7-46e7-8918-a4d334034ab3	REE-001	mythril	SWC-107	\N	exact	\N	2025-10-22 20:04:34.949948+00	2025-10-22 20:04:34.949952+00	t
033fa2ea-03dd-4eb0-8d64-b0a35c647c96	REE-001	aderyn	reentrancy	\N	exact	\N	2025-10-22 20:04:34.951977+00	2025-10-22 20:04:34.95198+00	t
5f06a26d-200a-43fc-a70d-4e5f426ead9d	REE-002	slither	reentrancy-no-eth	\N	fuzzy	\N	2025-10-22 20:04:34.954483+00	2025-10-22 20:04:34.954486+00	t
cd3429fa-799c-49ed-be25-a2ce60b039a7	ACC-001	slither	unprotected-function	\N	exact	\N	2025-10-22 20:04:34.957223+00	2025-10-22 20:04:34.957228+00	t
feb5e623-b647-4806-84d9-c24651997025	ACC-001	mythril	SWC-105	\N	exact	\N	2025-10-22 20:04:34.959735+00	2025-10-22 20:04:34.959739+00	t
ed6dd0d0-436e-4d0d-b36f-5b478737e272	INT-001	slither	overflow	\N	exact	\N	2025-10-22 20:04:34.961931+00	2025-10-22 20:04:34.961934+00	t
c5bebefd-40a1-4194-80aa-3fb4adc3001c	INT-001	mythril	SWC-101	\N	exact	\N	2025-10-22 20:04:34.963901+00	2025-10-22 20:04:34.963904+00	t
894ace31-7df4-4fd6-98be-b5c10594c7d4	INT-002	slither	underflow	\N	exact	\N	2025-10-22 20:04:34.965672+00	2025-10-22 20:04:34.965674+00	t
c24c4bf8-2192-4f7f-b2e2-ed5707b28e93	UNC-001	slither	unchecked-lowlevel	\N	exact	\N	2025-10-22 20:04:34.967379+00	2025-10-22 20:04:34.967382+00	t
04c71e0d-da59-4ae8-b665-cddbbd7b669b	UNC-002	slither	unchecked-send	\N	exact	\N	2025-10-22 20:04:34.96907+00	2025-10-22 20:04:34.969072+00	t
d0db4b41-af02-4382-9a23-dbe92f7679e0	DOS-001	slither	controlled-array-length	\N	fuzzy	\N	2025-10-22 20:04:34.970994+00	2025-10-22 20:04:34.970997+00	t
427608a7-73b4-4034-83a3-a31003a2131e	TIM-001	slither	timestamp	\N	exact	\N	2025-10-22 20:04:34.972859+00	2025-10-22 20:04:34.972861+00	t
370dc12c-b23b-4ee1-8ea0-63e2cd52dcb2	TIM-002	slither	tx-origin	\N	fuzzy	\N	2025-10-22 20:04:34.974644+00	2025-10-22 20:04:34.974647+00	t
09c76ef3-1823-430a-adb1-cdcac768339c	RAN-001	slither	weak-prng	\N	exact	\N	2025-10-22 20:04:34.976517+00	2025-10-22 20:04:34.97652+00	t
9c9ad310-18ff-483b-a362-8e185e7edf69	DEL-001	slither	controlled-delegatecall	\N	exact	\N	2025-10-22 20:04:34.978343+00	2025-10-22 20:04:34.978345+00	t
47c56ab9-62ee-4cbe-97ac-2a27a8dd2f4f	DEL-001	mythril	SWC-112	\N	exact	\N	2025-10-22 20:04:34.980104+00	2025-10-22 20:04:34.980106+00	t
3e8ea5d6-11ad-4a46-b4bb-7bfdcb15850d	SIG-001	slither	missing-zero-check	\N	fuzzy	\N	2025-10-22 20:04:34.981968+00	2025-10-22 20:04:34.98197+00	t
110588ab-a778-4158-a5cb-188e7afe6472	INI-001	slither	uninitialized-storage	\N	exact	\N	2025-10-22 20:04:34.983536+00	2025-10-22 20:04:34.983539+00	t
20ac233e-7350-4a85-9c45-ee6349e23b10	VIS-001	slither	incorrect-modifier	\N	fuzzy	\N	2025-10-22 20:04:34.985086+00	2025-10-22 20:04:34.985199+00	t
2cf7c649-30b2-407c-8433-04d2eb5adec7	SEL-001	slither	suicidal	\N	exact	\N	2025-10-22 20:04:34.986692+00	2025-10-22 20:04:34.986694+00	t
3822135b-2a83-4872-b2b7-e903643515b0	UNC-002	slither	arbitrary-send-eth	\N	exact	\N	2025-10-25 23:42:04.839772+00	2025-10-25 23:42:04.839772+00	t
24dd9a70-3911-4104-b027-f2d5d45e0af2	LOC-001	slither	locked-ether	\N	exact	\N	2025-10-25 23:42:18.192101+00	2025-10-25 23:42:18.192101+00	t
7b01a7f7-91de-4333-aedd-d8966c3ad6c7	BVD-COD-004	aderyn	constant-function-changes-state	\N	exact	\N	2025-10-29 23:54:23.987183+00	2025-10-29 23:54:23.987183+00	t
d5951d00-c3ae-4698-aba3-1d11e8323142	BVD-LOC-001	aderyn	contract-locks-ether	\N	exact	\N	2025-10-29 23:54:23.987183+00	2025-10-29 23:54:23.987183+00	t
f30c1e7d-b192-42cf-baca-664a1fbfc772	BVD-COL-001	aderyn	function-selector-collision	\N	exact	\N	2025-10-29 23:54:23.987183+00	2025-10-29 23:54:23.987183+00	t
b3068744-ca94-47aa-b904-e908e7860b96	BVD-ERC-001	aderyn	incorrect-erc721-interface	\N	exact	\N	2025-10-29 23:54:23.987183+00	2025-10-29 23:54:23.987183+00	t
bca579c5-d46f-4196-9fb2-c4ea207a442c	BVD-ERC-002	aderyn	incorrect-erc20-interface	\N	exact	\N	2025-10-29 23:54:23.987183+00	2025-10-29 23:54:23.987183+00	t
c097c418-33cc-42c4-ab46-049e91ae212f	BVD-EVM-REE-001	semgrep	compound-borrowfresh-reentrancy	\N	exact	\N	2025-10-31 23:32:56.729423+00	2025-10-31 23:32:56.729423+00	t
d834c211-35f5-4ee0-96ae-77a28386cec9	BVD-EVM-REE-004	semgrep	erc677-reentrancy	\N	exact	\N	2025-10-31 23:32:56.744168+00	2025-10-31 23:32:56.744168+00	t
215f5745-34e0-4899-9919-eeec01d66d02	BVD-EVM-REE-004	semgrep	erc777-reentrancy	\N	exact	\N	2025-10-31 23:32:56.7485+00	2025-10-31 23:32:56.7485+00	t
04b69d1d-9b81-4b7a-94c5-5e3600fc74a1	BVD-EVM-REE-004	semgrep	erc721-reentrancy	\N	exact	\N	2025-10-31 23:32:56.751566+00	2025-10-31 23:32:56.751566+00	t
af3ffbce-7015-412f-842a-6ce4d9f982ee	BVD-EVM-REE-005	semgrep	balancer-readonly-reentrancy-getrate	\N	exact	\N	2025-10-31 23:32:56.75499+00	2025-10-31 23:32:56.75499+00	t
3c8d28b3-dcd8-4b46-a329-d24cf4078427	BVD-EVM-REE-005	semgrep	balancer-readonly-reentrancy-getpooltokens	\N	exact	\N	2025-10-31 23:32:56.759441+00	2025-10-31 23:32:56.759441+00	t
e01d074b-1342-46fd-bf72-ef3ea8e88beb	BVD-EVM-REE-005	semgrep	curve-readonly-reentrancy	\N	exact	\N	2025-10-31 23:32:56.76372+00	2025-10-31 23:32:56.76372+00	t
51f18933-dcbb-477a-a364-d158dfd8d63a	BVD-EVM-ACC-001	semgrep	compound-sweeptoken-not-restricted	\N	exact	\N	2025-10-31 23:32:56.767892+00	2025-10-31 23:32:56.767892+00	t
b47243a2-066c-4371-aeba-ebf6e9f36e38	BVD-EVM-ACC-001	semgrep	rigoblock-missing-access-control	\N	exact	\N	2025-10-31 23:32:56.771458+00	2025-10-31 23:32:56.771458+00	t
4ccc2ed9-f0e7-4dde-a2c6-77a91bf7ad01	BVD-EVM-ORA-002	semgrep	oracle-price-update-not-restricted	\N	exact	\N	2025-10-31 23:32:56.774734+00	2025-10-31 23:32:56.774734+00	t
2f2eb75d-9859-46e2-bae7-2b6733cdc3fe	BVD-EVM-ORA-002	semgrep	sense-missing-oracle-access-control	\N	exact	\N	2025-10-31 23:32:56.777877+00	2025-10-31 23:32:56.777877+00	t
a784c387-969a-419f-b3fd-c6f3e4b6da09	BVD-EVM-ACC-005	semgrep	unrestricted-transferownership	\N	exact	\N	2025-10-31 23:32:56.781431+00	2025-10-31 23:32:56.781431+00	t
d082e287-0ce1-42a8-805c-9d17e35d43b4	BVD-EVM-TOK-001	semgrep	erc20-public-transfer	\N	exact	\N	2025-10-31 23:32:56.784704+00	2025-10-31 23:32:56.784704+00	t
b15a04f3-2478-45b0-b7a8-282d28aab6f4	BVD-EVM-TOK-002	semgrep	erc20-public-burn	\N	exact	\N	2025-10-31 23:32:56.788018+00	2025-10-31 23:32:56.788018+00	t
1063f775-7a58-4cd3-90e3-b563abf54912	BVD-EVM-TOK-003	semgrep	erc721-arbitrary-transferfrom	\N	exact	\N	2025-10-31 23:32:56.791265+00	2025-10-31 23:32:56.791265+00	t
8c0ce3e8-d087-4509-9a63-aa8572ebc84b	BVD-EVM-TOK-004	semgrep	redacted-cartel-custom-approval-bug	\N	exact	\N	2025-10-31 23:32:56.794749+00	2025-10-31 23:32:56.794749+00	t
2f817e65-bfbe-461d-a65e-7eac26c3795a	BVD-EVM-TOK-005	semgrep	public-transfer-fees-supporting-tax-tokens	\N	exact	\N	2025-10-31 23:32:56.798439+00	2025-10-31 23:32:56.798439+00	t
02b8ae01-d430-4ff1-93b0-a22d6adcb098	BVD-EVM-TOK-006	semgrep	tecra-coin-burnfrom-bug	\N	exact	\N	2025-10-31 23:32:56.801445+00	2025-10-31 23:32:56.801445+00	t
cc5861b7-eb9c-43e4-bcc4-73569ff204c1	BVD-EVM-ORA-001	semgrep	basic-oracle-manipulation	\N	exact	\N	2025-10-31 23:32:56.804498+00	2025-10-31 23:32:56.804498+00	t
9fd0d93f-e080-42b7-9745-6c1b3c5cfc1d	BVD-EVM-ORA-001	semgrep	keeper-network-oracle-manipulation	\N	exact	\N	2025-10-31 23:32:56.80793+00	2025-10-31 23:32:56.80793+00	t
5ced429c-d9c8-42e3-84df-8a9a5c36cbf2	BVD-EVM-ORA-003	semgrep	oracle-uses-curve-spot-price	\N	exact	\N	2025-10-31 23:32:56.811577+00	2025-10-31 23:32:56.811577+00	t
2719de77-7eaf-4ff0-9a0b-6282acce07f4	BVD-EVM-UNC-001	semgrep	arbitrary-low-level-call	\N	exact	\N	2025-10-31 23:32:56.814803+00	2025-10-31 23:32:56.814803+00	t
9fd231a5-5fcd-44d7-8fe1-e84ecfaec5be	BVD-EVM-DEL-001	semgrep	delegatecall-to-arbitrary-address	\N	exact	\N	2025-10-31 23:32:56.818681+00	2025-10-31 23:32:56.818681+00	t
af96c546-3790-4bbe-b6e9-6f6ce1598091	BVD-EVM-SEL-001	semgrep	accessible-selfdestruct	\N	exact	\N	2025-10-31 23:32:56.821872+00	2025-10-31 23:32:56.821872+00	t
111d465a-7d4c-4835-8039-bc673eb822ec	BVD-EVM-CAL-001	semgrep	uniswap-callback-not-protected	\N	exact	\N	2025-10-31 23:32:56.825506+00	2025-10-31 23:32:56.825506+00	t
ed15137f-35c7-4bf1-8d9c-91458c3431d7	BVD-EVM-CAL-001	semgrep	uniswap-v4-callback-not-protected	\N	exact	\N	2025-10-31 23:32:56.829316+00	2025-10-31 23:32:56.829316+00	t
2efb9ab7-c880-4198-903d-e36429715ac7	BVD-EVM-ENC-001	semgrep	encode-packed-collision	\N	exact	\N	2025-10-31 23:32:56.832804+00	2025-10-31 23:32:56.832804+00	t
9c1f774f-c107-4922-b0ef-646445181b49	BVD-EVM-SIG-004	semgrep	openzeppelin-ecdsa-recover-malleable	\N	exact	\N	2025-10-31 23:32:56.835745+00	2025-10-31 23:32:56.835745+00	t
092fbed2-21a9-4026-abb0-2e45f6f7c6ac	BVD-EVM-INT-002	semgrep	basic-arithmetic-underflow	\N	exact	\N	2025-10-31 23:32:56.838479+00	2025-10-31 23:32:56.838479+00	t
443c432f-5ee5-42f1-9fd5-629df321d214	BVD-EVM-PRE-001	semgrep	compound-precision-loss	\N	exact	\N	2025-10-31 23:32:56.841423+00	2025-10-31 23:32:56.841423+00	t
2b79918f-3a9b-45fd-bf76-0bd5cb01501d	BVD-EVM-SLP-001	semgrep	no-slippage-check	\N	exact	\N	2025-10-31 23:32:56.844556+00	2025-10-31 23:32:56.844556+00	t
ce453fc1-feca-46de-a2bd-747b15bee525	BVD-EVM-BAL-001	semgrep	exact-balance-check	\N	exact	\N	2025-10-31 23:32:56.847409+00	2025-10-31 23:32:56.847409+00	t
5b8faa2b-928c-4fb3-8cf1-57487e4b921b	BVD-EVM-PAT-001	semgrep	gearbox-tokens-path-confusion	\N	exact	\N	2025-10-31 23:32:56.851126+00	2025-10-31 23:32:56.851126+00	t
6861c06b-be25-453d-82ea-10beea3d9c63	BVD-EVM-MUL-001	semgrep	msg-value-multicall	\N	exact	\N	2025-10-31 23:32:56.85469+00	2025-10-31 23:32:56.85469+00	t
39b85570-8093-46e1-9e68-6d53c30471c9	BVD-EVM-MUL-002	semgrep	thirdweb-vulnerability	\N	exact	\N	2025-10-31 23:32:56.859537+00	2025-10-31 23:32:56.859537+00	t
ffc219d1-c648-4d72-b3f9-84a4c4e0989d	BVD-EVM-UNI-001	semgrep	no-bidi-characters	\N	exact	\N	2025-10-31 23:32:56.866509+00	2025-10-31 23:32:56.866509+00	t
3f51e50f-a926-436c-bd91-2155e07a3c63	BVD-EVM-BLO-001	semgrep	incorrect-use-of-blockhash	\N	exact	\N	2025-10-31 23:32:56.869535+00	2025-10-31 23:32:56.869535+00	t
75d199a2-511e-4527-a79c-b1671a4d066e	BVD-EVM-ASS-001	semgrep	missing-assignment	\N	exact	\N	2025-10-31 23:32:56.872443+00	2025-10-31 23:32:56.872443+00	t
fab43e35-5f4b-4b8f-a62c-6057b0ac8640	BVD-EVM-DEL-002	semgrep	proxy-storage-collision	\N	exact	\N	2025-10-31 23:32:56.875477+00	2025-10-31 23:32:56.875477+00	t
cfa15b18-bdfe-4009-ad7d-2d0d6a1151bb	BVD-EVM-PRO-002	semgrep	olympus-dao-staking-incorrect-call-order	\N	fuzzy	\N	2025-10-31 23:32:56.878823+00	2025-10-31 23:32:56.878823+00	t
d5aa31d2-dece-4d56-a972-a2931950c27d	BVD-EVM-INJ-001	semgrep	superfluid-ctx-injection	\N	exact	\N	2025-10-31 23:32:56.883889+00	2025-10-31 23:32:56.883889+00	t
c7a056df-a556-4fc8-80ae-e2ee350b5078	BVD-EVM-ACC-004	semgrep	bad-transferfrom-access-control	\N	exact	\N	2025-10-31 23:32:56.888695+00	2025-10-31 23:32:56.888695+00	t
ebfbf1fc-6dfc-4973-aca5-18e2cd198a0a	BVD-EVM-DEP-001	solhint	avoid-call-value	\N	exact	\N	2025-10-31 23:32:56.893296+00	2025-10-31 23:32:56.893296+00	t
4c5cf41b-4627-4a50-a088-fc09ee02bf49	BVD-EVM-UNC-001	solhint	avoid-low-level-calls	\N	exact	\N	2025-10-31 23:32:56.897227+00	2025-10-31 23:32:56.897227+00	t
6762b62f-9048-4fae-b573-389fcf18a61e	BVD-EVM-DEP-002	solhint	avoid-sha3	\N	exact	\N	2025-10-31 23:32:56.902778+00	2025-10-31 23:32:56.902778+00	t
0a2285f4-4581-4e16-93e3-f14194c6c7ad	BVD-EVM-SEL-001	solhint	avoid-suicide	\N	exact	\N	2025-10-31 23:32:56.906394+00	2025-10-31 23:32:56.906394+00	t
e50485e4-bc4b-4732-afa9-d4ccdee4ac57	BVD-EVM-DEP-003	solhint	avoid-throw	\N	exact	\N	2025-10-31 23:32:56.90983+00	2025-10-31 23:32:56.90983+00	t
c8016558-cbef-4862-bb6e-50a8b2c7de7f	BVD-EVM-ACC-006	solhint	avoid-tx-origin	\N	exact	\N	2025-10-31 23:32:56.912892+00	2025-10-31 23:32:56.912892+00	t
c1c11f2e-b0be-4740-9f6d-8ae7eb62ff6a	BVD-EVM-UNC-002	solhint	check-send-result	\N	exact	\N	2025-10-31 23:32:56.915759+00	2025-10-31 23:32:56.915759+00	t
fe5448e4-6dc9-45e7-a66a-771e0c10c19e	BVD-EVM-COM-001	solhint	compiler-version	\N	exact	\N	2025-10-31 23:32:56.918483+00	2025-10-31 23:32:56.918483+00	t
766a40de-0efb-43f3-ab2c-e31c0de47093	BVD-EVM-VIS-001	solhint	func-visibility	\N	exact	\N	2025-10-31 23:32:56.92145+00	2025-10-31 23:32:56.92145+00	t
8c4781b1-d999-414f-abb7-b7355f1fda4d	BVD-EVM-REE-006	solhint	multiple-sends	\N	exact	\N	2025-10-31 23:32:56.924597+00	2025-10-31 23:32:56.924597+00	t
38de5e44-4388-4341-a60b-2d7f0f6153be	BVD-EVM-FAL-001	solhint	no-complex-fallback	\N	exact	\N	2025-10-31 23:32:56.92861+00	2025-10-31 23:32:56.92861+00	t
1beec0a1-4a47-49da-8f10-f7f92f8124f3	BVD-EVM-ASM-001	solhint	no-inline-assembly	\N	exact	\N	2025-10-31 23:32:56.931531+00	2025-10-31 23:32:56.931531+00	t
47486b78-1c7e-4209-ab96-1d1d245c46b2	BVD-EVM-RAN-001	solhint	not-rely-on-block-hash	\N	exact	\N	2025-10-31 23:32:56.934555+00	2025-10-31 23:32:56.934555+00	t
50c10bc0-bbc8-42ef-a7ed-470b6fd4b936	BVD-EVM-TIM-001	solhint	not-rely-on-time	\N	exact	\N	2025-10-31 23:32:56.938797+00	2025-10-31 23:32:56.938797+00	t
924eca4b-7881-4344-a701-2bfc58010731	BVD-EVM-REE-001	solhint	reentrancy	\N	exact	\N	2025-10-31 23:32:56.941439+00	2025-10-31 23:32:56.941439+00	t
1f357fc5-4cff-48c8-8d31-7d1a49cdc1c0	BVD-EVM-VIS-003	solhint	state-visibility	\N	exact	\N	2025-10-31 23:32:56.944511+00	2025-10-31 23:32:56.944511+00	t
844f3af9-0d5a-4a90-95ac-2e12df6d0984	BVD-EVM-REE-001	aderyn	reentrancy-state-change	\N	exact	\N	2025-10-31 23:32:56.947901+00	2025-10-31 23:32:56.947901+00	t
b86aa60f-86c0-4543-b238-ddbaf76ddb77	BVD-EVM-UNC-001	aderyn	unchecked-low-level-call	\N	exact	\N	2025-10-31 23:32:56.951657+00	2025-10-31 23:32:56.951657+00	t
ff263fdf-5b67-4b94-87a6-0b4ae4e41457	BVD-EVM-ACC-004	aderyn	arbitrary-transfer-from	\N	exact	\N	2025-10-31 23:32:56.955726+00	2025-10-31 23:32:56.955726+00	t
0da84006-ca51-4a1f-9c8f-4080a8819b6a	BVD-EVM-INI-001	aderyn	unprotected-initializer	\N	exact	\N	2025-10-31 23:32:56.959302+00	2025-10-31 23:32:56.959302+00	t
24ceeeda-0f1c-4fa0-a979-7363c351e4cf	BVD-EVM-DEL-001	aderyn	delegatecall-unchecked-address	\N	exact	\N	2025-10-31 23:32:56.962396+00	2025-10-31 23:32:56.962396+00	t
dfcd68c0-8a48-4835-b76b-c7cb76fb2bf5	BVD-EVM-LOG-004	aderyn	enumerable-loop-removal	\N	exact	\N	2025-10-31 23:32:56.965384+00	2025-10-31 23:32:56.965384+00	t
5b80adbc-fe40-4df9-9183-453cf57a4d1a	BVD-EVM-COM-002	aderyn	experimental-encoder	\N	exact	\N	2025-10-31 23:32:56.968092+00	2025-10-31 23:32:56.968092+00	t
27351315-21f0-4eee-85a8-977a00bdc816	BVD-EVM-ASM-002	aderyn	incorrect-shift-order	\N	exact	\N	2025-10-31 23:32:56.970694+00	2025-10-31 23:32:56.970694+00	t
68cb5982-1d6e-4013-8dfb-feaa72b05ca2	BVD-EVM-DAT-001	aderyn	storage-array-memory-edit	\N	exact	\N	2025-10-31 23:32:56.973429+00	2025-10-31 23:32:56.973429+00	t
3df65fb8-ea49-45c8-bfd9-4b4cf6448160	BVD-EVM-COD-001	aderyn	multiple-constructors	\N	exact	\N	2025-10-31 23:32:56.977722+00	2025-10-31 23:32:56.977722+00	t
e64fa59e-20fb-4ffc-95ef-be55820f5e9b	BVD-EVM-COD-002	aderyn	reused-contract-name	\N	exact	\N	2025-10-31 23:32:56.980764+00	2025-10-31 23:32:56.980764+00	t
78325774-f927-4dc4-ae28-fd4c97276c73	BVD-EVM-COM-003	aderyn	nested-struct-mapping	\N	exact	\N	2025-10-31 23:32:56.983521+00	2025-10-31 23:32:56.983521+00	t
adc6007d-e40b-4c70-b210-83a563e2e09e	BVD-EVM-DAN-001	aderyn	dynamic-array-length-assignment	\N	exact	\N	2025-10-31 23:32:56.986555+00	2025-10-31 23:32:56.986555+00	t
1d510072-0871-445a-99d8-505ff10b564e	BVD-EVM-LOG-005	aderyn	incorrect-caret-operator	\N	exact	\N	2025-10-31 23:32:56.989706+00	2025-10-31 23:32:56.989706+00	t
5dfea06c-9dec-4261-adbc-f18dbdf5b8e6	BVD-EVM-ASM-003	aderyn	yul-return	\N	exact	\N	2025-10-31 23:32:56.993277+00	2025-10-31 23:32:56.993277+00	t
2aa00563-43ff-4cb0-b0a4-b88069ccc282	BVD-EVM-COD-003	aderyn	state-variable-shadowing	\N	exact	\N	2025-10-31 23:32:56.997926+00	2025-10-31 23:32:56.997926+00	t
8fb7eb1d-de5f-473e-9a41-a68eb7f4b27c	BVD-EVM-LOG-006	aderyn	misused-boolean	\N	exact	\N	2025-10-31 23:32:57.001215+00	2025-10-31 23:32:57.001215+00	t
d60d82b1-1c0f-4da2-b226-5c7b46fb4722	BVD-EVM-UNC-004	aderyn	send-ether-no-checks	\N	exact	\N	2025-10-31 23:32:57.004496+00	2025-10-31 23:32:57.004496+00	t
01a6b9ec-a529-4b14-b96c-90e1525675e8	BVD-EVM-LOG-007	aderyn	tautological-compare	\N	exact	\N	2025-10-31 23:32:57.007231+00	2025-10-31 23:32:57.007231+00	t
d212f65e-3f28-4b6e-8674-b1c4805953dd	BVD-EVM-MAL-001	aderyn	rtlo-character	\N	exact	\N	2025-10-31 23:32:57.009807+00	2025-10-31 23:32:57.009807+00	t
e4dea46e-f90e-4327-b981-49386ac317ab	BVD-EVM-LOG-008	aderyn	dangerous-unary-operator	\N	exact	\N	2025-10-31 23:32:57.012546+00	2025-10-31 23:32:57.012546+00	t
fd451afa-235f-4d31-bce4-557cfdcedd52	BVD-EVM-LOG-009	aderyn	tautology-contradiction	\N	exact	\N	2025-10-31 23:32:57.015302+00	2025-10-31 23:32:57.015302+00	t
a1ec26cb-b02c-423f-abdc-2b9ac3983828	BVD-EVM-COM-004	aderyn	storage-signed-integer-array	\N	exact	\N	2025-10-31 23:32:57.018709+00	2025-10-31 23:32:57.018709+00	t
8775c65f-da1f-49f5-86c9-e5f743e6a1b7	BVD-EVM-LOG-010	aderyn	pre-declared-local-variable	\N	exact	\N	2025-10-31 23:32:57.021706+00	2025-10-31 23:32:57.021706+00	t
2c55e59c-742f-4de7-a99f-8c8e7831ae05	BVD-EVM-DAT-002	aderyn	deletion-nested-mapping	\N	exact	\N	2025-10-31 23:32:57.025234+00	2025-10-31 23:32:57.025234+00	t
c918c0ed-7587-4894-9836-67e9c201708c	BVD-EVM-GAS-010	aderyn	delegatecall-in-loop	\N	exact	\N	2025-10-31 23:32:57.028819+00	2025-10-31 23:32:57.028819+00	t
d66528ce-2fac-4698-8556-ad4c719cf4b2	BVD-EVM-CEN-001	aderyn	centralization-risk	\N	exact	\N	2025-10-31 23:32:57.033269+00	2025-10-31 23:32:57.033269+00	t
2f45a858-3353-4332-8d62-eb284c16e6af	BVD-EVM-TOK-005	aderyn	solmate-safe-transfer-lib	\N	exact	\N	2025-10-31 23:32:57.036964+00	2025-10-31 23:32:57.036964+00	t
56e00c6f-4147-40e8-8f51-f9aa34fe4a23	BVD-EVM-CRY-001	aderyn	ecrecover	\N	exact	\N	2025-10-31 23:32:57.039746+00	2025-10-31 23:32:57.039746+00	t
902202f2-edf1-4e41-8edf-07c74e2431d4	BVD-EVM-DEP-001	aderyn	deprecated-oz-function	\N	exact	\N	2025-10-31 23:32:57.04269+00	2025-10-31 23:32:57.04269+00	t
1279f1c3-456d-4bf7-9b26-0b63969091fd	BVD-EVM-TOK-001	aderyn	unsafe-erc20-operation	\N	exact	\N	2025-10-31 23:32:57.046978+00	2025-10-31 23:32:57.046978+00	t
44b24703-5107-45eb-a63a-73099b9e9bc6	BVD-EVM-PRA-001	aderyn	unspecific-solidity-pragma	\N	exact	\N	2025-10-31 23:32:57.049808+00	2025-10-31 23:32:57.049808+00	t
290d65a9-dd6a-435a-9388-8801352cf041	BVD-EVM-VAL-001	aderyn	state-no-address-check	\N	exact	\N	2025-10-31 23:32:57.05292+00	2025-10-31 23:32:57.05292+00	t
cabc0dc4-3295-46aa-86bb-ad21c4788167	BVD-EVM-GAS-002	aderyn	unused-public-function	\N	exact	\N	2025-10-31 23:32:57.058077+00	2025-10-31 23:32:57.058077+00	t
5ff3abf5-be1e-4a63-a42b-a76798bd610b	BVD-EVM-GAS-003	aderyn	literals-instead-of-constants	\N	exact	\N	2025-10-31 23:32:57.062509+00	2025-10-31 23:32:57.062509+00	t
5e871cd6-c582-45f6-9c44-45cbf3f8ab60	BVD-EVM-COD-005	aderyn	empty-require-revert	\N	exact	\N	2025-10-31 23:32:57.066304+00	2025-10-31 23:32:57.066304+00	t
1b299f4a-3071-4204-9df5-d01df80ca3b1	BVD-EVM-REE-007	aderyn	non-reentrant-before-others	\N	exact	\N	2025-10-31 23:32:57.069712+00	2025-10-31 23:32:57.069712+00	t
b6eb688c-df95-4b58-b53e-da6d34ac12c9	BVD-EVM-TIM-001	aderyn	block-timestamp-deadline	\N	exact	\N	2025-10-31 23:32:57.072885+00	2025-10-31 23:32:57.072885+00	t
42b2b00c-1bec-41b7-b7aa-96aed7927d23	BVD-EVM-TOK-007	aderyn	unsafe-erc721-mint	\N	exact	\N	2025-10-31 23:32:57.076258+00	2025-10-31 23:32:57.076258+00	t
5be4d35c-81d8-43a7-afca-d783094fa34f	BVD-EVM-COM-005	aderyn	push-zero-opcode	\N	exact	\N	2025-10-31 23:32:57.07896+00	2025-10-31 23:32:57.07896+00	t
c3e28798-0fa1-4d9c-afad-63344213a421	BVD-EVM-GAS-004	aderyn	modifier-used-only-once	\N	exact	\N	2025-10-31 23:32:57.081747+00	2025-10-31 23:32:57.081747+00	t
2dbc9709-1408-4e2e-a282-ac0e4592b2e7	BVD-EVM-COD-006	aderyn	empty-block	\N	exact	\N	2025-10-31 23:32:57.084463+00	2025-10-31 23:32:57.084463+00	t
14b6acaf-0691-49c7-bc66-8e5a1a2012c6	BVD-EVM-COD-007	aderyn	large-literal-value	\N	exact	\N	2025-10-31 23:32:57.087508+00	2025-10-31 23:32:57.087508+00	t
a297fb33-adf3-4955-8adf-0bfa6b90b3a0	BVD-EVM-GAS-005	aderyn	internal-function-used-once	\N	exact	\N	2025-10-31 23:32:57.090405+00	2025-10-31 23:32:57.090405+00	t
7e7fe936-6cdc-4276-b6ad-3628e8263de5	BVD-EVM-COD-008	aderyn	todo	\N	exact	\N	2025-10-31 23:32:57.09345+00	2025-10-31 23:32:57.09345+00	t
1da4dc50-136f-434e-aa58-b3ba6606d2e8	BVD-EVM-COD-009	aderyn	inconsistent-type-names	\N	exact	\N	2025-10-31 23:32:57.096313+00	2025-10-31 23:32:57.096313+00	t
f1e5b5ef-ce4a-4c53-89e6-302f7f32251c	BVD-EVM-COD-010	aderyn	unused-error	\N	exact	\N	2025-10-31 23:32:57.099215+00	2025-10-31 23:32:57.099215+00	t
99263222-6a05-4fd5-a289-8a7148d06c5d	BVD-EVM-GAS-006	aderyn	require-revert-in-loop	\N	exact	\N	2025-10-31 23:32:57.102617+00	2025-10-31 23:32:57.102617+00	t
1c07ca45-b261-4612-bb60-ace363a09a87	BVD-EVM-PRE-001	aderyn	division-before-multiplication	\N	exact	\N	2025-10-31 23:32:57.105693+00	2025-10-31 23:32:57.105693+00	t
ac03eb19-88cd-4d1d-a0ef-6da5f551807c	BVD-EVM-COD-011	aderyn	redundant-statement	\N	exact	\N	2025-10-31 23:32:57.108736+00	2025-10-31 23:32:57.108736+00	t
f39b69f9-e9c8-47a2-acfc-0633413bc8cf	BVD-EVM-GAS-007	aderyn	state-variable-read-external	\N	exact	\N	2025-10-31 23:32:57.111811+00	2025-10-31 23:32:57.111811+00	t
43e173af-d999-4281-8485-0b6e085fbc58	BVD-EVM-COD-012	aderyn	unused-state-variables	\N	exact	\N	2025-10-31 23:32:57.114957+00	2025-10-31 23:32:57.114957+00	t
96e22103-f556-4021-abbe-264e54d222a8	BVD-EVM-ASM-004	aderyn	constant-function-assembly	\N	exact	\N	2025-10-31 23:32:57.11836+00	2025-10-31 23:32:57.11836+00	t
a1be13c6-15ba-47c3-9daf-5e9ea469e7b3	BVD-EVM-COD-013	aderyn	boolean-equality	\N	exact	\N	2025-10-31 23:32:57.120934+00	2025-10-31 23:32:57.120934+00	t
ce9300aa-c9ce-4078-b07b-ab6b695fdc7a	BVD-EVM-COD-014	aderyn	local-variable-shadowing	\N	exact	\N	2025-10-31 23:32:57.123626+00	2025-10-31 23:32:57.123626+00	t
2eb16c30-8b74-4d53-88f4-98cb7950482f	BVD-EVM-INI-004	aderyn	uninitialized-local-variable	\N	exact	\N	2025-10-31 23:32:57.127458+00	2025-10-31 23:32:57.127458+00	t
f0e7124b-798b-4b6c-abc2-cb5b646910c7	BVD-EVM-DOS-004	aderyn	return-bomb	\N	exact	\N	2025-10-31 23:32:57.13043+00	2025-10-31 23:32:57.13043+00	t
891b33d0-4552-4197-bd22-23c575e3c6fe	BVD-EVM-INI-003	aderyn	function-initializing-state	\N	exact	\N	2025-10-31 23:32:57.133095+00	2025-10-31 23:32:57.133095+00	t
952bd6cc-98e8-499b-b8bc-0eeadd197e0c	BVD-EVM-COD-015	aderyn	dead-code	\N	exact	\N	2025-10-31 23:32:57.135903+00	2025-10-31 23:32:57.135903+00	t
32d6aa26-018f-44d9-8be2-86b2ea7c35de	BVD-EVM-GAS-008	aderyn	cache-array-length	\N	exact	\N	2025-10-31 23:32:57.138828+00	2025-10-31 23:32:57.138828+00	t
b0a088a4-220a-43e9-8f10-df0e860c3a03	BVD-EVM-LOG-012	aderyn	assert-state-change	\N	exact	\N	2025-10-31 23:32:57.141862+00	2025-10-31 23:32:57.141862+00	t
7cb93b86-99a1-4dbc-93f4-22f19b37de37	BVD-EVM-GAS-009	aderyn	costly-loop	\N	exact	\N	2025-10-31 23:32:57.14552+00	2025-10-31 23:32:57.14552+00	t
cead41ef-54fb-42ca-a517-30afdc3acfc1	BVD-EVM-COD-016	aderyn	builtin-symbol-shadowing	\N	exact	\N	2025-10-31 23:32:57.149962+00	2025-10-31 23:32:57.149962+00	t
05086d3f-d143-442f-8a13-f4fbb1b7007b	BVD-EVM-COD-017	aderyn	void-constructor	\N	exact	\N	2025-10-31 23:32:57.154428+00	2025-10-31 23:32:57.154428+00	t
3ec84b40-fd61-4fbd-8817-b2b8a98ccd0e	BVD-EVM-INT-004	aderyn	missing-inheritance	\N	exact	\N	2025-10-31 23:32:57.157875+00	2025-10-31 23:32:57.157875+00	t
ee098d60-bd9c-4d90-b9d5-053baa8967a3	BVD-EVM-COD-018	aderyn	unused-import	\N	exact	\N	2025-10-31 23:32:57.162706+00	2025-10-31 23:32:57.162706+00	t
804a3f5a-9b5a-438d-a451-de8884931785	BVD-EVM-COD-019	aderyn	function-pointer-constructor	\N	exact	\N	2025-10-31 23:32:57.166434+00	2025-10-31 23:32:57.166434+00	t
a4fe83c2-505a-4a0a-a217-a1eaf7b391e4	BVD-EVM-OPT-002	aderyn	state-variable-constant	\N	exact	\N	2025-10-31 23:32:57.169644+00	2025-10-31 23:32:57.169644+00	t
3fd79401-e68b-4fe6-9dcf-492c15d63974	BVD-EVM-EVE-001	aderyn	state-change-without-event	\N	exact	\N	2025-10-31 23:32:57.172293+00	2025-10-31 23:32:57.172293+00	t
72bf8359-a98b-45e6-aeb8-6618dc69dfd7	BVD-EVM-OPT-003	aderyn	state-variable-immutable	\N	exact	\N	2025-10-31 23:32:57.175133+00	2025-10-31 23:32:57.175133+00	t
45e1ea39-bfb4-4c62-b0bd-fc5313c5403d	BVD-EVM-COD-020	aderyn	multiple-placeholders	\N	exact	\N	2025-10-31 23:32:57.177863+00	2025-10-31 23:32:57.177863+00	t
7e38b797-efd0-4a7a-b3d4-c58980ca6163	BVD-EVM-COD-021	aderyn	incorrect-use-of-modifier	\N	exact	\N	2025-10-31 23:32:57.181759+00	2025-10-31 23:32:57.181759+00	t
9a0e819a-8901-4d0c-9911-917626d8af10	BVD-EVM-UNC-005	aderyn	unchecked-return	\N	exact	\N	2025-10-31 23:32:57.185113+00	2025-10-31 23:32:57.185113+00	t
df92ca1c-469d-477b-bc49-f1592298e425	BVD-EVM-ENC-001	aderyn	avoid-abi-encode-packed	\N	exact	\N	2025-10-31 23:32:57.187812+00	2025-10-31 23:32:57.187812+00	t
ed84846b-b711-41c7-bb1e-8bd59206a31d	BVD-EVM-BAL-001	aderyn	dangerous-strict-equality	\N	exact	\N	2025-10-31 23:32:57.191152+00	2025-10-31 23:32:57.191152+00	t
372d1477-9415-448b-ab7a-c852d5d2c227	BVD-EVM-MUL-001	aderyn	msg-value-loop	\N	exact	\N	2025-10-31 23:32:57.194547+00	2025-10-31 23:32:57.194547+00	t
27ce70fa-a483-419a-8432-b0693c696a64	BVD-EVM-LOG-010	aderyn	out-of-order-retryable	\N	exact	\N	2025-10-31 23:32:57.197607+00	2025-10-31 23:32:57.197607+00	t
f198468d-cce9-4b79-9b1c-f2799194404e	BVD-EVM-SEL-001	aderyn	selfdestruct-deprecated	\N	exact	\N	2025-10-31 23:32:57.200575+00	2025-10-31 23:32:57.200575+00	t
1f6fb3ad-d132-4027-a84e-9be5aeb6e6fb	BVD-EVM-ACC-006	aderyn	tx-origin-auth	\N	exact	\N	2025-10-31 23:32:57.20411+00	2025-10-31 23:32:57.20411+00	t
3be35c2d-89fe-40fa-8a8f-ee9c05b65024	BVD-EVM-UNC-002	aderyn	unchecked-send	\N	exact	\N	2025-10-31 23:32:57.206697+00	2025-10-31 23:32:57.206697+00	t
a1f871e2-7ea5-4818-a5f9-0b966389957f	BVD-EVM-RAN-001	aderyn	weak-randomness	\N	exact	\N	2025-10-31 23:32:57.209586+00	2025-10-31 23:32:57.209586+00	t
cc556631-1638-4ab8-bda7-163becd9815b	BVD-EVM-INT-001	aderyn	unsafe-casting	\N	exact	\N	2025-10-31 23:32:57.212545+00	2025-10-31 23:32:57.212545+00	t
55ce5b02-b828-48dc-a5fd-f25d8f7e78b2	BVD-EVM-COM-006	slither	abiencoderv2-array	\N	exact	\N	2025-10-31 23:32:57.226454+00	2025-10-31 23:32:57.226454+00	t
01e1a18d-78d9-45a5-a91c-bc0c7402ac09	BVD-EVM-TOK-008	slither	arbitrary-send-erc20	\N	exact	\N	2025-10-31 23:32:57.228986+00	2025-10-31 23:32:57.228986+00	t
b93f2351-ec3d-4f26-9baf-a70b3f27b435	BVD-EVM-DAT-003	slither	array-by-reference	\N	exact	\N	2025-10-31 23:32:57.232291+00	2025-10-31 23:32:57.232291+00	t
9e62fd2e-c35d-4650-b265-fb913fd83d04	BVD-EVM-ARI-001	slither	incorrect-shift	\N	exact	\N	2025-10-31 23:32:57.24118+00	2025-10-31 23:32:57.24118+00	t
6efe0380-1a62-4556-a37c-92ebda5e4d9a	BVD-EVM-CON-002	slither	multiple-constructors	\N	exact	\N	2025-10-31 23:32:57.244225+00	2025-10-31 23:32:57.244225+00	t
9e1578aa-2f97-4709-ab9d-eb2108e0ee35	BVD-EVM-COM-007	slither	name-reused	\N	exact	\N	2025-10-31 23:32:57.247403+00	2025-10-31 23:32:57.247403+00	t
5e9ccdb1-c027-47b4-814e-506dc917bb3b	BVD-EVM-ACC-007	slither	protected-vars	\N	exact	\N	2025-10-31 23:32:57.250403+00	2025-10-31 23:32:57.250403+00	t
b642b32c-90ec-48dc-bd88-99d6e99ec14d	BVD-EVM-COM-008	slither	public-mappings-nested	\N	exact	\N	2025-10-31 23:32:57.253719+00	2025-10-31 23:32:57.253719+00	t
ea80e8da-2a2e-4f2a-a936-d7f9fdbab830	BVD-EVM-MAL-001	slither	rtlo	\N	exact	\N	2025-10-31 23:32:57.257266+00	2025-10-31 23:32:57.257266+00	t
31f18fee-c99c-470f-8b24-cd0b3010bf08	BVD-EVM-SHA-001	slither	shadowing-state	\N	exact	\N	2025-10-31 23:32:57.260298+00	2025-10-31 23:32:57.260298+00	t
08752230-2227-4acf-943d-72c148bacc74	BVD-EVM-INI-005	slither	uninitialized-state	\N	exact	\N	2025-10-31 23:32:57.263889+00	2025-10-31 23:32:57.263889+00	t
bef9b1af-67bc-4441-9ae2-d5420ecc1238	BVD-EVM-UPG-001	slither	unprotected-upgrade	\N	exact	\N	2025-10-31 23:32:57.267419+00	2025-10-31 23:32:57.267419+00	t
8f6aeaee-d6ab-4a13-bbe6-b006505f5b3c	BVD-EVM-SIG-005	slither	domain-separator-collision	\N	exact	\N	2025-10-31 23:32:57.271573+00	2025-10-31 23:32:57.271573+00	t
1267bff2-26a9-4fda-9e8e-14a358853767	BVD-EVM-SHA-002	slither	shadowing-abstract	\N	exact	\N	2025-10-31 23:32:57.274628+00	2025-10-31 23:32:57.274628+00	t
e057d20c-c41f-412f-b378-a5fc546ee65b	BVD-EVM-TOK-009	slither	arbitrary-send-erc20-permit	\N	exact	\N	2025-10-31 23:32:57.277657+00	2025-10-31 23:32:57.277657+00	t
42ef833c-d3e5-43fd-830f-6514c179c3af	BVD-EVM-UNC-006	slither	unchecked-transfer	\N	exact	\N	2025-10-31 23:32:57.281779+00	2025-10-31 23:32:57.281779+00	t
d1baf569-9530-4038-86bd-ae5c0cd3fbab	BVD-EVM-ERC-002	slither	erc20-interface	\N	exact	\N	2025-10-31 23:32:57.285431+00	2025-10-31 23:32:57.285431+00	t
05789126-c344-4009-bc4d-e78d45e18f76	BVD-EVM-ERC-001	slither	erc721-interface	\N	exact	\N	2025-10-31 23:32:57.288274+00	2025-10-31 23:32:57.288274+00	t
e53cf0f3-81c6-4ab2-bdf4-ccf02b086879	BVD-EVM-DAT-004	slither	mapping-deletion	\N	exact	\N	2025-10-31 23:32:57.293617+00	2025-10-31 23:32:57.293617+00	t
0970f559-8c5e-4bea-858c-3f765dbfa9db	BVD-EVM-DEL-003	slither	delegatecall-loop	\N	exact	\N	2025-10-31 23:32:57.298629+00	2025-10-31 23:32:57.298629+00	t
70fba8b2-032b-41b4-a581-dbbc0e8f6d6a	BVD-EVM-MSG-001	slither	msg-value-loop	\N	exact	\N	2025-10-31 23:32:57.301607+00	2025-10-31 23:32:57.301607+00	t
6b3173b8-9932-47a5-8eba-96a5c214e3ad	BVD-EVM-ARI-002	slither	incorrect-exp	\N	exact	\N	2025-10-31 23:32:57.305391+00	2025-10-31 23:32:57.305391+00	t
59deee75-a645-4d8a-94c8-e16c31cf701b	BVD-EVM-ORA-004	slither	pyth-deprecated-functions	\N	exact	\N	2025-10-31 23:32:57.308459+00	2025-10-31 23:32:57.308459+00	t
77559d4e-3f47-4c64-ba3c-1ebc6b0f3e5e	BVD-EVM-ORA-005	slither	pyth-unchecked-confidence	\N	exact	\N	2025-10-31 23:32:57.311192+00	2025-10-31 23:32:57.311192+00	t
b4884a94-0e58-459d-adc9-ec16610f4142	BVD-EVM-ORA-006	slither	pyth-unchecked-publishtime	\N	exact	\N	2025-10-31 23:32:57.313898+00	2025-10-31 23:32:57.313898+00	t
285b2720-c4af-4fd0-a6bb-8cf1fab04778	BVD-EVM-ORA-007	slither	chronicle-unchecked-price	\N	exact	\N	2025-10-31 23:32:57.317363+00	2025-10-31 23:32:57.317363+00	t
b192f519-26c0-4dbf-8008-ec8222c81f53	BVD-EVM-RND-001	slither	gelato-unprotected-randomness	\N	exact	\N	2025-10-31 23:32:57.320283+00	2025-10-31 23:32:57.320283+00	t
b5678e01-0f71-4753-a396-53ac43fb1d82	BVD-EVM-ARI-003	slither	divide-before-multiply	\N	exact	\N	2025-10-31 23:32:57.324218+00	2025-10-31 23:32:57.324218+00	t
020ad51e-68ec-44c0-bc81-88fe598ff8bd	BVD-EVM-LOG-013	slither	incorrect-equality	\N	exact	\N	2025-10-31 23:32:57.327344+00	2025-10-31 23:32:57.327344+00	t
2b54e426-7da7-49ee-95a3-986d8a35494c	BVD-EVM-L2-001	slither	out-of-order-retryable	\N	exact	\N	2025-10-31 23:32:57.330375+00	2025-10-31 23:32:57.330375+00	t
22aa89c7-b052-41e0-b8af-c73d003e1ec8	BVD-EVM-CON-003	slither	enum-conversion	\N	exact	\N	2025-10-31 23:32:57.333424+00	2025-10-31 23:32:57.333424+00	t
1cb23208-5f91-4302-b789-bb1b4acc29c7	BVD-EVM-LOG-014	slither	tautological-compare	\N	exact	\N	2025-10-31 23:32:57.337083+00	2025-10-31 23:32:57.337083+00	t
03846046-db21-4271-bc35-0413ea4ba6ad	BVD-EVM-LOG-014	slither	tautology	\N	exact	\N	2025-10-31 23:32:57.340735+00	2025-10-31 23:32:57.340735+00	t
7b8faa62-d239-4365-ba6f-4203da2fca69	BVD-EVM-COD-022	slither	write-after-write	\N	exact	\N	2025-10-31 23:32:57.345034+00	2025-10-31 23:32:57.345034+00	t
13d3c460-559b-44d3-8a64-4d7a201ea442	BVD-EVM-COD-023	slither	boolean-cst	\N	exact	\N	2025-10-31 23:32:57.34852+00	2025-10-31 23:32:57.34852+00	t
2d8bc47b-10d2-4909-bb09-a71bd8dd6982	BVD-EVM-COD-004	slither	constant-function-asm	\N	exact	\N	2025-10-31 23:32:57.351952+00	2025-10-31 23:32:57.351952+00	t
9f93bbb5-de19-408a-9b65-6096ff135ee1	BVD-EVM-COD-004	slither	constant-function-state	\N	exact	\N	2025-10-31 23:32:57.355753+00	2025-10-31 23:32:57.355753+00	t
5af9884a-2ceb-4e04-b99c-3e655cd6c529	BVD-EVM-CON-004	slither	reused-constructor	\N	exact	\N	2025-10-31 23:32:57.3598+00	2025-10-31 23:32:57.3598+00	t
150007ea-f474-47a5-a444-9c1dcb9977fa	BVD-EVM-INI-004	slither	uninitialized-local	\N	exact	\N	2025-10-31 23:32:57.363473+00	2025-10-31 23:32:57.363473+00	t
88286b7b-a82b-4d82-be6b-79f91a110712	BVD-EVM-UNC-005	slither	unused-return	\N	exact	\N	2025-10-31 23:32:57.366619+00	2025-10-31 23:32:57.366619+00	t
b179ef9b-3a21-4525-a6ba-9c09ea091909	BVD-EVM-COD-016	slither	shadowing-builtin	\N	exact	\N	2025-10-31 23:32:57.370207+00	2025-10-31 23:32:57.370207+00	t
32423f00-a90c-4e7d-93c5-79332317040c	BVD-EVM-COD-014	slither	shadowing-local	\N	exact	\N	2025-10-31 23:32:57.372796+00	2025-10-31 23:32:57.372796+00	t
ed458e62-a098-4bcb-96b8-87cbd3b30076	BVD-EVM-COD-019	slither	uninitialized-fptr-cst	\N	exact	\N	2025-10-31 23:32:57.375981+00	2025-10-31 23:32:57.375981+00	t
2a1a6bb1-6b52-4934-bd35-e3fad8e9c9f6	BVD-EVM-SCP-001	slither	variable-scope	\N	exact	\N	2025-10-31 23:32:57.378695+00	2025-10-31 23:32:57.378695+00	t
01aa8608-bfa2-447d-94fc-43bbb3eb2c60	BVD-EVM-COD-017	slither	void-cst	\N	exact	\N	2025-10-31 23:32:57.381657+00	2025-10-31 23:32:57.381657+00	t
0b5a6442-d6ec-4913-8089-16005ddb0927	BVD-EVM-DOS-005	slither	calls-loop	\N	exact	\N	2025-10-31 23:32:57.384965+00	2025-10-31 23:32:57.384965+00	t
f179dbe1-ad22-4e65-b8b9-520eff2d26e4	BVD-EVM-REE-008	slither	reentrancy-benign	\N	exact	\N	2025-10-31 23:32:57.387833+00	2025-10-31 23:32:57.387833+00	t
4bf6f331-f697-458e-a1db-843412b3b5c9	BVD-EVM-REE-009	slither	reentrancy-events	\N	exact	\N	2025-10-31 23:32:57.390634+00	2025-10-31 23:32:57.390634+00	t
257fbfcf-6345-47a2-83d2-806b0da573b2	BVD-EVM-DOS-004	slither	return-bomb	\N	exact	\N	2025-10-31 23:32:57.394141+00	2025-10-31 23:32:57.394141+00	t
b690af30-bf66-4250-babf-7eaa34d4e17a	BVD-EVM-TYP-001	slither	incorrect-unary	\N	exact	\N	2025-10-31 23:32:57.397617+00	2025-10-31 23:32:57.397617+00	t
4b219ba5-c9ba-4a90-9860-43091e06d808	BVD-EVM-ASM-001	slither	assembly	\N	exact	\N	2025-10-31 23:32:57.401394+00	2025-10-31 23:32:57.401394+00	t
9281da6b-14b3-4160-91c5-00c5a52b7e73	BVD-EVM-ASM-002	slither	incorrect-return	\N	exact	\N	2025-10-31 23:32:57.40542+00	2025-10-31 23:32:57.40542+00	t
c5588f76-fce0-460d-a404-c38f8fa61877	BVD-EVM-ASM-003	slither	return-leave	\N	exact	\N	2025-10-31 23:32:57.410296+00	2025-10-31 23:32:57.410296+00	t
733f2f44-b2b2-4cdd-bf10-d69cc0c00948	BVD-EVM-ASM-004	slither	low-level-calls	\N	exact	\N	2025-10-31 23:32:57.41416+00	2025-10-31 23:32:57.41416+00	t
68b05277-8b0d-4c49-9e32-3abe408a9194	BVD-EVM-COM-009	slither	solc-version	\N	exact	\N	2025-10-31 23:32:57.417391+00	2025-10-31 23:32:57.417391+00	t
2f3c1259-562c-4e21-92d6-a968820ccb9b	BVD-EVM-COM-010	slither	pragma	\N	exact	\N	2025-10-31 23:32:57.420195+00	2025-10-31 23:32:57.420195+00	t
7f9f947b-4b88-4dce-98cc-7a76030e7f48	BVD-EVM-COM-011	slither	deprecated-standards	\N	exact	\N	2025-10-31 23:32:57.422793+00	2025-10-31 23:32:57.422793+00	t
ed93ed9f-b0d4-4a59-824e-8ac4128dbbd0	BVD-EVM-COM-012	slither	storage-array	\N	exact	\N	2025-10-31 23:32:57.425554+00	2025-10-31 23:32:57.425554+00	t
cc76438d-1a35-4f20-8163-a7747141b7b8	BVD-EVM-COD-024	slither	naming-convention	\N	exact	\N	2025-10-31 23:32:57.428259+00	2025-10-31 23:32:57.428259+00	t
747101c7-7514-4b64-95d0-cad268d2ae4d	BVD-EVM-COD-025	slither	cyclomatic-complexity	\N	exact	\N	2025-10-31 23:32:57.431216+00	2025-10-31 23:32:57.431216+00	t
87c4c481-3298-4613-a0f6-eda923dc0b34	BVD-EVM-COD-026	slither	dead-code	\N	exact	\N	2025-10-31 23:32:57.433725+00	2025-10-31 23:32:57.433725+00	t
fb838620-c9ae-4570-b913-4b396ba8b1e6	BVD-EVM-COD-027	slither	unused-state	\N	exact	\N	2025-10-31 23:32:57.437476+00	2025-10-31 23:32:57.437476+00	t
4875de8a-592e-4e3f-880a-b080e8eb6335	BVD-EVM-COD-028	slither	redundant-statements	\N	exact	\N	2025-10-31 23:32:57.440556+00	2025-10-31 23:32:57.440556+00	t
3c9a176b-6721-49c9-bb92-41faec9dadcd	BVD-EVM-COD-029	slither	too-many-digits	\N	exact	\N	2025-10-31 23:32:57.444377+00	2025-10-31 23:32:57.444377+00	t
ca184b8a-8bc3-403e-b262-d95ac3adc834	BVD-EVM-COD-030	slither	boolean-equal	\N	exact	\N	2025-10-31 23:32:57.447148+00	2025-10-31 23:32:57.447148+00	t
c665237f-9a45-4e24-856d-8e8fa0667845	BVD-EVM-COD-031	slither	incorrect-using-for	\N	exact	\N	2025-10-31 23:32:57.450073+00	2025-10-31 23:32:57.450073+00	t
03b0b8f7-bc71-416a-86ce-b39a8a29c29a	BVD-EVM-COD-032	slither	unimplemented-functions	\N	exact	\N	2025-10-31 23:32:57.45288+00	2025-10-31 23:32:57.45288+00	t
a704c18e-e9e9-48ca-b435-46f77fc8ee4f	BVD-EVM-COD-033	slither	missing-inheritance	\N	exact	\N	2025-10-31 23:32:57.45688+00	2025-10-31 23:32:57.45688+00	t
d96c1de3-0016-419e-9afe-d08ae09bd17c	BVD-EVM-EVT-001	slither	events-access	\N	exact	\N	2025-10-31 23:32:57.46032+00	2025-10-31 23:32:57.46032+00	t
8da2c311-c43a-4e68-bf9a-93cc1dd03f3e	BVD-EVM-EVT-002	slither	events-maths	\N	exact	\N	2025-10-31 23:32:57.463743+00	2025-10-31 23:32:57.463743+00	t
19ca50a4-c819-436d-b0fe-0c261c73c81a	BVD-EVM-EVT-003	slither	erc20-indexed	\N	exact	\N	2025-10-31 23:32:57.466512+00	2025-10-31 23:32:57.466512+00	t
49aa3182-5eee-4efd-8a8e-4ed424e1fed0	BVD-EVM-ENC-001	slither	encode-packed-collision	\N	exact	\N	2025-10-31 23:32:57.469189+00	2025-10-31 23:32:57.469189+00	t
39c9e76a-31cb-41be-866b-420872721a5a	BVD-EVM-ORA-008	slither	chainlink-feed-registry	\N	exact	\N	2025-10-31 23:32:57.472315+00	2025-10-31 23:32:57.472315+00	t
c0b413b4-5a7c-4da3-851d-8421486723dc	BVD-EVM-INI-006	slither	function-init-state	\N	exact	\N	2025-10-31 23:32:57.474674+00	2025-10-31 23:32:57.474674+00	t
042107ae-48f3-4e1f-bb37-60a383757c37	BVD-EVM-INI-007	slither	assert-state-change	\N	exact	\N	2025-10-31 23:32:57.477327+00	2025-10-31 23:32:57.477327+00	t
fdf301a0-71c3-4638-9451-468cb389695b	BVD-EVM-L2-001	slither	optimism-deprecation	\N	exact	\N	2025-10-31 23:32:57.480528+00	2025-10-31 23:32:57.480528+00	t
f494fe06-4c7b-4d0d-a2be-22a46396465a	BVD-EVM-GAS-011	slither	costly-loop	\N	exact	\N	2025-10-31 23:32:57.483626+00	2025-10-31 23:32:57.483626+00	t
17392778-6965-48cc-bf99-40c839a7c49a	BVD-EVM-REE-010	slither	reentrancy-unlimited-gas	\N	exact	\N	2025-10-31 23:32:57.486415+00	2025-10-31 23:32:57.486415+00	t
9ffbd055-e485-4ae0-9b4a-f11940a73da8	BVD-EVM-OPT-004	slither	cache-array-length	\N	exact	\N	2025-10-31 23:32:57.48912+00	2025-10-31 23:32:57.48912+00	t
96b33e4f-abf9-4b88-930e-738280b3f2a6	BVD-EVM-OPT-005	slither	constable-states	\N	exact	\N	2025-10-31 23:32:57.491436+00	2025-10-31 23:32:57.491436+00	t
831cce89-9d67-4ecc-9c69-0855dedf094c	BVD-EVM-OPT-006	slither	external-function	\N	exact	\N	2025-10-31 23:32:57.494202+00	2025-10-31 23:32:57.494202+00	t
6f8d3f9d-a3bc-4d5d-b362-79f96b95d863	BVD-EVM-OPT-007	slither	immutable-states	\N	exact	\N	2025-10-31 23:32:57.496797+00	2025-10-31 23:32:57.496797+00	t
2c103c66-7d64-4e04-b9e9-d3099f864983	BVD-EVM-OPT-008	slither	var-read-using-this	\N	exact	\N	2025-10-31 23:32:57.499452+00	2025-10-31 23:32:57.499452+00	t
11a4b837-9df8-4014-879a-4ff89154892f	BVD-VYPER-VER-008	slither	codex	\N	exact	\N	2025-10-31 23:32:57.757817+00	2025-10-31 23:32:57.757817+00	t
32acaa12-0e23-4872-9be5-b24e513f481c	BVD-VYPER-REE-001	slither-vyper	reentrancy-eth	\N	exact	\N	2025-10-31 23:47:34.55436+00	2025-10-31 23:47:34.55436+00	t
bb50fd42-b883-498c-bf29-187ce6adc4e3	BVD-VYPER-REE-002	slither-vyper	reentrancy-no-eth	\N	exact	\N	2025-10-31 23:47:34.560598+00	2025-10-31 23:47:34.560598+00	t
594c853d-58de-47c7-918d-deb36654f8d1	BVD-VYPER-REE-003	slither-vyper	reentrancy-benign	\N	exact	\N	2025-10-31 23:47:34.563813+00	2025-10-31 23:47:34.563813+00	t
4e140fdc-21bd-4634-9b3e-e4392ed70f50	BVD-VYPER-REE-004	slither-vyper	reentrancy-events	\N	exact	\N	2025-10-31 23:47:34.567883+00	2025-10-31 23:47:34.567883+00	t
01833eab-dfe3-4ec1-a9be-fb979c0feb0e	BVD-VYPER-REE-005	slither-vyper	reentrancy-unlimited-gas	\N	exact	\N	2025-10-31 23:47:34.572336+00	2025-10-31 23:47:34.572336+00	t
1054ca99-4096-4afc-92dc-a79709efb1b0	BVD-VYPER-REE-006	slither-vyper	msg-value-loop	\N	exact	\N	2025-10-31 23:47:34.576665+00	2025-10-31 23:47:34.576665+00	t
87708043-5d5b-48fe-8b1a-098b906fd1c2	BVD-VYPER-REE-007	slither-vyper	delegatecall-loop	\N	exact	\N	2025-10-31 23:47:34.581003+00	2025-10-31 23:47:34.581003+00	t
59e3bb22-cb68-403d-b493-393406e9143c	BVD-VYPER-REE-008	slither-vyper	calls-loop	\N	exact	\N	2025-10-31 23:47:34.584541+00	2025-10-31 23:47:34.584541+00	t
d43778f7-0b49-4566-8e0b-c995f5891fae	BVD-VYPER-ACC-001	slither-vyper	suicidal	\N	exact	\N	2025-10-31 23:47:34.5886+00	2025-10-31 23:47:34.5886+00	t
9c3098fd-74c4-413d-9442-fa2550c19480	BVD-VYPER-ACC-002	slither-vyper	unprotected-upgrade	\N	exact	\N	2025-10-31 23:47:34.591866+00	2025-10-31 23:47:34.591866+00	t
05b307cc-b119-4ea0-9360-085156810b3a	BVD-VYPER-ACC-003	slither-vyper	arbitrary-send-eth	\N	exact	\N	2025-10-31 23:47:34.595527+00	2025-10-31 23:47:34.595527+00	t
49e12c7d-e7e5-4185-a6d3-6827de807986	BVD-VYPER-ACC-004	slither-vyper	arbitrary-send-erc20	\N	exact	\N	2025-10-31 23:47:34.599429+00	2025-10-31 23:47:34.599429+00	t
9c43475a-71b0-4e9f-a2be-aa7719ca8a17	BVD-VYPER-ACC-005	slither-vyper	arbitrary-send-erc20-permit	\N	exact	\N	2025-10-31 23:47:34.602715+00	2025-10-31 23:47:34.602715+00	t
9ac0d85d-e29c-4797-9d3a-1d3f222cd2fa	BVD-VYPER-ACC-006	slither-vyper	controlled-delegatecall	\N	exact	\N	2025-10-31 23:47:34.605646+00	2025-10-31 23:47:34.605646+00	t
b4cc7186-4276-4bf9-8ffc-9ad74f2facfc	BVD-VYPER-ACC-007	slither-vyper	tx-origin	\N	exact	\N	2025-10-31 23:47:34.608465+00	2025-10-31 23:47:34.608465+00	t
1303ac62-373a-4ca8-a555-b7bc5fbb0f3d	BVD-VYPER-ACC-008	slither-vyper	events-access	\N	exact	\N	2025-10-31 23:47:34.611466+00	2025-10-31 23:47:34.611466+00	t
da25fc02-6e4d-4c1a-82eb-c92641d62887	BVD-VYPER-ACC-009	slither-vyper	missing-zero-check	\N	exact	\N	2025-10-31 23:47:34.614375+00	2025-10-31 23:47:34.614375+00	t
8501d4e7-a8bf-48fe-8277-6591be98694b	BVD-VYPER-ACC-010	slither-vyper	protected-vars	\N	exact	\N	2025-10-31 23:47:34.617279+00	2025-10-31 23:47:34.617279+00	t
b76423d8-137c-4b1a-8ccf-d6f77ea78e14	BVD-VYPER-ACC-011	slither-vyper	gelato-unprotected-randomness	\N	exact	\N	2025-10-31 23:47:34.620343+00	2025-10-31 23:47:34.620343+00	t
46e16a2e-632b-4c85-b215-838b0a6bcbf6	BVD-VYPER-ACC-012	slither-vyper	pyth-unchecked-publishtime	\N	exact	\N	2025-10-31 23:47:34.623311+00	2025-10-31 23:47:34.623311+00	t
88ad2d6e-2115-47f6-ab2a-c36f98a15b78	BVD-VYPER-INT-001	slither-vyper	divide-before-multiply	\N	exact	\N	2025-10-31 23:47:34.626398+00	2025-10-31 23:47:34.626398+00	t
0fe6cf28-0b37-4d89-9829-581269631095	BVD-VYPER-INT-002	slither-vyper	incorrect-exp	\N	exact	\N	2025-10-31 23:47:34.629416+00	2025-10-31 23:47:34.629416+00	t
72d86b3f-2a43-401d-8e44-af3def64f139	BVD-VYPER-INT-003	slither-vyper	incorrect-shift	\N	exact	\N	2025-10-31 23:47:34.633162+00	2025-10-31 23:47:34.633162+00	t
2947e57d-c084-48f4-a5cb-b7d30cb03928	BVD-VYPER-INT-004	slither-vyper	incorrect-unary	\N	exact	\N	2025-10-31 23:47:34.636617+00	2025-10-31 23:47:34.636617+00	t
c5b8723c-f94a-4f99-97d5-800afcc6a476	BVD-VYPER-INT-005	slither-vyper	events-maths	\N	exact	\N	2025-10-31 23:47:34.639767+00	2025-10-31 23:47:34.639767+00	t
c8df92a1-9331-4e09-bd98-949913d18512	BVD-VYPER-INT-006	slither-vyper	tautology	\N	exact	\N	2025-10-31 23:47:34.642562+00	2025-10-31 23:47:34.642562+00	t
2a7f516c-efe3-48b1-a6fb-69b224f7b13c	BVD-VYPER-INT-007	slither-vyper	tautological-compare	\N	exact	\N	2025-10-31 23:47:34.645499+00	2025-10-31 23:47:34.645499+00	t
1959e966-03ac-41d7-8697-b7adf4707e8c	BVD-VYPER-INT-008	slither-vyper	too-many-digits	\N	exact	\N	2025-10-31 23:47:34.648243+00	2025-10-31 23:47:34.648243+00	t
b5d532df-0a4e-4f19-ac9a-e7fba9308ec4	BVD-VYPER-INT-009	slither-vyper	weak-prng	\N	exact	\N	2025-10-31 23:47:34.650741+00	2025-10-31 23:47:34.650741+00	t
242f630b-9fa5-414a-bddc-75f671df7d45	BVD-VYPER-EXT-001	slither-vyper	unchecked-lowlevel	\N	exact	\N	2025-10-31 23:47:34.653962+00	2025-10-31 23:47:34.653962+00	t
6b91e128-76f3-42ed-937e-c2184e365ada	BVD-VYPER-EXT-002	slither-vyper	unchecked-send	\N	exact	\N	2025-10-31 23:47:34.657121+00	2025-10-31 23:47:34.657121+00	t
153c08a5-fb81-472d-ad72-76c41a0f1e1b	BVD-VYPER-EXT-003	slither-vyper	unchecked-transfer	\N	exact	\N	2025-10-31 23:47:34.660027+00	2025-10-31 23:47:34.660027+00	t
c220e301-5fce-4f47-a50b-ce37ad0997be	BVD-VYPER-EXT-004	slither-vyper	unused-return	\N	exact	\N	2025-10-31 23:47:34.663313+00	2025-10-31 23:47:34.663313+00	t
3cb182ff-4607-4411-8af4-f6ff4aa5f791	BVD-VYPER-EXT-005	slither-vyper	low-level-calls	\N	exact	\N	2025-10-31 23:47:34.668284+00	2025-10-31 23:47:34.668284+00	t
4da768e1-8ec0-4fbe-8e29-829f6cdcd677	BVD-VYPER-EXT-006	slither-vyper	incorrect-return	\N	exact	\N	2025-10-31 23:47:34.672149+00	2025-10-31 23:47:34.672149+00	t
bfa10d37-c8ce-43de-9233-8ae849886b12	BVD-VYPER-EXT-007	slither-vyper	return-leave	\N	exact	\N	2025-10-31 23:47:34.676737+00	2025-10-31 23:47:34.676737+00	t
8a3958f5-0d5f-4ed9-8881-32bce8931456	BVD-VYPER-EXT-008	slither-vyper	return-bomb	\N	exact	\N	2025-10-31 23:47:34.680493+00	2025-10-31 23:47:34.680493+00	t
25376deb-c45b-4987-9d45-bbde79672821	BVD-VYPER-EXT-009	slither-vyper	chainlink-feed-registry	\N	exact	\N	2025-10-31 23:47:34.683616+00	2025-10-31 23:47:34.683616+00	t
08fd21f3-2947-4266-acff-83126d83f841	BVD-VYPER-EXT-010	slither-vyper	chronicle-unchecked-price	\N	exact	\N	2025-10-31 23:47:34.687076+00	2025-10-31 23:47:34.687076+00	t
10ce0986-a08d-4ae4-94aa-48da99b53da1	BVD-VYPER-STA-001	slither-vyper	uninitialized-state	\N	exact	\N	2025-10-31 23:47:34.690209+00	2025-10-31 23:47:34.690209+00	t
0e614469-6c77-45f6-97aa-b07bce428a89	BVD-VYPER-STA-002	slither-vyper	uninitialized-storage	\N	exact	\N	2025-10-31 23:47:34.693036+00	2025-10-31 23:47:34.693036+00	t
5ed17b5a-e1e7-4649-a097-e0b2be28eeca	BVD-VYPER-STA-003	slither-vyper	uninitialized-local	\N	exact	\N	2025-10-31 23:47:34.696913+00	2025-10-31 23:47:34.696913+00	t
59f620e0-aca1-43ea-b328-5292515cb323	BVD-VYPER-STA-004	slither-vyper	uninitialized-fptr-cst	\N	exact	\N	2025-10-31 23:47:34.700314+00	2025-10-31 23:47:34.700314+00	t
5f612842-b44f-4255-9432-fd721133b5c9	BVD-VYPER-STA-005	slither-vyper	shadowing-state	\N	exact	\N	2025-10-31 23:47:34.703376+00	2025-10-31 23:47:34.703376+00	t
67af156a-7fcf-4602-99cf-7d24804e3728	BVD-VYPER-STA-006	slither-vyper	shadowing-abstract	\N	exact	\N	2025-10-31 23:47:34.706335+00	2025-10-31 23:47:34.706335+00	t
bd8da61b-34c7-4c0d-8888-ae22aedb0d41	BVD-VYPER-STA-007	slither-vyper	shadowing-local	\N	exact	\N	2025-10-31 23:47:34.710028+00	2025-10-31 23:47:34.710028+00	t
50065e6b-fde0-4baf-b9b8-2b57a8e4a7a9	BVD-VYPER-STA-008	slither-vyper	shadowing-builtin	\N	exact	\N	2025-10-31 23:47:34.713821+00	2025-10-31 23:47:34.713821+00	t
999801f1-5507-43a1-b3bd-01a5916263a8	BVD-VYPER-STA-009	slither-vyper	unused-state	\N	exact	\N	2025-10-31 23:47:34.717305+00	2025-10-31 23:47:34.717305+00	t
ea9e5a2d-0cdb-4f3a-a227-822577e66283	BVD-VYPER-STA-010	slither-vyper	constable-states	\N	exact	\N	2025-10-31 23:47:34.720493+00	2025-10-31 23:47:34.720493+00	t
6fe0ddab-8aea-4244-b8ae-c9da48646535	BVD-VYPER-STA-011	slither-vyper	immutable-states	\N	exact	\N	2025-10-31 23:47:34.7236+00	2025-10-31 23:47:34.7236+00	t
3cdae796-4376-4109-b2aa-d59591caff73	BVD-VYPER-STA-012	slither-vyper	variable-scope	\N	exact	\N	2025-10-31 23:47:34.726739+00	2025-10-31 23:47:34.726739+00	t
5ba00c42-1020-4b05-94d0-388e72428f39	BVD-VYPER-STA-013	slither-vyper	write-after-write	\N	exact	\N	2025-10-31 23:47:34.729798+00	2025-10-31 23:47:34.729798+00	t
6d226647-8bff-41ac-8cdf-35681261c027	BVD-VYPER-STA-014	slither-vyper	constant-function-state	\N	exact	\N	2025-10-31 23:47:34.732891+00	2025-10-31 23:47:34.732891+00	t
4763b671-7084-4204-bfe2-ce91d3be421e	BVD-VYPER-STA-015	slither-vyper	assert-state-change	\N	exact	\N	2025-10-31 23:47:34.735882+00	2025-10-31 23:47:34.735882+00	t
64eedef9-b01a-4243-a259-225a1accb9b8	BVD-VYPER-TIM-001	slither-vyper	timestamp	\N	exact	\N	2025-10-31 23:47:34.739044+00	2025-10-31 23:47:34.739044+00	t
09f6dd9d-f506-46fe-a9b0-0f6ed1d119cd	BVD-VYPER-TIM-002	slither-vyper	out-of-order-retryable	\N	exact	\N	2025-10-31 23:47:34.741831+00	2025-10-31 23:47:34.741831+00	t
9e350d84-e61e-4a1f-b666-470700a2a064	BVD-VYPER-GAS-001	slither-vyper	cache-array-length	\N	exact	\N	2025-10-31 23:47:34.744412+00	2025-10-31 23:47:34.744412+00	t
6e129de8-9332-473a-9005-a4c72ae7fd99	BVD-VYPER-GAS-002	slither-vyper	external-function	\N	exact	\N	2025-10-31 23:47:34.746806+00	2025-10-31 23:47:34.746806+00	t
1bb0b2b5-4c5f-4f7c-b489-24e706aa5297	BVD-VYPER-GAS-003	slither-vyper	var-read-using-this	\N	exact	\N	2025-10-31 23:47:34.749526+00	2025-10-31 23:47:34.749526+00	t
b1786405-0114-48f6-8331-133b0013f449	BVD-VYPER-GAS-004	slither-vyper	costly-loop	\N	exact	\N	2025-10-31 23:47:34.752234+00	2025-10-31 23:47:34.752234+00	t
bea8e72a-a671-47ff-bd30-144729665cb5	BVD-VYPER-GAS-005	slither-vyper	array-by-reference	\N	exact	\N	2025-10-31 23:47:34.755143+00	2025-10-31 23:47:34.755143+00	t
812083cf-cd87-40c0-8faa-f4cf5e4c1141	BVD-VYPER-GAS-006	slither-vyper	controlled-array-length	\N	exact	\N	2025-10-31 23:47:34.758451+00	2025-10-31 23:47:34.758451+00	t
70504f0d-6213-4de4-afd6-83c08d406cf6	BVD-VYPER-GAS-007	slither-vyper	storage-array	\N	exact	\N	2025-10-31 23:47:34.761668+00	2025-10-31 23:47:34.761668+00	t
d23e2018-5dc6-4c50-8044-87a7b3aafdfa	BVD-VYPER-GAS-008	slither-vyper	public-mappings-nested	\N	exact	\N	2025-10-31 23:47:34.76472+00	2025-10-31 23:47:34.76472+00	t
85625d37-342b-415e-84cb-58f979792fde	BVD-VYPER-GAS-009	slither-vyper	mapping-deletion	\N	exact	\N	2025-10-31 23:47:34.768336+00	2025-10-31 23:47:34.768336+00	t
ce0b15dc-0bc9-4813-82dd-c0473ba50108	BVD-VYPER-GAS-010	slither-vyper	locked-ether	\N	exact	\N	2025-10-31 23:47:34.77236+00	2025-10-31 23:47:34.77236+00	t
905c61fe-3558-4d35-a57e-7579d0436c31	BVD-VYPER-GAS-011	slither-vyper	constant-function-asm	\N	exact	\N	2025-10-31 23:47:34.775305+00	2025-10-31 23:47:34.775305+00	t
36da443f-d8fc-4627-901a-c14a3b809f14	BVD-VYPER-GAS-012	slither-vyper	cyclomatic-complexity	\N	exact	\N	2025-10-31 23:47:34.778501+00	2025-10-31 23:47:34.778501+00	t
9bd2d957-a38d-4bcb-85d2-a806fe55702e	BVD-VYPER-GAS-013	slither-vyper	function-init-state	\N	exact	\N	2025-10-31 23:47:34.781478+00	2025-10-31 23:47:34.781478+00	t
3ff16be2-ef55-4a78-8cae-c724f280621b	BVD-VYPER-LOG-001	slither-vyper	dead-code	\N	exact	\N	2025-10-31 23:47:34.784262+00	2025-10-31 23:47:34.784262+00	t
61b8f281-d4ed-48a1-be5d-e284f4359bd8	BVD-VYPER-LOG-002	slither-vyper	incorrect-equality	\N	exact	\N	2025-10-31 23:47:34.787125+00	2025-10-31 23:47:34.787125+00	t
aefa2ae9-4c49-4b50-a646-1fa6eadc628b	BVD-VYPER-LOG-003	slither-vyper	boolean-cst	\N	exact	\N	2025-10-31 23:47:34.789875+00	2025-10-31 23:47:34.789875+00	t
99083a8f-3b24-4138-b69f-6c5ad70f7ed1	BVD-VYPER-LOG-004	slither-vyper	boolean-equal	\N	exact	\N	2025-10-31 23:47:34.79264+00	2025-10-31 23:47:34.79264+00	t
ef47c1ca-031e-4526-b721-25d5106cfd6e	BVD-VYPER-LOG-005	slither-vyper	incorrect-modifier	\N	exact	\N	2025-10-31 23:47:34.795536+00	2025-10-31 23:47:34.795536+00	t
2557935b-c8c2-49d1-9d2a-ec318b72dd0a	BVD-VYPER-LOG-006	slither-vyper	void-cst	\N	exact	\N	2025-10-31 23:47:34.798615+00	2025-10-31 23:47:34.798615+00	t
c3b445ac-303f-4c8a-9e9d-dcc60587ed31	BVD-VYPER-LOG-007	slither-vyper	redundant-statements	\N	exact	\N	2025-10-31 23:47:34.801684+00	2025-10-31 23:47:34.801684+00	t
fbf15cf0-e237-4326-a986-cc13bf37d8ad	BVD-VYPER-LOG-008	slither-vyper	unimplemented-functions	\N	exact	\N	2025-10-31 23:47:34.804614+00	2025-10-31 23:47:34.804614+00	t
caeb4c3d-8480-488b-9b3c-77f00ecf6d9b	BVD-VYPER-LOG-009	slither-vyper	incorrect-using-for	\N	exact	\N	2025-10-31 23:47:34.807577+00	2025-10-31 23:47:34.807577+00	t
46c58627-d34b-4f3f-b8a6-3dc6169633b6	BVD-VYPER-LOG-010	slither-vyper	reused-constructor	\N	exact	\N	2025-10-31 23:47:34.810269+00	2025-10-31 23:47:34.810269+00	t
9a760b6a-bf6d-44c6-8da9-9a37fab269f9	BVD-VYPER-LOG-011	slither-vyper	multiple-constructors	\N	exact	\N	2025-10-31 23:47:34.813939+00	2025-10-31 23:47:34.813939+00	t
53e94ac8-079e-400e-85ae-84661758ab32	BVD-VYPER-LOG-012	slither-vyper	missing-inheritance	\N	exact	\N	2025-10-31 23:47:34.816961+00	2025-10-31 23:47:34.816961+00	t
393fca0d-c8b1-45a7-823b-0ed76a4d9780	BVD-VYPER-DAT-001	slither-vyper	encode-packed-collision	\N	exact	\N	2025-10-31 23:47:34.819688+00	2025-10-31 23:47:34.819688+00	t
40e5feed-7a9c-4969-810c-f42cf54c5268	BVD-VYPER-DAT-002	slither-vyper	abiencoderv2-array	\N	exact	\N	2025-10-31 23:47:34.822237+00	2025-10-31 23:47:34.822237+00	t
7b2e0bd6-5a76-4663-9e2e-e09ada9c02b2	BVD-VYPER-DAT-003	slither-vyper	enum-conversion	\N	exact	\N	2025-10-31 23:47:34.824738+00	2025-10-31 23:47:34.824738+00	t
5fb67be4-067d-490f-9041-0999a8a95f69	BVD-VYPER-DAT-004	slither-vyper	erc20-interface	\N	exact	\N	2025-10-31 23:47:34.82739+00	2025-10-31 23:47:34.82739+00	t
ac260602-9759-47ff-a06b-499d485c07ce	BVD-VYPER-DAT-005	slither-vyper	erc721-interface	\N	exact	\N	2025-10-31 23:47:34.830034+00	2025-10-31 23:47:34.830034+00	t
20ce737e-c8e4-49eb-a352-45fe9d021e5f	BVD-VYPER-DAT-006	slither-vyper	erc20-indexed	\N	exact	\N	2025-10-31 23:47:34.833124+00	2025-10-31 23:47:34.833124+00	t
0501340b-190e-43ef-b808-6a9d9e8fe432	BVD-VYPER-DAT-007	slither-vyper	name-reused	\N	exact	\N	2025-10-31 23:47:34.836254+00	2025-10-31 23:47:34.836254+00	t
25187c60-690d-4d10-bea1-c322d2f01799	BVD-VYPER-DAT-008	slither-vyper	rtlo	\N	exact	\N	2025-10-31 23:47:34.83954+00	2025-10-31 23:47:34.83954+00	t
3b249c51-1bfb-4ec6-a078-2ecf870e5cef	BVD-VYPER-DAT-009	slither-vyper	domain-separator-collision	\N	exact	\N	2025-10-31 23:47:34.842649+00	2025-10-31 23:47:34.842649+00	t
a4aad50f-0cce-4ef2-82f7-f5198b92fce9	BVD-VYPER-DAT-010	slither-vyper	pyth-unchecked-confidence	\N	exact	\N	2025-10-31 23:47:34.845412+00	2025-10-31 23:47:34.845412+00	t
f4243e88-c6d6-4269-ae24-361b20e0af48	BVD-VYPER-VER-001	slither-vyper	solc-version	\N	exact	\N	2025-10-31 23:47:34.848189+00	2025-10-31 23:47:34.848189+00	t
8c30efbc-f349-4f23-b0e0-acb2e2488787	BVD-VYPER-VER-002	slither-vyper	pragma	\N	exact	\N	2025-10-31 23:47:34.850907+00	2025-10-31 23:47:34.850907+00	t
e695abac-d4e8-445b-bf8a-27a398eaa719	BVD-VYPER-VER-003	slither-vyper	deprecated-standards	\N	exact	\N	2025-10-31 23:47:34.853556+00	2025-10-31 23:47:34.853556+00	t
c9b9048e-814e-4963-b0fa-a222a1f08768	BVD-VYPER-VER-004	slither-vyper	naming-convention	\N	exact	\N	2025-10-31 23:47:34.856474+00	2025-10-31 23:47:34.856474+00	t
11dd510d-83b8-4129-b6a7-478eec0d29f1	BVD-VYPER-VER-005	slither-vyper	assembly	\N	exact	\N	2025-10-31 23:47:34.859537+00	2025-10-31 23:47:34.859537+00	t
dffa5859-cd61-41f3-9f1d-cd5262de8c5f	BVD-VYPER-VER-006	slither-vyper	optimism-deprecation	\N	exact	\N	2025-10-31 23:47:34.862457+00	2025-10-31 23:47:34.862457+00	t
c8917bfe-0c5a-47a9-832d-03c6069244fa	BVD-VYPER-VER-007	slither-vyper	pyth-deprecated-functions	\N	exact	\N	2025-10-31 23:47:34.866034+00	2025-10-31 23:47:34.866034+00	t
b6e5922e-b165-465f-8e78-228bf211f0a5	BVD-VYPER-VER-008	slither-vyper	codex	\N	exact	\N	2025-10-31 23:47:34.870893+00	2025-10-31 23:47:34.870893+00	t
eaa3fc73-ad81-4ff0-983a-4bddcca4f82b	BVD-SOLANA-ACC-001	sol-azy	account_data_matching	0.9	exact	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
609139a9-76b3-40ef-9844-accb7226f1ae	BVD-SOLANA-ACC-002	sol-azy	account_data_reallocation	0.9	exact	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
78daa58e-f979-4b46-9929-357ada466439	BVD-SOLANA-ACC-003	sol-azy	account_reinitialization	0.9	exact	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
be13cc37-7867-4d09-8b1d-f857431ef85e	BVD-SOLANA-ACC-004	sol-azy	missing_owner_check	0.9	exact	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
56e7ad81-6c87-43ca-b3eb-b1595f0b9508	BVD-SOLANA-ACC-005	sol-azy	missing_signer_check	0.9	exact	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
83729693-85bd-4952-8a03-19d502f0adad	BVD-SOLANA-ACC-006	sol-azy	unvalidated_sysvar_accounts	0.7	exact	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
e552de4f-f748-46f5-bd24-a73563b9307a	BVD-SOLANA-ACC-007	sol-azy	closing_accounts	0.9	exact	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
7981ebe4-9bd5-46f9-bd60-d9acf0a2fe9a	BVD-SOLANA-CPI-001	sol-azy	arbitrary_cpi	0.9	exact	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
b7cb4f48-cd94-4107-95a3-18dc3e74a72f	BVD-SOLANA-CPI-002	sol-azy	duplicate_mutable_accounts	0.9	exact	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
20358286-f097-4c30-b3c7-3b10f708fb88	BVD-SOLANA-PDA-001	sol-azy	missing_bump_seed_canonicalization	0.9	exact	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
e6f8f754-6499-47ea-9dba-f1ac07d01927	BVD-SOLANA-PDA-002	sol-azy	pda_sharing	0.7	exact	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
205e472b-3866-4acc-8563-f4a8253c93c8	BVD-SOLANA-INT-001	sol-azy	checked_arithm_unwrap	0.9	exact	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
02be772b-6635-495d-b72c-670f9429681f	BVD-SOLANA-INT-002	sol-azy	saturating_math_usage	0.7	exact	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
a0dcdac3-3729-49e1-ac35-4c3180cb7288	BVD-SOLANA-TYP-001	sol-azy	type_cosplay	0.9	exact	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
e277f4e6-0177-44a7-84f5-ec7ce608799c	BVD-SOLANA-ACC-005	sec3-xray	MissingSignerCheck	0.9	exact	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
0556c5e3-3dbb-4539-997f-ef5a039e443f	BVD-SOLANA-ACC-004	sec3-xray	MissingOwnerCheck	0.9	exact	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
1a5fc3a0-67b8-4472-bd41-57927283837c	BVD-SOLANA-INT-005	sec3-xray	IntegerAddOverflow	0.9	exact	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
c9592105-a1d4-4c6f-a813-5609af68c6ab	BVD-SOLANA-INT-004	sec3-xray	IntegerUnderflow	0.9	exact	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
4d0894eb-7b80-478f-a1c4-446e037dc268	BVD-SOLANA-INT-006	sec3-xray	IntegerMulOverflow	0.9	exact	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
59a72f38-088b-49a0-aa4b-cb1ed20fbdd2	BVD-SOLANA-INT-007	sec3-xray	IntegerDivOverflow	0.9	exact	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
08b1b084-b4c3-4bff-836b-1ff8fe0b67a3	BVD-SOLANA-ACC-008	sec3-xray	UnverifiedParsedAccount	0.9	exact	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
1e5a3d78-5c22-4c74-86a9-182a7c9d3cb4	BVD-SOLANA-ACC-009	sec3-xray	UnvalidatedAccount	0.9	exact	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
b1d30a2f-c971-43de-ae36-0b06dfcdf3e8	BVD-SOLANA-TYP-002	sec3-xray	TypeFullCosplay	0.9	exact	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
248234ff-4ccd-4419-a68f-52914d92c420	BVD-SOLANA-TYP-003	sec3-xray	TypePartialCosplay	0.9	exact	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
eae3c80f-306b-47fa-9c94-c2638e6fd0a0	BVD-SOLANA-PDA-003	sec3-xray	BumpSeedNotValidated	0.9	exact	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
82f7b468-00b7-4c66-b30f-6368ef278a89	BVD-SOLANA-PDA-004	sec3-xray	InsecurePDASharing	0.7	exact	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
53fef45e-e587-4a77-95a6-7289a8a73362	BVD-SOLANA-CPI-001	sec3-xray	ArbitraryCPI	0.9	exact	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
6846c095-e860-44a9-8f16-a83c7299cb6a	BVD-SOLANA-SEC-001	sec3-xray	MaliciousSimulation	0.7	exact	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
1aad2e07-3cce-4351-8be1-3e466c71f81d	BVD-SOLANA-LOG-001	sec3-xray	IncorrectLogic_2001	0.7	exact	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
20416865-6493-42f6-9504-90fa522579dd	BVD-SOLANA-LOG-002	sec3-xray	IncorrectLogic_2002	0.7	exact	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
1ad11f8e-a4ac-468b-9c93-98722b1b5b02	BVD-SOLANA-LOG-003	sec3-xray	IncorrectLogic_2003	0.7	exact	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
c814c0cb-381a-4e97-b7d0-497bb4007233	BVD-SOLANA-LOG-004	sec3-xray	IncorrectLogic_2004	0.9	exact	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
570d6065-9674-4725-aa2a-dbd0b22f730c	BVD-SOLANA-LOG-005	sec3-xray	IncorrectLogic_2005	0.9	exact	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
3a6fa287-c315-4244-a289-9217bc4a9d1c	BVD-CAIRO-ACC-001	caracal	controlled-library-call	0.7	exact	\N	2025-11-01 16:25:08.767942+00	2025-11-01 16:25:08.767942+00	t
9e2870e7-2cb4-401a-878a-aa60e6c1294d	BVD-CAIRO-ACC-002	caracal	tx-origin	0.7	exact	\N	2025-11-01 16:25:08.767942+00	2025-11-01 16:25:08.767942+00	t
ae888851-d10e-4d6c-98e6-6d7950925c5c	BVD-CAIRO-L2S-001	caracal	unchecked-l1-handler-from	0.7	exact	\N	2025-11-01 16:25:08.767942+00	2025-11-01 16:25:08.767942+00	t
9312c5ce-dc76-4eff-8540-06ca0d7a5742	BVD-CAIRO-ARI-001	caracal	felt252-unsafe-arithmetic	0.7	exact	\N	2025-11-01 16:25:08.767942+00	2025-11-01 16:25:08.767942+00	t
b33c5c28-0374-469b-8be9-f190c644ff42	BVD-CAIRO-STA-001	caracal	unenforced-view	0.7	exact	\N	2025-11-01 16:25:08.767942+00	2025-11-01 16:25:08.767942+00	t
d59ba28c-4968-4336-8619-6e81832f8127	BVD-CAIRO-MEM-001	caracal	use-after-pop-front	0.7	exact	\N	2025-11-01 16:25:08.767942+00	2025-11-01 16:25:08.767942+00	t
9a5791bc-a67d-4076-b646-0f187d9dad58	BVD-CAIRO-REE-001	caracal	reentrancy	0.7	exact	\N	2025-11-01 16:25:08.767942+00	2025-11-01 16:25:08.767942+00	t
f3330faf-d673-472a-ba69-12e27fd8ac55	BVD-CAIRO-REE-002	caracal	read-only-reentrancy	0.7	exact	\N	2025-11-01 16:25:08.767942+00	2025-11-01 16:25:08.767942+00	t
cc41da89-9927-4d06-a8db-2adbf8397dc9	BVD-CAIRO-REE-003	caracal	reentrancy-benign	0.7	exact	\N	2025-11-01 16:25:08.767942+00	2025-11-01 16:25:08.767942+00	t
f72f035a-e743-4ae7-87f9-1c1c76cedafe	BVD-CAIRO-REE-004	caracal	reentrancy-events	0.7	exact	\N	2025-11-01 16:25:08.767942+00	2025-11-01 16:25:08.767942+00	t
2ae75a7e-2139-4374-8140-c7faf0950974	BVD-CAIRO-QUA-001	caracal	unused-events	0.7	exact	\N	2025-11-01 16:25:08.767942+00	2025-11-01 16:25:08.767942+00	t
bb7df6e7-7992-4347-a4e6-287ae3560b20	BVD-CAIRO-QUA-002	caracal	unused-return	0.7	exact	\N	2025-11-01 16:25:08.767942+00	2025-11-01 16:25:08.767942+00	t
11982183-996a-448f-bbd2-fb0da00cfe19	BVD-CAIRO-QUA-003	caracal	unused-arguments	0.7	exact	\N	2025-11-01 16:25:08.767942+00	2025-11-01 16:25:08.767942+00	t
519b652a-410a-4b19-bc30-e45b74fecf6b	BVD-CAIRO-QUA-004	caracal	dead-code	0.7	exact	\N	2025-11-01 16:25:08.767942+00	2025-11-01 16:25:08.767942+00	t
\.


--
-- Data for Name: project_contracts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.project_contracts (project_id, contract_id, added_at) FROM stdin;
\.


--
-- Data for Name: projects; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.projects (id, name, description, user_id, settings, default_scan_profile, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: saved_searches; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.saved_searches (id, user_id, name, description, search_params, last_executed_at, execution_count, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: scanner_release_tracking; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.scanner_release_tracking (id, scanner_name, release_version, release_date, release_url, is_prerelease, checked_at, applied_to_platform, applied_at, release_notes) FROM stdin;
\.


--
-- Data for Name: scanner_version_history; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.scanner_version_history (id, scanner_name, old_version, new_version, old_image_tag, new_image_tag, change_type, breaking_changes, detector_changes, updated_at, updated_by, changelog_url, release_notes) FROM stdin;
1	aderyn	0.6.4	0.6.5	0.2.0	0.2.1	patch	f	None - all 87/87 detector mappings remain valid	2025-10-30 00:00:00+00	platform-team	\N	Added grep API to MCP server
2	semgrep	1.122.0	1.141.0	0.2.0	0.2.1	minor	f	TBD - needs verification after 19-version jump	2025-10-30 00:00:00+00	platform-team	\N	19 versions jump. Pattern matching requires validation
3	echidna	2.2.4	2.2.7	0.2.0	0.2.1	patch	f	N/A - fuzzer, no fixed detectors	2025-10-30 00:00:00+00	platform-team	\N	Performance improvements from upstream
\.


--
-- Data for Name: scanner_versions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.scanner_versions (id, scanner_name, scanner_type, ecosystem, language, current_version, latest_version, version_status, image_tag, image_name, developer, repository_url, documentation_url, detector_count, integrated_detector_count, last_checked_at, last_updated_at, created_at, notes) FROM stdin;
2	aderyn	static-analysis	evm	solidity	0.6.5	0.6.5	up-to-date	0.2.1	scanner-aderyn:0.2.1	Cyfrin	https://github.com/Cyfrin/aderyn	https://github.com/Cyfrin/aderyn/tree/dev/aderyn_core/src/detect	87	87	2025-10-30 00:00:00+00	2025-10-30 17:04:11.249854+00	2025-10-30 17:04:11.249854+00	Updated 2025-10-30. 100% integration complete
3	semgrep	static-analysis	evm	solidity	1.141.0	1.141.0	up-to-date	0.2.1	scanner-semgrep:0.2.1	Semgrep Inc	https://github.com/Decurity/semgrep-smart-contracts	https://github.com/Decurity/semgrep-smart-contracts	47	43	2025-10-30 00:00:00+00	2025-10-30 17:04:11.249854+00	2025-10-30 17:04:11.249854+00	Updated 2025-10-30. 19-version jump from 1.122.0. 43/47 detectors integrated (91.5%)
4	solhint	static-analysis	evm	solidity	6.0.1	6.0.1	up-to-date	0.2.0	scanner-solhint:0.2.0	Protofire	https://github.com/protofire/solhint	https://github.com/protofire/solhint/blob/master/docs/rules.md	20	16	2025-10-30 00:00:00+00	2025-10-30 17:04:11.249854+00	2025-10-30 17:04:11.249854+00	Updated 2025-10-19. 16/20 detectors integrated (80%)
5	echidna	fuzzer	evm	solidity	2.2.7	2.2.7	up-to-date	0.2.1	scanner-echidna:0.2.1	Trail of Bits	https://github.com/crytic/echidna	https://github.com/crytic/echidna	0	0	2025-10-30 00:00:00+00	2025-10-30 17:04:11.249854+00	2025-10-30 17:04:11.249854+00	Updated 2025-10-30. Property-based fuzzer, no fixed detectors
6	halmos	formal-verification	evm	solidity	0.3.3	0.3.3	up-to-date	0.2.0	scanner-halmos:0.2.0	a16z	https://github.com/a16z/halmos	https://github.com/a16z/halmos	0	0	2025-10-30 00:00:00+00	2025-10-30 17:04:11.249854+00	2025-10-30 17:04:11.249854+00	Updated 2025-10-19. Symbolic execution, user-defined properties
7	certora	formal-verification	evm	solidity	8.3.1	8.3.1	up-to-date	0.2.0	scanner-certora:0.2.0	Certora	https://www.certora.com/	https://docs.certora.com/en/latest/docs/cvl/builtin.html	5	0	2025-10-30 00:00:00+00	2025-10-30 17:04:11.249854+00	2025-10-30 17:04:11.249854+00	Updated 2025-10-19. 5 built-in rules, 0 integrated
8	vyper	static-analysis	evm	vyper	0.11.3	0.11.3	up-to-date	0.2.0	scanner-vyper:0.2.0	Trail of Bits	https://github.com/crytic/slither	https://github.com/crytic/slither/wiki/Detector-Documentation	99	0	2025-10-30 00:00:00+00	2025-10-30 17:04:11.249854+00	2025-10-30 17:04:11.249854+00	Same as slither (slither-vyper). No detectors integrated yet
9	moccasin	fuzzer	evm	vyper	0.3.6	0.3.6	up-to-date	0.1.0	scanner-moccasin:0.1.0	Cyfrin	https://github.com/Cyfrin/moccasin	https://github.com/Cyfrin/moccasin	0	0	2025-10-30 00:00:00+00	2025-10-30 17:04:11.249854+00	2025-10-30 17:04:11.249854+00	Updated 2025-10-19. Vyper fuzzing framework
10	sol-azy	static-analysis	solana	rust	0.2.0	0.2.0	up-to-date	0.2.0	scanner-sol-azy:0.2.0	FuzzingLabs	https://github.com/FuzzingLabs/sol-azy	https://github.com/FuzzingLabs/sol-azy/tree/master/rules/syn_ast	14	0	2025-10-30 00:00:00+00	2025-10-30 17:04:11.249854+00	2025-10-30 17:04:11.249854+00	No formal releases, source version. 14 security rules
11	sec3-xray	static-analysis	solana	rust	0.0.6	0.0.6	up-to-date	0.1.0	scanner-sec3-xray:0.1.0	Sec3	https://github.com/sec3-service/x-ray	https://github.com/sec3-service/x-ray	11	0	2025-10-30 00:00:00+00	2025-10-30 17:04:11.249854+00	2025-10-30 17:04:11.249854+00	Last release 2024. 11+ detector categories
12	trident	fuzzer	solana	rust	0.11.0	0.11.0	up-to-date	0.1.0	scanner-trident:0.1.0	Ackee Blockchain	https://github.com/Ackee-Blockchain/trident	https://github.com/Ackee-Blockchain/trident	0	0	2025-10-30 00:00:00+00	2025-10-30 17:04:11.249854+00	2025-10-30 17:04:11.249854+00	Updated 2025-10-19. Solana fuzzing framework
13	cargo-fuzz-solana	fuzzer	solana	rust	0.13.1	0.13.1	up-to-date	0.1.0	scanner-cargo-fuzz-solana:0.1.0	rust-fuzz	https://github.com/rust-fuzz/cargo-fuzz	https://github.com/rust-fuzz/cargo-fuzz	0	0	2025-10-30 00:00:00+00	2025-10-30 17:04:11.249854+00	2025-10-30 17:04:11.249854+00	Updated 2025-10-19. Rust fuzzing for Solana
14	caracal	static-analysis	cairo	cairo	0.2.3	0.2.3	up-to-date	0.2.0	scanner-caracal:0.2.0	Trail of Bits	https://github.com/crytic/caracal	https://github.com/crytic/caracal	14	0	2025-10-30 00:00:00+00	2025-10-30 17:04:11.249854+00	2025-10-30 17:04:11.249854+00	Updated 2025-10-19. 14 SIERRA-based detectors
15	tayt	fuzzer	cairo	cairo	0.1.0	0.1.0	deprecated	0.2.0	scanner-tayt:0.2.0	Trail of Bits	https://github.com/crytic/tayt	https://github.com/crytic/tayt	0	0	2025-10-30 00:00:00+00	2025-10-30 17:04:11.249854+00	2025-10-30 17:04:11.249854+00	Repository archived Feb 2025, no releases
16	starknet-foundry	fuzzer	cairo	cairo	0.50.0	0.50.0	up-to-date	0.1.0	scanner-starknet-foundry:0.1.0	Foundry	https://github.com/foundry-rs/starknet-foundry	https://github.com/foundry-rs/starknet-foundry	0	0	2025-10-30 00:00:00+00	2025-10-30 17:04:11.249854+00	2025-10-30 17:04:11.249854+00	Updated 2025-10-19. Cairo testing framework
1	slither	static-analysis	evm	solidity	0.11.3	0.11.3	up-to-date	0.2.0	scanner-slither:0.2.0	Trail of Bits	https://github.com/crytic/slither	https://github.com/crytic/slither/wiki/Detector-Documentation	101	101	2025-10-30 00:00:00+00	2025-10-31 17:52:56.684762+00	2025-10-30 17:04:11.249854+00	Updated 2025-10-19. 18/99 detectors integrated (18.2%)
\.


--
-- Data for Name: scans; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.scans (id, contract_id, user_id, scan_type, status, started_at, completed_at, error_message, critical_count, high_count, medium_count, low_count, created_at, updated_at, scanners_used, scan_config, duration_seconds) FROM stdin;
5461ec78-43f7-4a30-86cf-f120b6473196	86f9a16f-7896-4115-b321-adf9db382682	ab45210a-44a1-490e-bd5f-18135cdc3c91	quick	completed	2025-10-16 22:15:57.032901+00	2025-10-16 22:16:09.790802+00	\N	0	1	0	1	2025-10-16 22:15:51.755661+00	2025-10-16 22:15:59.040916+00	\N	{}	\N
b0e9ac5e-bc8a-441f-933c-4e8782683e66	4557d54f-bc37-4e82-819f-32a9a5137315	56bc0604-49bc-4a73-8b4f-69fc3386a0f8	quick	completed	2025-10-17 21:31:32.035208+00	2025-10-17 21:31:34.265536+00	\N	1	1	0	0	2025-10-17 21:31:31.976695+00	2025-10-17 21:31:34.262851+00	\N	{}	\N
9d566dd4-a057-43b4-adc4-ed7051a4900b	86f9a16f-7896-4115-b321-adf9db382682	ab45210a-44a1-490e-bd5f-18135cdc3c91	quick	completed	2025-10-16 22:16:27.014627+00	2025-10-16 22:16:33.345636+00	\N	0	1	0	1	2025-10-16 22:16:19.702025+00	2025-10-16 22:16:27.023053+00	\N	{}	\N
4afaea04-0764-468c-ad64-5c63075fcdf7	e29b1d07-26aa-4f45-bee2-83040bf5745e	56bc0604-49bc-4a73-8b4f-69fc3386a0f8	quick	completed	2025-10-17 21:34:16.391603+00	2025-10-17 21:34:18.513164+00	\N	0	0	0	0	2025-10-17 21:34:16.322417+00	2025-10-17 21:34:18.509924+00	\N	{}	\N
9cda5db3-28e4-48ba-96bd-796c7330ddb0	af250661-1a6a-4989-985b-7e73b6e8f306	27850871-1cd4-4804-9c1d-6cf8fb90fbd2	quick	completed	2025-10-17 14:52:02.07158+00	2025-10-17 14:52:06.390122+00	\N	0	0	0	0	2025-10-17 14:52:01.743648+00	2025-10-17 14:52:06.322439+00	\N	{}	\N
31742a9d-5f1d-42a7-819a-c873870d252d	fc783138-6c5a-4dce-b469-9fdf46020f14	27850871-1cd4-4804-9c1d-6cf8fb90fbd2	quick	completed	2025-10-17 01:05:22.929408+00	2025-10-17 01:05:29.942907+00	\N	1	0	0	0	2025-10-17 01:05:21.774975+00	2025-10-17 01:05:29.925867+00	\N	{}	\N
ad9f0969-beda-485f-bbaa-6d854cbb86da	fc783138-6c5a-4dce-b469-9fdf46020f14	ab45210a-44a1-490e-bd5f-18135cdc3c91	quick	completed	2025-10-17 17:17:21.046574+00	2025-10-17 17:17:23.942096+00	\N	1	0	0	0	2025-10-17 17:17:20.829621+00	2025-10-17 17:17:23.865724+00	\N	{}	\N
92197c37-a3e0-4d4f-ad78-1f262a27703b	97970ea9-196b-4643-95e6-f1aa019bcf6f	56bc0604-49bc-4a73-8b4f-69fc3386a0f8	quick	completed	2025-10-17 22:29:52.114898+00	2025-10-17 22:29:56.092418+00	\N	2	5	0	0	2025-10-17 22:29:52.055946+00	2025-10-17 22:29:56.089651+00	\N	{}	\N
ab38ce7e-f785-4195-9cbc-f5005a03a531	fc783138-6c5a-4dce-b469-9fdf46020f14	ab45210a-44a1-490e-bd5f-18135cdc3c91	quick	completed	2025-10-17 17:25:01.166373+00	2025-10-17 17:25:03.781531+00	\N	1	0	0	0	2025-10-17 17:25:01.005552+00	2025-10-17 17:25:03.770008+00	\N	{}	\N
0540d982-7d72-45a0-a8ca-a30a24a9f710	526f3007-70d4-4bf2-a53e-2d99ead52669	56bc0604-49bc-4a73-8b4f-69fc3386a0f8	quick	completed	2025-10-17 21:35:49.302711+00	2025-10-17 21:35:51.466537+00	\N	8	0	0	0	2025-10-17 21:35:49.249883+00	2025-10-17 21:35:51.463832+00	\N	{}	\N
f259704f-3393-4ef6-88c7-f59a4f41c586	fc783138-6c5a-4dce-b469-9fdf46020f14	ab45210a-44a1-490e-bd5f-18135cdc3c91	quick	completed	2025-10-17 17:27:06.548836+00	2025-10-17 17:27:08.906687+00	\N	1	0	0	0	2025-10-17 17:27:06.335847+00	2025-10-17 17:27:08.823072+00	\N	{}	\N
1546015b-d5f5-4e9e-9d76-ecc8d082d88e	fc783138-6c5a-4dce-b469-9fdf46020f14	ab45210a-44a1-490e-bd5f-18135cdc3c91	quick	completed	2025-10-17 17:30:36.036971+00	2025-10-17 17:30:38.45146+00	\N	1	0	0	0	2025-10-17 17:30:35.977529+00	2025-10-17 17:30:38.370197+00	\N	{}	\N
0ffcad6c-ac72-4278-9ae3-e846d397530a	fc783138-6c5a-4dce-b469-9fdf46020f14	ab45210a-44a1-490e-bd5f-18135cdc3c91	quick	completed	2025-10-17 17:34:52.763623+00	2025-10-17 17:34:55.267228+00	\N	1	0	0	0	2025-10-17 17:34:52.700317+00	2025-10-17 17:34:55.189274+00	\N	{}	\N
8c5f9f99-0634-4833-890e-3f3aae0ef221	fc783138-6c5a-4dce-b469-9fdf46020f14	ab45210a-44a1-490e-bd5f-18135cdc3c91	quick	completed	2025-10-17 17:48:17.930506+00	2025-10-17 17:48:20.316247+00	\N	1	0	0	0	2025-10-17 17:48:17.79318+00	2025-10-17 17:48:20.311103+00	\N	{}	\N
5d741b89-e602-4862-9bda-4eea5acf333f	fc783138-6c5a-4dce-b469-9fdf46020f14	ab45210a-44a1-490e-bd5f-18135cdc3c91	quick	completed	2025-10-17 17:52:33.470605+00	2025-10-17 17:52:35.962065+00	\N	1	0	0	0	2025-10-17 17:52:33.404319+00	2025-10-17 17:52:35.868994+00	\N	{}	\N
9e06c8f8-30e1-4b62-8332-3bb8da5068a4	fc783138-6c5a-4dce-b469-9fdf46020f14	ab45210a-44a1-490e-bd5f-18135cdc3c91	full	completed	2025-10-17 17:55:25.844726+00	2025-10-17 17:55:28.257024+00	\N	1	0	0	0	2025-10-17 17:55:25.780684+00	2025-10-17 17:55:28.153663+00	\N	{}	\N
e6d541e1-65d3-4072-9263-7b3714135fe0	fc783138-6c5a-4dce-b469-9fdf46020f14	ab45210a-44a1-490e-bd5f-18135cdc3c91	full	completed	2025-10-17 17:58:21.506933+00	2025-10-17 17:58:24.088072+00	\N	1	0	0	0	2025-10-17 17:58:21.323057+00	2025-10-17 17:58:24.084041+00	\N	{}	\N
0300d842-455a-4102-9fa0-684e5e5d53fa	fc783138-6c5a-4dce-b469-9fdf46020f14	ab45210a-44a1-490e-bd5f-18135cdc3c91	full	completed	2025-10-17 18:03:15.928644+00	2025-10-17 18:03:18.313844+00	\N	1	0	0	0	2025-10-17 18:03:15.864809+00	2025-10-17 18:03:18.311543+00	\N	{}	\N
77b7e537-a626-4e5a-9697-9bfdd8b64551	fc783138-6c5a-4dce-b469-9fdf46020f14	ab45210a-44a1-490e-bd5f-18135cdc3c91	full	completed	2025-10-17 18:21:38.655773+00	2025-10-17 18:21:41.486228+00	\N	1	0	0	0	2025-10-17 18:21:38.395867+00	2025-10-17 18:21:41.482781+00	\N	{}	\N
3a11448c-16f3-46d8-ae50-2e4f35fc597c	98593981-74f4-43f4-b7f6-3d795f4a488c	ab45210a-44a1-490e-bd5f-18135cdc3c91	quick	running	2025-10-18 17:03:28.932585+00	\N	\N	0	0	0	0	2025-10-18 17:03:28.843164+00	2025-10-18 17:03:28.859116+00	\N	{}	\N
50226168-4bd5-460e-8976-0dd50d6e7016	98593981-74f4-43f4-b7f6-3d795f4a488c	ab45210a-44a1-490e-bd5f-18135cdc3c91	quick	completed	2025-10-17 19:10:36.933722+00	2025-10-17 19:10:39.244371+00	\N	4	1	0	0	2025-10-17 19:10:36.873817+00	2025-10-17 19:10:39.241762+00	\N	{}	\N
67b31138-1bd4-4422-bfdb-564f441ce01d	43195d13-0923-4e91-9008-cb6ccd854b66	56bc0604-49bc-4a73-8b4f-69fc3386a0f8	quick	completed	2025-10-17 21:15:13.961079+00	2025-10-17 21:15:16.153194+00	\N	1	0	0	0	2025-10-17 21:15:13.729764+00	2025-10-17 21:15:16.150978+00	\N	{}	\N
2b1f4884-513c-4176-a8b4-fa0dc33b7ee6	0e2ea42e-a14d-446a-a193-04a3fbefbd6c	56bc0604-49bc-4a73-8b4f-69fc3386a0f8	quick	failed	2025-10-17 21:36:11.511046+00	2025-10-17 22:27:23.926727+00	\N	0	0	0	0	2025-10-17 21:36:11.464533+00	2025-10-17 22:27:23.915411+00	\N	{}	\N
f8facdd2-ad72-4757-adc0-1178e4ef6427	0e2ea42e-a14d-446a-a193-04a3fbefbd6c	56bc0604-49bc-4a73-8b4f-69fc3386a0f8	full	failed	2025-10-17 22:22:35.814973+00	2025-10-17 22:27:24.089206+00	\N	0	0	0	0	2025-10-17 22:22:35.678748+00	2025-10-17 22:27:24.086766+00	\N	{}	\N
29de47a0-a2c2-457e-b326-4c945dd7421e	f2f3239b-3d5e-4299-a45f-924b5761a0dc	ab45210a-44a1-490e-bd5f-18135cdc3c91	full	failed	2025-10-19 03:49:38.122653+00	2025-10-19 03:50:59.922716+00	\N	0	0	0	0	2025-10-19 03:49:37.696536+00	2025-10-19 03:50:59.910672+00	\N	{}	\N
d27fe555-06b6-47b1-bf8f-d7b28b9a1779	0e2ea42e-a14d-446a-a193-04a3fbefbd6c	56bc0604-49bc-4a73-8b4f-69fc3386a0f8	full	completed	2025-10-17 22:27:26.129635+00	2025-10-17 22:27:30.240142+00	\N	0	4	0	0	2025-10-17 22:27:26.059152+00	2025-10-17 22:27:30.237187+00	\N	{}	\N
dcf88f86-7f8a-4fc8-afa7-e1574b423a08	48fe8623-d7fb-40a3-90a9-1ee1ee96fd89	56bc0604-49bc-4a73-8b4f-69fc3386a0f8	full	failed	2025-10-18 01:18:43.914869+00	2025-10-18 01:25:06.671692+00	\N	0	0	0	0	2025-10-18 01:18:43.852333+00	2025-10-18 01:25:06.668571+00	\N	{}	\N
d6769c16-e4fa-4c0d-809d-912779d96421	f2f3239b-3d5e-4299-a45f-924b5761a0dc	ab45210a-44a1-490e-bd5f-18135cdc3c91	full	failed	2025-10-19 04:13:40.547311+00	2025-10-19 05:14:43.769768+00	\N	0	0	0	0	2025-10-19 04:13:40.370306+00	2025-10-19 05:14:43.767445+00	\N	{}	\N
4008c00b-763b-4c37-b11e-f94b0582eca6	39ff6067-d614-4017-8c01-896029a2729a	ab45210a-44a1-490e-bd5f-18135cdc3c91	quick	failed	2025-10-18 01:13:29.781193+00	2025-10-19 05:14:43.33061+00	\N	0	0	0	0	2025-10-18 01:13:29.171614+00	2025-10-19 05:14:43.328206+00	\N	{}	\N
69d0cba1-0371-4113-a759-094c89f33309	48fe8623-d7fb-40a3-90a9-1ee1ee96fd89	56bc0604-49bc-4a73-8b4f-69fc3386a0f8	full	failed	2025-10-18 01:26:52.070711+00	2025-10-19 05:14:43.424666+00	\N	0	0	0	0	2025-10-18 01:26:51.85201+00	2025-10-19 05:14:43.422433+00	\N	{}	\N
f0e7fb4d-12fa-4070-b36f-3ce1249c4620	f2f3239b-3d5e-4299-a45f-924b5761a0dc	ab45210a-44a1-490e-bd5f-18135cdc3c91	full	failed	2025-10-19 05:30:51.780457+00	2025-10-19 05:31:44.351514+00	\N	0	0	0	0	2025-10-19 05:30:51.32784+00	2025-10-19 05:31:44.348876+00	\N	{}	\N
fc383f6c-e03b-4d0a-af9c-d13b2596bd84	f2f3239b-3d5e-4299-a45f-924b5761a0dc	ab45210a-44a1-490e-bd5f-18135cdc3c91	full	running	2025-10-19 05:36:06.027436+00	\N	\N	0	0	0	0	2025-10-19 05:36:05.873449+00	2025-10-19 05:36:05.896591+00	\N	{}	\N
5fbf47f2-c421-4608-8770-eaa9a21f1789	f2f3239b-3d5e-4299-a45f-924b5761a0dc	ab45210a-44a1-490e-bd5f-18135cdc3c91	full	completed	2025-10-19 16:01:36.284154+00	2025-10-19 16:01:52.792361+00	\N	0	0	0	0	2025-10-19 16:01:34.13457+00	2025-10-19 16:01:36.982468+00	\N	{}	\N
b3b89b39-1b4b-46c3-bb2e-4f2698201962	8af6de60-912a-4eff-aa1f-96779a3bac91	ab45210a-44a1-490e-bd5f-18135cdc3c91	full	completed	2025-10-23 15:27:07.548999+00	2025-10-23 15:27:13.31487+00	\N	0	0	2	3	2025-10-23 15:27:06.541252+00	2025-10-23 15:27:13.312352+00	\N	{}	\N
43c248a1-5484-4274-acf2-3485f9f08b1e	8af6de60-912a-4eff-aa1f-96779a3bac91	27850871-1cd4-4804-9c1d-6cf8fb90fbd2	full	running	2025-10-24 03:10:57.361427+00	\N	\N	0	0	0	0	2025-10-24 03:10:47.642802+00	2025-10-24 03:10:57.359517+00	\N	{}	\N
a3d8d360-2385-4281-818f-4dae403d485e	8af6de60-912a-4eff-aa1f-96779a3bac91	27850871-1cd4-4804-9c1d-6cf8fb90fbd2	full	running	2025-10-24 03:28:58.40602+00	\N	\N	0	0	0	0	2025-10-24 03:26:09.320889+00	2025-10-24 03:28:58.398849+00	\N	{}	\N
bc87370e-ee8d-4251-b30a-3a0ad54fd735	86f9a16f-7896-4115-b321-adf9db382682	ab45210a-44a1-490e-bd5f-18135cdc3c91	full	completed	2025-10-24 03:54:19.947768+00	2025-10-24 03:57:02.042211+00	\N	0	1	0	0	2025-10-24 03:54:14.876171+00	2025-10-24 03:57:02.034313+00	\N	{}	\N
7cbbfacf-e078-4aa5-87da-ca5b8c9d578b	86f9a16f-7896-4115-b321-adf9db382682	27850871-1cd4-4804-9c1d-6cf8fb90fbd2	full	completed	2025-10-24 05:07:22.60787+00	2025-10-24 05:07:39.816526+00	\N	0	1	0	0	2025-10-24 05:06:26.110182+00	2025-10-24 05:07:39.809751+00	\N	{}	\N
0746ab0f-fbb3-485a-86f1-098f20fad4a1	86f9a16f-7896-4115-b321-adf9db382682	27850871-1cd4-4804-9c1d-6cf8fb90fbd2	comprehensive	completed	2025-10-24 17:57:32.421265+00	2025-10-24 17:57:51.225346+00	\N	0	0	0	0	2025-10-24 17:57:24.111704+00	2025-10-24 17:57:51.215358+00	\N	{}	\N
73ff92f2-632a-426b-bf11-783c55cc0eae	39ff6067-d614-4017-8c01-896029a2729a	ab45210a-44a1-490e-bd5f-18135cdc3c91	quick	failed	2025-10-18 17:03:18.654185+00	2025-10-24 22:59:43.082343+00	\N	0	0	0	0	2025-10-18 17:03:18.445688+00	2025-10-24 22:59:42.899102+00	\N	{}	\N
94ec0b8a-869f-43c6-91f3-f2784c06e2d3	0e2ea42e-a14d-446a-a193-04a3fbefbd6c	56bc0604-49bc-4a73-8b4f-69fc3386a0f8	quick	failed	2025-10-17 21:52:31.611464+00	2025-10-24 22:59:43.134935+00	\N	0	0	0	0	2025-10-17 21:52:31.541615+00	2025-10-24 22:59:43.131221+00	\N	{}	\N
ccb1a2ad-c8e7-4806-8b6f-197dd2d81991	f2f3239b-3d5e-4299-a45f-924b5761a0dc	ab45210a-44a1-490e-bd5f-18135cdc3c91	full	failed	2025-10-19 04:19:23.48928+00	2025-10-24 22:59:43.183889+00	\N	0	0	0	0	2025-10-19 04:19:23.34291+00	2025-10-24 22:59:43.179368+00	\N	{}	\N
e8472be4-7a4b-4637-94e1-4435aba66fb2	39ff6067-d614-4017-8c01-896029a2729a	ab45210a-44a1-490e-bd5f-18135cdc3c91	full	failed	2025-10-18 22:20:34.48075+00	2025-10-24 22:59:43.339022+00	\N	0	0	0	0	2025-10-18 22:20:34.253557+00	2025-10-24 22:59:43.33494+00	\N	{}	\N
f4b89c5b-d294-4978-af9c-aff35aaa88d1	48fe8623-d7fb-40a3-90a9-1ee1ee96fd89	56bc0604-49bc-4a73-8b4f-69fc3386a0f8	full	failed	2025-10-18 01:17:21.463358+00	2025-10-24 22:59:43.390982+00	\N	0	0	0	0	2025-10-18 01:17:21.395035+00	2025-10-24 22:59:43.386407+00	\N	{}	\N
d177d341-4673-4f3c-a70e-5a25dfa2da6c	86f9a16f-7896-4115-b321-adf9db382682	27850871-1cd4-4804-9c1d-6cf8fb90fbd2	full	completed	2025-10-24 23:26:01.71619+00	2025-10-25 00:26:24.318745+00	\N	0	0	0	0	2025-10-24 23:25:55.607415+00	2025-10-25 00:26:24.308522+00	{slither}	{}	\N
a6286a25-9c0a-4406-8661-85295c785d48	86f9a16f-7896-4115-b321-adf9db382682	27850871-1cd4-4804-9c1d-6cf8fb90fbd2	standard	completed	2025-10-25 02:06:29.761354+00	2025-10-25 02:06:43.674847+00	\N	0	0	0	0	2025-10-25 02:06:26.351177+00	2025-10-25 02:06:43.665479+00	{slither}	{}	\N
6baaca28-a409-4c4d-802a-c0c56a170890	86f9a16f-7896-4115-b321-adf9db382682	27850871-1cd4-4804-9c1d-6cf8fb90fbd2	standard	completed	2025-10-25 15:49:11.804682+00	2025-10-25 15:55:48.67036+00	\N	0	0	0	0	2025-10-25 15:49:06.921406+00	2025-10-25 15:55:48.651686+00	{slither}	{}	\N
3a0084eb-8cac-457e-80a3-c2b68269e224	86f9a16f-7896-4115-b321-adf9db382682	27850871-1cd4-4804-9c1d-6cf8fb90fbd2	standard	completed	2025-10-25 15:56:00.260214+00	2025-10-25 15:56:21.362741+00	\N	0	0	0	0	2025-10-25 15:55:58.828246+00	2025-10-25 15:56:21.351128+00	{slither}	{}	\N
1c237e1a-5a68-47f1-aa48-05b9ff872c50	86f9a16f-7896-4115-b321-adf9db382682	27850871-1cd4-4804-9c1d-6cf8fb90fbd2	standard	completed	2025-10-25 17:50:15.69024+00	2025-10-25 17:50:30.072197+00	\N	0	0	0	0	2025-10-25 17:46:40.726632+00	2025-10-25 17:50:30.063902+00	{slither}	{}	\N
1018d5b1-0265-4096-b2e1-87e664298284	86f9a16f-7896-4115-b321-adf9db382682	27850871-1cd4-4804-9c1d-6cf8fb90fbd2	standard	completed	2025-10-25 18:13:46.525766+00	2025-10-25 18:14:00.414697+00	\N	0	0	0	0	2025-10-25 18:13:42.999099+00	2025-10-25 18:14:00.406727+00	{slither}	{}	\N
9c4b1006-5d71-48da-b416-18f3684d4572	86f9a16f-7896-4115-b321-adf9db382682	27850871-1cd4-4804-9c1d-6cf8fb90fbd2	standard	completed	2025-10-25 18:29:04.104307+00	2025-10-25 18:29:32.762627+00	\N	0	0	0	0	2025-10-25 18:24:29.335249+00	2025-10-25 18:29:32.754244+00	{slither}	{}	\N
f2201b28-2a42-4d87-9ebd-ba094580f571	86f9a16f-7896-4115-b321-adf9db382682	27850871-1cd4-4804-9c1d-6cf8fb90fbd2	comprehensive	completed	2025-10-25 18:29:04.156725+00	2025-10-25 18:29:32.765302+00	\N	0	0	0	0	2025-10-25 18:26:05.021096+00	2025-10-25 18:29:32.756995+00	\N	{}	\N
d4d01fd8-ced4-4209-b8f2-659cdabf3a67	fc783138-6c5a-4dce-b469-9fdf46020f14	27850871-1cd4-4804-9c1d-6cf8fb90fbd2	standard	completed	2025-10-25 20:55:06.913069+00	2025-10-25 20:55:22.830428+00	\N	0	0	0	0	2025-10-25 20:54:57.863499+00	2025-10-25 20:55:22.823112+00	{slither}	{}	\N
00658c8e-a359-426c-90a0-31f9489c3759	97970ea9-196b-4643-95e6-f1aa019bcf6f	27850871-1cd4-4804-9c1d-6cf8fb90fbd2	standard	completed	2025-10-25 21:03:07.114856+00	2025-10-25 21:03:19.816554+00	\N	0	0	0	0	2025-10-25 21:02:57.535443+00	2025-10-25 21:03:19.815344+00	{slither}	{}	\N
2f987517-ca20-43c5-aabc-0246f8973d2e	4557d54f-bc37-4e82-819f-32a9a5137315	27850871-1cd4-4804-9c1d-6cf8fb90fbd2	comprehensive	completed	2025-10-25 22:34:50.235585+00	2025-10-25 22:35:03.643473+00	\N	0	0	0	0	2025-10-25 22:34:40.301049+00	2025-10-25 22:35:03.635473+00	\N	{}	\N
fe153dad-4c0b-4165-b529-6cec12692b34	4557d54f-bc37-4e82-819f-32a9a5137315	27850871-1cd4-4804-9c1d-6cf8fb90fbd2	comprehensive	completed	2025-10-25 23:18:18.870042+00	2025-10-25 23:18:36.739521+00	\N	0	1	1	0	2025-10-25 23:18:14.804717+00	2025-10-25 23:18:36.657809+00	\N	{}	\N
b5b1f73c-53b8-4567-ae23-3e25c00143af	4557d54f-bc37-4e82-819f-32a9a5137315	27850871-1cd4-4804-9c1d-6cf8fb90fbd2	comprehensive	completed	2025-10-25 23:44:09.827238+00	2025-10-25 23:44:29.437375+00	\N	0	1	1	0	2025-10-25 23:44:04.592652+00	2025-10-25 23:44:29.436066+00	\N	{}	\N
d99fd397-e73d-4103-af77-6848b1212476	86f9a16f-7896-4115-b321-adf9db382682	27850871-1cd4-4804-9c1d-6cf8fb90fbd2	comprehensive	completed	2025-10-26 00:23:30.038945+00	2025-10-26 00:23:46.921428+00	\N	0	1	0	0	2025-10-26 00:19:01.955892+00	2025-10-26 00:23:46.917184+00	\N	{}	\N
f6723229-7b79-4fe3-bb94-42f4b5f18369	86f9a16f-7896-4115-b321-adf9db382682	27850871-1cd4-4804-9c1d-6cf8fb90fbd2	comprehensive	completed	2025-10-26 00:44:43.209179+00	2025-10-26 00:44:57.029847+00	\N	0	1	0	0	2025-10-26 00:40:01.003905+00	2025-10-26 00:44:57.025735+00	\N	{}	\N
fe4d7fb8-f706-4522-87dd-e400a783ab58	70b27594-33ef-4d19-b443-1906060c5cc6	fd01ee0b-02c6-48c3-8d2e-fa150a152d2e	full	completed	2025-10-27 21:34:06.739694+00	2025-10-27 21:34:10.739512+00	\N	1	1	2	3	2025-10-27 21:34:04.926136+00	2025-10-27 21:34:10.729038+00	\N	{}	\N
9263afbb-6723-4249-a3c0-b59bab200f43	c065cb49-0a9e-465c-9944-2ba193513c97	ab45210a-44a1-490e-bd5f-18135cdc3c91	full	completed	2025-10-28 03:54:41.825601+00	2025-10-28 03:55:15.052164+00	\N	0	0	1	2	2025-10-28 03:54:40.834779+00	2025-10-28 03:55:14.951693+00	\N	{}	\N
4986c18e-7693-49b2-bb12-e2e1ab8c0df8	c065cb49-0a9e-465c-9944-2ba193513c97	ab45210a-44a1-490e-bd5f-18135cdc3c91	full	completed	2025-10-28 04:21:35.771765+00	2025-10-28 04:21:42.127607+00	\N	0	0	1	2	2025-10-28 04:21:35.242605+00	2025-10-28 04:21:42.123178+00	\N	{}	\N
\.


--
-- Data for Name: sessions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.sessions (id, user_id, token, refresh_token, expires_at, created_at, is_revoked) FROM stdin;
72f41138-aecf-4ff4-bab4-491597e3d17b	ab45210a-44a1-490e-bd5f-18135cdc3c91	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjA2NjIxMzcsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJhY2Nlc3MifQ.SQSB5sUDM4ScfS4YVPly8hR8RLI3PJR1z_hh0qO8B0Y	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjEyNTYxMzcsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJyZWZyZXNoIn0.PF6L2z5XwEGf0rFBoyP5YWm-JkqsyLV6hk_X8xXxLoc	2025-10-23 21:48:57.353249+00	2025-10-16 21:48:57.229258+00	f
29d9bdb6-93f8-4f4c-a7ea-34222c880d2a	ab45210a-44a1-490e-bd5f-18135cdc3c91	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjA2NjIxNzEsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJhY2Nlc3MifQ.3pFOFpuHw6jdkoS_SqScz1DsjeLnyBOqSRT9K6xK8LA	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjEyNTYxNzEsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJyZWZyZXNoIn0.4_0s_YdfG3JIIptW0ocAXW9fdrRJ2NS2VqkwwLh8WAw	2025-10-23 21:49:31.497391+00	2025-10-16 21:49:31.407814+00	f
1adff8f2-c653-4116-912e-d234abc78866	ab45210a-44a1-490e-bd5f-18135cdc3c91	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjA2NjI2MjcsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJhY2Nlc3MifQ.7pmQwO9jVnXrswsydqe4hGVHkfKh9BIuEGGg57inVVs	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjEyNTY2MjcsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJyZWZyZXNoIn0.hMrZeE4S-5QdC9Dbk1MPV4qFDA3iBaVAOiDYwiJQ8Ew	2025-10-23 21:57:07.33299+00	2025-10-16 21:57:07.296584+00	f
48c6442b-7f28-404c-a3a4-d1cd9df47014	ab45210a-44a1-490e-bd5f-18135cdc3c91	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjA2Njg0MTAsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJhY2Nlc3MifQ.w16YmQuHFrf4lt6izKB0I6BYhZOhQ8_qpJwZyLaaLFE	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjEyNjI0MTAsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJyZWZyZXNoIn0.h6-XKd_GSp0Tow_6K8s0Ss4OkkQOdqF05TnmKhxkSUw	2025-10-23 23:33:30.633071+00	2025-10-16 23:33:30.450018+00	f
36966a67-e055-40af-a642-c2bcecc6cf05	ab45210a-44a1-490e-bd5f-18135cdc3c91	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjA2NzA4MDUsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJhY2Nlc3MifQ.hsxp6cIqxiLRLbRp__V8D0tyvI1_ajxwROZcCu84T5Y	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjEyNjQ4MDUsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJyZWZyZXNoIn0.eaPfXB_HFY1O0SYoE5-3tyM9oP8Mbukm2JVEv0Jh2XA	2025-10-24 00:13:25.816421+00	2025-10-17 00:13:25.72136+00	f
a95a09fa-d152-4972-9e10-cde011c6b67d	ab45210a-44a1-490e-bd5f-18135cdc3c91	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjA2NzMzODcsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJhY2Nlc3MifQ.Qkka05VtRBThjQ2fBM93qNrvg2OeygoK0eN5wUvs8dc	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjEyNjczODcsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJyZWZyZXNoIn0.LvzHVix6MM1Ihzw5VLZbnS5gsw4pLS1X5ewc0VsXh_M	2025-10-24 00:56:27.556005+00	2025-10-17 00:56:27.457837+00	f
a93e2fc2-dd6e-440c-a0fc-c46f17f92460	ab45210a-44a1-490e-bd5f-18135cdc3c91	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjA2NzMzOTYsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJhY2Nlc3MifQ.fMQ3BRVkBNWV2YmGxfJylKJ1HzWR5J9_w39IumlN7nc	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjEyNjczOTYsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJyZWZyZXNoIn0.Dx1Q_9Ent8jusEKSi2VGWD9GuFzBYs5mIiP_0lTyDRc	2025-10-24 00:56:36.561823+00	2025-10-17 00:56:36.525821+00	f
48f285fc-e873-4aa2-9c8d-a8020b19956c	ab45210a-44a1-490e-bd5f-18135cdc3c91	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjA2NzYyNTIsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJhY2Nlc3MifQ.zUuhKJcTzr1NqClBHaIL8Z0XiQtKSq4Hwss7xIyu3pU	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjEyNzAyNTIsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJyZWZyZXNoIn0.VmhoVonADHQTtDqP1EiG8p9IVZqX6Ik84vhtK-XQWjQ	2025-10-24 01:44:12.339018+00	2025-10-17 01:44:12.291875+00	f
c37d4d9a-8ead-4bb6-946f-e91243948ad9	ab45210a-44a1-490e-bd5f-18135cdc3c91	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjA2NzY5MzQsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJhY2Nlc3MifQ.zMhg0o4tTaZ00tdOxEoJ7RmfQL7FylWCva1mIMfVbrg	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjEyNzA5MzQsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJyZWZyZXNoIn0._HyljtzvPRHQZgeiwuwT1DMo__Js92IhQ0x6nBBIe6U	2025-10-24 01:55:34.960109+00	2025-10-17 01:55:34.660605+00	f
d92b1925-62ed-46b2-a723-7c3cc2497b03	27850871-1cd4-4804-9c1d-6cf8fb90fbd2	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjA3MjM0MDMsInN1YiI6IjI3ODUwODcxLTFjZDQtNDgwNC05YzFkLTZjZjhmYjkwZmJkMiIsInR5cGUiOiJhY2Nlc3MifQ.F5rPe5TXT5uTpPuut6ZbGyXGGRAWsqZ43aFyJqe3lWo	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjEzMTc0MDMsInN1YiI6IjI3ODUwODcxLTFjZDQtNDgwNC05YzFkLTZjZjhmYjkwZmJkMiIsInR5cGUiOiJyZWZyZXNoIn0.tveeL8qtdAmVPF1W-1ogtzAXVzgM24QpsrqW5-qhXTQ	2025-10-24 14:50:03.900627+00	2025-10-17 14:50:03.722194+00	f
59e90ab7-d852-4d43-bd13-0367cabda003	27850871-1cd4-4804-9c1d-6cf8fb90fbd2	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjA3MjM0MTAsInN1YiI6IjI3ODUwODcxLTFjZDQtNDgwNC05YzFkLTZjZjhmYjkwZmJkMiIsInR5cGUiOiJhY2Nlc3MifQ.x-DBASzO3-5fPFiMjCHGgoBGQHUrc1kv1Svwb82czTw	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjEzMTc0MTEsInN1YiI6IjI3ODUwODcxLTFjZDQtNDgwNC05YzFkLTZjZjhmYjkwZmJkMiIsInR5cGUiOiJyZWZyZXNoIn0.Jyzyl-gCq-Ct8p6FA1PCq3xTy2IOm8deOKc11PCUcXc	2025-10-24 14:50:11.069346+00	2025-10-17 14:50:10.873843+00	f
04fb83ff-d7e5-41bc-9e98-fd1f089f5248	27850871-1cd4-4804-9c1d-6cf8fb90fbd2	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjA3MjM0MTgsInN1YiI6IjI3ODUwODcxLTFjZDQtNDgwNC05YzFkLTZjZjhmYjkwZmJkMiIsInR5cGUiOiJhY2Nlc3MifQ.bETULvPZ1_A1AFaCm-WU7RlO5cDDmDA5QsoKSTv1g2o	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjEzMTc0MTgsInN1YiI6IjI3ODUwODcxLTFjZDQtNDgwNC05YzFkLTZjZjhmYjkwZmJkMiIsInR5cGUiOiJyZWZyZXNoIn0.9mGEdhp49ioe1xior0HMFQZrDIUgc9C5-BL2Soii2gY	2025-10-24 14:50:18.091112+00	2025-10-17 14:50:17.982241+00	f
351d108c-f392-4dc3-ab43-b357b4e77c35	ab45210a-44a1-490e-bd5f-18135cdc3c91	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjA3MzQzMTcsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJhY2Nlc3MifQ.RuQ-FZsRw65kvRdU5CLzOne8YeMI38_aQtnn_n8rIV8	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjEzMjgzMTcsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJyZWZyZXNoIn0.GqZWF8KitaFsK04pBdLJcgLOukhI4N6yOcr3uM9vPcs	2025-10-24 17:51:57.480432+00	2025-10-17 17:51:57.438259+00	f
1b218cd1-a6cb-448d-adcf-b40e06f44a18	56bc0604-49bc-4a73-8b4f-69fc3386a0f8	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjA3NDQ2NTksInN1YiI6IjU2YmMwNjA0LTQ5YmMtNGE3My04YjRmLTY5ZmMzMzg2YTBmOCIsInR5cGUiOiJhY2Nlc3MifQ.ezgJzuFCJAchumgK5NVNOY8ZsQvqu-RutzkQtSec4U8	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjEzMzg2NTksInN1YiI6IjU2YmMwNjA0LTQ5YmMtNGE3My04YjRmLTY5ZmMzMzg2YTBmOCIsInR5cGUiOiJyZWZyZXNoIn0._1vwq54rrppM8UM7sVgybGJTutrRBwds6e5bPM6I7XM	2025-10-24 20:44:19.339058+00	2025-10-17 20:44:19.232032+00	f
6e37da25-3d64-47d4-9386-09dcb6202179	ab45210a-44a1-490e-bd5f-18135cdc3c91	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjA3NTk3OTksInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJhY2Nlc3MifQ.qCPrMJ7cl77MzuEAkf0FCud0tVbRZb2ee2DhVqrLx60	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjEzNTM3OTksInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJyZWZyZXNoIn0.5GNMrshdTm85o4E1UK8Is8rpthl_ffyIoZUCq3dEEAk	2025-10-25 00:56:39.406211+00	2025-10-17 01:56:12.593743+00	f
678d4c53-58b1-4dc9-b393-efc164e4ac75	56bc0604-49bc-4a73-8b4f-69fc3386a0f8	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjA3NDQ2NjYsInN1YiI6IjU2YmMwNjA0LTQ5YmMtNGE3My04YjRmLTY5ZmMzMzg2YTBmOCIsInR5cGUiOiJhY2Nlc3MifQ.9gkmJMTQnnnp8yFjRB8ZjveuPFu96fWQQIAZ4RGRTlU	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjEzMzg2NjYsInN1YiI6IjU2YmMwNjA0LTQ5YmMtNGE3My04YjRmLTY5ZmMzMzg2YTBmOCIsInR5cGUiOiJyZWZyZXNoIn0.RdHHo2HqKxnbMmPwQBEFIjxPP-sz_2VChQgcAOE8rxc	2025-10-24 20:44:26.793551+00	2025-10-17 20:44:26.750765+00	f
9fa28072-62a1-4f22-9ea4-da46eb5bf674	56bc0604-49bc-4a73-8b4f-69fc3386a0f8	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjA3NDUwNDksInN1YiI6IjU2YmMwNjA0LTQ5YmMtNGE3My04YjRmLTY5ZmMzMzg2YTBmOCIsInR5cGUiOiJhY2Nlc3MifQ.I-yMr4VptdOm6rxVpZFx1lU12RHCy_lk3o1JG5Appyg	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjEzMzkwNDksInN1YiI6IjU2YmMwNjA0LTQ5YmMtNGE3My04YjRmLTY5ZmMzMzg2YTBmOCIsInR5cGUiOiJyZWZyZXNoIn0.zSWyrkVcqT4q2AVDw-gxzhmk9Gjj_JKCbTYcjdKmSYA	2025-10-24 20:50:49.7321+00	2025-10-17 20:50:49.688881+00	f
d9dda68d-7e1a-4235-acfe-cc2f4ad6e3f7	56bc0604-49bc-4a73-8b4f-69fc3386a0f8	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjA3NDUxNDgsInN1YiI6IjU2YmMwNjA0LTQ5YmMtNGE3My04YjRmLTY5ZmMzMzg2YTBmOCIsInR5cGUiOiJhY2Nlc3MifQ.1M0Y3h2x8rGjajmQDj8ON2n_5Iz0Xg-OOm477HN3PeE	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjEzMzkxNDgsInN1YiI6IjU2YmMwNjA0LTQ5YmMtNGE3My04YjRmLTY5ZmMzMzg2YTBmOCIsInR5cGUiOiJyZWZyZXNoIn0.8F6sjICVW9Dp-IQc_ncat98vjlgHDZXJXfqON086Lxc	2025-10-24 20:52:28.366319+00	2025-10-17 20:52:28.331369+00	f
1b487bc2-f035-4de8-9663-f7f306d17af9	56bc0604-49bc-4a73-8b4f-69fc3386a0f8	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjA3NzEyMjAsInN1YiI6IjU2YmMwNjA0LTQ5YmMtNGE3My04YjRmLTY5ZmMzMzg2YTBmOCIsInR5cGUiOiJhY2Nlc3MifQ.Fmai1G7Wk0pGRq0lukGR0ivN-kK_SAVQ7LLPtmC0U48	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjEzNjUyMjAsInN1YiI6IjU2YmMwNjA0LTQ5YmMtNGE3My04YjRmLTY5ZmMzMzg2YTBmOCIsInR5cGUiOiJyZWZyZXNoIn0.vJHi3uT3WE81zx6oFh7wdm6M5G0x6IX37XQiRPEthxs	2025-10-25 04:07:00.778626+00	2025-10-17 21:13:28.215771+00	f
c7791230-b8a7-44b5-88ce-6ac9f361030b	4868936c-4b8c-4233-b4ac-175363f232bd	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjA3NzkzMTgsInN1YiI6IjQ4Njg5MzZjLTRiOGMtNDIzMy1iNGFjLTE3NTM2M2YyMzJiZCIsInR5cGUiOiJhY2Nlc3MifQ.qnGWwGxkMFj2RrBXaEX7uOuHRJr4ZiaYIz03U8Tly4w	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjEzNzMzMTgsInN1YiI6IjQ4Njg5MzZjLTRiOGMtNDIzMy1iNGFjLTE3NTM2M2YyMzJiZCIsInR5cGUiOiJyZWZyZXNoIn0.u4JTxG29xJ9uNTdEnWsIkk5v9s7E346jALtS2ku9PBU	2025-10-25 06:21:58.615194+00	2025-10-18 06:21:58.544933+00	f
48ae0ae6-3303-49d1-8824-0e61fc936606	63af5224-5fd9-4353-a54a-4eff7e7aa249	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjA3NzkzNjMsInN1YiI6IjYzYWY1MjI0LTVmZDktNDM1My1hNTRhLTRlZmY3ZTdhYTI0OSIsInR5cGUiOiJhY2Nlc3MifQ.Es9P4y6pmPs_gZKdr0_495wP_PyJHVPGJn4CKFMv558	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjEzNzMzNjMsInN1YiI6IjYzYWY1MjI0LTVmZDktNDM1My1hNTRhLTRlZmY3ZTdhYTI0OSIsInR5cGUiOiJyZWZyZXNoIn0.PxcITHee705AYyidMtr5pwP6tlxZbUkv8oa63qsgfVs	2025-10-25 06:22:43.760678+00	2025-10-18 06:22:43.676397+00	f
6dc47535-8a84-4c8f-b4a8-2e0e4b89980a	63af5224-5fd9-4353-a54a-4eff7e7aa249	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjA3NzkzNzAsInN1YiI6IjYzYWY1MjI0LTVmZDktNDM1My1hNTRhLTRlZmY3ZTdhYTI0OSIsInR5cGUiOiJhY2Nlc3MifQ.BJFMMUzyTS0P0MkslwN_g4Lta7Didnql4p5_g__hdOg	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjEzNzMzNzAsInN1YiI6IjYzYWY1MjI0LTVmZDktNDM1My1hNTRhLTRlZmY3ZTdhYTI0OSIsInR5cGUiOiJyZWZyZXNoIn0.18CL-R9Ey-Px4J_X_bTkC1QKnD2EVbyHomtlhBE5BJw	2025-10-25 06:22:50.087976+00	2025-10-18 06:22:50.048517+00	f
3b8e531b-7ccc-4cdc-9ea7-87f801b7ce17	63af5224-5fd9-4353-a54a-4eff7e7aa249	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjA3NzkzNzksInN1YiI6IjYzYWY1MjI0LTVmZDktNDM1My1hNTRhLTRlZmY3ZTdhYTI0OSIsInR5cGUiOiJhY2Nlc3MifQ.2d0Ul53n1FrVgRxOL4vthKBHjj5jMPgusczK_Z0TYTM	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjEzNzMzNzksInN1YiI6IjYzYWY1MjI0LTVmZDktNDM1My1hNTRhLTRlZmY3ZTdhYTI0OSIsInR5cGUiOiJyZWZyZXNoIn0.w6PliVKYOERZ-6SxECd5x-ORO7dRnKC1Smgv1yy6zwc	2025-10-25 06:22:59.429224+00	2025-10-18 06:22:59.387133+00	f
5fa84873-bb7c-4954-bff0-e02bea9e5b57	ab45210a-44a1-490e-bd5f-18135cdc3c91	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjA4MDE3MzUsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJhY2Nlc3MifQ.TY91ZSTTdkwVXNoNxhEHi5I4OF50d9f4_iHLoKdciKg	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjEzOTU3MzUsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJyZWZyZXNoIn0.tq0oTd8UWubBR0ha8y0FVNcFWIgazlZR5oItjdHVfHg	2025-10-25 12:35:35.330646+00	2025-10-18 05:39:05.159089+00	f
8f243026-dd21-4a37-ba7a-64f64030932a	ab45210a-44a1-490e-bd5f-18135cdc3c91	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjA4MTIyMjksInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJhY2Nlc3MifQ.U_N1su3A9DR4Kh89h_FRTXGexsyeUXI8rWH0Q3b4uxA	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjE0MDYyMjksInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJyZWZyZXNoIn0.7q45TA2M_7b0hhviN4AuHREJOndF9GFBsncejQ-ptYE	2025-10-25 15:30:29.927613+00	2025-10-18 15:30:29.885966+00	f
c1116b07-c5ad-474a-a2af-19bdd03faec9	ab45210a-44a1-490e-bd5f-18135cdc3c91	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjA4MjcwOTAsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJhY2Nlc3MifQ.SBAk6G69winJeBsO4_q9S6cHs8c8BnK7HU75u4PBGGk	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjE0MjEwOTAsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJyZWZyZXNoIn0.BNFiPnmUg1nJ8GU9AwyZZPLkSnm5zu1LOqA2VZbNrrY	2025-10-25 19:38:10.725611+00	2025-10-18 16:36:49.956909+00	f
6957b12f-4c02-4b14-8b60-cd693ec4c582	ab45210a-44a1-490e-bd5f-18135cdc3c91	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjA4Mjc3MjEsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJhY2Nlc3MifQ.eMGAMqhqiAg8d1shJZ-e8c-dD5eMI6FPFOANTird6vI	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjE0MjE3MjEsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJyZWZyZXNoIn0.HMtseFIQWSARb-nUqxqgARYPjQ6ceMMtTsxyB_ZKmbY	2025-10-25 19:48:41.353151+00	2025-10-18 19:38:13.068432+00	f
8f334e61-3ea8-49b1-ae46-28f8847904f2	ab45210a-44a1-490e-bd5f-18135cdc3c91	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjA4Njg0MjIsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJhY2Nlc3MifQ.TC1zwFDaRpUNEW-ZGC0O7wHRBblqc2C9vqPcOus9-Wk	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjE0NjI0MjIsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJyZWZyZXNoIn0.ED8l1ewGWPyYuNg7hOJZnQLHy22Ln_HSBpuoP83T4Yw	2025-10-26 07:07:02.534029+00	2025-10-18 19:48:47.199843+00	f
a1a8a984-06da-4206-b013-be3e24214165	ab45210a-44a1-490e-bd5f-18135cdc3c91	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjA5MDAzNDksInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJhY2Nlc3MifQ.epn4vg1m0hB6jmxWBmT0Y5eh1ULhaOnCYMlXNdTsDPc	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjE0OTQzNDksInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJyZWZyZXNoIn0.jp_2vXJqal8_3mga8cODTXuTBq6iMl0CykCkGh0Q9z4	2025-10-26 15:59:09.477226+00	2025-10-19 15:59:09.17911+00	f
61373c17-957a-4492-9047-2f3ebefc1e68	ab45210a-44a1-490e-bd5f-18135cdc3c91	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjEyMzk4NDAsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJhY2Nlc3MifQ.YjA4d_pBaBE1yZz05PDGmHhzo7cK2f4qoP-husUDy6Q	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjE4MzM4NDEsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJyZWZyZXNoIn0.23dYzXTGHJw2avAHzTZozXreuovo-8__ZUk7DRHAiRQ	2025-10-30 14:17:21.02216+00	2025-10-23 14:17:20.038621+00	f
c0af6384-41c9-4330-9b51-93dfd12ca7c6	ab45210a-44a1-490e-bd5f-18135cdc3c91	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjEyNDA3MjIsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJhY2Nlc3MifQ.0EQtM8LM18lpedJ1UrZgjqS_pqFvQFtdlx3cGrcbbyI	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjE4MzQ3MjIsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJyZWZyZXNoIn0.4zTA6j7gQZ_jHH-E8m4QOWIa2rPnSAkCBFNnlzRWBCo	2025-10-30 14:32:02.569243+00	2025-10-23 14:32:01.966904+00	f
da9a2891-2d4d-4294-8b9c-758648a26d22	ab45210a-44a1-490e-bd5f-18135cdc3c91	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjEyNDEzNzEsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJhY2Nlc3MifQ.yjylkwXMk-oQwgr0CaOpHbDwDr8LSK73caGF_Od9Jt4	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjE4MzUzNzEsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJyZWZyZXNoIn0.mJvrrlxFyyXCvRI1omQ7sRsqM22S8M6N-Chg8DBhupE	2025-10-30 14:42:51.166002+00	2025-10-23 14:42:49.594683+00	f
edb7a795-365f-43e1-8284-892086705c14	ab45210a-44a1-490e-bd5f-18135cdc3c91	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjEyNDc0OTEsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJhY2Nlc3MifQ.4N0iRzXMd0ZIyDNzpA1vStwZWbz-YEwTXBPTm2Lu2U8	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjE4NDE0OTEsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJyZWZyZXNoIn0.eJFU_DsCTKEAZs1M7MbVL770jGKX7b_R04wQ2sm0vNQ	2025-10-30 16:24:51.663073+00	2025-10-23 16:24:50.99376+00	f
5f637bbc-776e-4de9-a40f-ddf5cba8a451	9bf04466-2628-425e-9ccb-617287260383	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjE0NDIwNjQsInN1YiI6IjliZjA0NDY2LTI2MjgtNDI1ZS05Y2NiLTYxNzI4NzI2MDM4MyIsInR5cGUiOiJhY2Nlc3MifQ.PNBB_bHK-NoqCYa0eF3lUiHkvh4Hgg4N4hUViG11t9g	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjIwMzYwNjUsInN1YiI6IjliZjA0NDY2LTI2MjgtNDI1ZS05Y2NiLTYxNzI4NzI2MDM4MyIsInR5cGUiOiJyZWZyZXNoIn0.rUfOgZgoZ2K_ut6D4XdsNyQnbrpevLUUtdMTUC1Zj4g	2025-11-01 22:27:45.405785+00	2025-10-25 22:27:44.157094+00	f
a630a279-eb07-48f5-912d-a4c07a026422	9bf04466-2628-425e-9ccb-617287260383	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjE0NDIxMDQsInN1YiI6IjliZjA0NDY2LTI2MjgtNDI1ZS05Y2NiLTYxNzI4NzI2MDM4MyIsInR5cGUiOiJhY2Nlc3MifQ.GKr8g0kWL_70WAi2U_YiGD5TmEMPkr4UXkUHUMDITmQ	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjIwMzYxMDQsInN1YiI6IjliZjA0NDY2LTI2MjgtNDI1ZS05Y2NiLTYxNzI4NzI2MDM4MyIsInR5cGUiOiJyZWZyZXNoIn0.w0UVeWYjYU4OufJbqRydojxfygoOAkq2-p142Ndrqkc	2025-11-01 22:28:24.185852+00	2025-10-25 22:28:23.685285+00	f
6299ca7c-8139-4b6a-b3da-e5ae54d4dcba	9bf04466-2628-425e-9ccb-617287260383	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjE0NDIxMTEsInN1YiI6IjliZjA0NDY2LTI2MjgtNDI1ZS05Y2NiLTYxNzI4NzI2MDM4MyIsInR5cGUiOiJhY2Nlc3MifQ.-FVSLc1yrGtWSHK7hFle0cFUQQ66sGrQIEVye28FVxU	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjIwMzYxMTEsInN1YiI6IjliZjA0NDY2LTI2MjgtNDI1ZS05Y2NiLTYxNzI4NzI2MDM4MyIsInR5cGUiOiJyZWZyZXNoIn0.OsiGYuXeEoJPxHplFnlleYtsHCt44O6UIIFHBSMsUFg	2025-11-01 22:28:31.3177+00	2025-10-25 22:28:31.277336+00	f
c5b45ee1-de3b-4b05-ab74-0ee9c91ee7f5	fd01ee0b-02c6-48c3-8d2e-fa150a152d2e	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjE2MTE2MTYsInN1YiI6ImZkMDFlZTBiLTAyYzYtNDhjMy04ZDJlLWZhMTUwYTE1MmQyZSIsInR5cGUiOiJhY2Nlc3MifQ.lgL764xygWVsvf6GH7S46NJfuxRbp5efgnScuaHKtbI	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjIyMDU2MTYsInN1YiI6ImZkMDFlZTBiLTAyYzYtNDhjMy04ZDJlLWZhMTUwYTE1MmQyZSIsInR5cGUiOiJyZWZyZXNoIn0.dEjvlwqyeRIR7S8hK-HX8EKKFJiqrLPeo5RtKXqEAH8	2025-11-03 21:33:36.585459+00	2025-10-27 21:33:36.540314+00	f
d7c5fb52-eb62-4b76-a084-400c73174518	fd01ee0b-02c6-48c3-8d2e-fa150a152d2e	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjE2MTE2MTEsInN1YiI6ImZkMDFlZTBiLTAyYzYtNDhjMy04ZDJlLWZhMTUwYTE1MmQyZSIsInR5cGUiOiJhY2Nlc3MifQ.YnYioqsXrULh-CNLmX5xxMDB4BEgf9DFO3l1Rnru4GM	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjIyMDU2MTEsInN1YiI6ImZkMDFlZTBiLTAyYzYtNDhjMy04ZDJlLWZhMTUwYTE1MmQyZSIsInR5cGUiOiJyZWZyZXNoIn0.p4D-UhdDqbX5BDOliRCJx_zMeMEN7i36IdEsX5ZtaHs	2025-11-03 21:33:31.355934+00	2025-10-27 21:33:30.838002+00	f
25d01daf-c639-4529-8857-a0316a1f5c98	ab45210a-44a1-490e-bd5f-18135cdc3c91	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjE2MjMzNzcsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJhY2Nlc3MifQ.iDvCuZ0LKD61ofuUJLYJ81AINi0KTsS06lbcWyJvtZM	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjIyMTczNzcsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJyZWZyZXNoIn0.CVmlCtME3B-dgQai3WCLTxFLCTiXUWk0sjeN9EYxoG4	2025-11-04 00:49:37.020479+00	2025-10-27 21:46:04.314275+00	f
a4083feb-65f9-4b0a-89bc-4b7cccd2b7d4	ab45210a-44a1-490e-bd5f-18135cdc3c91	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjE2MzQzMjcsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJhY2Nlc3MifQ.jWvJ8Ib3XOIDboHNo2Nk2wzUqY5eBvyG1FzPpCH8t4M	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjIyMjgzMjcsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJyZWZyZXNoIn0.mH055EoQv3MwX6a0-0807bJcPAyazqUr-kxfYPJK-us	2025-11-04 03:52:07.50837+00	2025-10-28 03:52:06.469483+00	f
28ec6f0b-6b03-4165-9618-8b0943365733	ab45210a-44a1-490e-bd5f-18135cdc3c91	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjE2NzI5NDUsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJhY2Nlc3MifQ.tc6xWRMFXPG2gwDnetXfSntxeSqfbZst5842_dYGZyI	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjIyNjY5NDUsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJyZWZyZXNoIn0.3aWFYk2DCq_c4ndker7mdzXiK6jTxidl2PIVfuTj0Ks	2025-11-04 14:35:45.60379+00	2025-10-28 14:35:44.637565+00	f
53c09663-bc4c-45c4-a573-e33a4056958b	ab45210a-44a1-490e-bd5f-18135cdc3c91	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjE4MTIxMzEsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJhY2Nlc3MifQ.icKs-LTvwvFUegAOeEr4gCMjwLpd_jPARaAKqkL9N3I	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjI0MDYxMzEsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJyZWZyZXNoIn0.GDoMKdI4P1OO9ltknycDiTV3x2TJwyQFEhhMXhIWilc	2025-11-06 05:15:31.504158+00	2025-10-30 05:15:30.099087+00	f
402aed97-9967-4601-98b1-44880bc2e3de	ab45210a-44a1-490e-bd5f-18135cdc3c91	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjIwMzI0NzIsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJhY2Nlc3MifQ.eSY4zuU0_yx9DA_XBRZ7uSjYLLTnKSgyw1H6IL92Ink	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjI2MjY0NzIsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJyZWZyZXNoIn0.9pRwAvVd9sSnYY4R3lqZ8n_EpZS_L6Tfa1lQ6UODWIk	2025-11-08 18:27:52.985915+00	2025-11-01 00:23:42.424274+00	f
e61c4ebd-e654-4b25-997d-adb8aabfc321	ab45210a-44a1-490e-bd5f-18135cdc3c91	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjIxMDY4NTQsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJhY2Nlc3MifQ.XsdrILGPFV8BAFnOyxXB0w7rjvYPLi7xyk-Cwthj26A	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjI3MDA4NTQsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJyZWZyZXNoIn0.a_BZMUzA23EgDseNChSfQkn_S1Bhfs3AqkkZVnEMc58	2025-11-09 15:07:34.766138+00	2025-11-02 15:07:34.258025+00	f
9f77c5f2-9e3e-430e-9d50-f0dfe84de44d	ab45210a-44a1-490e-bd5f-18135cdc3c91	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjIxMDY4OTIsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJhY2Nlc3MifQ.MZ_baF81Hq0_WdRVQbYMQxwZOUfcY9EjT78Y9bs11A0	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjI3MDA4OTIsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJyZWZyZXNoIn0.Q4DfQa-1qRfYj8XXZ_yvvsorVIpFoTOmY8RChyB5-Js	2025-11-09 15:08:12.464822+00	2025-11-02 15:08:11.896024+00	f
310c13c2-912e-4855-b455-ac661dc38961	ab45210a-44a1-490e-bd5f-18135cdc3c91	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjIxMTg4ODgsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJhY2Nlc3MifQ.JyciaDRjTm5cXlUskDbea4fZ-ePCdbSpRlzCPuEBO88	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjI3MTI4ODgsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJyZWZyZXNoIn0.A3oTtnJmHmQX2QRR5b4_P27-JHKJbuKpfpni9bhGbJw	2025-11-09 18:28:08.952002+00	2025-11-02 14:51:25.183648+00	f
f1a512e7-3d90-4bbd-bdc5-e577430bb594	ab45210a-44a1-490e-bd5f-18135cdc3c91	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjIxMTkzNTQsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJhY2Nlc3MifQ.V0dljONMN4Js8PWQ4m1Ob128UY1sR5p4AbX6pyiyLdM	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjI3MTMzNTQsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJyZWZyZXNoIn0.L0VnYW9gj7iLpISHaPQI1EQhMy2xQT8WdwHBa1SKQlo	2025-11-09 18:35:54.623452+00	2025-11-02 18:35:54.13786+00	f
00c1dec0-b127-40ba-a2c9-6b70717683ba	ab45210a-44a1-490e-bd5f-18135cdc3c91	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjIxMTk3NTgsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJhY2Nlc3MifQ.mWZG0xnCkJLgAZD2aVOyIm6M0QbRIxgVP4JFhHB5rb0	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjI3MTM3NTgsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJyZWZyZXNoIn0.I8EuAjjWFncJ3bHJhlHoFkyzJtI42wsNFCU0Q5of5aA	2025-11-09 18:42:38.923942+00	2025-11-02 18:42:38.413753+00	f
6fc6484f-bf85-4bbf-8550-d2159d02b2b3	594f18c9-3605-4068-9e04-f614b9dd0efa	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjIxMjE5NjMsInN1YiI6IjU5NGYxOGM5LTM2MDUtNDA2OC05ZTA0LWY2MTRiOWRkMGVmYSIsInR5cGUiOiJhY2Nlc3MifQ.A9u4AGbpYznaC5GoYigHGbi3iIWQtSlXnm0-JSShvXE	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjI3MTU5NjMsInN1YiI6IjU5NGYxOGM5LTM2MDUtNDA2OC05ZTA0LWY2MTRiOWRkMGVmYSIsInR5cGUiOiJyZWZyZXNoIn0.xlpIMAsbM1HJ8r6SKO5P9FgBfxDsmikUbG9rdq8rL64	2025-11-09 19:19:23.781082+00	2025-11-02 19:19:23.691114+00	f
c6de96e8-512e-4399-987d-026dabf09de4	ab45210a-44a1-490e-bd5f-18135cdc3c91	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjIxMjM2MTMsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJhY2Nlc3MifQ._sL1lEqI20hTjz7pyQ2-GUgw3ZC0fLC8sg56MjjqKOk	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NjI3MTc2MTMsInN1YiI6ImFiNDUyMTBhLTQ0YTEtNDkwZS1iZDVmLTE4MTM1Y2RjM2M5MSIsInR5cGUiOiJyZWZyZXNoIn0.U_iRhKt_QUMEuyUZGb-8Qzwj4CqrtzeCEcYJgDYyT0E	2025-11-09 19:46:53.79698+00	2025-11-02 19:46:53.282257+00	f
\.


--
-- Data for Name: user_preferences; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_preferences (user_id, email_notifications, scan_completion_notifications, critical_vulnerability_alerts, weekly_digest, theme, timezone, language, preferences, created_at, updated_at) FROM stdin;
63af5224-5fd9-4353-a54a-4eff7e7aa249	f	t	t	f	dark	America/New_York	en	{}	2025-10-18 06:22:59.499499+00	2025-10-18 06:23:07.72718+00
ab45210a-44a1-490e-bd5f-18135cdc3c91	t	t	t	f	light	America/Denver	en	{}	2025-10-18 22:34:09.263332+00	2025-10-18 22:34:51.882869+00
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, email, hashed_password, is_active, is_superuser, created_at, updated_at) FROM stdin;
27850871-1cd4-4804-9c1d-6cf8fb90fbd2	pdf-test@example.com	$argon2id$v=19$m=19456,t=2,p=1$tQ31cEsbrSUr+sakt3sVcw$BfM5icymMA1TCsPXDj9YA1pUrAKHcEm3rEtZdLE1BgE	t	f	2025-10-17 14:50:03.722194+00	2025-10-17 14:50:03.722194+00
56bc0604-49bc-4a73-8b4f-69fc3386a0f8	admin@blocksecops.com	$argon2id$v=19$m=19456,t=2,p=1$D/LW7GwVqYPpkAgmeA8Rug$cEyqRknTwLa1FsX2A0DDLFnnpU4pJIqkLIbrY6YRQPU	t	f	2025-10-17 20:44:19.232032+00	2025-10-17 20:44:19.232032+00
4868936c-4b8c-4233-b4ac-175363f232bd	testuser@example.com	$argon2id$v=19$m=19456,t=2,p=1$sHGFP1cRU82wG7k6WkdLzQ$Y5GTpeAsL4NFMTiXih8ZSI3SLIe3ZzSFky4bZSbHQzk	t	f	2025-10-18 06:21:58.544933+00	2025-10-18 06:21:58.544933+00
63af5224-5fd9-4353-a54a-4eff7e7aa249	test2@example.com	$argon2id$v=19$m=19456,t=2,p=1$2czMsiP6G93cPifXSqrgkQ$gtm0b490ZNK0ap/DfXRFxif0CwbVBnOn6adogl0eTR8	t	f	2025-10-18 06:22:43.676397+00	2025-10-18 06:22:43.676397+00
ab45210a-44a1-490e-bd5f-18135cdc3c91	test-rebrand@blocksecops.com	$argon2id$v=19$m=65536,t=3,p=4$MOAP+cV+ogkm03GbuNY9zA$Znp+f/QGPDWGDTCPMN9mhNNy0Cqnt/BA6PJsiihRWTU	t	f	2025-10-16 21:48:57.229258+00	2025-10-16 21:48:57.229258+00
9bf04466-2628-425e-9ccb-617287260383	test@blocksecops.com	$argon2id$v=19$m=19456,t=2,p=1$qyv5fwNVZ/b2XJ3dGckaMg$+zEIx59hBRBz7lp98BThsCx52Ev1zWKlo/CGBzYTvac	t	f	2025-10-25 22:27:44.157094+00	2025-10-25 22:27:44.157094+00
fd01ee0b-02c6-48c3-8d2e-fa150a152d2e	test-pipeline@example.com	$argon2id$v=19$m=19456,t=2,p=1$whlP+j2nyiZxgJNEebIcLg$OGfGSzWcqmRgnLyIzbcdPOfNqADDWks3QHdqq8kAwxM	t	f	2025-10-27 21:33:30.838002+00	2025-10-27 21:33:30.838002+00
594f18c9-3605-4068-9e04-f614b9dd0efa	test@example.com	$argon2id$v=19$m=19456,t=2,p=1$HWLvcFLdnwgCrXZrNMtXBw$H9zXGf9GxaH0QCzXmQ66UGYNLaVGlOX60gNHz17fTTs	t	f	2025-11-02 19:19:23.691114+00	2025-11-02 19:19:23.691114+00
\.


--
-- Data for Name: vulnerabilities; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.vulnerabilities (id, scan_id, contract_id, title, description, severity, status, swc_id, line_number, code_snippet, recommendation, detected_at, updated_at, category, confidence, pattern_id, classification_confidence, classification_method, fingerprint_code, fingerprint_ast, fingerprint_location, fingerprint_semantic, fingerprint_composite, deduplication_group_id, is_primary, duplicate_count, deduplication_strategy, similarity_score, false_positive_score, false_positive_reasons, scanner_confidence, tool_consensus_score, first_seen, last_seen, occurrence_count, was_fixed, reintroduced, user_classification, user_feedback, fix_verified, fix_verified_at, fix_verified_by, scanner_id, detector_id, raw_output, normalization_version, file_path, function_name, contract_name, fingerprint_location_fuzzy, pattern_code) FROM stdin;
b06ae689-bbe6-4609-a28d-8de5fcc4e7b5	5461ec78-43f7-4a30-86cf-f120b6473196	86f9a16f-7896-4115-b321-adf9db382682	Reentrancy Eth	Reentrancy in VulnerableBank.withdraw() (ReEntrancy Contract.sol#19-29):\n\tExternal calls:\n\t- (success,None) = msg.sender.call{value: amount}() (ReEntrancy Contract.sol#24)\n\tState variables written after the call(s):\n\t- balances[msg.sender] = 0 (ReEntrancy Contract.sol#28)\n\tVulnerableBank.balances (ReEntrancy Contract.sol#12) can be used in cross function reentrancies:\n\t- VulnerableBank.balances (ReEntrancy Contract.sol#12)\n\t- VulnerableBank.deposit() (ReEntrancy Contract.sol#14-16)\n\t- VulnerableBank.withdraw() (ReEntrancy Contract.sol#19-29)\n	high	open	reentrancy-eth	19	    // VULNERABLE: State update happens after external call\n    function withdraw() public {\n        uint256 amount = balances[msg.sender];\n        require(amount > 0, "Insufficient balance");	Use the Checks-Effects-Interactions pattern. Move external calls to the end of the function after all state changes.	2025-10-16 22:16:09.78698+00	2025-10-16 22:15:59.040916+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
4378478f-64c6-4c37-ab40-614ed24c5dba	5461ec78-43f7-4a30-86cf-f120b6473196	86f9a16f-7896-4115-b321-adf9db382682	Immutable States	ReentrancyAttacker.vulnerableBank (ReEntrancy Contract.sol#41) should be immutable \n	low	open	immutable-states	41	contract ReentrancyAttacker {\n    VulnerableBank public vulnerableBank;\n    uint256 public attackCount;\n	Review the code and consult Slither documentation for specific recommendations.	2025-10-16 22:16:09.787161+00	2025-10-16 22:15:59.040916+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
ca76ae11-453c-4b67-ba2e-ab364e6629a1	50226168-4bd5-460e-8976-0dd50d6e7016	98593981-74f4-43f4-b7f6-3d795f4a488c	Weak Pseudo-Random Number Generator	VulnerableLottery.drawWinner() (contract.sol#29-40) uses a weak PRNG: "randomIndex = uint256(keccak256(bytes)(abi.encodePacked(block.timestamp,block.difficulty))) % players.length (contract.sol#34)"\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** weak-prng	critical	open	\N	29		Do not use block properties (timestamp, blockhash) for randomness. Use Chainlink VRF or similar oracle-based randomness solution.	2025-10-17 19:10:39.241762+00	2025-10-17 19:10:39.241762+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
9400d793-ee35-4744-9a19-185feaa96c2f	d27fe555-06b6-47b1-bf8f-d7b28b9a1779	0e2ea42e-a14d-446a-a193-04a3fbefbd6c	Mapping Deletion	VulnerableMapping.deleteUser() (contract.sol#166-170) deletes VulnerableMapping.User (contract.sol#150-153) which contains a mapping:\n\t-delete users[msg.sender] (contract.sol#169)\n\n**Impact:** Medium\n**Confidence:** High\n\n**Detector:** mapping-deletion	high	open	\N	166		\N	2025-10-17 22:27:30.237187+00	2025-10-17 22:27:30.237187+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
05a47790-8b91-4b49-8371-8d1db044e39b	d27fe555-06b6-47b1-bf8f-d7b28b9a1779	0e2ea42e-a14d-446a-a193-04a3fbefbd6c	Uninitialized Local	VulnerableStorage.addUser(address,uint256).newUser (contract.sol#35) is a local variable never initialized\n\n**Impact:** Medium\n**Confidence:** Medium\n\n**Detector:** uninitialized-local	high	open	\N	35		\N	2025-10-17 22:27:30.237187+00	2025-10-17 22:27:30.237187+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
919c2362-2369-4db4-beea-af4c9fdcc987	d27fe555-06b6-47b1-bf8f-d7b28b9a1779	0e2ea42e-a14d-446a-a193-04a3fbefbd6c	Uninitialized Local	StorageCollision.createTransaction(address,uint256).txn (contract.sol#138) is a local variable never initialized\n\n**Impact:** Medium\n**Confidence:** Medium\n\n**Detector:** uninitialized-local	high	open	\N	138		\N	2025-10-17 22:27:30.237187+00	2025-10-17 22:27:30.237187+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
bd32bea5-6939-4bc8-85aa-1a1065db3761	9d566dd4-a057-43b4-adc4-ed7051a4900b	86f9a16f-7896-4115-b321-adf9db382682	Reentrancy Eth	Reentrancy in VulnerableBank.withdraw() (ReEntrancy Contract.sol#19-29):\n\tExternal calls:\n\t- (success,None) = msg.sender.call{value: amount}() (ReEntrancy Contract.sol#24)\n\tState variables written after the call(s):\n\t- balances[msg.sender] = 0 (ReEntrancy Contract.sol#28)\n\tVulnerableBank.balances (ReEntrancy Contract.sol#12) can be used in cross function reentrancies:\n\t- VulnerableBank.balances (ReEntrancy Contract.sol#12)\n\t- VulnerableBank.deposit() (ReEntrancy Contract.sol#14-16)\n\t- VulnerableBank.withdraw() (ReEntrancy Contract.sol#19-29)\n	high	open	reentrancy-eth	19	    // VULNERABLE: State update happens after external call\n    function withdraw() public {\n        uint256 amount = balances[msg.sender];\n        require(amount > 0, "Insufficient balance");	Use the Checks-Effects-Interactions pattern. Move external calls to the end of the function after all state changes.	2025-10-16 22:16:33.343259+00	2025-10-16 22:16:27.023053+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
509b9c82-08c1-493f-beff-96eeb9a237a2	9d566dd4-a057-43b4-adc4-ed7051a4900b	86f9a16f-7896-4115-b321-adf9db382682	Immutable States	ReentrancyAttacker.vulnerableBank (ReEntrancy Contract.sol#41) should be immutable \n	low	open	immutable-states	41	contract ReentrancyAttacker {\n    VulnerableBank public vulnerableBank;\n    uint256 public attackCount;\n	Review the code and consult Slither documentation for specific recommendations.	2025-10-16 22:16:33.343661+00	2025-10-16 22:16:27.023053+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
354d21a6-a700-45c7-850e-1f07a9f7c5c7	31742a9d-5f1d-42a7-819a-c873870d252d	fc783138-6c5a-4dce-b469-9fdf46020f14	Msg Value Loop	VulnerableDistributor.distributeRewards() (contract.sol#42-54) use msg.value in a loop: reward = (msg.value * shares[shareholders[i_scope_0]]) / totalShares (contract.sol#51)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** msg-value-loop	critical	open	\N	42		\N	2025-10-17 01:05:29.925867+00	2025-10-17 01:05:29.925867+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
1bcd8121-6b29-47ae-a011-e13ae15262ba	ad9f0969-beda-485f-bbaa-6d854cbb86da	fc783138-6c5a-4dce-b469-9fdf46020f14	Msg Value Loop	VulnerableDistributor.distributeRewards() (contract.sol#42-54) use msg.value in a loop: reward = (msg.value * shares[shareholders[i_scope_0]]) / totalShares (contract.sol#51)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** msg-value-loop	critical	open	\N	42		\N	2025-10-17 17:17:23.865724+00	2025-10-17 17:17:23.865724+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
c9f3f064-504f-40ac-a81f-dbbf94d24537	ab38ce7e-f785-4195-9cbc-f5005a03a531	fc783138-6c5a-4dce-b469-9fdf46020f14	Msg Value Loop	VulnerableDistributor.distributeRewards() (contract.sol#42-54) use msg.value in a loop: reward = (msg.value * shares[shareholders[i_scope_0]]) / totalShares (contract.sol#51)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** msg-value-loop	critical	open	\N	42		\N	2025-10-17 17:25:03.770008+00	2025-10-17 17:25:03.770008+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
66c5120b-0295-472a-9247-714a849169aa	f259704f-3393-4ef6-88c7-f59a4f41c586	fc783138-6c5a-4dce-b469-9fdf46020f14	Msg Value Loop	VulnerableDistributor.distributeRewards() (contract.sol#42-54) use msg.value in a loop: reward = (msg.value * shares[shareholders[i_scope_0]]) / totalShares (contract.sol#51)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** msg-value-loop	critical	open	\N	42		\N	2025-10-17 17:27:08.823072+00	2025-10-17 17:27:08.823072+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
5a443e08-263a-49c6-a97e-1914f56c9cb3	1546015b-d5f5-4e9e-9d76-ecc8d082d88e	fc783138-6c5a-4dce-b469-9fdf46020f14	Msg Value Loop	VulnerableDistributor.distributeRewards() (contract.sol#42-54) use msg.value in a loop: reward = (msg.value * shares[shareholders[i_scope_0]]) / totalShares (contract.sol#51)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** msg-value-loop	critical	open	\N	42		\N	2025-10-17 17:30:38.370197+00	2025-10-17 17:30:38.370197+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
f9548d68-fcb4-47d7-b722-a4127f2ab3f2	0ffcad6c-ac72-4278-9ae3-e846d397530a	fc783138-6c5a-4dce-b469-9fdf46020f14	Msg Value Loop	VulnerableDistributor.distributeRewards() (contract.sol#42-54) use msg.value in a loop: reward = (msg.value * shares[shareholders[i_scope_0]]) / totalShares (contract.sol#51)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** msg-value-loop	critical	open	\N	42		\N	2025-10-17 17:34:55.189274+00	2025-10-17 17:34:55.189274+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
05661a38-9ba5-411a-8edf-6ba4be296c12	8c5f9f99-0634-4833-890e-3f3aae0ef221	fc783138-6c5a-4dce-b469-9fdf46020f14	Msg Value Loop	VulnerableDistributor.distributeRewards() (contract.sol#42-54) use msg.value in a loop: reward = (msg.value * shares[shareholders[i_scope_0]]) / totalShares (contract.sol#51)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** msg-value-loop	critical	open	\N	42		\N	2025-10-17 17:48:20.311103+00	2025-10-17 17:48:20.311103+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
805e36d3-3923-45bd-a234-89501d953d86	5d741b89-e602-4862-9bda-4eea5acf333f	fc783138-6c5a-4dce-b469-9fdf46020f14	Msg Value Loop	VulnerableDistributor.distributeRewards() (contract.sol#42-54) use msg.value in a loop: reward = (msg.value * shares[shareholders[i_scope_0]]) / totalShares (contract.sol#51)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** msg-value-loop	critical	open	\N	42		\N	2025-10-17 17:52:35.868994+00	2025-10-17 17:52:35.868994+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
625971b4-da2f-4d9b-8376-9e9bf6ea2bfb	9e06c8f8-30e1-4b62-8332-3bb8da5068a4	fc783138-6c5a-4dce-b469-9fdf46020f14	Msg Value Loop	VulnerableDistributor.distributeRewards() (contract.sol#42-54) use msg.value in a loop: reward = (msg.value * shares[shareholders[i_scope_0]]) / totalShares (contract.sol#51)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** msg-value-loop	critical	open	\N	42		\N	2025-10-17 17:55:28.153663+00	2025-10-17 17:55:28.153663+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
542b3c9f-3e87-435f-b207-cafc668e7e09	e6d541e1-65d3-4072-9263-7b3714135fe0	fc783138-6c5a-4dce-b469-9fdf46020f14	Msg Value Loop	VulnerableDistributor.distributeRewards() (contract.sol#42-54) use msg.value in a loop: reward = (msg.value * shares[shareholders[i_scope_0]]) / totalShares (contract.sol#51)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** msg-value-loop	critical	open	\N	42		\N	2025-10-17 17:58:24.084041+00	2025-10-17 17:58:24.084041+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
b70f037c-0ae7-4a4f-a121-f1767df2def1	0300d842-455a-4102-9fa0-684e5e5d53fa	fc783138-6c5a-4dce-b469-9fdf46020f14	Msg Value Loop	VulnerableDistributor.distributeRewards() (contract.sol#42-54) use msg.value in a loop: reward = (msg.value * shares[shareholders[i_scope_0]]) / totalShares (contract.sol#51)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** msg-value-loop	critical	open	\N	42		\N	2025-10-17 18:03:18.311543+00	2025-10-17 18:03:18.311543+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
bb469d80-50ac-48a3-9939-64fc0e51d3c7	77b7e537-a626-4e5a-9697-9bfdd8b64551	fc783138-6c5a-4dce-b469-9fdf46020f14	Msg Value Loop	VulnerableDistributor.distributeRewards() (contract.sol#42-54) use msg.value in a loop: reward = (msg.value * shares[shareholders[i_scope_0]]) / totalShares (contract.sol#51)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** msg-value-loop	critical	open	\N	42		\N	2025-10-17 18:21:41.482781+00	2025-10-17 18:21:41.482781+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
8002b0bc-048a-4ada-abe6-e097717db9d4	50226168-4bd5-460e-8976-0dd50d6e7016	98593981-74f4-43f4-b7f6-3d795f4a488c	Arbitrary Ether Send	VulnerableRandomness.playGame() (contract.sol#98-109) sends eth to arbitrary user\n\tDangerous calls:\n\t- address(msg.sender).transfer(20000000000000000) (contract.sol#105)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** arbitrary-send-eth	critical	open	\N	98		Implement access control to restrict who can trigger Ether transfers. Consider using withdrawal pattern instead of send pattern.	2025-10-17 19:10:39.241762+00	2025-10-17 19:10:39.241762+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
01904add-4d39-4e70-abf9-237ffa83229d	50226168-4bd5-460e-8976-0dd50d6e7016	98593981-74f4-43f4-b7f6-3d795f4a488c	Weak Pseudo-Random Number Generator	VulnerableRandomness.generateRandomNumber() (contract.sol#85-96) uses a weak PRNG: "random = uint256(keccak256(bytes)(abi.encodePacked(block.timestamp,block.difficulty,block.number,msg.sender))) % 100 (contract.sol#87-92)"\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** weak-prng	critical	open	\N	85		Do not use block properties (timestamp, blockhash) for randomness. Use Chainlink VRF or similar oracle-based randomness solution.	2025-10-17 19:10:39.241762+00	2025-10-17 19:10:39.241762+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
77c88644-a381-47c6-ae1d-5a736cd15250	50226168-4bd5-460e-8976-0dd50d6e7016	98593981-74f4-43f4-b7f6-3d795f4a488c	Weak Pseudo-Random Number Generator	VulnerableTimelock.emergencyWithdraw() (contract.sol#69-74) uses a weak PRNG: "require(bool,string)(block.timestamp % 2 == 0,Can only withdraw on even seconds) (contract.sol#71)"\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** weak-prng	critical	open	\N	69		Do not use block properties (timestamp, blockhash) for randomness. Use Chainlink VRF or similar oracle-based randomness solution.	2025-10-17 19:10:39.241762+00	2025-10-17 19:10:39.241762+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
7e1039f6-0f2e-462a-ab91-e8de02e364bc	50226168-4bd5-460e-8976-0dd50d6e7016	98593981-74f4-43f4-b7f6-3d795f4a488c	Incorrect Equality	VulnerableTimelock.emergencyWithdraw() (contract.sol#69-74) uses a dangerous strict equality:\n\t- require(bool,string)(block.timestamp % 2 == 0,Can only withdraw on even seconds) (contract.sol#71)\n\n**Impact:** Medium\n**Confidence:** High\n\n**Detector:** incorrect-equality	high	open	\N	69		\N	2025-10-17 19:10:39.241762+00	2025-10-17 19:10:39.241762+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
2ed6f199-91d1-4535-bf49-73242bdc8186	67b31138-1bd4-4422-bfdb-564f441ce01d	43195d13-0923-4e91-9008-cb6ccd854b66	Reentrancy Attack (Ether)	Reentrancy in VulnerableBank.withdraw() (contract.sol#19-29):\n\tExternal calls:\n\t- (success) = msg.sender.call{value: amount}() (contract.sol#24)\n\tState variables written after the call(s):\n\t- balances[msg.sender] = 0 (contract.sol#28)\n\tVulnerableBank.balances (contract.sol#12) can be used in cross function reentrancies:\n\t- VulnerableBank.balances (contract.sol#12)\n\t- VulnerableBank.deposit() (contract.sol#14-16)\n\t- VulnerableBank.withdraw() (contract.sol#19-29)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** reentrancy-eth	critical	open	\N	19		Apply the checks-effects-interactions pattern: 1) Check conditions, 2) Update state, 3) Make external calls. Consider using OpenZeppelin's ReentrancyGuard modifier.	2025-10-17 21:15:16.150978+00	2025-10-17 21:15:16.150978+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
8c326bb5-9880-42e4-a2fc-5398c808f419	b0e9ac5e-bc8a-441f-933c-4e8782683e66	4557d54f-bc37-4e82-819f-32a9a5137315	Arbitrary Ether Send	VulnerablePuzzle.submitSolution(string) (contract.sol#23-31) sends eth to arbitrary user\n\tDangerous calls:\n\t- address(msg.sender).transfer(reward) (contract.sol#30)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** arbitrary-send-eth	critical	open	\N	23		Implement access control to restrict who can trigger Ether transfers. Consider using withdrawal pattern instead of send pattern.	2025-10-17 21:31:34.262851+00	2025-10-17 21:31:34.262851+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
dd8610cf-3366-4659-90b5-e709d3545668	b0e9ac5e-bc8a-441f-933c-4e8782683e66	4557d54f-bc37-4e82-819f-32a9a5137315	Locked Ether	Contract locking ether found:\n\tContract VulnerableICO (contract.sol#81-107) has payable functions:\n\t - VulnerableICO.buyTokens(uint256) (contract.sol#98-106)\n\tBut does not have a function to withdraw the ether\n\n**Impact:** Medium\n**Confidence:** High\n\n**Detector:** locked-ether	high	open	\N	81		\N	2025-10-17 21:31:34.262851+00	2025-10-17 21:31:34.262851+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
046bbdd4-d980-4d3c-8659-49ba4e64bab8	0540d982-7d72-45a0-a8ca-a30a24a9f710	526f3007-70d4-4bf2-a53e-2d99ead52669	Controlled Delegatecall	VulnerableRegistry.executeLogic(bytes) (contract.sol#124-127) uses delegatecall to a input-controlled function id\n\t- (success) = logicContract.delegatecall(_data) (contract.sol#125)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** controlled-delegatecall	critical	open	\N	124		Avoid using delegatecall with user-controlled targets. If necessary, use a whitelist of approved contracts.	2025-10-17 21:35:51.463832+00	2025-10-17 21:35:51.463832+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
da79350e-26a3-4647-af64-9e17a3862a7c	0540d982-7d72-45a0-a8ca-a30a24a9f710	526f3007-70d4-4bf2-a53e-2d99ead52669	Controlled Delegatecall	VulnerableProxy.forward(bytes) (contract.sol#21-26) uses delegatecall to a input-controlled function id\n\t- (success) = implementation.delegatecall(_data) (contract.sol#24)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** controlled-delegatecall	critical	fixed	\N	21		Avoid using delegatecall with user-controlled targets. If necessary, use a whitelist of approved contracts.	2025-10-17 21:35:51.463832+00	2025-10-17 21:49:41.554976+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
fc97bb5a-a729-4b33-b862-181eb39319b0	0540d982-7d72-45a0-a8ca-a30a24a9f710	526f3007-70d4-4bf2-a53e-2d99ead52669	Controlled Delegatecall	VulnerableWallet.fallback() (contract.sol#82-86) uses delegatecall to a input-controlled function id\n\t- (success) = libAddress.delegatecall(msg.data) (contract.sol#84)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** controlled-delegatecall	critical	open	\N	82		Avoid using delegatecall with user-controlled targets. If necessary, use a whitelist of approved contracts.	2025-10-17 21:35:51.463832+00	2025-10-17 21:35:51.463832+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
cbc00f9f-ac59-4481-b41f-21194eb2aa2f	0540d982-7d72-45a0-a8ca-a30a24a9f710	526f3007-70d4-4bf2-a53e-2d99ead52669	Controlled Delegatecall	VulnerableProxy.execute(address,bytes) (contract.sol#29-33) uses delegatecall to a input-controlled function id\n\t- (success) = _target.delegatecall(_data) (contract.sol#31)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** controlled-delegatecall	critical	open	\N	29		Avoid using delegatecall with user-controlled targets. If necessary, use a whitelist of approved contracts.	2025-10-17 21:35:51.463832+00	2025-10-17 21:35:51.463832+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
80221585-654a-469f-a39e-2aa657ab6782	0540d982-7d72-45a0-a8ca-a30a24a9f710	526f3007-70d4-4bf2-a53e-2d99ead52669	Controlled Delegatecall	UninitializedProxy.fallback() (contract.sol#163-166) uses delegatecall to a input-controlled function id\n\t- (success) = implementation.delegatecall(msg.data) (contract.sol#164)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** controlled-delegatecall	critical	open	\N	163		Avoid using delegatecall with user-controlled targets. If necessary, use a whitelist of approved contracts.	2025-10-17 21:35:51.463832+00	2025-10-17 21:35:51.463832+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
3207230f-115d-4ba9-bf32-4f3b0a06ac38	4986c18e-7693-49b2-bb12-e2e1ab8c0df8	c065cb49-0a9e-465c-9944-2ba193513c97	Immutable States	BridgeToken.bridge (contract.sol#11) should be immutable\n\n**Impact:** Optimization\n**Confidence:** High\n\n**Detector:** immutable-states	low	open	\N	11		\N	2025-10-28 04:21:42.123178+00	2025-10-28 04:21:42.123178+00	uncategorized	0.90	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	slither	\N	\N	\N	\N	\N	\N	\N	\N
2bfe3b83-f5e0-4bd2-a9c7-dd1022f8ef72	0540d982-7d72-45a0-a8ca-a30a24a9f710	526f3007-70d4-4bf2-a53e-2d99ead52669	Controlled Delegatecall	VulnerableWallet.withdraw(uint256) (contract.sol#73-80) uses delegatecall to a input-controlled function id\n\t- (success) = libAddress.delegatecall(abi.encodeWithSignature(withdraw(uint256),_amount)) (contract.sol#76-78)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** controlled-delegatecall	critical	open	\N	73		Avoid using delegatecall with user-controlled targets. If necessary, use a whitelist of approved contracts.	2025-10-17 21:35:51.463832+00	2025-10-17 21:35:51.463832+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
d5df1ff4-92ac-4017-8705-70262aeec586	0540d982-7d72-45a0-a8ca-a30a24a9f710	526f3007-70d4-4bf2-a53e-2d99ead52669	Suicidal	MaliciousLogic.destroy(address) (contract.sol#135-138) allows anyone to destruct the contract\n\n**Impact:** High\n**Confidence:** High\n\n**Detector:** suicidal	critical	open	\N	135		\N	2025-10-17 21:35:51.463832+00	2025-10-17 21:35:51.463832+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
0c67d090-a132-4797-b9d3-49c78fb7de4e	0540d982-7d72-45a0-a8ca-a30a24a9f710	526f3007-70d4-4bf2-a53e-2d99ead52669	Suicidal	MaliciousImplementation.destroy() (contract.sol#49-51) allows anyone to destruct the contract\n\n**Impact:** High\n**Confidence:** High\n\n**Detector:** suicidal	critical	open	\N	49		\N	2025-10-17 21:35:51.463832+00	2025-10-17 21:35:51.463832+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
fae61385-c9e7-483f-afc8-1882853c784d	d27fe555-06b6-47b1-bf8f-d7b28b9a1779	0e2ea42e-a14d-446a-a193-04a3fbefbd6c	Erc20 Interface	VulnerableMapping (contract.sol#149-175) has incorrect ERC20 function interface:VulnerableMapping.approve(address,uint256) (contract.sol#161-163)\n\n**Impact:** Medium\n**Confidence:** High\n\n**Detector:** erc20-interface	high	open	\N	149		\N	2025-10-17 22:27:30.237187+00	2025-10-17 22:27:30.237187+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
3b451a39-2753-4208-8546-0fc69b6583e9	92197c37-a3e0-4d4f-ad78-1f262a27703b	97970ea9-196b-4643-95e6-f1aa019bcf6f	Arbitrary Ether Send	VulnerablePayment.batchPayout(address[],uint256[]) (contract.sol#37-44) sends eth to arbitrary user\n\tDangerous calls:\n\t- _recipients[i].call{value: _amounts[i]}() (contract.sol#42)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** arbitrary-send-eth	critical	false_positive	\N	37		Implement access control to restrict who can trigger Ether transfers. Consider using withdrawal pattern instead of send pattern.	2025-10-17 22:29:56.089651+00	2025-10-17 22:33:36.92334+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
039cb732-10b4-4b5c-8f8f-1ebe7c51a22c	92197c37-a3e0-4d4f-ad78-1f262a27703b	97970ea9-196b-4643-95e6-f1aa019bcf6f	Arbitrary Ether Send	MaliciousReceiver.attack(address,uint256) (contract.sol#94-103) sends eth to arbitrary user\n\tDangerous calls:\n\t- vulnerable.deposit{value: _amount}() (contract.sol#98)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** arbitrary-send-eth	critical	open	\N	94		Implement access control to restrict who can trigger Ether transfers. Consider using withdrawal pattern instead of send pattern.	2025-10-17 22:29:56.089651+00	2025-10-17 22:29:56.089651+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
688ea2cd-d78d-4438-b822-2c29a118c23a	92197c37-a3e0-4d4f-ad78-1f262a27703b	97970ea9-196b-4643-95e6-f1aa019bcf6f	Reentrancy Attack (State Changes)	Reentrancy in VulnerableIntegration.claimReward() (contract.sol#64-74):\n\tExternal calls:\n\t- externalContract.executeAction(msg.sender) (contract.sol#69)\n\tState variables written after the call(s):\n\t- rewards[msg.sender] = 0 (contract.sol#72)\n\tVulnerableIntegration.rewards (contract.sol#57) can be used in cross function reentrancies:\n\t- VulnerableIntegration.claimReward() (contract.sol#64-74)\n\t- VulnerableIntegration.rewards (contract.sol#57)\n\t- VulnerableIntegration.setReward(address,uint256) (contract.sol#76-78)\n\n**Impact:** Medium\n**Confidence:** Medium\n\n**Detector:** reentrancy-no-eth	high	open	\N	64		Ensure state changes occur before external calls. Follow the checks-effects-interactions pattern.	2025-10-17 22:29:56.089651+00	2025-10-17 22:29:56.089651+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
fc2d3c48-282d-49dc-b68c-57f6a8ad2225	92197c37-a3e0-4d4f-ad78-1f262a27703b	97970ea9-196b-4643-95e6-f1aa019bcf6f	Unchecked Low-Level Call	VulnerablePayment.withdrawUnchecked(address,uint256) (contract.sol#18-25) ignores return value by _recipient.call{value: _amount}() (contract.sol#23)\n\n**Impact:** Medium\n**Confidence:** Medium\n\n**Detector:** unchecked-lowlevel	high	fixed	\N	18		Always check the return value of low-level calls (call, delegatecall, staticcall). Use require() to validate the success boolean.	2025-10-17 22:29:56.089651+00	2025-10-17 22:33:34.333496+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
ef1d7945-1504-4d65-b871-7c94c9863c2b	92197c37-a3e0-4d4f-ad78-1f262a27703b	97970ea9-196b-4643-95e6-f1aa019bcf6f	Unchecked Low-Level Call	VulnerablePayment.batchPayout(address[],uint256[]) (contract.sol#37-44) ignores return value by _recipients[i].call{value: _amounts[i]}() (contract.sol#42)\n\n**Impact:** Medium\n**Confidence:** Medium\n\n**Detector:** unchecked-lowlevel	high	open	\N	37		Always check the return value of low-level calls (call, delegatecall, staticcall). Use require() to validate the success boolean.	2025-10-17 22:29:56.089651+00	2025-10-17 22:29:56.089651+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
6ec90ecd-cd96-415f-b306-aaf23f11a642	92197c37-a3e0-4d4f-ad78-1f262a27703b	97970ea9-196b-4643-95e6-f1aa019bcf6f	Unchecked Send Return Value	VulnerablePayment.withdrawWithSend(address,uint256) (contract.sol#28-34) ignores return value by _recipient.send(_amount) (contract.sol#33)\n\n**Impact:** Medium\n**Confidence:** Medium\n\n**Detector:** unchecked-send	high	open	\N	28		Check the return value of send() and transfer() calls. Consider using call{value: amount}() with proper checks instead.	2025-10-17 22:29:56.089651+00	2025-10-17 22:29:56.089651+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
a3149731-5c4e-4aec-a301-43d3c2dc9eb3	92197c37-a3e0-4d4f-ad78-1f262a27703b	97970ea9-196b-4643-95e6-f1aa019bcf6f	Unused Return	VulnerableIntegration.claimReward() (contract.sol#64-74) ignores return value by externalContract.executeAction(msg.sender) (contract.sol#69)\n\n**Impact:** Medium\n**Confidence:** Medium\n\n**Detector:** unused-return	high	open	\N	64		\N	2025-10-17 22:29:56.089651+00	2025-10-17 22:29:56.089651+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
d36a8d41-563f-4620-b472-a8a34a209565	b3b89b39-1b4b-46c3-bb2e-4f2698201962	8af6de60-912a-4eff-aa1f-96779a3bac91	Missing Zero Check	ComplexBridge.constructor(address)._signer (contract.sol#13) lacks a zero-check on :\n\t\t- trustedSigner = _signer (contract.sol#14)\n\n**Impact:** Low\n**Confidence:** Medium\n\n**Detector:** missing-zero-check	medium	open	\N	13		\N	2025-10-23 15:27:13.312352+00	2025-10-23 15:27:13.312352+00	access_control	0.70	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	slither	\N	\N	\N	\N	\N	\N	\N	\N
c64419ff-64de-4cc2-bf9b-98a21e999674	b3b89b39-1b4b-46c3-bb2e-4f2698201962	8af6de60-912a-4eff-aa1f-96779a3bac91	Reentrancy (Event Emission)	Reentrancy in ComplexBridge.executeWithProof(bytes32,bytes32,bytes32[],bytes) (contract.sol#42-57):\n\tExternal calls:\n\t- (success,None) = address(this).call(payload) (contract.sol#53)\n\tEvent emitted after the call(s):\n\t- MessageExecuted(leaf) (contract.sol#56)\n\n**Impact:** Low\n**Confidence:** Medium\n\n**Detector:** reentrancy-events	medium	open	\N	42		\N	2025-10-23 15:27:13.312352+00	2025-10-23 15:27:13.312352+00	reentrancy	0.70	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	slither	\N	\N	\N	\N	\N	\N	\N	\N
72b84beb-10d4-46f3-8d27-473b1fcaafa4	b3b89b39-1b4b-46c3-bb2e-4f2698201962	8af6de60-912a-4eff-aa1f-96779a3bac91	Solc Version	Version constraint ^0.8.0 contains known severe issues (https://solidity.readthedocs.io/en/latest/bugs.html)\n\t- FullInlinerNonExpressionSplitArgumentEvaluationOrder\n\t- MissingSideEffectsOnSelectorAccess\n\t- AbiReencodingHeadOverflowWithStaticArrayCleanup\n\t- DirtyBytesArrayToStorage\n\t- DataLocationChangeInInternalOverride\n\t- NestedCalldataArrayAbiReencodingSizeValidation\n\t- SignedImmutables\n\t- ABIDecodeTwoDimensionalArrayMemory\n\t- KeccakCaching.\nIt is used by:\n\t- ^0.8.0 (contract.sol#2)\n\n**Impact:** Informational\n**Confidence:** High\n\n**Detector:** solc-version	low	open	\N	2		\N	2025-10-23 15:27:13.312352+00	2025-10-23 15:27:13.312352+00	best_practice	0.90	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	slither	\N	\N	\N	\N	\N	\N	\N	\N
921f3cec-5074-456f-bc0a-c53a4426adf0	b3b89b39-1b4b-46c3-bb2e-4f2698201962	8af6de60-912a-4eff-aa1f-96779a3bac91	Low Level Calls	Low level call in ComplexBridge.executeWithProof(bytes32,bytes32,bytes32[],bytes) (contract.sol#42-57):\n\t- (success,None) = address(this).call(payload) (contract.sol#53)\n\n**Impact:** Informational\n**Confidence:** High\n\n**Detector:** low-level-calls	low	open	\N	42		\N	2025-10-23 15:27:13.312352+00	2025-10-23 15:27:13.312352+00	uncategorized	0.90	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	slither	\N	\N	\N	\N	\N	\N	\N	\N
e4bbeb7d-3d70-4dd7-9a7f-021199dc638f	b3b89b39-1b4b-46c3-bb2e-4f2698201962	8af6de60-912a-4eff-aa1f-96779a3bac91	Immutable States	ComplexBridge.trustedSigner (contract.sol#9) should be immutable\n\n**Impact:** Optimization\n**Confidence:** High\n\n**Detector:** immutable-states	low	open	\N	9		\N	2025-10-23 15:27:13.312352+00	2025-10-23 15:27:13.312352+00	uncategorized	0.90	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	slither	\N	\N	\N	\N	\N	\N	\N	\N
ef8f95aa-fadd-448b-94fa-df14910cf3e0	bc87370e-ee8d-4251-b30a-3a0ad54fd735	86f9a16f-7896-4115-b321-adf9db382682	Reentrancy Eth	Reentrancy in VulnerableBank.withdraw() (ReEntrancy Contract.sol#19-29):\n\tExternal calls:\n\t- (success,None) = msg.sender.call{value: amount}() (ReEntrancy Contract.sol#24)\n\tState variables written after the call(s):\n\t- balances[msg.sender] = 0 (ReEntrancy Contract.sol#28)\n\tVulnerableBank.balances (ReEntrancy Contract.sol#12) can be used in cross function reentrancies:\n\t- VulnerableBank.balances (ReEntrancy Contract.sol#12)\n\t- VulnerableBank.deposit() (ReEntrancy Contract.sol#14-16)\n\t- VulnerableBank.withdraw() (ReEntrancy Contract.sol#19-29)\n	high	open	reentrancy-eth	19	\n    // VULNERABLE: State update happens after external call\n    function withdraw() public {\n        uint256 amount = balances[msg.sender];\n        require(amount > 0, "Insufficient balance");	Use the Checks-Effects-Interactions pattern. Move external calls to the end of the function after all state changes.	2025-10-24 03:57:01.930813+00	2025-10-24 03:56:45.427917+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
5451f753-1238-4e1c-a591-4348bc6660d6	7cbbfacf-e078-4aa5-87da-ca5b8c9d578b	86f9a16f-7896-4115-b321-adf9db382682	Reentrancy Eth	Reentrancy in VulnerableBank.withdraw() (ReEntrancy Contract.sol#19-29):\n\tExternal calls:\n\t- (success,None) = msg.sender.call{value: amount}() (ReEntrancy Contract.sol#24)\n\tState variables written after the call(s):\n\t- balances[msg.sender] = 0 (ReEntrancy Contract.sol#28)\n\tVulnerableBank.balances (ReEntrancy Contract.sol#12) can be used in cross function reentrancies:\n\t- VulnerableBank.balances (ReEntrancy Contract.sol#12)\n\t- VulnerableBank.deposit() (ReEntrancy Contract.sol#14-16)\n\t- VulnerableBank.withdraw() (ReEntrancy Contract.sol#19-29)\n	high	open	reentrancy-eth	19	\n    // VULNERABLE: State update happens after external call\n    function withdraw() public {\n        uint256 amount = balances[msg.sender];\n        require(amount > 0, "Insufficient balance");	Use the Checks-Effects-Interactions pattern. Move external calls to the end of the function after all state changes.	2025-10-24 05:07:39.718558+00	2025-10-24 05:07:22.815092+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
36832830-0540-4ef3-bc81-6466593a223d	fe153dad-4c0b-4165-b529-6cec12692b34	4557d54f-bc37-4e82-819f-32a9a5137315	Arbitrary Send Eth	VulnerablePuzzle.submitSolution(string) (Front Running.sol#23-31) sends eth to arbitrary user\n\tDangerous calls:\n\t- address(msg.sender).transfer(reward) (Front Running.sol#30)\n	high	open	arbitrary-send-eth	23	\n    // VULNERABLE: Solution is visible in mempool before confirmation\n    function submitSolution(string memory _solution) public {\n        require(!solved, "Already solved");\n	Review the code and consult Slither documentation for specific recommendations.	2025-10-25 23:18:36.33986+00	2025-10-25 23:18:19.356658+00	\N	\N	\N	\N	\N	9d07aced0792e4a98f839ff9f176503a83468dca803bd9208d31eeabd39b4ca8	173d64e4da0f9c9a463f9383de981b519e5b1500a46628158f60bce353792e45	ff2ef7c33fd7abfc77fe026c208a2e1b966d54781dafde40b0ffc410aa26c3d8	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	arbitrary-send-eth	\N	\N	Front Running.sol	submitSolution	VulnerablePuzzle	\N	\N
dcefd005-fa7a-4dba-ad58-72627409a107	fe153dad-4c0b-4165-b529-6cec12692b34	4557d54f-bc37-4e82-819f-32a9a5137315	Locked Ether	Contract locking ether found:\n\tContract VulnerableICO (Front Running.sol#81-107) has payable functions:\n\t - VulnerableICO.buyTokens(uint256) (Front Running.sol#98-106)\n\tBut does not have a function to withdraw the ether\n	medium	open	locked-ether	81	 * @dev Shows vulnerability where transaction order affects outcome\n */\ncontract VulnerableICO {\n    uint256 public price = 1 ether;\n    uint256 public tokensAvailable = 1000;	Review the code and consult Slither documentation for specific recommendations.	2025-10-25 23:18:36.339905+00	2025-10-25 23:18:19.356658+00	\N	\N	\N	\N	\N	8ce0de52163b09c4accd172f6e8267c8a5105af1c887fb13182f15fe7157a48c	9a1105e92640e2a13d21dda6b39cc5a692f876d8348d7c487c5b2bdb72505ea9	77e8a964b41cd32c5d68edff8fe9d7f4107ff1ef4bf20c6a47006dcac3f63dc0	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	locked-ether	\N	\N	Front Running.sol	VulnerableICO	VulnerableICO	\N	\N
24590df0-1cab-4058-b430-716d5468d057	b5b1f73c-53b8-4567-ae23-3e25c00143af	4557d54f-bc37-4e82-819f-32a9a5137315	Arbitrary Send Eth	VulnerablePuzzle.submitSolution(string) (Front Running.sol#23-31) sends eth to arbitrary user\n\tDangerous calls:\n\t- address(msg.sender).transfer(reward) (Front Running.sol#30)\n	high	open	arbitrary-send-eth	23	\n    // VULNERABLE: Solution is visible in mempool before confirmation\n    function submitSolution(string memory _solution) public {\n        require(!solved, "Already solved");\n	Review the code and consult Slither documentation for specific recommendations.	2025-10-25 23:44:29.337125+00	2025-10-25 23:44:09.840054+00	\N	\N	\N	\N	\N	9d07aced0792e4a98f839ff9f176503a83468dca803bd9208d31eeabd39b4ca8	173d64e4da0f9c9a463f9383de981b519e5b1500a46628158f60bce353792e45	ff2ef7c33fd7abfc77fe026c208a2e1b966d54781dafde40b0ffc410aa26c3d8	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	arbitrary-send-eth	\N	\N	Front Running.sol	submitSolution	VulnerablePuzzle	\N	\N
32b04090-ab77-42e1-8cfb-8501a285b8be	b5b1f73c-53b8-4567-ae23-3e25c00143af	4557d54f-bc37-4e82-819f-32a9a5137315	Locked Ether	Contract locking ether found:\n\tContract VulnerableICO (Front Running.sol#81-107) has payable functions:\n\t - VulnerableICO.buyTokens(uint256) (Front Running.sol#98-106)\n\tBut does not have a function to withdraw the ether\n	medium	open	locked-ether	81	 * @dev Shows vulnerability where transaction order affects outcome\n */\ncontract VulnerableICO {\n    uint256 public price = 1 ether;\n    uint256 public tokensAvailable = 1000;	Review the code and consult Slither documentation for specific recommendations.	2025-10-25 23:44:29.337177+00	2025-10-25 23:44:09.840054+00	\N	\N	\N	\N	\N	8ce0de52163b09c4accd172f6e8267c8a5105af1c887fb13182f15fe7157a48c	9a1105e92640e2a13d21dda6b39cc5a692f876d8348d7c487c5b2bdb72505ea9	77e8a964b41cd32c5d68edff8fe9d7f4107ff1ef4bf20c6a47006dcac3f63dc0	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	locked-ether	\N	\N	Front Running.sol	VulnerableICO	VulnerableICO	\N	\N
7f3acfc6-7a74-4045-9d4f-3c2478ca31c5	d99fd397-e73d-4103-af77-6848b1212476	86f9a16f-7896-4115-b321-adf9db382682	Reentrancy Eth	Reentrancy in VulnerableBank.withdraw() (ReEntrancy Contract.sol#19-29):\n\tExternal calls:\n\t- (success,None) = msg.sender.call{value: amount}() (ReEntrancy Contract.sol#24)\n\tState variables written after the call(s):\n\t- balances[msg.sender] = 0 (ReEntrancy Contract.sol#28)\n\tVulnerableBank.balances (ReEntrancy Contract.sol#12) can be used in cross function reentrancies:\n\t- VulnerableBank.balances (ReEntrancy Contract.sol#12)\n\t- VulnerableBank.deposit() (ReEntrancy Contract.sol#14-16)\n\t- VulnerableBank.withdraw() (ReEntrancy Contract.sol#19-29)\n	high	open	reentrancy-eth	19	\n    // VULNERABLE: State update happens after external call\n    function withdraw() public {\n        uint256 amount = balances[msg.sender];\n        require(amount > 0, "Insufficient balance");	Use the Checks-Effects-Interactions pattern. Move external calls to the end of the function after all state changes.	2025-10-26 00:23:46.611909+00	2025-10-26 00:23:30.246054+00	\N	\N	\N	\N	\N	14a916b2ef5547990a405ad68e4ff94e87f981fc906bb33fd2edf2da6cf2cec1	3a1799ad3cdf2d61587e8863ea0d41659424c6784be301afffd5d76d17d5c380	ab4b681c45ae0eeee6741dac63a7f236cf5a69ff5681a1271ad92dbd636fe563	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	reentrancy-eth	\N	\N	ReEntrancy Contract.sol	withdraw	VulnerableBank	\N	\N
01f98d4d-d413-497c-ae15-2587f0eacf3d	f6723229-7b79-4fe3-bb94-42f4b5f18369	86f9a16f-7896-4115-b321-adf9db382682	Reentrancy Eth	Reentrancy in VulnerableBank.withdraw() (ReEntrancy Contract.sol#19-29):\n\tExternal calls:\n\t- (success,None) = msg.sender.call{value: amount}() (ReEntrancy Contract.sol#24)\n\tState variables written after the call(s):\n\t- balances[msg.sender] = 0 (ReEntrancy Contract.sol#28)\n\tVulnerableBank.balances (ReEntrancy Contract.sol#12) can be used in cross function reentrancies:\n\t- VulnerableBank.balances (ReEntrancy Contract.sol#12)\n\t- VulnerableBank.deposit() (ReEntrancy Contract.sol#14-16)\n\t- VulnerableBank.withdraw() (ReEntrancy Contract.sol#19-29)\n	high	open	reentrancy-eth	19	\n    // VULNERABLE: State update happens after external call\n    function withdraw() public {\n        uint256 amount = balances[msg.sender];\n        require(amount > 0, "Insufficient balance");	Use the Checks-Effects-Interactions pattern. Move external calls to the end of the function after all state changes.	2025-10-26 00:44:56.81443+00	2025-10-26 00:44:43.417744+00	\N	\N	REE-001	0.9	rule_based	14a916b2ef5547990a405ad68e4ff94e87f981fc906bb33fd2edf2da6cf2cec1	3a1799ad3cdf2d61587e8863ea0d41659424c6784be301afffd5d76d17d5c380	ab4b681c45ae0eeee6741dac63a7f236cf5a69ff5681a1271ad92dbd636fe563	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	\N	reentrancy-eth	\N	\N	ReEntrancy Contract.sol	withdraw	VulnerableBank	\N	\N
6c36a99d-168a-40eb-b9a1-f9f2ebfb11fc	fe4d7fb8-f706-4522-87dd-e400a783ab58	70b27594-33ef-4d19-b443-1906060c5cc6	Reentrancy Attack (Ether)	Reentrancy in ReentrancyTest.withdraw() (contract.sol#22-28):\n\tExternal calls:\n\t- (success,None) = msg.sender.call{value: balance}() (contract.sol#25)\n\tState variables written after the call(s):\n\t- balances[msg.sender] = 0 (contract.sol#27)\n\tReentrancyTest.balances (contract.sol#10) can be used in cross function reentrancies:\n\t- ReentrancyTest.balances (contract.sol#10)\n\t- ReentrancyTest.deposit() (contract.sol#17-19)\n\t- ReentrancyTest.getBalance() (contract.sol#48-50)\n\t- ReentrancyTest.unsafeDeposit() (contract.sol#44-46)\n\t- ReentrancyTest.withdraw() (contract.sol#22-28)\n\t- ReentrancyTest.withdrawTo(address) (contract.sol#36-41)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** reentrancy-eth	critical	open	\N	22		Apply the checks-effects-interactions pattern: 1) Check conditions, 2) Update state, 3) Make external calls. Consider using OpenZeppelin's ReentrancyGuard modifier.	2025-10-27 21:34:10.729038+00	2025-10-27 21:34:10.729038+00	reentrancy	0.70	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	slither	\N	\N	\N	\N	\N	\N	\N	\N
882d5242-5bd8-4c09-9a7d-9f96f5d2e0ff	fe4d7fb8-f706-4522-87dd-e400a783ab58	70b27594-33ef-4d19-b443-1906060c5cc6	Unchecked Send Return Value	ReentrancyTest.withdrawTo(address) (contract.sol#36-41) ignores return value by recipient.send(balance) (contract.sol#39)\n\n**Impact:** Medium\n**Confidence:** Medium\n\n**Detector:** unchecked-send	high	open	\N	36		Check the return value of send() and transfer() calls. Consider using call{value: amount}() with proper checks instead.	2025-10-27 21:34:10.729038+00	2025-10-27 21:34:10.729038+00	best_practice	0.70	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	slither	\N	\N	\N	\N	\N	\N	\N	\N
fe5432de-d24b-45ea-aad6-9b098c05e912	fe4d7fb8-f706-4522-87dd-e400a783ab58	70b27594-33ef-4d19-b443-1906060c5cc6	Missing Zero Check	ReentrancyTest.withdrawTo(address).recipient (contract.sol#36) lacks a zero-check on :\n\t\t- recipient.send(balance) (contract.sol#39)\n\n**Impact:** Low\n**Confidence:** Medium\n\n**Detector:** missing-zero-check	medium	open	\N	36		\N	2025-10-27 21:34:10.729038+00	2025-10-27 21:34:10.729038+00	access_control	0.70	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	slither	\N	\N	\N	\N	\N	\N	\N	\N
499234a7-b0e8-4e29-bade-8711c04b4072	fe4d7fb8-f706-4522-87dd-e400a783ab58	70b27594-33ef-4d19-b443-1906060c5cc6	Missing Zero Check	ReentrancyTest.setOwner(address).newOwner (contract.sol#31) lacks a zero-check on :\n\t\t- owner = newOwner (contract.sol#32)\n\n**Impact:** Low\n**Confidence:** Medium\n\n**Detector:** missing-zero-check	medium	open	\N	31		\N	2025-10-27 21:34:10.729038+00	2025-10-27 21:34:10.729038+00	access_control	0.70	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	slither	\N	\N	\N	\N	\N	\N	\N	\N
d57a8168-46b8-4d0b-ad65-3124637e3061	fe4d7fb8-f706-4522-87dd-e400a783ab58	70b27594-33ef-4d19-b443-1906060c5cc6	Solc Version	Version constraint ^0.8.0 contains known severe issues (https://solidity.readthedocs.io/en/latest/bugs.html)\n\t- FullInlinerNonExpressionSplitArgumentEvaluationOrder\n\t- MissingSideEffectsOnSelectorAccess\n\t- AbiReencodingHeadOverflowWithStaticArrayCleanup\n\t- DirtyBytesArrayToStorage\n\t- DataLocationChangeInInternalOverride\n\t- NestedCalldataArrayAbiReencodingSizeValidation\n\t- SignedImmutables\n\t- ABIDecodeTwoDimensionalArrayMemory\n\t- KeccakCaching.\nIt is used by:\n\t- ^0.8.0 (contract.sol#2)\n\n**Impact:** Informational\n**Confidence:** High\n\n**Detector:** solc-version	low	open	\N	2		\N	2025-10-27 21:34:10.729038+00	2025-10-27 21:34:10.729038+00	best_practice	0.90	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	slither	\N	\N	\N	\N	\N	\N	\N	\N
d77bf611-eb1f-4696-a1dd-19625cfa1b6c	fe4d7fb8-f706-4522-87dd-e400a783ab58	70b27594-33ef-4d19-b443-1906060c5cc6	Low Level Calls	Low level call in ReentrancyTest.withdraw() (contract.sol#22-28):\n\t- (success,None) = msg.sender.call{value: balance}() (contract.sol#25)\n\n**Impact:** Informational\n**Confidence:** High\n\n**Detector:** low-level-calls	low	open	\N	22		\N	2025-10-27 21:34:10.729038+00	2025-10-27 21:34:10.729038+00	uncategorized	0.90	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	slither	\N	\N	\N	\N	\N	\N	\N	\N
b8e4be1a-7d0a-478c-9f8a-8416ba49c018	fe4d7fb8-f706-4522-87dd-e400a783ab58	70b27594-33ef-4d19-b443-1906060c5cc6	Reentrancy Unlimited Gas	Reentrancy in ReentrancyTest.withdrawTo(address) (contract.sol#36-41):\n\tExternal calls:\n\t- recipient.send(balance) (contract.sol#39)\n\tState variables written after the call(s):\n\t- balances[msg.sender] = 0 (contract.sol#40)\n\n**Impact:** Informational\n**Confidence:** Medium\n\n**Detector:** reentrancy-unlimited-gas	low	open	\N	36		\N	2025-10-27 21:34:10.729038+00	2025-10-27 21:34:10.729038+00	reentrancy	0.70	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	slither	\N	\N	\N	\N	\N	\N	\N	\N
66eda9b2-cace-4fef-9f16-f961ee5ad175	9263afbb-6723-4249-a3c0-b59bab200f43	c065cb49-0a9e-465c-9944-2ba193513c97	Missing Zero Check	BridgeToken.constructor(address)._bridge (contract.sol#20) lacks a zero-check on :\n\t\t- bridge = _bridge (contract.sol#21)\n\n**Impact:** Low\n**Confidence:** Medium\n\n**Detector:** missing-zero-check	medium	open	\N	20		\N	2025-10-28 03:54:47.883747+00	2025-10-28 03:54:47.883747+00	access_control	0.70	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	slither	\N	\N	\N	\N	\N	\N	\N	\N
5557d7e5-ed67-4a02-974a-1643fc31c9cf	9263afbb-6723-4249-a3c0-b59bab200f43	c065cb49-0a9e-465c-9944-2ba193513c97	Solc Version	Version constraint ^0.8.0 contains known severe issues (https://solidity.readthedocs.io/en/latest/bugs.html)\n\t- FullInlinerNonExpressionSplitArgumentEvaluationOrder\n\t- MissingSideEffectsOnSelectorAccess\n\t- AbiReencodingHeadOverflowWithStaticArrayCleanup\n\t- DirtyBytesArrayToStorage\n\t- DataLocationChangeInInternalOverride\n\t- NestedCalldataArrayAbiReencodingSizeValidation\n\t- SignedImmutables\n\t- ABIDecodeTwoDimensionalArrayMemory\n\t- KeccakCaching.\nIt is used by:\n\t- ^0.8.0 (contract.sol#2)\n\n**Impact:** Informational\n**Confidence:** High\n\n**Detector:** solc-version	low	open	\N	2		\N	2025-10-28 03:54:47.883747+00	2025-10-28 03:54:47.883747+00	best_practice	0.90	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	slither	\N	\N	\N	\N	\N	\N	\N	\N
bce15431-4cde-49da-8248-010b2f1cf852	9263afbb-6723-4249-a3c0-b59bab200f43	c065cb49-0a9e-465c-9944-2ba193513c97	Immutable States	BridgeToken.bridge (contract.sol#11) should be immutable\n\n**Impact:** Optimization\n**Confidence:** High\n\n**Detector:** immutable-states	low	open	\N	11		\N	2025-10-28 03:54:47.883747+00	2025-10-28 03:54:47.883747+00	uncategorized	0.90	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	slither	\N	\N	\N	\N	\N	\N	\N	\N
e78d9acd-d39b-4283-afc8-d6a8992e3a9d	4986c18e-7693-49b2-bb12-e2e1ab8c0df8	c065cb49-0a9e-465c-9944-2ba193513c97	Missing Zero Check	BridgeToken.constructor(address)._bridge (contract.sol#20) lacks a zero-check on :\n\t\t- bridge = _bridge (contract.sol#21)\n\n**Impact:** Low\n**Confidence:** Medium\n\n**Detector:** missing-zero-check	medium	open	\N	20		\N	2025-10-28 04:21:42.123178+00	2025-10-28 04:21:42.123178+00	access_control	0.70	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	slither	\N	\N	\N	\N	\N	\N	\N	\N
6e24206c-0036-45ef-9f5a-26e51618c0ba	4986c18e-7693-49b2-bb12-e2e1ab8c0df8	c065cb49-0a9e-465c-9944-2ba193513c97	Solc Version	Version constraint ^0.8.0 contains known severe issues (https://solidity.readthedocs.io/en/latest/bugs.html)\n\t- FullInlinerNonExpressionSplitArgumentEvaluationOrder\n\t- MissingSideEffectsOnSelectorAccess\n\t- AbiReencodingHeadOverflowWithStaticArrayCleanup\n\t- DirtyBytesArrayToStorage\n\t- DataLocationChangeInInternalOverride\n\t- NestedCalldataArrayAbiReencodingSizeValidation\n\t- SignedImmutables\n\t- ABIDecodeTwoDimensionalArrayMemory\n\t- KeccakCaching.\nIt is used by:\n\t- ^0.8.0 (contract.sol#2)\n\n**Impact:** Informational\n**Confidence:** High\n\n**Detector:** solc-version	low	open	\N	2		\N	2025-10-28 04:21:42.123178+00	2025-10-28 04:21:42.123178+00	best_practice	0.90	\N	\N	\N	\N	\N	\N	\N	\N	\N	t	0	\N	\N	\N	\N	\N	\N	\N	\N	1	f	f	\N	\N	f	\N	\N	slither	\N	\N	\N	\N	\N	\N	\N	\N
\.


--
-- Data for Name: vulnerability_classifications; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.vulnerability_classifications (id, vulnerability_id, user_id, classification, previous_classification, confidence, feedback_text, tags, fix_status, fix_commit_hash, fix_verified, fix_verified_at, was_actually_vulnerable, exploitability_score, business_impact, created_at, updated_at, is_latest) FROM stdin;
\.


--
-- Data for Name: vulnerability_patterns; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.vulnerability_patterns (id, name, description, category, severity, swc_id, cwe_id, owasp_category, remediation, fix_examples, "references", detection_methods, false_positive_rate, affected_languages, semantic_description, keywords, created_at, updated_at, is_active) FROM stdin;
REE-001	Reentrancy Attack	External call followed by state change allows attacker to re-enter contract and manipulate state	reentrancy	critical	SWC-107	CWE-841	A1: Reentrancy	Use checks-effects-interactions pattern, reentrancy guards, or pull payment pattern	["Use ReentrancyGuard from OpenZeppelin", "Move state changes before external calls", "Use .transfer() instead of .call{value}()"]	["https://consensys.github.io/smart-contract-best-practices/attacks/reentrancy/", "https://swcregistry.io/docs/SWC-107"]	{static,symbolic}	0.15	{solidity,vyper}	Function makes external call to untrusted contract then modifies state variables, creating opportunity for recursive callback exploitation	{reentrancy,"external call","state change",callback,recursive}	2025-10-22 20:04:34.821365+00	2025-10-22 20:04:34.821371+00	t
REE-002	Cross-Function Reentrancy	Reentrancy across multiple functions sharing state	reentrancy	high	SWC-107	CWE-841	A1: Reentrancy	Implement function-level reentrancy guards and state locking	["Use nonReentrant modifier on all functions sharing state", "Implement mutex locks"]	["https://consensys.github.io/smart-contract-best-practices/attacks/reentrancy/"]	{static,symbolic}	0.2	{solidity}	Multiple functions share state variables and at least one makes external call before updating shared state	{cross-function,reentrancy,"shared state","external call"}	2025-10-22 20:04:34.836423+00	2025-10-22 20:04:34.836429+00	t
REE-003	Read-Only Reentrancy	View/pure function reads inconsistent state during reentrancy	reentrancy	medium	SWC-107	CWE-841	A1: Reentrancy	Use reentrancy guards even on view functions that read critical state	["Add nonReentrant to view functions", "Cache state before external calls"]	["https://chainsecurity.com/heartbreaks-curve-lp-oracles/"]	{static,symbolic}	0.25	{solidity}	View or pure function reads state that can be manipulated during reentrancy attack on related contract	{read-only,view,pure,reentrancy,"state consistency"}	2025-10-22 20:04:34.854638+00	2025-10-22 20:04:34.854643+00	t
ACC-001	Missing Access Control	Critical function lacks access control modifiers allowing unauthorized execution	access-control	critical	SWC-105	CWE-284	A2: Access Control	Add onlyOwner, onlyRole, or custom access control modifiers	["Use OpenZeppelin Ownable", "Implement AccessControl with roles", "Add require(msg.sender == owner)"]	["https://swcregistry.io/docs/SWC-105"]	{static}	0.1	{solidity,vyper}	Function that modifies critical state or transfers value has no sender verification	{"access control",authorization,onlyOwner,permission,unauthorized}	2025-10-22 20:04:34.856966+00	2025-10-22 20:04:34.856978+00	t
ACC-002	Centralization Risk	Single owner has excessive control over contract operations	access-control	medium	SWC-105	CWE-284	A2: Access Control	Implement multi-sig, timelock, or decentralized governance	["Use Gnosis Safe multisig", "Implement timelock delays", "Add governance voting"]	["https://blog.openzeppelin.com/protect-your-users-with-smart-contract-timelocks"]	{static}	0.3	{solidity,vyper}	Owner address has unilateral control over critical functions without multi-party approval or time delays	{centralization,owner,admin,governance,multisig}	2025-10-22 20:04:34.859611+00	2025-10-22 20:04:34.859614+00	t
ACC-003	Privilege Escalation	User can escalate their privileges to admin/owner	access-control	high	SWC-105	CWE-269	A2: Access Control	Ensure role assignment is properly protected and immutable where needed	["Protect role grant functions", "Use two-step ownership transfer"]	["https://swcregistry.io/docs/SWC-105"]	{static,symbolic}	0.15	{solidity,vyper}	Non-privileged user can call functions to grant themselves elevated permissions	{"privilege escalation","role assignment","permission elevation"}	2025-10-22 20:04:34.861861+00	2025-10-22 20:04:34.861864+00	t
INT-001	Integer Overflow	Arithmetic operation can overflow beyond maximum value	arithmetic	high	SWC-101	CWE-190	A3: Arithmetic Issues	Use SafeMath library or Solidity 0.8+ built-in overflow protection	["Use SafeMath.add()", "Upgrade to Solidity ^0.8.0", "Add overflow checks"]	["https://swcregistry.io/docs/SWC-101"]	{static,symbolic}	0.05	{solidity}	Addition, multiplication, or exponentiation without overflow protection in Solidity < 0.8.0	{overflow,arithmetic,SafeMath,unchecked,integer}	2025-10-22 20:04:34.864227+00	2025-10-22 20:04:34.864233+00	t
INT-002	Integer Underflow	Arithmetic operation can underflow below zero	arithmetic	high	SWC-101	CWE-191	A3: Arithmetic Issues	Use SafeMath library or Solidity 0.8+ built-in underflow protection	["Use SafeMath.sub()", "Add require checks", "Use checked arithmetic"]	["https://swcregistry.io/docs/SWC-101"]	{static,symbolic}	0.05	{solidity}	Subtraction without underflow protection allowing values to wrap around to maximum uint	{underflow,arithmetic,SafeMath,subtraction,integer}	2025-10-22 20:04:34.866664+00	2025-10-22 20:04:34.866668+00	t
INT-003	Division by Zero	Division operation can be executed with zero denominator	arithmetic	medium	SWC-101	CWE-369	A3: Arithmetic Issues	Add require statement to check denominator is not zero	["require(denominator != 0, 'Division by zero')", "Use SafeMath.div()"]	["https://swcregistry.io/docs/SWC-101"]	{static,symbolic}	0.1	{solidity,vyper}	Division or modulo operation where denominator can be zero causing transaction revert	{division,zero,modulo,arithmetic,denominator}	2025-10-22 20:04:34.868801+00	2025-10-22 20:04:34.868804+00	t
UNC-001	Unchecked External Call	Low-level call return value not checked for failure	unchecked-calls	high	SWC-104	CWE-252	A4: Unchecked Return Values	Check return value of call/delegatecall/staticcall	["(bool success,) = addr.call(); require(success)", "Use high-level calls"]	["https://swcregistry.io/docs/SWC-104"]	{static}	0.1	{solidity}	Low-level call, delegatecall, or staticcall with unchecked boolean return value	{unchecked,call,delegatecall,"return value",external}	2025-10-22 20:04:34.870777+00	2025-10-22 20:04:34.870781+00	t
UNC-002	Unchecked Send/Transfer	Send return value not checked, transfer may fail silently	unchecked-calls	medium	SWC-104	CWE-252	A4: Unchecked Return Values	Check return value of send or use transfer	["require(addr.send(amount))", "Use addr.transfer(amount)"]	["https://swcregistry.io/docs/SWC-104"]	{static}	0.15	{solidity}	Send operation return value ignored, potentially losing funds if transfer fails	{send,transfer,unchecked,"return value",ether}	2025-10-22 20:04:34.872851+00	2025-10-22 20:04:34.872854+00	t
DOS-001	Denial of Service - Unbounded Loop	Loop over unbounded array can exceed block gas limit	dos	high	SWC-128	CWE-400	A5: Denial of Service	Limit array size, use pagination, or redesign to avoid loops	["Implement max array size", "Use mapping instead of array", "Add pagination"]	["https://swcregistry.io/docs/SWC-128"]	{static}	0.2	{solidity,vyper}	For loop iterating over storage array with no size limit that could grow unbounded	{dos,loop,"gas limit",unbounded,array}	2025-10-22 20:04:34.874794+00	2025-10-22 20:04:34.874798+00	t
DOS-002	Denial of Service - Block Gas Limit	Operation can be blocked by manipulating gas costs	dos	medium	SWC-128	CWE-400	A5: Denial of Service	Avoid operations dependent on number of participants	["Use pull over push payment pattern", "Implement circuit breaker"]	["https://consensys.github.io/smart-contract-best-practices/attacks/denial-of-service/"]	{static,symbolic}	0.25	{solidity,vyper}	Function performs operations proportional to user-controllable parameter that can exceed block gas limit	{dos,"gas limit",block,"computational cost"}	2025-10-22 20:04:34.877348+00	2025-10-22 20:04:34.877353+00	t
DOS-003	Denial of Service - Revert on Failure	External call failure causes entire batch operation to revert	dos	medium	SWC-113	CWE-703	A5: Denial of Service	Handle failures gracefully, use pull payment pattern	["Try-catch external calls", "Skip failed transfers", "Pull payment pattern"]	["https://swcregistry.io/docs/SWC-113"]	{static}	0.2	{solidity}	Loop making external calls where single failure reverts entire transaction affecting all participants	{dos,revert,batch,"external call",failure}	2025-10-22 20:04:34.879601+00	2025-10-22 20:04:34.879605+00	t
TIM-001	Block Timestamp Manipulation	Critical logic depends on block.timestamp which miners can manipulate	time-manipulation	medium	SWC-116	CWE-829	A6: Bad Randomness	Use block.number for time-dependent logic or accept timestamp tolerance	["Use block.number instead", "Allow timestamp tolerance window"]	["https://swcregistry.io/docs/SWC-116"]	{static}	0.3	{solidity,vyper}	Contract uses block.timestamp in critical comparison that miners can manipulate within ~900 second window	{timestamp,block.timestamp,now,time,manipulation}	2025-10-22 20:04:34.881685+00	2025-10-22 20:04:34.88169+00	t
TIM-002	Transaction Order Dependence	Contract behavior depends on transaction ordering (front-running)	time-manipulation	medium	SWC-114	CWE-362	A7: Front-Running	Use commit-reveal scheme or implement order-independent logic	["Implement commit-reveal", "Use submarine sends", "Add slippage protection"]	["https://swcregistry.io/docs/SWC-114"]	{static,symbolic}	0.35	{solidity,vyper}	State changes create value opportunity for observers who can execute transactions before target transaction	{front-running,MEV,ordering,"race condition",sandwich}	2025-10-22 20:04:34.88431+00	2025-10-22 20:04:34.884315+00	t
RAN-001	Weak Randomness	Pseudorandom number generated from predictable blockchain data	randomness	high	SWC-120	CWE-330	A6: Bad Randomness	Use Chainlink VRF or similar oracle-based randomness	["Implement Chainlink VRF", "Use commit-reveal with user entropy"]	["https://swcregistry.io/docs/SWC-120"]	{static}	0.1	{solidity,vyper}	Random value derived from block.timestamp, block.difficulty, blockhash or other miner-influenced values	{randomness,blockhash,difficulty,predictable,VRF}	2025-10-22 20:04:34.886773+00	2025-10-22 20:04:34.886776+00	t
DEL-001	Delegatecall to Untrusted Contract	Delegatecall executes code in context of calling contract with arbitrary target	delegatecall	critical	SWC-112	CWE-829	A8: Unsafe Delegatecall	Only delegatecall to trusted, immutable library addresses	["Hardcode library addresses", "Use library keyword", "Whitelist allowed targets"]	["https://swcregistry.io/docs/SWC-112"]	{static,symbolic}	0.1	{solidity}	Delegatecall target address comes from user input or mutable storage allowing arbitrary code execution	{delegatecall,arbitrary,proxy,untrusted,"code injection"}	2025-10-22 20:04:34.888933+00	2025-10-22 20:04:34.888936+00	t
DEL-002	Storage Collision in Proxy	Proxy and implementation storage layouts conflict	delegatecall	high	SWC-112	CWE-664	A8: Unsafe Delegatecall	Use unstructured storage pattern or EIP-1967 standard slots	["Follow EIP-1967", "Use OpenZeppelin upgradeable contracts", "Implement unstructured storage"]	["https://eips.ethereum.org/EIPS/eip-1967"]	{static}	0.15	{solidity}	Proxy contract and implementation use overlapping storage slots causing state corruption	{proxy,"storage collision",delegatecall,upgrade,EIP-1967}	2025-10-22 20:04:34.890779+00	2025-10-22 20:04:34.890782+00	t
SIG-001	Signature Replay Attack	Signed message can be reused across chains or transactions	signature	high	SWC-117	CWE-294	A9: Signature Issues	Include nonce, chainId, and contract address in signed message	["Add nonce tracking", "Include block.chainid", "Use EIP-712 structured data"]	["https://swcregistry.io/docs/SWC-117", "https://eips.ethereum.org/EIPS/eip-712"]	{static}	0.15	{solidity,vyper}	Signature verification lacks nonce, chainId, or contract address allowing message replay	{signature,replay,nonce,chainId,EIP-712}	2025-10-22 20:04:34.892761+00	2025-10-22 20:04:34.892765+00	t
SIG-002	Missing Signature Verification	Function accepts signed data without verifying signature	signature	critical	SWC-122	CWE-345	A9: Signature Issues	Implement ecrecover signature verification	["Use ecrecover", "Verify signer address", "Implement EIP-712"]	["https://swcregistry.io/docs/SWC-122"]	{static}	0.05	{solidity,vyper}	Function processes signed parameters without recovering and validating signer address	{signature,verification,ecrecover,authentication}	2025-10-22 20:04:34.895153+00	2025-10-22 20:04:34.895158+00	t
SIG-003	Signature Malleability	Signature can be modified to different valid signature for same message	signature	medium	SWC-117	CWE-347	A9: Signature Issues	Check signature s value is in lower half of curve	["Require s <= secp256k1n/2", "Use OpenZeppelin ECDSA library"]	["https://swcregistry.io/docs/SWC-117"]	{static}	0.2	{solidity}	Ecrecover usage without checking s parameter allowing signature malleability	{signature,malleability,ecrecover,ECDSA}	2025-10-22 20:04:34.897687+00	2025-10-22 20:04:34.897692+00	t
INI-001	Uninitialized Storage Pointer	Storage pointer not initialized, points to slot 0	initialization	high	SWC-109	CWE-824	A10: Uninitialized Storage	Initialize storage variables or use memory keyword	["Add memory keyword", "Initialize before use", "Use Solidity 0.5+"]	["https://swcregistry.io/docs/SWC-109"]	{static}	0.05	{solidity}	Local struct or array variable without memory/storage keyword defaults to storage slot 0	{uninitialized,storage,pointer,memory,slot}	2025-10-22 20:04:34.901702+00	2025-10-22 20:04:34.901708+00	t
INI-002	Uninitialized Proxy Implementation	Proxy implementation not initialized allowing takeover	initialization	critical	SWC-109	CWE-665	A10: Uninitialized Storage	Initialize implementation in constructor or with initializer	["Call initialize() in constructor", "Use initializer modifier", "Lock implementation"]	["https://docs.openzeppelin.com/upgrades-plugins/1.x/writing-upgradeable"]	{static}	0.1	{solidity}	Upgradeable contract implementation has uninitialized state allowing anyone to initialize and take control	{uninitialized,proxy,implementation,initializer,upgrade}	2025-10-22 20:04:34.90479+00	2025-10-22 20:04:34.904795+00	t
VIS-001	Unprotected Function Visibility	Critical function has public visibility instead of private/internal	visibility	high	SWC-100	CWE-710	A2: Access Control	Set appropriate visibility (private/internal/external)	["Change to private/internal", "Add access control modifier"]	["https://swcregistry.io/docs/SWC-100"]	{static}	0.15	{solidity}	Internal function or helper accidentally exposed as public allowing unauthorized access	{visibility,public,private,internal,access}	2025-10-22 20:04:34.907441+00	2025-10-22 20:04:34.907446+00	t
VIS-002	Unprotected Constructor	Constructor is public allowing anyone to reinitialize	visibility	critical	SWC-118	CWE-665	A10: Uninitialized Storage	Ensure constructor is only callable once during deployment	["Use constructor keyword", "Upgrade to Solidity 0.5+"]	["https://swcregistry.io/docs/SWC-118"]	{static}	0.05	{solidity}	Function with same name as contract but not using constructor keyword can be called by anyone	{constructor,initialization,reinitialize,visibility}	2025-10-22 20:04:34.909729+00	2025-10-22 20:04:34.909732+00	t
SEL-001	Selfdestruct to Arbitrary Address	Contract can be destroyed with funds sent to attacker address	selfdestruct	critical	SWC-106	CWE-284	A2: Access Control	Remove selfdestruct or hardcode recipient address with access control	["Remove selfdestruct", "Hardcode recipient", "Add onlyOwner modifier"]	["https://swcregistry.io/docs/SWC-106"]	{static}	0.1	{solidity}	Selfdestruct with user-controlled destination address allowing fund theft and contract destruction	{selfdestruct,suicide,destruction,"arbitrary address"}	2025-10-22 20:04:34.911726+00	2025-10-22 20:04:34.911729+00	t
EXT-001	External Contract Reference	Contract calls external address from user input	external-calls	medium	SWC-107	CWE-829	A1: Reentrancy	Whitelist allowed external contracts	["Hardcode external addresses", "Maintain whitelist", "Validate contract code"]	["https://consensys.github.io/smart-contract-best-practices/development-recommendations/general/external-calls/"]	{static}	0.25	{solidity,vyper}	Contract makes call to address provided by user without validation	{"external call",arbitrary,untrusted,"user input"}	2025-10-22 20:04:34.918057+00	2025-10-22 20:04:34.91806+00	t
GAS-001	Gas Limit in External Call	External call forwards all available gas	gas	low	SWC-134	CWE-400	A5: Denial of Service	Specify gas limit for external calls	["Use call{gas: amount}", "Limit gas forwarded"]	["https://swcregistry.io/docs/SWC-134"]	{static}	0.3	{solidity}	Call forwards all remaining gas to external contract increasing reentrancy risk	{gas,"external call","gas limit",stipend}	2025-10-22 20:04:34.919978+00	2025-10-22 20:04:34.919981+00	t
CON-001	Constructor State Change	Constructor makes external calls before state is fully initialized	construction	medium	SWC-112	CWE-665	A10: Uninitialized Storage	Complete state initialization before external calls	["Initialize all state first", "Move external calls to separate function"]	["https://docs.openzeppelin.com/upgrades-plugins/1.x/writing-upgradeable"]	{static}	0.2	{solidity}	Constructor calls external contracts before finishing state initialization creating reentrancy risk	{constructor,initialization,"external call",reentrancy}	2025-10-22 20:04:34.931811+00	2025-10-22 20:04:34.931816+00	t
LOC-001	Locked Ether in Contract	Contract can receive Ether but has no mechanism to withdraw it, potentially locking funds permanently	funds-management	medium	SWC-132	CWE-1126	A03:2021-Injection	Add a withdraw function with proper access control to allow authorized users to retrieve locked funds	\N	\N	{static-analysis,code-review}	0	{solidity}	\N	{locked,ether,payable,withdraw,funds,trapped}	2025-10-25 23:42:18.192101+00	2025-10-25 23:42:18.192101+00	t
BVD-COD-004	Constant Function Changes State	Function marked constant, view, or pure modifies contract state	code-quality	high	SWC-128	CWE-710	A9: Code Quality	Remove constant/view/pure modifier or eliminate state changes	["Remove view/pure modifier if function modifies state", "Move state changes to separate non-constant function", "Use memory variables instead of storage"]	["https://docs.soliditylang.org/en/latest/contracts.html#view-functions", "https://swcregistry.io/docs/SWC-128"]	{static}	0.1	{solidity}	Function with state mutability restriction (view/pure/constant) contains operations that modify state	{constant,view,pure,"state change",mutability}	2025-10-29 23:54:23.987183+00	2025-10-29 23:54:23.987183+00	t
BVD-LOC-001	Contract Locks Ether	Contract accepts ether but has no withdraw function, permanently locking funds	locked-ether	high	SWC-132	CWE-404	A4: Insecure Design	Add withdraw function or make contract non-payable	["Add withdraw function with access control", "Implement selfdestruct with owner check", "Remove payable functions if ether handling not needed"]	["https://swcregistry.io/docs/SWC-132", "https://consensys.github.io/smart-contract-best-practices/development-recommendations/general/force-feeding/"]	{static}	0.15	{solidity,vyper}	Contract with payable functions or fallback but no mechanism to withdraw ether	{"locked ether",withdraw,payable,"stuck funds"}	2025-10-29 23:54:23.987183+00	2025-10-29 23:54:23.987183+00	t
BVD-COL-001	Function Selector Collision	Function selectors collide causing incorrect function routing and potential exploits	collision	high	SWC-133	CWE-477	A4: Insecure Design	Rename functions to avoid selector collision	["Use different function names", "Add parameters to change function signature", "Review proxy function selectors for conflicts"]	["https://swcregistry.io/docs/SWC-133", "https://github.com/ethereum/solidity/issues/3556"]	{static}	0.05	{solidity}	Multiple functions hash to same 4-byte selector causing routing ambiguity	{selector,collision,"function signature","hash collision"}	2025-10-29 23:54:23.987183+00	2025-10-29 23:54:23.987183+00	t
BVD-ERC-001	Incorrect ERC721 Interface	ERC721 implementation doesn't match standard interface causing incompatibility	interface	high	SWC-128	CWE-704	A4: Insecure Design	Implement ERC721 interface correctly according to EIP-721	["Inherit from OpenZeppelin ERC721", "Implement all required ERC721 functions", "Match function signatures exactly to standard"]	["https://eips.ethereum.org/EIPS/eip-721", "https://docs.openzeppelin.com/contracts/4.x/erc721"]	{static}	0.1	{solidity}	NFT contract claims ERC721 compatibility but interface deviates from standard	{erc721,nft,interface,standard,compliance}	2025-10-29 23:54:23.987183+00	2025-10-29 23:54:23.987183+00	t
BVD-ERC-002	Incorrect ERC20 Interface	ERC20 implementation doesn't match standard interface causing incompatibility	interface	high	SWC-128	CWE-704	A4: Insecure Design	Implement ERC20 interface correctly according to EIP-20	["Inherit from OpenZeppelin ERC20", "Implement all required ERC20 functions", "Match function signatures and return types to standard"]	["https://eips.ethereum.org/EIPS/eip-20", "https://docs.openzeppelin.com/contracts/4.x/erc20"]	{static}	0.1	{solidity}	Token contract claims ERC20 compatibility but interface deviates from standard	{erc20,token,interface,standard,compliance}	2025-10-29 23:54:23.987183+00	2025-10-29 23:54:23.987183+00	t
BVD-EVM-REE-002	Cross-Function Reentrancy	Reentrancy across multiple functions sharing state	reentrancy	high	SWC-107	CWE-841	A1: Reentrancy	Implement function-level reentrancy guards and state locking	["Use nonReentrant modifier on all functions sharing state", "Implement mutex locks"]	["https://consensys.github.io/smart-contract-best-practices/attacks/reentrancy/"]	{static,symbolic}	0.2	{solidity}	Multiple functions share state variables and at least one makes external call before updating shared state	{cross-function,reentrancy,"shared state","external call"}	2025-10-31 23:32:55.559457+00	2025-10-31 23:47:32.647489+00	t
BVD-EVM-REE-003	Read-Only Reentrancy	View/pure function reads inconsistent state during reentrancy	reentrancy	medium	SWC-107	CWE-841	A1: Reentrancy	Use reentrancy guards even on view functions that read critical state	["Add nonReentrant to view functions", "Cache state before external calls"]	["https://chainsecurity.com/heartbreaks-curve-lp-oracles/"]	{static,symbolic}	0.25	{solidity}	View or pure function reads state that can be manipulated during reentrancy attack on related contract	{read-only,view,pure,reentrancy,"state consistency"}	2025-10-31 23:32:55.56332+00	2025-10-31 23:47:32.652214+00	t
BVD-EVM-ACC-002	Centralization Risk	Single owner has excessive control over contract operations	access-control	medium	SWC-105	CWE-284	A2: Access Control	Implement multi-sig, timelock, or decentralized governance	["Use Gnosis Safe multisig", "Implement timelock delays", "Add governance voting"]	["https://blog.openzeppelin.com/protect-your-users-with-smart-contract-timelocks"]	{static}	0.3	{solidity,vyper}	Owner address has unilateral control over critical functions without multi-party approval or time delays	{centralization,owner,admin,governance,multisig}	2025-10-31 23:32:55.573802+00	2025-10-31 23:47:32.660472+00	t
BVD-EVM-ACC-003	Privilege Escalation	User can escalate their privileges to admin/owner	access-control	high	SWC-105	CWE-269	A2: Access Control	Ensure role assignment is properly protected and immutable where needed	["Protect role grant functions", "Use two-step ownership transfer"]	["https://swcregistry.io/docs/SWC-105"]	{static,symbolic}	0.15	{solidity,vyper}	Non-privileged user can call functions to grant themselves elevated permissions	{"privilege escalation","role assignment","permission elevation"}	2025-10-31 23:32:55.629146+00	2025-10-31 23:47:32.664471+00	t
BVD-EVM-INT-001	Integer Overflow	Arithmetic operation can overflow beyond maximum value	arithmetic	high	SWC-101	CWE-190	A3: Arithmetic Issues	Use SafeMath library or Solidity 0.8+ built-in overflow protection	["Use SafeMath.add()", "Upgrade to Solidity ^0.8.0", "Add overflow checks"]	["https://swcregistry.io/docs/SWC-101"]	{static,symbolic}	0.05	{solidity}	Addition, multiplication, or exponentiation without overflow protection in Solidity < 0.8.0	{overflow,arithmetic,SafeMath,unchecked,integer}	2025-10-31 23:32:55.633336+00	2025-10-31 23:47:32.668646+00	t
BVD-EVM-INT-002	Integer Underflow	Arithmetic operation can underflow below zero	arithmetic	high	SWC-101	CWE-191	A3: Arithmetic Issues	Use SafeMath library or Solidity 0.8+ built-in underflow protection	["Use SafeMath.sub()", "Add require checks", "Use checked arithmetic"]	["https://swcregistry.io/docs/SWC-101"]	{static,symbolic}	0.05	{solidity}	Subtraction without underflow protection allowing values to wrap around to maximum uint	{underflow,arithmetic,SafeMath,subtraction,integer}	2025-10-31 23:32:55.638672+00	2025-10-31 23:47:32.67441+00	t
BVD-EVM-INT-003	Division by Zero	Division operation can be executed with zero denominator	arithmetic	medium	SWC-101	CWE-369	A3: Arithmetic Issues	Add require statement to check denominator is not zero	["require(denominator != 0, 'Division by zero')", "Use SafeMath.div()"]	["https://swcregistry.io/docs/SWC-101"]	{static,symbolic}	0.1	{solidity,vyper}	Division or modulo operation where denominator can be zero causing transaction revert	{division,zero,modulo,arithmetic,denominator}	2025-10-31 23:32:55.648311+00	2025-10-31 23:47:32.68037+00	t
BVD-EVM-UNC-001	Unchecked External Call	Low-level call return value not checked for failure	unchecked-calls	high	SWC-104	CWE-252	A4: Unchecked Return Values	Check return value of call/delegatecall/staticcall	["(bool success,) = addr.call(); require(success)", "Use high-level calls"]	["https://swcregistry.io/docs/SWC-104"]	{static}	0.1	{solidity}	Low-level call, delegatecall, or staticcall with unchecked boolean return value	{unchecked,call,delegatecall,"return value",external}	2025-10-31 23:32:55.654571+00	2025-10-31 23:47:32.687293+00	t
BVD-EVM-UNC-002	Unchecked Send/Transfer	Send return value not checked, transfer may fail silently	unchecked-calls	medium	SWC-104	CWE-252	A4: Unchecked Return Values	Check return value of send or use transfer	["require(addr.send(amount))", "Use addr.transfer(amount)"]	["https://swcregistry.io/docs/SWC-104"]	{static}	0.15	{solidity}	Send operation return value ignored, potentially losing funds if transfer fails	{send,transfer,unchecked,"return value",ether}	2025-10-31 23:32:55.658353+00	2025-10-31 23:47:32.692021+00	t
BVD-EVM-DOS-001	Denial of Service - Unbounded Loop	Loop over unbounded array can exceed block gas limit	dos	high	SWC-128	CWE-400	A5: Denial of Service	Limit array size, use pagination, or redesign to avoid loops	["Implement max array size", "Use mapping instead of array", "Add pagination"]	["https://swcregistry.io/docs/SWC-128"]	{static}	0.2	{solidity,vyper}	For loop iterating over storage array with no size limit that could grow unbounded	{dos,loop,"gas limit",unbounded,array}	2025-10-31 23:32:55.661864+00	2025-10-31 23:47:32.73819+00	t
BVD-EVM-DOS-002	Denial of Service - Block Gas Limit	Operation can be blocked by manipulating gas costs	dos	medium	SWC-128	CWE-400	A5: Denial of Service	Avoid operations dependent on number of participants	["Use pull over push payment pattern", "Implement circuit breaker"]	["https://consensys.github.io/smart-contract-best-practices/attacks/denial-of-service/"]	{static,symbolic}	0.25	{solidity,vyper}	Function performs operations proportional to user-controllable parameter that can exceed block gas limit	{dos,"gas limit",block,"computational cost"}	2025-10-31 23:32:55.666296+00	2025-10-31 23:47:32.741528+00	t
BVD-EVM-DOS-003	Denial of Service - Revert on Failure	External call failure causes entire batch operation to revert	dos	medium	SWC-113	CWE-703	A5: Denial of Service	Handle failures gracefully, use pull payment pattern	["Try-catch external calls", "Skip failed transfers", "Pull payment pattern"]	["https://swcregistry.io/docs/SWC-113"]	{static}	0.2	{solidity}	Loop making external calls where single failure reverts entire transaction affecting all participants	{dos,revert,batch,"external call",failure}	2025-10-31 23:32:55.670109+00	2025-10-31 23:47:32.744968+00	t
BVD-EVM-TIM-001	Block Timestamp Manipulation	Critical logic depends on block.timestamp which miners can manipulate	time-manipulation	medium	SWC-116	CWE-829	A6: Bad Randomness	Use block.number for time-dependent logic or accept timestamp tolerance	["Use block.number instead", "Allow timestamp tolerance window"]	["https://swcregistry.io/docs/SWC-116"]	{static}	0.3	{solidity,vyper}	Contract uses block.timestamp in critical comparison that miners can manipulate within ~900 second window	{timestamp,block.timestamp,now,time,manipulation}	2025-10-31 23:32:55.674064+00	2025-10-31 23:47:32.748562+00	t
BVD-EVM-RAN-001	Weak Randomness	Pseudorandom number generated from predictable blockchain data	randomness	high	SWC-120	CWE-330	A6: Bad Randomness	Use Chainlink VRF or similar oracle-based randomness	["Implement Chainlink VRF", "Use commit-reveal with user entropy"]	["https://swcregistry.io/docs/SWC-120"]	{static}	0.1	{solidity,vyper}	Random value derived from block.timestamp, block.difficulty, blockhash or other miner-influenced values	{randomness,blockhash,difficulty,predictable,VRF}	2025-10-31 23:32:55.682768+00	2025-10-31 23:47:32.757359+00	t
BVD-EVM-DEL-001	Delegatecall to Untrusted Contract	Delegatecall executes code in context of calling contract with arbitrary target	delegatecall	critical	SWC-112	CWE-829	A8: Unsafe Delegatecall	Only delegatecall to trusted, immutable library addresses	["Hardcode library addresses", "Use library keyword", "Whitelist allowed targets"]	["https://swcregistry.io/docs/SWC-112"]	{static,symbolic}	0.1	{solidity}	Delegatecall target address comes from user input or mutable storage allowing arbitrary code execution	{delegatecall,arbitrary,proxy,untrusted,"code injection"}	2025-10-31 23:32:55.686409+00	2025-10-31 23:47:32.762476+00	t
BVD-EVM-DEL-002	Storage Collision in Proxy	Proxy and implementation storage layouts conflict	delegatecall	high	SWC-112	CWE-664	A8: Unsafe Delegatecall	Use unstructured storage pattern or EIP-1967 standard slots	["Follow EIP-1967", "Use OpenZeppelin upgradeable contracts", "Implement unstructured storage"]	["https://eips.ethereum.org/EIPS/eip-1967"]	{static}	0.15	{solidity}	Proxy contract and implementation use overlapping storage slots causing state corruption	{proxy,"storage collision",delegatecall,upgrade,EIP-1967}	2025-10-31 23:32:55.689697+00	2025-10-31 23:47:32.774056+00	t
BVD-EVM-SIG-001	Signature Replay Attack	Signed message can be reused across chains or transactions	signature	high	SWC-117	CWE-294	A9: Signature Issues	Include nonce, chainId, and contract address in signed message	["Add nonce tracking", "Include block.chainid", "Use EIP-712 structured data"]	["https://swcregistry.io/docs/SWC-117", "https://eips.ethereum.org/EIPS/eip-712"]	{static}	0.15	{solidity,vyper}	Signature verification lacks nonce, chainId, or contract address allowing message replay	{signature,replay,nonce,chainId,EIP-712}	2025-10-31 23:32:55.693617+00	2025-10-31 23:47:32.777648+00	t
BVD-EVM-SIG-002	Missing Signature Verification	Function accepts signed data without verifying signature	signature	critical	SWC-122	CWE-345	A9: Signature Issues	Implement ecrecover signature verification	["Use ecrecover", "Verify signer address", "Implement EIP-712"]	["https://swcregistry.io/docs/SWC-122"]	{static}	0.05	{solidity,vyper}	Function processes signed parameters without recovering and validating signer address	{signature,verification,ecrecover,authentication}	2025-10-31 23:32:55.697394+00	2025-10-31 23:47:32.781059+00	t
BVD-EVM-SIG-003	Signature Malleability	Signature can be modified to different valid signature for same message	signature	medium	SWC-117	CWE-347	A9: Signature Issues	Check signature s value is in lower half of curve	["Require s <= secp256k1n/2", "Use OpenZeppelin ECDSA library"]	["https://swcregistry.io/docs/SWC-117"]	{static}	0.2	{solidity}	Ecrecover usage without checking s parameter allowing signature malleability	{signature,malleability,ecrecover,ECDSA}	2025-10-31 23:32:55.702279+00	2025-10-31 23:47:32.784395+00	t
BVD-EVM-INI-001	Uninitialized Storage Pointer	Storage pointer not initialized, points to slot 0	initialization	high	SWC-109	CWE-824	A10: Uninitialized Storage	Initialize storage variables or use memory keyword	["Add memory keyword", "Initialize before use", "Use Solidity 0.5+"]	["https://swcregistry.io/docs/SWC-109"]	{static}	0.05	{solidity}	Local struct or array variable without memory/storage keyword defaults to storage slot 0	{uninitialized,storage,pointer,memory,slot}	2025-10-31 23:32:55.705411+00	2025-10-31 23:47:32.788018+00	t
BVD-EVM-INI-002	Uninitialized Proxy Implementation	Proxy implementation not initialized allowing takeover	initialization	critical	SWC-109	CWE-665	A10: Uninitialized Storage	Initialize implementation in constructor or with initializer	["Call initialize() in constructor", "Use initializer modifier", "Lock implementation"]	["https://docs.openzeppelin.com/upgrades-plugins/1.x/writing-upgradeable"]	{static}	0.1	{solidity}	Upgradeable contract implementation has uninitialized state allowing anyone to initialize and take control	{uninitialized,proxy,implementation,initializer,upgrade}	2025-10-31 23:32:55.708228+00	2025-10-31 23:47:32.791632+00	t
BVD-EVM-VIS-001	Unprotected Function Visibility	Critical function has public visibility instead of private/internal	visibility	high	SWC-100	CWE-710	A2: Access Control	Set appropriate visibility (private/internal/external)	["Change to private/internal", "Add access control modifier"]	["https://swcregistry.io/docs/SWC-100"]	{static}	0.15	{solidity}	Internal function or helper accidentally exposed as public allowing unauthorized access	{visibility,public,private,internal,access}	2025-10-31 23:32:55.71165+00	2025-10-31 23:47:32.795078+00	t
BVD-EVM-VIS-002	Unprotected Constructor	Constructor is public allowing anyone to reinitialize	visibility	critical	SWC-118	CWE-665	A10: Uninitialized Storage	Ensure constructor is only callable once during deployment	["Use constructor keyword", "Upgrade to Solidity 0.5+"]	["https://swcregistry.io/docs/SWC-118"]	{static}	0.05	{solidity}	Function with same name as contract but not using constructor keyword can be called by anyone	{constructor,initialization,reinitialize,visibility}	2025-10-31 23:32:55.714499+00	2025-10-31 23:47:32.798399+00	t
BVD-EVM-SEL-001	Selfdestruct to Arbitrary Address	Contract can be destroyed with funds sent to attacker address	selfdestruct	critical	SWC-106	CWE-284	A2: Access Control	Remove selfdestruct or hardcode recipient address with access control	["Remove selfdestruct", "Hardcode recipient", "Add onlyOwner modifier"]	["https://swcregistry.io/docs/SWC-106"]	{static}	0.1	{solidity}	Selfdestruct with user-controlled destination address allowing fund theft and contract destruction	{selfdestruct,suicide,destruction,"arbitrary address"}	2025-10-31 23:32:55.719089+00	2025-10-31 23:47:32.801211+00	t
BVD-EVM-GAS-001	Gas Limit in External Call	External call forwards all available gas	gas	low	SWC-134	CWE-400	A5: Denial of Service	Specify gas limit for external calls	["Use call{gas: amount}", "Limit gas forwarded"]	["https://swcregistry.io/docs/SWC-134"]	{static}	0.3	{solidity}	Call forwards all remaining gas to external contract increasing reentrancy risk	{gas,"external call","gas limit",stipend}	2025-10-31 23:32:55.725702+00	2025-10-31 23:47:32.807851+00	t
BVD-EVM-CON-001	Constructor State Change	Constructor makes external calls before state is fully initialized	construction	medium	SWC-112	CWE-665	A10: Uninitialized Storage	Complete state initialization before external calls	["Initialize all state first", "Move external calls to separate function"]	["https://docs.openzeppelin.com/upgrades-plugins/1.x/writing-upgradeable"]	{static}	0.2	{solidity}	Constructor calls external contracts before finishing state initialization creating reentrancy risk	{constructor,initialization,"external call",reentrancy}	2025-10-31 23:32:55.728851+00	2025-10-31 23:47:32.812591+00	t
BVD-EVM-REE-004	Token Callback Reentrancy	Token standard callbacks (ERC777, ERC721, ERC677) exploited for reentrancy	reentrancy	critical	SWC-107	CWE-841	A1: Reentrancy	Add reentrancy guards to token callback handlers	["Use nonReentrant on token receiver functions", "Follow checks-effects-interactions in callbacks", "Disable or validate callbacks"]	["https://consensys.github.io/smart-contract-best-practices/attacks/reentrancy/"]	{static}	0.15	{solidity}	Token transfer callbacks (tokensReceived, onERC721Received, onTokenTransfer) allow reentrancy	{token,callback,reentrancy,ERC777,ERC721,ERC677}	2025-10-31 23:32:55.732591+00	2025-10-31 23:47:32.815641+00	t
BVD-EVM-ORA-001	Oracle Price Manipulation	Flash loan or single-block price manipulation of oracle	oracle	critical	\N	CWE-20	A3: Arithmetic Issues	Use TWAP oracles, multi-block price feeds, or Chainlink	["Implement Chainlink price feeds", "Use Uniswap V3 TWAP", "Require multi-block price averaging"]	["https://consensys.github.io/smart-contract-best-practices/attacks/oracle-manipulation/"]	{static}	0.25	{solidity}	Contract uses spot price from DEX without time-weighting or manipulation resistance	{oracle,price,manipulation,"flash loan",TWAP,"spot price"}	2025-10-31 23:32:55.73898+00	2025-10-31 23:47:32.822732+00	t
BVD-EVM-ORA-002	Unrestricted Oracle Update	Oracle price update function lacks access control	oracle	critical	SWC-105	CWE-284	A2: Access Control	Restrict oracle updates to authorized addresses only	["Add onlyOracle modifier", "Implement keeper role", "Use Chainlink automation"]	["https://github.com/Decurity/semgrep-smart-contracts"]	{static}	0.1	{solidity}	Oracle update function public or external without access control allowing price manipulation	{oracle,update,"access control",price,keeper}	2025-10-31 23:32:55.741794+00	2025-10-31 23:47:32.826962+00	t
BVD-EVM-ORA-003	Unsafe Spot Price Usage	Using Curve spot price or similar for critical decisions	oracle	high	\N	CWE-20	A3: Arithmetic Issues	Use time-weighted average price or Chainlink oracle	["Replace get_virtual_price with TWAP", "Use Curve's price oracle", "Implement Chainlink price feed"]	["https://chainsecurity.com/curve-lp-oracle-manipulation-post-mortem/"]	{static}	0.15	{solidity}	Contract uses Curve get_virtual_price or similar spot price functions for value calculations	{curve,"spot price",get_virtual_price,oracle,manipulation}	2025-10-31 23:32:55.744524+00	2025-10-31 23:47:32.830732+00	t
BVD-EVM-TOK-001	ERC20 Public Transfer Method	ERC20 internal _transfer function exposed as public	token	medium	SWC-100	CWE-284	A2: Access Control	Change _transfer visibility to internal	["function _transfer(...) internal {...}", "Remove public keyword", "Use OpenZeppelin ERC20 template"]	["https://github.com/Decurity/semgrep-smart-contracts"]	{static}	0.1	{solidity}	Internal transfer function exposed as public allowing unauthorized token transfers	{ERC20,transfer,public,visibility,token}	2025-10-31 23:32:55.747435+00	2025-10-31 23:47:32.833897+00	t
BVD-EVM-TOK-002	ERC20 Public Burn Method	ERC20 internal _burn function exposed as public	token	medium	SWC-100	CWE-284	A2: Access Control	Change _burn visibility to internal	["function _burn(...) internal {...}", "Add access control to burn", "Use OpenZeppelin ERC20Burnable"]	["https://github.com/Decurity/semgrep-smart-contracts"]	{static}	0.1	{solidity}	Internal burn function exposed as public allowing unauthorized token burning	{ERC20,burn,public,visibility,token}	2025-10-31 23:32:55.75115+00	2025-10-31 23:47:32.837092+00	t
BVD-EVM-TOK-003	ERC721 Arbitrary TransferFrom	ERC721 transferFrom lacks proper ownership validation	token	high	SWC-105	CWE-284	A2: Access Control	Validate msg.sender is owner or approved before transfer	["require(_isApprovedOrOwner(msg.sender, tokenId))", "Use OpenZeppelin ERC721", "Add ownership checks"]	["https://github.com/Decurity/semgrep-smart-contracts"]	{static}	0.1	{solidity}	ERC721 transferFrom missing validation allowing unauthorized NFT transfers	{ERC721,transferFrom,NFT,ownership,validation}	2025-10-31 23:32:55.75449+00	2025-10-31 23:47:32.840082+00	t
BVD-EVM-GAS-008	Cache Array Length	Array length read in every loop iteration	gas	low	SWC-110	CWE-1164	A5: Gas Optimization	Cache array length before loop	["uint256 length = array.length; for(uint i=0; i<length; i++)"]	[]	{static}	0.15	{solidity}	Repeated array length reads waste gas	{array,length,loop,gas}	2025-10-31 23:32:55.977891+00	2025-10-31 23:47:33.055662+00	t
BVD-EVM-CAL-001	Unprotected Uniswap Callback	Uniswap callback function lacks caller validation	callback	critical	SWC-105	CWE-284	A2: Access Control	Validate callback caller is legitimate Uniswap pool	["Verify msg.sender is pool address", "Use factory.getPool() to validate", "Check pool derivation from tokens"]	["https://docs.uniswap.org/contracts/v3/guides/swaps/single-swaps"]	{static}	0.1	{solidity}	uniswapV3SwapCallback or uniswapV4SwapCallback without msg.sender validation enabling unauthorized calls	{uniswap,callback,swap,validation,pool}	2025-10-31 23:32:55.760625+00	2025-10-31 23:47:32.847247+00	t
BVD-EVM-CAL-002	Missing Callback Authentication	Callback function lacks caller authentication	callback	high	SWC-105	CWE-284	A2: Access Control	Validate callback caller is authorized contract	["Whitelist allowed callers", "Verify msg.sender matches expected address", "Use contract derivation validation"]	["https://consensys.github.io/smart-contract-best-practices/development-recommendations/general/external-calls/"]	{static}	0.15	{solidity}	Callback function (onXXX, xxxCallback) without caller validation allowing malicious invocation	{callback,authentication,validation,external,caller}	2025-10-31 23:32:55.763368+00	2025-10-31 23:47:32.850221+00	t
BVD-EVM-ENC-001	abi.encodePacked Hash Collision	Dynamic types in abi.encodePacked can cause hash collisions	encoding	medium	SWC-133	CWE-294	A9: Signature Issues	Use abi.encode for hashing or add delimiters	["Use abi.encode instead of abi.encodePacked", "Add fixed-size delimiter between dynamic types", "Use different hash for each parameter"]	["https://swcregistry.io/docs/SWC-133"]	{static}	0.2	{solidity}	abi.encodePacked with multiple dynamic types (string, bytes, arrays) allows collision attacks	{abi.encodePacked,hash,collision,encoding,keccak256}	2025-10-31 23:32:55.765996+00	2025-10-31 23:47:32.85358+00	t
BVD-EVM-SLP-001	Missing Slippage Protection	DEX swap lacks minimum output amount check (slippage protection)	defi	medium	\N	CWE-20	A7: Front-Running	Add amountOutMin parameter to swaps	["Add minimum output check", "Calculate acceptable slippage range", "Use deadline parameter"]	["https://docs.uniswap.org/contracts/v2/guides/smart-contract-integration/trading"]	{static}	0.25	{solidity}	Uniswap/DEX swap with amountOutMin = 0 or missing slippage parameter allowing sandwich attacks	{slippage,swap,uniswap,DEX,front-running,sandwich}	2025-10-31 23:32:55.7689+00	2025-10-31 23:47:32.857525+00	t
BVD-EVM-BAL-001	Exact Balance Check	Logic depends on exact token balance allowing DoS via dust	validation	medium	\N	CWE-703	A5: Denial of Service	Use balance thresholds instead of exact equality	["Use >= instead of ==", "Track internal accounting separately", "Implement balance tolerance"]	["https://consensys.github.io/smart-contract-best-practices/attacks/denial-of-service/"]	{static}	0.3	{solidity}	Contract logic uses balance == expectedAmount allowing DoS by sending dust amounts	{balance,exact,equality,DoS,dust}	2025-10-31 23:32:55.772549+00	2025-10-31 23:47:32.862913+00	t
BVD-EVM-PRE-001	Precision Loss in Calculation	Integer division causes precision loss in financial calculations	arithmetic	medium	SWC-101	CWE-190	A3: Arithmetic Issues	Multiply before divide, use higher precision, or fixed-point math	["amount * price / PRICE_PRECISION", "Use FixedPoint library", "Calculate with 18 decimals"]	["https://github.com/Decurity/semgrep-smart-contracts"]	{static}	0.35	{solidity}	Division before multiplication in token amount calculations losing precision	{precision,division,calculation,rounding,loss}	2025-10-31 23:32:55.775445+00	2025-10-31 23:47:32.866958+00	t
BVD-EVM-MUL-001	msg.value in Multicall Loop	Multicall reuses same msg.value across multiple calls	multicall	high	\N	CWE-682	A3: Arithmetic Issues	Track msg.value usage or disallow payable in multicall	["Subtract used value from remaining", "Disallow msg.value in multicall", "Implement value tracking per call"]	["https://github.com/Decurity/semgrep-smart-contracts"]	{static}	0.15	{solidity}	Loop executing multiple calls with same msg.value allowing double-spending of ETH	{multicall,msg.value,loop,payable,double-spend}	2025-10-31 23:32:55.778166+00	2025-10-31 23:47:32.870949+00	t
BVD-EVM-BLO-001	Incorrect Blockhash Usage	blockhash() used incorrectly (too old blocks return 0)	blockchain	low	SWC-120	CWE-330	A6: Bad Randomness	Check block number is within 256 blocks or use different approach	["require(block.number - blockNum <= 256)", "Use Chainlink VRF", "Implement commit-reveal"]	["https://docs.soliditylang.org/en/latest/units-and-global-variables.html#block-and-transaction-properties"]	{static}	0.25	{solidity}	blockhash() called on blocks older than 256 returns 0 causing security issues	{blockhash,block,randomness,old}	2025-10-31 23:32:55.780846+00	2025-10-31 23:47:32.874924+00	t
BVD-EVM-ASS-001	Missing State Assignment	Calculation result not assigned to state variable	logic	medium	\N	CWE-563	A3: Arithmetic Issues	Assign calculation result to storage variable	["balance = calculateBalance()", "Store intermediate results", "Complete state updates"]	["https://github.com/Decurity/semgrep-smart-contracts"]	{static}	0.4	{solidity}	Function calculates value but doesn't assign to storage making changes ineffective	{assignment,state,storage,unused,calculation}	2025-10-31 23:32:55.784171+00	2025-10-31 23:47:32.878945+00	t
BVD-EVM-ACC-004	Transfer Without Access Control	Fund transfer function lacks proper sender validation	access-control	high	SWC-105	CWE-284	A2: Access Control	Validate msg.sender owns the funds being transferred	["require(balances[msg.sender] >= amount)", "Validate ownership before transfer", "Use OpenZeppelin patterns"]	["https://github.com/Decurity/semgrep-smart-contracts"]	{static}	0.15	{solidity}	Transfer function allows moving funds without verifying sender authorization	{transfer,"access control",validation,funds,authorization}	2025-10-31 23:32:55.787554+00	2025-10-31 23:47:32.883943+00	t
BVD-EVM-UNI-001	Unicode Bidirectional Characters	Unicode direction control characters in source code	code-quality	high	\N	CWE-838	A3: Arithmetic Issues	Remove unicode bidirectional override characters	["Remove U+202E, U+202D, U+2066, U+2067, U+2068 characters", "Use ASCII-only identifiers", "Enable unicode character detection in IDE"]	["https://trojansource.codes/"]	{static}	0.05	{solidity}	Source code contains unicode bidirectional control characters enabling trojan source attacks	{unicode,bidirectional,trojan,BIDI,RLO}	2025-10-31 23:32:55.794798+00	2025-10-31 23:47:32.893484+00	t
BVD-EVM-PRO-001	Compound Protocol Vulnerability	Compound-specific implementation vulnerability	protocol	varies	\N	\N	A3: Arithmetic Issues	Follow Compound security guidelines	["Use latest Compound V2/V3 code", "Add proper access controls", "Follow protocol patterns"]	["https://docs.compound.finance/"]	{static}	0.2	{solidity}	Compound protocol integration with implementation-specific vulnerabilities	{compound,protocol,borrow,sweep,precision}	2025-10-31 23:32:55.798625+00	2025-10-31 23:47:32.896966+00	t
BVD-EVM-PRO-002	DeFi Protocol Integration Issue	Protocol-specific integration vulnerability	protocol	varies	\N	\N	A3: Arithmetic Issues	Follow protocol-specific security guidelines	["Review protocol documentation", "Implement recommended patterns", "Add validation checks"]	["https://github.com/Decurity/semgrep-smart-contracts"]	{static}	0.25	{solidity}	DeFi protocol integration with protocol-specific vulnerabilities or misuse	{protocol,integration,DeFi,vulnerability}	2025-10-31 23:32:55.801949+00	2025-10-31 23:47:32.900676+00	t
BVD-EVM-SIG-004	OpenZeppelin ECDSA Malleability	Using vulnerable version of OpenZeppelin ECDSA.recover	signature	medium	SWC-117	CWE-347	A9: Signature Issues	Upgrade to OpenZeppelin 4.7.3+ or use tryRecover	["Upgrade OpenZeppelin to 4.7.3+", "Use ECDSA.tryRecover", "Implement s-value check"]	["https://github.com/OpenZeppelin/openzeppelin-contracts/security/advisories/GHSA-4h98-2769-gh6h"]	{static}	0.1	{solidity}	Old OpenZeppelin ECDSA.recover allows signature malleability in versions < 4.7.3	{ECDSA,OpenZeppelin,malleability,signature,recover}	2025-10-31 23:32:55.805348+00	2025-10-31 23:47:32.903935+00	t
BVD-EVM-INJ-001	Context Injection Attack	Calldata-based context injection enabling impersonation	injection	critical	\N	CWE-94	A1: Reentrancy	Validate context parameters, use msg.sender directly	["Don't pass sender via calldata", "Use msg.sender directly", "Validate context authenticity"]	["https://github.com/Decurity/semgrep-smart-contracts"]	{static}	0.1	{solidity}	Function accepts account address via calldata allowing impersonation attacks	{injection,context,calldata,impersonation,spoofing}	2025-10-31 23:32:55.808743+00	2025-10-31 23:47:32.90726+00	t
BVD-EVM-PAT-001	Token Path Confusion	Incorrect token path extraction in DEX adapter	defi	medium	\N	CWE-20	A3: Arithmetic Issues	Correctly extract token addresses from encoded path	["Use proper Uniswap V3 path decoding", "Validate token addresses", "Test path extraction"]	["https://github.com/Decurity/semgrep-smart-contracts"]	{static}	0.2	{solidity}	DEX adapter incorrectly extracts token addresses from encoded path	{path,token,uniswap,extraction,decoding}	2025-10-31 23:32:55.812093+00	2025-10-31 23:47:32.910915+00	t
BVD-EVM-TOK-005	Tax Token Transfer Vulnerability	Public transfer function supporting tax tokens without protection	token	medium	\N	CWE-20	A3: Arithmetic Issues	Restrict access or handle fee-on-transfer tokens properly	["Check balances before and after transfer", "Add access control", "Document tax token support"]	["https://github.com/Decurity/semgrep-smart-contracts"]	{static}	0.25	{solidity}	Transfer function public allowing manipulation of fee-on-transfer token amounts	{token,tax,fee,transfer,deflation}	2025-10-31 23:32:55.815348+00	2025-10-31 23:47:32.914326+00	t
BVD-EVM-TOK-006	Burn Function Parameter Error	BurnFrom function parameter validation or logic error	token	high	\N	CWE-20	A3: Arithmetic Issues	Validate parameters and implement correct burn logic	["Check amount parameter", "Validate allowances", "Use OpenZeppelin ERC20Burnable"]	["https://github.com/Decurity/semgrep-smart-contracts"]	{static}	0.15	{solidity}	Custom burnFrom with incorrect parameter handling enabling unintended burns	{burn,burnFrom,parameter,validation,token}	2025-10-31 23:32:55.818133+00	2025-10-31 23:47:32.917447+00	t
BVD-EVM-MUL-002	Thirdweb Multicall Vulnerability	Arbitrary address spoofing in multicall contracts	multicall	critical	\N	CWE-94	A1: Reentrancy	Validate msg.sender in multicall, patch Thirdweb contracts	["Use fixed msg.sender", "Upgrade Thirdweb contracts", "Add sender validation"]	["https://github.com/thirdweb-dev/security-advisories"]	{static}	0.1	{solidity}	Multicall implementation allows spoofing msg.sender enabling unauthorized actions	{multicall,thirdweb,spoofing,msg.sender,vulnerability}	2025-10-31 23:32:55.820956+00	2025-10-31 23:47:32.920386+00	t
BVD-EVM-ORD-001	Incorrect Function Call Sequence	Functions called in wrong order causing unexpected behavior	logic	medium	\N	CWE-696	A3: Arithmetic Issues	Follow correct protocol function call sequence	["Call functions in documented order", "Add state checks", "Follow protocol examples"]	["https://github.com/Decurity/semgrep-smart-contracts"]	{static}	0.3	{solidity}	Protocol functions invoked in incorrect sequence causing state inconsistency	{order,sequence,function,protocol,state}	2025-10-31 23:32:55.82434+00	2025-10-31 23:47:32.923063+00	t
BVD-EVM-DEP-001	Deprecated Call Value Pattern	Usage of deprecated .call.value()() pattern for sending Ether	deprecated	medium	SWC-134	CWE-477	A5: Denial of Service	Use call{value: amount}() instead of .call.value()()	["payable(addr).call{value: amount}(\\"\\")", "Use modern Solidity 0.6+ syntax", "Consider using transfer() or send() for simple transfers"]	["https://docs.soliditylang.org/en/latest/070-breaking-changes.html"]	{static}	0.05	{solidity}	Deprecated .call.value()() syntax for Ether transfers in Solidity < 0.6.0	{deprecated,call.value,ether,transfer,legacy}	2025-10-31 23:32:55.828393+00	2025-10-31 23:47:32.925915+00	t
BVD-EVM-DEP-003	Deprecated Throw Statement	Usage of deprecated throw keyword for error handling	deprecated	low	\N	CWE-477	\N	Replace throw with revert(), require(), or assert()	["Use revert() for custom error handling", "Use require() for input validation", "Use assert() for invariant checks"]	["https://docs.soliditylang.org/en/latest/050-breaking-changes.html"]	{static}	0.05	{solidity}	Deprecated throw keyword replaced by revert/require/assert in Solidity 0.5+	{deprecated,throw,revert,require,"error handling"}	2025-10-31 23:32:55.835756+00	2025-10-31 23:47:32.933498+00	t
BVD-EVM-COM-001	Insecure Compiler Version	Using outdated Solidity compiler version with known vulnerabilities	configuration	medium	\N	CWE-1104	\N	Upgrade to Solidity ^0.8.24 or latest stable version	["pragma solidity ^0.8.24;", "Use latest stable compiler version", "Review compiler changelog for security fixes"]	["https://docs.soliditylang.org/en/latest/bugs.html", "https://github.com/ethereum/solidity/releases"]	{static}	0.15	{solidity}	Solidity compiler version older than recommended with known security vulnerabilities	{compiler,version,outdated,pragma,upgrade}	2025-10-31 23:32:55.841622+00	2025-10-31 23:47:32.939329+00	t
BVD-EVM-REE-006	Multiple Sends Pattern	Multiple send operations in single transaction increase reentrancy risk	reentrancy	medium	SWC-107	CWE-841	A1: Reentrancy	Use pull payment pattern or reentrancy guards	["Implement withdrawal pattern", "Use ReentrancyGuard from OpenZeppelin", "Combine multiple sends into single operation"]	["https://consensys.github.io/smart-contract-best-practices/attacks/reentrancy/"]	{static}	0.2	{solidity}	Function contains multiple send/transfer operations creating reentrancy and state consistency risks	{"multiple sends",reentrancy,send,transfer,batch}	2025-10-31 23:32:55.84442+00	2025-10-31 23:47:32.942291+00	t
BVD-EVM-FAL-001	Complex Fallback Function	Fallback function contains complex logic increasing attack surface	code-quality	medium	\N	CWE-1126	\N	Keep fallback functions simple, move logic to explicit functions	["Limit fallback to event emission", "Move complex logic to named functions", "Use receive() for simple ETH reception"]	["https://consensys.github.io/smart-contract-best-practices/development-recommendations/solidity-specific/fallback-functions/"]	{static}	0.25	{solidity}	Fallback or receive function contains complex logic beyond simple ETH reception	{fallback,receive,complexity,"attack surface",gas}	2025-10-31 23:32:55.847886+00	2025-10-31 23:47:32.945028+00	t
BVD-EVM-ASM-001	Unsafe Inline Assembly	Inline assembly bypasses Solidity safety checks and type system	code-quality	medium	\N	CWE-1095	\N	Avoid inline assembly unless absolutely necessary, audit carefully	["Use high-level Solidity constructs", "Extensive testing and auditing if assembly required", "Document assembly usage and safety reasoning"]	["https://docs.soliditylang.org/en/latest/assembly.html"]	{static}	0.3	{solidity}	Function uses inline assembly bypassing compiler safety checks and increasing vulnerability risk	{assembly,inline,yul,low-level,unsafe}	2025-10-31 23:32:55.850714+00	2025-10-31 23:47:32.948483+00	t
BVD-EVM-VIS-003	Missing State Variable Visibility	State variable lacks explicit visibility declaration	visibility	low	SWC-108	CWE-710	A2: Access Control	Explicitly declare state variable visibility (public/private/internal)	["uint256 public count;", "address private owner;", "mapping(address => uint256) internal balances;"]	["https://swcregistry.io/docs/SWC-108", "https://docs.soliditylang.org/en/latest/contracts.html#visibility-and-getters"]	{static}	0.05	{solidity}	State variable missing explicit visibility modifier defaulting to internal	{visibility,"state variable",public,private,internal}	2025-10-31 23:32:55.853958+00	2025-10-31 23:47:32.951452+00	t
BVD-EVM-LOG-004	EnumerableSet Unsafe Remove	Using EnumerableSet.remove() in a loop without proper checks can cause unexpected behavior	logic	high	SWC-128	CWE-834	A9: Using Components with Known Vulnerabilities	Store elements to remove in a temporary array, then remove them after iteration	["Store indices to remove before loop", "Iterate backwards when removing elements", "Use a separate array for deletions"]	["https://docs.openzeppelin.com/contracts/3.x/api/utils#EnumerableSet"]	{static}	0.1	{solidity}	Removing elements from EnumerableSet during iteration can skip elements or cause out-of-bounds access	{enumerable,remove,loop,iteration}	2025-10-31 23:32:55.860738+00	2025-10-31 23:47:32.954321+00	t
BVD-EVM-COM-002	Experimental Encoder	Contract uses experimental ABIEncoderV2 which has known bugs	compiler	high	SWC-102	CWE-937	A9: Using Components with Known Vulnerabilities	Upgrade to Solidity 0.8.0+ where ABIEncoderV2 is stable by default	["Remove 'pragma experimental ABIEncoderV2'", "Upgrade to Solidity 0.8.0 or higher"]	["https://docs.soliditylang.org/en/v0.8.0/080-breaking-changes.html"]	{static}	0.05	{solidity}	Use of experimental ABIEncoderV2 in Solidity versions before 0.8.0	{encoder,experimental,abi,compiler}	2025-10-31 23:32:55.866685+00	2025-10-31 23:47:32.957256+00	t
BVD-EVM-ASM-002	Incorrect Shift Order in Assembly	Assembly shift operations have operands in unexpected order	assembly	high	SWC-128	CWE-682	A1: Logic Errors	Review Solidity assembly shift syntax: shl(bits, value) and shr(bits, value)	["Correct: shl(8, value) shifts value left by 8 bits", "Correct: shr(8, value) shifts value right by 8 bits"]	["https://docs.soliditylang.org/en/latest/yul.html#evm-dialect"]	{static}	0.05	{solidity}	Shift operations in Yul have shift amount before value, opposite of many languages	{assembly,shift,shl,shr,yul}	2025-10-31 23:32:55.870978+00	2025-10-31 23:47:32.960971+00	t
BVD-EVM-COD-001	Multiple Constructor Definitions	Contract defines constructor multiple times	code-quality	high	SWC-128	CWE-710	A9: Code Quality	Remove duplicate constructor definitions	["Keep only one constructor", "Merge constructor logic"]	["https://docs.soliditylang.org/en/latest/contracts.html#constructors"]	{static}	0.01	{solidity}	Multiple constructor definitions in same contract	{constructor,duplicate}	2025-10-31 23:32:55.880414+00	2025-10-31 23:47:32.967389+00	t
BVD-EVM-COD-002	Reused Contract Name	Contract name is reused causing ambiguity	code-quality	high	SWC-128	CWE-710	A9: Code Quality	Use unique contract names	["Rename duplicate contracts", "Use unique identifiers"]	["https://docs.soliditylang.org/en/latest/style-guide.html#naming-conventions"]	{static}	0.05	{solidity}	Multiple contracts with same name in codebase causing namespace collision	{"name collision",contract,duplicate}	2025-10-31 23:32:55.884416+00	2025-10-31 23:47:32.970296+00	t
BVD-EVM-COM-003	Nested Struct in Mapping	Nested struct in mapping with deletions can cause data corruption in older Solidity versions	compiler	high	SWC-128	CWE-664	A4: Data Integrity	Upgrade to Solidity 0.8.0+ or avoid deleting nested structs in mappings	["Upgrade compiler version", "Use separate cleanup function", "Avoid delete on nested structs"]	["https://github.com/ethereum/solidity/issues/11053"]	{static}	0.1	{solidity}	Deleting nested struct in mapping leaves dirty data in older compiler versions	{struct,mapping,nested,delete,"compiler bug"}	2025-10-31 23:32:55.887508+00	2025-10-31 23:47:32.973232+00	t
BVD-EVM-DAN-001	Dynamic Array Length Assignment	Directly assigning array.length in Solidity <0.6.0 can cause data corruption	data-structure	high	SWC-128	CWE-129	A4: Data Integrity	Use push() and pop() methods instead of direct length manipulation	["Use array.push() to add elements", "Use array.pop() to remove elements", "Upgrade to Solidity 0.6.0+"]	["https://docs.soliditylang.org/en/v0.6.0/060-breaking-changes.html"]	{static}	0.05	{solidity}	Direct array length manipulation can leave uninitialized storage	{array,length,dynamic,storage}	2025-10-31 23:32:55.890401+00	2025-10-31 23:47:32.976435+00	t
BVD-EVM-LOG-005	Incorrect Caret Operator	Using ^ operator incorrectly, confusing it with exponentiation instead of XOR	logic	high	SWC-128	CWE-682	A1: Logic Errors	Use ** for exponentiation, not ^. The ^ operator is bitwise XOR	["Replace x ^ 2 with x ** 2 for squaring", "Use SafeMath.pow() for safe exponentiation"]	["https://docs.soliditylang.org/en/latest/types.html#operators"]	{static}	0.05	{solidity}	Developer confusion between ^ (XOR) and ** (exponentiation) operators leading to incorrect calculations	{caret,xor,exponentiation,operator}	2025-10-31 23:32:55.894495+00	2025-10-31 23:47:32.979922+00	t
BVD-EVM-ASM-003	Unsafe Yul Return	Using return(0, 0) in Yul discards return data and can cause issues	assembly	high	SWC-128	CWE-252	A4: Insecure Design	Specify proper return data location and size in assembly returns	["Use return(ptr, size) with actual data", "Return to Solidity code instead of assembly return"]	["https://docs.soliditylang.org/en/latest/yul.html"]	{static}	0.15	{solidity}	Return statement in Yul without proper data pointer and size	{yul,assembly,return,"inline assembly"}	2025-10-31 23:32:55.898009+00	2025-10-31 23:47:32.983904+00	t
BVD-EVM-COD-003	State Variable Shadowing	State variable shadows inherited variable	code-quality	high	SWC-119	CWE-710	A9: Code Quality	Rename shadowing variable	["Use unique variable names", "Check parent contracts for name conflicts"]	["https://swcregistry.io/docs/SWC-119"]	{static}	0.1	{solidity}	Derived contract declares state variable with same name as parent contract	{shadowing,inheritance,"state variable"}	2025-10-31 23:32:55.901156+00	2025-10-31 23:47:32.987336+00	t
BVD-EVM-LOG-006	Misused Boolean	Boolean constant misused in conditional logic, creating unreachable code	logic	high	SWC-110	CWE-561	A9: Logic Errors	Remove constant boolean conditions or fix the logic error	["Replace 'if (true)' with unconditional execution", "Remove 'if (false)' dead code branches"]	["https://swcregistry.io/docs/SWC-110"]	{static}	0.05	{solidity}	Boolean constant in conditional creates dead code or makes condition meaningless	{boolean,constant,"dead code",unreachable}	2025-10-31 23:32:55.904436+00	2025-10-31 23:47:32.990695+00	t
BVD-EVM-UNC-004	Send Ether Without Checks	Ether sent without checking if recipient can receive it	unchecked-return	high	SWC-126	CWE-252	A3: Unchecked Call	Check recipient code size or use pull payment pattern	["Implement pull payment pattern", "Check recipient.code.length > 0"]	["https://swcregistry.io/docs/SWC-126"]	{static}	0.15	{solidity}	Sending ether to address without verifying it can receive	{ether,send,receive,payable}	2025-10-31 23:32:55.907657+00	2025-10-31 23:47:32.994195+00	t
BVD-EVM-LOG-007	Tautological Compare	Comparison that is always true or always false	logic	high	SWC-110	CWE-570	A1: Logic Errors	Fix the comparison logic or remove the tautological condition	["Compare with correct variable", "Remove always-true conditions"]	["https://swcregistry.io/docs/SWC-110"]	{static}	0.05	{solidity}	Comparison expression that always evaluates to the same result regardless of inputs	{tautology,comparison,"logic error"}	2025-10-31 23:32:55.910638+00	2025-10-31 23:47:32.997902+00	t
BVD-EVM-MAL-001	Right-to-Left Override Character	Unicode RTLO character used to hide malicious code	malicious	high	SWC-130	CWE-838	A8: Malicious Code	Remove RTLO characters from source code	["Scan and remove Unicode RTLO characters", "Use ASCII-only identifiers"]	["https://swcregistry.io/docs/SWC-130", "https://github.com/crytic/slither/wiki/Detector-Documentation#right-to-left-override-character"]	{static}	0.01	{solidity}	Right-to-left override Unicode character hides code intent	{unicode,rtlo,malicious,trojan}	2025-10-31 23:32:55.914192+00	2025-10-31 23:47:33.000949+00	t
BVD-EVM-GAS-009	Costly Loop	Loop with expensive operations may hit gas limit	gas	low	SWC-113	CWE-400	A5: Gas Optimization	Limit loop iterations or use pagination	["Add maximum iteration limit", "Implement pagination pattern", "Use pull pattern instead"]	[]	{static}	0.25	{solidity}	Unbounded loop with expensive operations risks gas limit	{loop,"gas limit",dos}	2025-10-31 23:32:55.981268+00	2025-10-31 23:47:33.059619+00	t
BVD-EVM-LOG-009	Tautology or Contradiction	Boolean expression that is always true (tautology) or always false (contradiction)	logic	high	SWC-110	CWE-570	A1: Logic Errors	Review and fix the boolean logic	["Remove redundant conditions", "Fix contradictory requirements"]	["https://en.wikipedia.org/wiki/Tautology_(logic)"]	{static}	0.05	{solidity}	Boolean expression with predictable outcome indicating logic error	{tautology,contradiction,logic,boolean}	2025-10-31 23:32:55.920363+00	2025-10-31 23:47:33.007385+00	t
BVD-EVM-COM-004	Storage Signed Integer Array Bug	Assigning array of signed integers to storage can corrupt data in Solidity <0.7.0	compiler	high	SWC-128	CWE-191	A4: Data Integrity	Upgrade to Solidity 0.7.0 or higher	["Update pragma to ^0.7.0 or higher", "Use unsigned integers where possible"]	["https://github.com/ethereum/solidity/issues/9088"]	{static}	0.05	{solidity}	Compiler bug in Solidity <0.7.0 corrupts signed integer arrays assigned to storage	{"signed integer",array,storage,"compiler bug"}	2025-10-31 23:32:55.923495+00	2025-10-31 23:47:33.010321+00	t
BVD-EVM-LOG-010	Pre-declared Local Variable	Local variable name shadows a previously declared variable	logic	high	SWC-128	CWE-710	A9: Code Quality	Use unique variable names within scope	["Rename shadowing variable", "Use different variable names"]	["https://docs.soliditylang.org/en/latest/security-considerations.html"]	{static}	0.15	{solidity}	Variable declaration shadows earlier declaration in same scope causing confusion	{shadowing,variable,redeclaration}	2025-10-31 23:32:55.926357+00	2025-10-31 23:47:33.013069+00	t
BVD-EVM-DAT-002	Delete Nested Mapping	Using delete on nested mapping doesn't delete nested data	data-structure	high	SWC-128	CWE-459	A4: Data Integrity	Manually delete nested mapping values before deleting parent	["Delete nested mappings explicitly", "Iterate and delete nested values first"]	["https://docs.soliditylang.org/en/latest/types.html#delete"]	{static}	0.1	{solidity}	Delete operator on struct containing mapping only resets non-mapping fields	{delete,mapping,nested,struct}	2025-10-31 23:32:55.929615+00	2025-10-31 23:47:33.016684+00	t
BVD-EVM-GAS-010	Delegatecall in Loop	Delegatecall inside loop consumes excessive gas	gas	low	SWC-113	CWE-400	A5: Gas Optimization	Minimize delegatecalls or restructure to avoid loop	["Move delegatecall outside loop", "Batch operations differently"]	[]	{static}	0.2	{solidity}	Delegatecall in loop can hit gas limits on large arrays	{delegatecall,loop,gas}	2025-10-31 23:32:55.932965+00	2025-10-31 23:47:33.019916+00	t
BVD-EVM-CEN-001	Centralization Risk	Critical functions controlled by single account create centralization risk	access-control	low	SWC-128	CWE-710	A2: Access Control	Implement multi-signature wallet or decentralized governance	["Use multi-sig for admin functions", "Implement timelock", "Add governance system"]	[]	{static}	0.3	{solidity}	Single point of failure in access control	{centralization,owner,admin,governance}	2025-10-31 23:32:55.937155+00	2025-10-31 23:47:33.023562+00	t
BVD-EVM-CRY-001	Unsafe ecrecover	ecrecover can return zero address on invalid signature	cryptography	low	SWC-117	CWE-347	A8: Cryptographic Failures	Check ecrecover return value against zero address	["require(signer != address(0))", "Use OpenZeppelin ECDSA library"]	["https://swcregistry.io/docs/SWC-117"]	{static}	0.15	{solidity}	ecrecover usage without zero address validation	{ecrecover,signature,"zero address"}	2025-10-31 23:32:55.940395+00	2025-10-31 23:47:33.026663+00	t
BVD-EVM-OPT-002	State Variable Should Be Constant	State variable never changes and should be declared constant	gas	low	SWC-110	CWE-1164	A5: Gas Optimization	Add constant keyword to immutable state variables	["uint256 constant MAX_SUPPLY = 10000"]	[]	{static}	0.2	{solidity}	State variable with fixed value wastes storage	{constant,"state variable",gas}	2025-10-31 23:32:55.942931+00	2025-10-31 23:47:33.029587+00	t
BVD-EVM-OPT-003	State Variable Should Be Immutable	State variable set only in constructor should be immutable	gas	low	SWC-110	CWE-1164	A5: Gas Optimization	Add immutable keyword to variables set only in constructor	["address immutable owner"]	[]	{static}	0.2	{solidity}	Constructor-only state variable wastes storage slots	{immutable,"state variable",gas,constructor}	2025-10-31 23:32:55.946276+00	2025-10-31 23:47:33.032661+00	t
BVD-EVM-GAS-002	Unused Public Function	Public function never called internally, should be external	gas	low	SWC-110	CWE-1164	A5: Gas Optimization	Change visibility to external	["Replace 'public' with 'external'"]	[]	{static}	0.15	{solidity}	Public function not called internally wastes gas on parameter copying	{public,external,gas,visibility}	2025-10-31 23:32:55.949009+00	2025-10-31 23:47:33.035552+00	t
BVD-EVM-GAS-003	Use Constant for Literals	Repeated literal values should be constants	gas	low	SWC-110	CWE-1164	A5: Gas Optimization	Define constant for repeated literal values	["uint256 constant MAGIC_NUMBER = 12345"]	[]	{static}	0.25	{solidity}	Repeated literal values waste bytecode space	{constant,literal,gas}	2025-10-31 23:32:55.951644+00	2025-10-31 23:47:33.038653+00	t
BVD-EVM-GAS-004	Modifier Used Once	Modifier used only once, should be inlined	gas	low	SWC-110	CWE-1164	A5: Gas Optimization	Inline modifier code or remove modifier	["Move modifier logic into function", "Remove modifier wrapper"]	[]	{static}	0.2	{solidity}	Single-use modifier adds unnecessary function call overhead	{modifier,gas,inline}	2025-10-31 23:32:55.955024+00	2025-10-31 23:47:33.042327+00	t
BVD-EVM-GAS-005	Internal Function Used Once	Internal function called only once, should be inlined	gas	low	SWC-110	CWE-1164	A5: Gas Optimization	Inline function code	["Move function body to call site", "Remove function wrapper"]	[]	{static}	0.25	{solidity}	Single-use internal function adds overhead without reuse benefit	{internal,gas,inline}	2025-10-31 23:32:55.959613+00	2025-10-31 23:47:33.045364+00	t
BVD-EVM-COD-005	Empty Require or Revert	require() or revert() without error message	code-quality	low	SWC-110	CWE-703	A9: Code Quality	Add descriptive error messages to all require/revert statements	["require(condition, \\"Descriptive error message\\")", "Use custom errors in Solidity 0.8.4+"]	["https://docs.soliditylang.org/en/latest/control-structures.html#error-handling-assert-require-revert-and-exceptions"]	{static}	0.05	{solidity}	Error handling without message reduces debuggability	{require,revert,"error message"}	2025-10-31 23:32:55.990364+00	2025-10-31 23:47:33.071928+00	t
BVD-EVM-REE-007	NonReentrant Modifier Order	nonReentrant modifier should be first to be effective	reentrancy	low	SWC-107	CWE-841	A1: Reentrancy	Place nonReentrant as first modifier	["Move nonReentrant to beginning of modifier list"]	["https://docs.openzeppelin.com/contracts/4.x/api/security#ReentrancyGuard"]	{static}	0.15	{solidity}	NonReentrant modifier after other modifiers may not protect properly	{nonreentrant,modifier,order}	2025-10-31 23:32:55.993719+00	2025-10-31 23:47:33.07652+00	t
BVD-EVM-TOK-007	Unsafe ERC721 Mint	ERC721 mint without safe transfer check	token	low	SWC-128	CWE-252	A4: Token Security	Use _safeMint instead of _mint	["Replace _mint with _safeMint", "Implement onERC721Received check"]	["https://eips.ethereum.org/EIPS/eip-721"]	{static}	0.15	{solidity}	Minting ERC721 without checking recipient can receive NFTs	{erc721,nft,mint,"safe transfer"}	2025-10-31 23:32:55.99641+00	2025-10-31 23:47:33.080886+00	t
BVD-EVM-COM-005	Push0 Opcode Compatibility	Contract uses PUSH0 opcode not supported on all EVM chains	compiler	low	SWC-128	CWE-758	A4: Insecure Design	Specify EVM version in compiler settings to match target chain	["Set 'evmVersion: \\"paris\\"' for pre-Shanghai chains", "Use Shanghai-compatible chains only"]	["https://eips.ethereum.org/EIPS/eip-3855"]	{static}	0.1	{solidity}	PUSH0 opcode introduced in Shanghai hard fork not available on all chains	{push0,evm,opcode,compatibility}	2025-10-31 23:32:55.999117+00	2025-10-31 23:47:33.084969+00	t
BVD-EVM-COD-006	Empty Block	Empty code block without comment explaining intent	code-quality	low	SWC-110	CWE-1164	A9: Code Quality	Add comment explaining empty block or remove unnecessary code	["Add comment: // solhint-disable-next-line no-empty-blocks", "Remove empty function or block"]	["https://docs.soliditylang.org/en/latest/style-guide.html"]	{static}	0.2	{solidity}	Empty code block may indicate incomplete implementation or dead code	{"empty block","dead code"}	2025-10-31 23:32:56.001978+00	2025-10-31 23:47:33.088455+00	t
BVD-EVM-COD-007	Large Literal Value	Large numeric literal without separator reduces readability	code-quality	low	SWC-110	CWE-1164	A9: Code Quality	Use underscores as thousands separator	["Replace 1000000 with 1_000_000", "Use named constants for large values"]	["https://docs.soliditylang.org/en/latest/types.html#rational-and-integer-literals"]	{static}	0.15	{solidity}	Large numeric literals without formatting are error-prone	{literal,readability,"magic number"}	2025-10-31 23:32:56.00467+00	2025-10-31 23:47:33.091915+00	t
BVD-EVM-COD-008	TODO Comment	Code contains TODO comment indicating incomplete implementation	code-quality	low	SWC-110	CWE-1164	A9: Code Quality	Complete implementation or create issue to track work	["Implement the TODO item", "Remove TODO if completed", "Create GitHub issue for tracking"]	[]	{static}	0.3	{solidity}	TODO comment indicates incomplete or unfinished code	{todo,incomplete,comment}	2025-10-31 23:32:56.007378+00	2025-10-31 23:47:33.095709+00	t
BVD-EVM-COD-009	Inconsistent Type Names	Type naming does not follow conventions	code-quality	low	SWC-110	CWE-1164	A9: Code Quality	Follow Solidity style guide for naming conventions	["Use CapWords for contracts and structs", "Use mixedCase for functions and variables"]	["https://docs.soliditylang.org/en/latest/style-guide.html#naming-conventions"]	{static}	0.25	{solidity}	Type naming violates Solidity style guide conventions	{naming,convention,style}	2025-10-31 23:32:56.010205+00	2025-10-31 23:47:33.099602+00	t
BVD-EVM-COD-010	Unused Custom Error	Custom error defined but never used	code-quality	low	SWC-110	CWE-1164	A9: Code Quality	Use the custom error or remove the definition	["Replace revert() with custom error", "Remove unused error definition"]	["https://docs.soliditylang.org/en/latest/contracts.html#errors"]	{static}	0.15	{solidity}	Custom error declaration without any usage in contract	{unused,error,"dead code"}	2025-10-31 23:32:56.013306+00	2025-10-31 23:47:33.102831+00	t
BVD-EVM-COD-011	Redundant Statement	Statement has no effect and can be removed	code-quality	low	SWC-110	CWE-1164	A9: Code Quality	Remove redundant statement	["Remove statement with no side effects", "Assign result to variable if needed"]	[]	{static}	0.1	{solidity}	Statement computes value but doesn't use or store result	{redundant,no-op,"dead code"}	2025-10-31 23:32:56.016288+00	2025-10-31 23:47:33.105903+00	t
BVD-EVM-COD-012	Unused State Variable	State variable declared but never used	code-quality	low	SWC-110	CWE-1164	A9: Code Quality	Remove unused state variables to save gas	["Delete unused variable", "Use the variable if it was forgotten"]	[]	{static}	0.15	{solidity}	State variable declared but not read or written anywhere	{unused,"state variable","dead code"}	2025-10-31 23:32:56.019268+00	2025-10-31 23:47:33.109246+00	t
BVD-EVM-ASM-004	Constant Function with Assembly	Function marked constant/view/pure contains assembly that may change state	assembly	low	SWC-128	CWE-710	A9: Code Quality	Verify assembly doesn't modify state or remove view/pure modifier	["Review assembly for state changes", "Remove constant/view/pure if assembly modifies state"]	["https://docs.soliditylang.org/en/latest/contracts.html#view-functions"]	{static}	0.2	{solidity}	Function with state mutability restriction contains assembly that cannot be statically verified	{assembly,view,pure,constant}	2025-10-31 23:32:56.022089+00	2025-10-31 23:47:33.112479+00	t
BVD-EVM-COD-014	Local Variable Shadowing	Local variable shadows state variable or inherited variable	code-quality	low	SWC-119	CWE-710	A9: Code Quality	Rename local variable to avoid shadowing	["Use different variable name", "Add prefix/suffix to distinguish"]	["https://swcregistry.io/docs/SWC-119"]	{static}	0.2	{solidity}	Local variable name hides state variable or inherited name	{shadowing,"local variable"}	2025-10-31 23:32:56.027658+00	2025-10-31 23:47:33.121538+00	t
BVD-EVM-INI-004	Uninitialized Local Variable	Local variable used before initialization	initialization	low	SWC-109	CWE-457	A1: Logic Errors	Initialize variable before use	["Assign value before reading", "Initialize in declaration"]	["https://swcregistry.io/docs/SWC-109"]	{static}	0.1	{solidity}	Local variable read before any assignment	{uninitialized,"local variable"}	2025-10-31 23:32:56.030337+00	2025-10-31 23:47:33.124778+00	t
BVD-EVM-DOS-004	Return Bomb	External call can return huge data causing out-of-gas	dos	low	SWC-113	CWE-400	A5: Denial of Service	Limit return data size or use assembly with returndatasize()	["Check returndatasize() before copying", "Limit expected return data size"]	["https://github.com/nomad-xyz/ExcessivelySafeCall"]	{static}	0.2	{solidity}	Low-level call copies all return data which can exhaust gas	{"return bomb",dos,gas,"external call"}	2025-10-31 23:32:56.034042+00	2025-10-31 23:47:33.128973+00	t
BVD-EVM-INI-003	Function Initializing State	Function name suggests initialization but isn't protected	initialization	low	SWC-128	CWE-665	A2: Access Control	Add initialization protection or rename function	["Add onlyOwner modifier", "Use initializer pattern", "Check initialization flag"]	[]	{static}	0.25	{solidity}	Function appears to be initializer but lacks access control	{initialization,setup,"access control"}	2025-10-31 23:32:56.036953+00	2025-10-31 23:47:33.131988+00	t
BVD-EVM-COD-015	Dead Code	Unreachable code detected	code-quality	low	SWC-110	CWE-561	A9: Code Quality	Remove unreachable code	["Delete code after return/revert", "Fix control flow logic"]	["https://swcregistry.io/docs/SWC-110"]	{static}	0.05	{solidity}	Code that can never be executed due to control flow	{"dead code",unreachable}	2025-10-31 23:32:56.039514+00	2025-10-31 23:47:33.134719+00	t
BVD-EVM-LOG-012	Assert with State Change	Assert statement contains expression with state-changing side effects	logic	low	SWC-110	CWE-670	A1: Logic Errors	Separate state changes from assertions, perform state change first	["Extract state change before assert", "Use require instead of assert for user input validation"]	["https://docs.soliditylang.org/en/latest/control-structures.html#error-handling-assert-require-revert-and-exceptions"]	{static}	0.15	{solidity}	Assert condition includes function calls that modify state, violating assert semantics	{assert,"state change","side effect"}	2025-10-31 23:32:56.042496+00	2025-10-31 23:47:33.137394+00	t
BVD-EVM-COD-016	Built-in Symbol Shadowing	Variable or function shadows built-in Solidity symbol	code-quality	low	SWC-119	CWE-710	A9: Code Quality	Rename variable to avoid shadowing built-in	["Don't use names like 'msg', 'block', 'tx'", "Avoid shadowing 'now', 'this', 'super'"]	["https://docs.soliditylang.org/en/latest/units-and-global-variables.html"]	{static}	0.1	{solidity}	Variable name shadows Solidity built-in global or reserved word	{shadowing,built-in,reserved}	2025-10-31 23:32:56.045439+00	2025-10-31 23:47:33.140215+00	t
BVD-EVM-COD-017	Void Constructor	Constructor is empty and can be removed	code-quality	low	SWC-110	CWE-1164	A9: Code Quality	Remove empty constructor	["Delete empty constructor definition"]	[]	{static}	0.15	{solidity}	Constructor with no body serves no purpose	{constructor,empty,"dead code"}	2025-10-31 23:32:56.048522+00	2025-10-31 23:47:33.142928+00	t
BVD-EVM-INT-004	Missing Interface Inheritance	Contract implements interface functions but doesn't declare inheritance	interface	low	SWC-128	CWE-1164	A9: Code Quality	Explicitly declare interface inheritance	["Add 'is IInterface' to contract declaration", "Properly declare all inherited interfaces"]	["https://docs.soliditylang.org/en/latest/contracts.html#interfaces"]	{static}	0.2	{solidity}	Contract appears to implement interface but doesn't declare it	{interface,inheritance,declaration}	2025-10-31 23:32:56.051882+00	2025-10-31 23:47:33.14594+00	t
BVD-EVM-COD-018	Unused Import	Imported contract or library is not used	code-quality	low	SWC-110	CWE-1164	A9: Code Quality	Remove unused imports	["Delete unused import statement"]	[]	{static}	0.15	{solidity}	Import statement for contract never referenced in code	{import,unused,"dead code"}	2025-10-31 23:32:56.056353+00	2025-10-31 23:47:33.149498+00	t
BVD-EVM-COD-019	Function Pointer Constructor	Old-style constructor using function with contract name	code-quality	low	SWC-128	CWE-710	A9: Code Quality	Use constructor() keyword instead	["Replace 'function ContractName()' with 'constructor()'", "Update to modern Solidity syntax"]	["https://docs.soliditylang.org/en/latest/050-breaking-changes.html"]	{static}	0.05	{solidity}	Deprecated constructor syntax using function name	{constructor,deprecated,legacy}	2025-10-31 23:32:56.059962+00	2025-10-31 23:47:33.15279+00	t
BVD-EVM-EVE-001	State Change Without Event	State variable changed without emitting event	events	low	SWC-110	CWE-1164	A9: Code Quality	Emit event when changing important state	["Add event emission after state change", "Create appropriate event definition"]	["https://docs.soliditylang.org/en/latest/contracts.html#events"]	{static}	0.25	{solidity}	State modification without logging event reduces transparency	{event,"state change",logging}	2025-10-31 23:32:56.065253+00	2025-10-31 23:47:33.156398+00	t
BVD-EVM-COD-020	Multiple Modifier Placeholders	Modifier contains multiple _ placeholders which is confusing	code-quality	low	SWC-110	CWE-710	A9: Code Quality	Use only one _ placeholder per modifier	["Refactor modifier to have single _", "Split into multiple modifiers"]	["https://docs.soliditylang.org/en/latest/contracts.html#function-modifiers"]	{static}	0.15	{solidity}	Multiple underscore placeholders make control flow unclear	{modifier,placeholder,underscore}	2025-10-31 23:32:56.070165+00	2025-10-31 23:47:33.160614+00	t
BVD-EVM-UNC-005	Unchecked Return Value	Function return value not checked for errors	unchecked-return	low	SWC-104	CWE-252	A3: Unchecked Call	Check return values or use SafeERC20	["Check boolean return value", "Use SafeERC20 wrapper", "Handle failure case"]	["https://swcregistry.io/docs/SWC-104"]	{static}	0.2	{solidity}	Return value indicating success/failure not checked	{unchecked,"return value"}	2025-10-31 23:32:56.077359+00	2025-10-31 23:47:33.168794+00	t
BVD-EVM-COD-004	Constant Function Changes State	Function marked constant, view, or pure modifies contract state	code-quality	high	SWC-128	CWE-710	A9: Code Quality	Remove constant/view/pure modifier or eliminate state changes	["Remove view/pure modifier if function modifies state", "Move state changes to separate non-constant function", "Use memory variables instead of storage"]	["https://docs.soliditylang.org/en/latest/contracts.html#view-functions", "https://swcregistry.io/docs/SWC-128"]	{static}	0.1	{solidity}	Function with state mutability restriction (view/pure/constant) contains operations that modify state	{constant,view,pure,"state change",mutability}	2025-10-31 23:32:56.080213+00	2025-10-31 23:47:33.172248+00	t
BVD-EVM-LOC-001	Contract Locks Ether	Contract accepts ether but has no withdraw function, permanently locking funds	locked-ether	high	SWC-132	CWE-404	A4: Insecure Design	Add withdraw function or make contract non-payable	["Add withdraw function with access control", "Implement selfdestruct with owner check", "Remove payable functions if ether handling not needed"]	["https://swcregistry.io/docs/SWC-132", "https://consensys.github.io/smart-contract-best-practices/development-recommendations/general/force-feeding/"]	{static}	0.15	{solidity,vyper}	Contract with payable functions or fallback but no mechanism to withdraw ether	{"locked ether",withdraw,payable,"stuck funds"}	2025-10-31 23:32:56.083564+00	2025-10-31 23:47:33.176365+00	t
BVD-EVM-COL-001	Function Selector Collision	Function selectors collide causing incorrect function routing and potential exploits	collision	high	SWC-133	CWE-477	A4: Insecure Design	Rename functions to avoid selector collision	["Use different function names", "Add parameters to change function signature", "Review proxy function selectors for conflicts"]	["https://swcregistry.io/docs/SWC-133", "https://github.com/ethereum/solidity/issues/3556"]	{static}	0.05	{solidity}	Multiple functions hash to same 4-byte selector causing routing ambiguity	{selector,collision,"function signature","hash collision"}	2025-10-31 23:32:56.086663+00	2025-10-31 23:47:33.179938+00	t
BVD-EVM-ERC-001	Incorrect ERC721 Interface	ERC721 implementation doesn't match standard interface causing incompatibility	interface	high	SWC-128	CWE-704	A4: Insecure Design	Implement ERC721 interface correctly according to EIP-721	["Inherit from OpenZeppelin ERC721", "Implement all required ERC721 functions", "Match function signatures exactly to standard"]	["https://eips.ethereum.org/EIPS/eip-721", "https://docs.openzeppelin.com/contracts/4.x/erc721"]	{static}	0.1	{solidity}	NFT contract claims ERC721 compatibility but interface deviates from standard	{erc721,nft,interface,standard,compliance}	2025-10-31 23:32:56.089453+00	2025-10-31 23:47:33.184036+00	t
BVD-EVM-ERC-002	Incorrect ERC20 Interface	ERC20 implementation doesn't match standard interface causing incompatibility	interface	high	SWC-128	CWE-704	A4: Insecure Design	Implement ERC20 interface correctly according to EIP-20	["Inherit from OpenZeppelin ERC20", "Implement all required ERC20 functions", "Match function signatures and return types to standard"]	["https://eips.ethereum.org/EIPS/eip-20", "https://docs.openzeppelin.com/contracts/4.x/erc20"]	{static}	0.1	{solidity}	Token contract claims ERC20 compatibility but interface deviates from standard	{erc20,token,interface,standard,compliance}	2025-10-31 23:32:56.092531+00	2025-10-31 23:47:33.187629+00	t
BVD-EVM-COM-006	ABI Encoder V2 Array Bug	Solidity compiler bug (0.4.7-0.5.9) affecting ABI encoder with nested arrays can cause data corruption	compiler	high	SWC-102	CWE-1103	A9: Using Components with Known Vulnerabilities	Upgrade to Solidity 0.5.10 or higher, avoid nested arrays with ABI encoder v2	["Upgrade pragma solidity to ^0.5.10 or higher", "Avoid nested array structures with external/public functions", "Use alternative data structures"]	["https://github.com/ethereum/solidity/issues/6643", "https://blog.solidityscan.com/abi-encoder-v2-array-bug-45a9e99ac7df"]	{static}	0.05	{solidity}	Contract uses ABI encoder v2 with nested arrays on vulnerable Solidity version	{abi,encoder,"nested array","compiler bug","data corruption"}	2025-10-31 23:32:56.095462+00	2025-10-31 23:47:33.190975+00	t
BVD-EVM-DAT-003	Array Passed By Value	Storage array passed by value instead of reference wastes gas and creates unexpected copy semantics	data-structure	high	SWC-128	CWE-1126	A6: Resource Management	Pass storage arrays by reference using 'storage' keyword, not 'memory' or implicit copy	["function processArray(uint[] storage arr) internal", "Avoid passing storage arrays to external/public functions", "Use memory arrays for temporary data only"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#array-by-reference"]	{static}	0.05	{solidity}	Storage array is passed to function that receives it as memory/value instead of storage reference, causing full array copy	{array,storage,reference,memory,copy,gas}	2025-10-31 23:32:56.103409+00	2025-10-31 23:47:33.198538+00	t
BVD-EVM-COM-007	Contract Name Reuse	Multiple contracts with same name cause compilation artifact confusion and deployment errors	compiler	medium	SWC-135	CWE-1109	A9: Configuration	Rename contracts to have unique names, use unique contract names across all files	["Rename duplicate contracts to unique names", "Use file-based namespacing conventions", "Verify compilation artifacts point to correct contracts"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#name-reused"]	{static}	0	{solidity}	Two or more contracts in the codebase share the same name, causing artifact collision	{name,duplicate,contract,compilation,artifact}	2025-10-31 23:32:56.112762+00	2025-10-31 23:47:33.210554+00	t
BVD-EVM-ACC-007	Unprotected Security-Critical Variable	State variables marked as security-sensitive lack proper access control protections	access-control	high	SWC-105	CWE-284	A1: Access Control	Add access control modifiers (onlyOwner, onlyRole) to functions modifying sensitive variables	["function setSensitiveVar(uint val) external onlyOwner", "Use OpenZeppelin AccessControl", "Implement role-based access control for sensitive state"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#protected-vars"]	{static}	0.15	{solidity}	State variable is marked with @custom:security or similar annotation but functions modifying it lack access control checks	{"access control",protected,sensitive,authorization,privileged}	2025-10-31 23:32:56.116447+00	2025-10-31 23:47:33.21398+00	t
BVD-EVM-COM-008	Public Nested Mapping Bug	Solidity pre-0.5.0 bug with public nested mappings causes incorrect getter generation	compiler	high	SWC-102	CWE-1103	A9: Using Components with Known Vulnerabilities	Upgrade to Solidity 0.5.0 or higher, or make nested mappings private/internal	["Upgrade pragma solidity to ^0.5.0 or higher", "Change public nested mappings to private/internal", "Create explicit getter functions"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#public-mappings-nested"]	{static}	0.05	{solidity}	Public mapping with nested structure on Solidity version prior to 0.5.0	{mapping,nested,public,"compiler bug",getter}	2025-10-31 23:32:56.119717+00	2025-10-31 23:47:33.217321+00	t
BVD-EVM-SHA-001	State Variable Shadowing	State variable in derived contract shadows state variable from base contract, causing confusion and potential bugs	data-structure	high	SWC-119	CWE-1109	A1: Logic Errors	Rename shadowing variable to unique name or remove redundant declaration	["Rename variable to avoid name collision", "Use different variable names in derived contracts", "Review inheritance hierarchy for variable conflicts"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#state-variable-shadowing", "https://swcregistry.io/docs/SWC-119"]	{static}	0.1	{solidity}	Derived contract declares state variable with same name as base contract state variable	{shadowing,inheritance,"state variable","name collision","derived contract"}	2025-10-31 23:32:56.123392+00	2025-10-31 23:47:33.220241+00	t
BVD-EVM-INI-005	Uninitialized State Variable	State variable not initialized in constructor defaults to zero, potentially causing security issues	initialization	high	SWC-109	CWE-665	A6: Initialization	Initialize all state variables explicitly in constructor or at declaration	["constructor() { owner = msg.sender; }", "address public owner = msg.sender;", "Explicitly initialize all critical state variables"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#uninitialized-state-variables", "https://swcregistry.io/docs/SWC-109"]	{static}	0.2	{solidity}	State variable is never assigned a value in constructor or at declaration, defaulting to zero	{uninitialized,"state variable",constructor,"default value",zero}	2025-10-31 23:32:56.126489+00	2025-10-31 23:47:33.223582+00	t
BVD-EVM-SIG-005	EIP-2612 DOMAIN_SEPARATOR Collision	EIP-2612 permit function has DOMAIN_SEPARATOR that can collide across chains/forks, enabling replay attacks	signature	high	SWC-117	CWE-294	A2: Signature/Cryptography	Include chainId in DOMAIN_SEPARATOR and recompute on chain forks, use EIP-712 correctly	["DOMAIN_SEPARATOR = keccak256(abi.encode(TYPE_HASH, name, version, block.chainid, address(this)))", "Implement _domainSeparatorV4() to handle chain forks", "Use OpenZeppelin's EIP712 implementation"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#domain-separator-collision", "https://eips.ethereum.org/EIPS/eip-2612", "https://eips.ethereum.org/EIPS/eip-712"]	{static}	0.1	{solidity}	EIP-2612 permit implementation computes DOMAIN_SEPARATOR without proper chain ID handling or fork protection	{eip-2612,permit,"domain separator","replay attack",eip-712,signature}	2025-10-31 23:32:56.132293+00	2025-10-31 23:47:33.229256+00	t
BVD-EVM-UNC-006	Unchecked ERC20 Transfer	Return value of ERC20 transfer or transferFrom is not checked for success, allowing operations to proceed even when token transfer fails	unchecked-return	high	SWC-104	CWE-252	A6: Security Misconfiguration	Use SafeERC20 library or explicitly check the boolean return value of transfer/transferFrom operations	["Use OpenZeppelin SafeERC20: token.safeTransfer(to, amount)", "Check return value: require(token.transfer(to, amount), 'Transfer failed')", "Handle tokens that return false on failure rather than reverting"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#unchecked-transfer", "https://docs.openzeppelin.com/contracts/api/token/erc20#SafeERC20"]	{static}	0.05	{solidity}	ERC20 transfer or transferFrom call does not validate the boolean return value, allowing silent failures for non-reverting tokens	{erc20,transfer,transferFrom,unchecked,"return value","silent failure"}	2025-10-31 23:32:56.140859+00	2025-10-31 23:47:33.240199+00	t
BVD-EVM-DEL-003	Delegatecall in Loop	Payable function uses delegatecall within a loop, causing msg.value to be credited multiple times and enabling fund theft	delegatecall	high	SWC-113	CWE-670	A1: Logic Errors	Verify that delegatecall targets are non-payable or avoid using delegatecall inside loops. Use alternative patterns for batch operations.	["Remove payable modifier if delegatecall is in loop", "Ensure delegatecall targets are non-payable contracts", "Use call instead of delegatecall for loop iterations", "Track and validate total value sent matches msg.value"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#delegatecall-loop", "https://swcregistry.io/docs/SWC-113"]	{static}	0.05	{solidity}	Payable function contains delegatecall inside loop, allowing msg.value to be credited multiple times in each iteration	{delegatecall,loop,msg.value,payable,"multiple credit"}	2025-10-31 23:32:56.148578+00	2025-10-31 23:47:33.251649+00	t
BVD-EVM-MSG-001	msg.value in Loop	msg.value is referenced inside a loop, allowing its value to be counted multiple times and enabling users to deposit more than sent	dangerous-operations	high	SWC-113	CWE-670	A1: Logic Errors	Provide explicit arrays of amounts alongside recipient arrays, verifying the total matches msg.value. Avoid using msg.value inside loops.	["Pass amount array: function distribute(address[] recipients, uint[] amounts) payable", "Validate total: require(sum(amounts) == msg.value)", "Use msg.value only once outside loop", "Implement separate deposit and distribute functions"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#msg-value-loop", "https://swcregistry.io/docs/SWC-113"]	{static}	0.05	{solidity}	Loop body references msg.value, causing the same value to be counted in each iteration instead of being divided	{msg.value,loop,"multiple count",deposit,"value accounting"}	2025-10-31 23:32:56.151691+00	2025-10-31 23:47:33.254931+00	t
BVD-EVM-COD-030	Boolean Equality Comparison	Boolean variables compared to true/false constants unnecessarily, reducing code clarity	code-quality	informational	\N	CWE-1099	A04: Insecure Design	Use boolean variables directly in conditionals instead of comparing to true/false	["Change 'if (x == true)' to 'if (x)'", "Change 'if (y == false)' to 'if (!y)'", "Remove redundant boolean comparisons"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#boolean-equality"]	{static}	0.1	{solidity}	\N	{}	2025-10-31 23:32:56.262816+00	2025-10-31 23:47:33.3675+00	t
BVD-EVM-ORA-004	Pyth Deprecated Functions	Usage of deprecated Pyth oracle functions that may cause unexpected failures or return stale/incorrect price data	oracle	medium	SWC-111	CWE-477	A6: Security Misconfiguration	Replace deprecated Pyth functions with current recommended API methods. Consult Pyth Network API reference for updated function signatures and migration paths.	["Replace getPrice() with getPriceUnsafe() or getPriceNoOlderThan()", "Use getEmaPrice() instead of deprecated price feed methods", "Consult https://api-reference.pyth.network/ for current functions", "Update contract dependencies to latest Pyth SDK version"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#pyth-deprecated-functions", "https://api-reference.pyth.network/", "https://docs.pyth.network/price-feeds/api-reference"]	{static}	0.05	{solidity}	Contract uses deprecated Pyth oracle functions that are no longer supported and may behave unexpectedly	{pyth,oracle,deprecated,"price feed","stale data"}	2025-10-31 23:32:56.165948+00	2025-10-31 23:47:33.265845+00	t
BVD-EVM-ORA-005	Pyth Unchecked Confidence	Pyth oracle price data consumed without validating confidence intervals, potentially using unreliable price information	oracle	medium	SWC-111	CWE-754	A6: Security Misconfiguration	Always validate Pyth price confidence levels before consuming price data. Reject prices with confidence intervals exceeding acceptable thresholds for your application.	["Check price.conf and ensure it's within acceptable bounds", "Implement: require(price.conf < maxAcceptableConfidence, 'Low confidence')", "Use getPriceNoOlderThan() which includes confidence validation", "Define application-specific confidence thresholds based on risk tolerance"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#pyth-unchecked-confidence", "https://docs.pyth.network/price-feeds/best-practices", "https://docs.pyth.network/price-feeds/pull-updates"]	{static}	0.1	{solidity}	Contract obtains Pyth price data but does not validate the confidence interval field before using the price	{pyth,oracle,confidence,"price feed",validation,reliability}	2025-10-31 23:32:56.17057+00	2025-10-31 23:47:33.270053+00	t
BVD-EVM-ORA-006	Pyth Unchecked PublishTime	Pyth oracle price data used without verifying publication timestamp freshness, potentially consuming stale price information	oracle	medium	SWC-111	CWE-672	A6: Security Misconfiguration	Always check the publishTime field from Pyth price data and ensure it's sufficiently recent for your use case. Reject prices older than your maximum staleness threshold.	["Validate: require(block.timestamp - price.publishTime < maxStaleness)", "Use getPriceNoOlderThan(age) to enforce freshness automatically", "Define staleness threshold based on asset volatility and risk", "Implement fallback oracle if Pyth price is too stale"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#pyth-unchecked-publishtime", "https://docs.pyth.network/price-feeds/best-practices", "https://docs.pyth.network/price-feeds/schedule-price-updates"]	{static}	0.1	{solidity}	Contract retrieves Pyth price data but does not validate the publishTime timestamp to ensure price freshness	{pyth,oracle,timestamp,"price feed",staleness,freshness}	2025-10-31 23:32:56.174972+00	2025-10-31 23:47:33.274876+00	t
BVD-EVM-ORA-007	Chronicle Unchecked Price Validity	Chronicle oracle price data consumed without validation checks, potentially using inactive or invalid oracle values	oracle	medium	SWC-111	CWE-754	A6: Security Misconfiguration	Validate Chronicle oracle responses to ensure the oracle is active and the price data is valid before consumption. Check return values and oracle status.	["Verify oracle.isActive() before consuming price data", "Check return value: (bool success, uint price) = oracle.tryRead()", "Implement require(success, 'Invalid oracle response')", "Use Chronicle's read() which reverts on invalid data"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#chronicle-unchecked-price", "https://chroniclelabs.org/", "https://docs.chroniclelabs.org/"]	{static}	0.15	{solidity}	Contract obtains Chronicle oracle price without validating oracle active status or price validity	{chronicle,oracle,validation,"price feed",inactive}	2025-10-31 23:32:56.178506+00	2025-10-31 23:47:33.279622+00	t
BVD-EVM-RND-001	Unprotected Randomness Request	Gelato VRF randomness request function accessible without proper access controls, enabling unauthorized users to trigger randomness requests and manipulate outcomes	randomness	medium	SWC-105	CWE-284	A1: Access Control	Restrict randomness request functions to authorized users only using access control modifiers. Prevent arbitrary users from initiating randomness requests.	["Add onlyOwner modifier to _requestRandomness() function", "Implement role-based access control for randomness requests", "Use allowlist pattern: mapping(address => bool) public authorizedRequesters", "Add require(msg.sender == authorizedContract, 'Unauthorized')"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#gelato-unprotected-randomness", "https://docs.gelato.network/web3-services/vrf", "https://www.gelato.network/vrf"]	{static}	0.1	{solidity}	Function calling _requestRandomness or similar VRF methods lacks access control, allowing any address to initiate randomness requests	{gelato,vrf,randomness,"access control",authorization}	2025-10-31 23:32:56.183297+00	2025-10-31 23:47:33.283005+00	t
BVD-EVM-COD-031	Incorrect Using-For Statement	Using-for statement references library function with mismatched type signature	code-quality	informational	\N	CWE-704	A04: Insecure Design	Ensure using-for library functions match expected type signatures	["Verify library function first parameter matches using-for type", "Correct library import", "Update using-for declaration"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#incorrect-using-for-statement"]	{static}	0.1	{solidity}	\N	{}	2025-10-31 23:32:56.267104+00	2025-10-31 23:47:33.370995+00	t
BVD-EVM-LOG-013	Manipulable Strict Equality	Use of strict equality (==) checks on balances or contract values that attackers can manipulate to bypass logic or cause denial of service	logic	medium	SWC-132	CWE-670	A1: Logic Errors	Replace strict equality with relational operators (>=, <=) for balance and token amount comparisons. Use threshold checks instead of exact matches.	["Change if (balance == 100 ether) to if (balance >= 100 ether)", "Use if (tokens >= requiredAmount) instead of if (tokens == requiredAmount)", "Avoid exact balance checks that can be griefed with small transfers", "For state transitions, use boolean flags instead of balance comparisons"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#incorrect-equality", "https://consensys.github.io/smart-contract-best-practices/attacks/denial-of-service/", "https://swcregistry.io/docs/SWC-132"]	{static}	0.2	{solidity}	Code uses strict equality operator to compare balances, token amounts, or contract state that external parties can influence	{equality,balance,manipulation,griefing,dos}	2025-10-31 23:32:56.190261+00	2025-10-31 23:47:33.289896+00	t
BVD-EVM-L2-001	Out-of-Order Retryable Execution	Arbitrum retryable tickets may execute in unpredictable order, causing dependent cross-chain operations to fail or execute incorrectly	layer2	medium	SWC-114	CWE-362	A1: Logic Errors	Design cross-chain logic to be order-independent. Avoid dependencies between retryable tickets. Use sequence numbers or explicit ordering mechanisms if order matters.	["Make retryable operations idempotent and order-independent", "Use Arbitrum's sequenceNumber for explicit ordering if required", "Implement state checks: verify prerequisites before execution", "Avoid: claim() depending on unstake() completing first"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#out-of-order-retryable", "https://docs.arbitrum.io/arbos/l1-to-l2-messaging", "https://docs.arbitrum.io/arbos/retryables"]	{static}	0.2	{solidity}	Contract logic assumes specific execution order for Arbitrum retryable tickets, but tickets may complete out of sequence	{arbitrum,retryable,l2,cross-chain,ordering,"race condition"}	2025-10-31 23:32:56.193118+00	2025-10-31 23:47:33.293361+00	t
BVD-EVM-CON-003	Unsafe Enum Conversion	Out-of-range integer to enum type conversions in Solidity < 0.4.5 allow attackers to assign invalid enum values causing undefined behavior	conversion	medium	SWC-101	CWE-704	A1: Logic Errors	Upgrade to Solidity 0.4.5 or later where enum conversion bounds are enforced automatically. For older versions, manually validate integer values before enum conversion.	["Upgrade pragma to ^0.4.5 or later", "Add bounds check: require(value < uint(type(MyEnum).max), 'Invalid enum value')", "Use SafeCast libraries for type conversions", "Validate all external inputs before enum conversion"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#enum-conversion", "https://docs.soliditylang.org/en/latest/types.html#enums", "https://github.com/ethereum/solidity/blob/develop/Changelog.md#045-2016-08-10"]	{static}	0.05	{solidity}	Contract performs integer to enum type conversion without bounds validation in Solidity versions before 0.4.5	{enum,conversion,"type safety","bounds check","undefined behavior"}	2025-10-31 23:32:56.195825+00	2025-10-31 23:47:33.296849+00	t
BVD-EVM-LOG-014	Tautological Expression	Expressions that are always true or always false (tautologies/contradictions), including self-comparisons and type-bound violations, indicating logic errors	logic	medium	SWC-110	CWE-571	A1: Logic Errors	Remove tautological comparisons or correct the logic to reflect intended behavior. Verify variable types match comparison expectations.	["Remove self-comparison: change 'if (a >= a)' to proper comparison", "Fix type-bound checks: remove 'if (uintVar >= 0)' as unsigned integers are always >= 0", "Correct comparison operators: verify < > <= >= == != are used correctly", "Check variable types: ensure comparisons make sense for the data type"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#tautology", "https://github.com/crytic/slither/wiki/Detector-Documentation#tautological-compare", "https://en.wikipedia.org/wiki/Tautology_(logic)"]	{static}	0.1	{solidity}	Code contains expressions that are logically impossible or always evaluate to the same value, indicating developer error	{tautology,self-comparison,"always true","always false","logic error"}	2025-10-31 23:32:56.198667+00	2025-10-31 23:47:33.300581+00	t
BVD-EVM-COD-022	Redundant Write Operation	Variable assigned multiple times in sequence without intermediate reads, making the first assignment redundant and wasting gas	code-quality	medium	SWC-127	CWE-563	A6: Security Misconfiguration	Remove redundant assignments or insert logic between assignments that uses the intermediate value. Review code logic to ensure correct value assignment order.	["Remove first assignment if second value is intended", "Add logic between assignments that reads the intermediate value", "Review initialization logic to ensure correct assignment order", "Consolidate multiple assignments into single assignment of final value"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#write-after-write", "https://docs.soliditylang.org/en/latest/control-structures.html", "https://consensys.github.io/smart-contract-best-practices/development-recommendations/general/code-quality/"]	{static}	0.15	{solidity}	State or local variable written to multiple times consecutively without being read between assignments	{"redundant write","gas waste","dead assignment","code quality",optimization}	2025-10-31 23:32:56.202538+00	2025-10-31 23:47:33.303901+00	t
BVD-EVM-CON-004	Reused Base Constructor	Same base constructor called from multiple locations in inheritance hierarchy causing repeated initialization with potentially conflicting values	constructor	medium	SWC-106	CWE-665	A1: Logic Errors	Remove redundant constructor calls from inheritance chain. Ensure each base constructor executes only once with consistent arguments using linearization order.	["Remove duplicate constructor calls from derived contracts", "Consolidate base constructor calls in most derived contract", "Use inheritance linearization to determine single call point", "Document constructor parameter requirements for derived contracts"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#reused-base-constructor", "https://docs.soliditylang.org/en/latest/contracts.html#constructors", "https://docs.soliditylang.org/en/latest/contracts.html#multiple-inheritance-and-linearization"]	{static}	0.1	{solidity}	Base contract constructor invoked multiple times with different arguments from multiple derived contracts in inheritance hierarchy	{constructor,inheritance,"multiple initialization",linearization,"base contract"}	2025-10-31 23:32:56.209409+00	2025-10-31 23:47:33.310946+00	t
BVD-EVM-SCP-001	Variable Scope Misuse	Variable used before declaration or referenced outside its scope, causing uninitialized access or referencing wrong variable	scope	low	SWC-131	CWE-563	A1: Logic Errors	Move variable declarations before any usage. Ensure variables declared in outer scope when needed across multiple blocks. Avoid conditional declaration of unconditionally-used variables.	["Move declaration before first use in function", "Declare variables outside conditional blocks if used after", "Initialize variables at declaration point", "Use function-level scope for variables used across multiple blocks"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#pre-declaration-usage-of-local-variables", "https://docs.soliditylang.org/en/latest/control-structures.html#scoping-and-declarations", "https://consensys.github.io/smart-contract-best-practices/development-recommendations/solidity-specific/variable-declarations/"]	{static}	0.05	{solidity}	Local variable referenced before its declaration statement or used outside the scope where it was declared	{scope,declaration,initialization,"local variable",uninitialized}	2025-10-31 23:32:56.212701+00	2025-10-31 23:47:33.314402+00	t
BVD-EVM-DOS-005	Call in Loop DoS	External calls inside loops create denial-of-service vulnerability where single failing call reverts entire transaction affecting all iterations	denial-of-service	low	SWC-113	CWE-400	A5: Security Misconfiguration	Implement pull-over-push pattern where recipients initiate their own transactions. Avoid loops with external calls. Use separate transactions for each recipient.	["Replace loop transfers with withdrawal pattern (pull payments)", "Allow recipients to claim funds in separate transactions", "Track pending amounts and let users withdraw individually", "Use mapping to store amounts rather than iterating and sending"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#calls-inside-a-loop", "https://consensys.github.io/smart-contract-best-practices/attacks/denial-of-service/", "https://fravoll.github.io/solidity-patterns/pull_over_push.html", "https://swcregistry.io/docs/SWC-113"]	{static}	0.2	{solidity}	Function contains external call or transfer operation inside loop structure creating DoS risk if any call fails	{"denial of service",loop,"external call",revert,"pull over push"}	2025-10-31 23:32:56.216777+00	2025-10-31 23:47:33.318003+00	t
BVD-EVM-REE-008	Benign Reentrancy	Reentrancy vulnerability where exploitation produces same effect as two consecutive legitimate calls, not involving Ether theft but potentially manipulating state	reentrancy	low	SWC-107	CWE-841	A1: Broken Access Control	Apply checks-effects-interactions pattern by completing state updates before external calls. Consider using nonReentrant modifier even for benign cases.	["Move all state changes before external calls", "Use nonReentrant modifier from OpenZeppelin", "Implement state machine to prevent multiple invocations", "Add reentrancy guard even if financial impact seems low"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#reentrancy-vulnerabilities", "https://consensys.github.io/smart-contract-best-practices/attacks/reentrancy/", "https://docs.openzeppelin.com/contracts/4.x/api/security#ReentrancyGuard"]	{static}	0.25	{solidity}	External call followed by state modification where reentrancy acts as double call without stealing funds	{reentrancy,benign,"state manipulation",checks-effects-interactions,"double call"}	2025-10-31 23:32:56.219735+00	2025-10-31 23:47:33.322076+00	t
BVD-EVM-REE-009	Event Ordering Reentrancy	Reentrancy vulnerability affecting event emission order or values, compromising off-chain systems that depend on accurate event logs	reentrancy	low	SWC-107	CWE-841	A1: Broken Access Control	Emit events before making external calls to ensure correct event ordering. Apply checks-effects-interactions pattern including event emissions in effects phase.	["Emit all events before external calls", "Move event emissions to effects phase of CEI pattern", "Use nonReentrant modifier to prevent event manipulation", "Ensure event parameters reflect state before external call"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#reentrancy-vulnerabilities", "https://consensys.github.io/smart-contract-best-practices/attacks/reentrancy/", "https://docs.soliditylang.org/en/latest/contracts.html#events"]	{static}	0.25	{solidity}	External call made before event emission allowing reentrancy to manipulate event order or logged values	{reentrancy,events,ordering,off-chain,indexing,"audit trail"}	2025-10-31 23:32:56.22255+00	2025-10-31 23:47:33.325447+00	t
BVD-EVM-COM-009	Outdated Compiler Version	Contract uses outdated Solidity compiler version lacking recent security improvements and bug fixes	compiler	informational	SWC-102	CWE-937	A06: Vulnerable Components	Deploy with recent Solidity version (≥0.8.0) without known severe issues; use simple pragma allowing safe compiler range	["Update pragma to: pragma solidity ^0.8.20;", "Test with latest compiler version", "Review compiler changelog for breaking changes"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#incorrect-versions-of-solidity", "https://docs.soliditylang.org/en/latest/bugs.html"]	{static}	0.1	{solidity}	\N	{}	2025-10-31 23:32:56.229241+00	2025-10-31 23:47:33.332617+00	t
BVD-EVM-COM-010	Inconsistent Pragma Directives	Project uses different Solidity compiler versions across files, risking compilation issues and unexpected behavior	compiler	informational	SWC-103	CWE-710	A04: Insecure Design	Use single consistent Solidity version across entire codebase to ensure compilation compatibility	["Standardize pragma across all contracts", "Use pragma solidity ^0.8.20; consistently", "Configure compiler version in hardhat/foundry config"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#different-pragma-directives-are-used"]	{static}	0.05	{solidity}	\N	{}	2025-10-31 23:32:56.231848+00	2025-10-31 23:47:33.335795+00	t
BVD-EVM-COM-011	Deprecated Solidity Standards	Contract uses deprecated Solidity language features or standards that may be removed in future compiler versions	compiler	informational	SWC-111	CWE-477	A06: Vulnerable Components	Replace deprecated features with current Solidity standards and best practices	["Replace 'throw' with 'revert()'", "Use 'selfdestruct' carefully or avoid", "Update deprecated syntax per compiler warnings"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#deprecated-standards", "https://docs.soliditylang.org/en/latest/080-breaking-changes.html"]	{static}	0.1	{solidity}	\N	{}	2025-10-31 23:32:56.234557+00	2025-10-31 23:47:33.338688+00	t
BVD-EVM-COM-012	Signed Storage Array Compiler Bug	Solidity compiler bug (v0.4.7-0.5.9) causes incorrect values in signed integer storage arrays	compiler	medium	SWC-127	CWE-682	A04: Insecure Design	Use compiler version ≥0.5.10 to avoid signed integer array storage bug	["Upgrade to Solidity ≥0.5.10", "Test signed array storage values", "Verify array initialization correctness"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#signed-storage-array", "https://docs.soliditylang.org/en/latest/bugs.html"]	{static}	0.05	{solidity}	\N	{}	2025-10-31 23:32:56.237252+00	2025-10-31 23:47:33.341559+00	t
BVD-EVM-COD-024	Naming Convention Violation	Code does not follow Solidity naming conventions, reducing readability and maintainability	code-quality	informational	\N	CWE-1099	A04: Insecure Design	Follow Solidity style guide: PascalCase for contracts/structs/enums, camelCase for functions/variables, UPPER_CASE for constants	["Rename contracts to PascalCase", "Use camelCase for function names", "Constants should be UPPER_CASE_WITH_UNDERSCORES"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#conformance-to-solidity-naming-conventions", "https://docs.soliditylang.org/en/latest/style-guide.html"]	{static}	0.2	{solidity}	\N	{}	2025-10-31 23:32:56.241343+00	2025-10-31 23:47:33.34474+00	t
BVD-EVM-COD-025	High Cyclomatic Complexity	Function has excessive cyclomatic complexity making it difficult to test, understand, and maintain	code-quality	informational	\N	CWE-1121	A04: Insecure Design	Refactor complex functions into smaller, single-responsibility functions; reduce branching logic	["Split function into multiple helper functions", "Extract complex conditionals to named functions", "Reduce nested if/else structures"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#cyclomatic-complexity"]	{static}	0.15	{solidity}	\N	{}	2025-10-31 23:32:56.244361+00	2025-10-31 23:47:33.348131+00	t
BVD-EVM-COD-026	Dead Code	Function is defined but never called, indicating unused code that should be removed	code-quality	informational	\N	CWE-561	A04: Insecure Design	Remove unused functions to improve code clarity and reduce maintenance burden	["Delete unused function definitions", "Document reason if function retained for interface", "Remove obsolete helper functions"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#dead-code"]	{static}	0.1	{solidity}	\N	{}	2025-10-31 23:32:56.247865+00	2025-10-31 23:47:33.35177+00	t
BVD-EVM-COD-027	Unused State Variable	State variable declared but never used, wasting gas and reducing code clarity	code-quality	informational	\N	CWE-563	A04: Insecure Design	Remove unused state variables to reduce contract size and improve maintainability	["Delete unused state variable declarations", "Remove from storage layout if safe", "Document if retained for upgrade compatibility"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#unused-state-variable"]	{static}	0.1	{solidity}	\N	{}	2025-10-31 23:32:56.250919+00	2025-10-31 23:47:33.355015+00	t
BVD-EVM-COD-028	Redundant Statements	Code contains statements with no effect, indicating potential logic errors or incomplete refactoring	code-quality	informational	\N	CWE-1164	A04: Insecure Design	Remove redundant statements; verify intended logic is correctly implemented	["Delete statements with no effect", "Complete incomplete refactoring", "Fix operator precedence issues"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#redundant-statements"]	{static}	0.1	{solidity}	\N	{}	2025-10-31 23:32:56.255459+00	2025-10-31 23:47:33.359247+00	t
BVD-EVM-COD-029	Too Many Digits	Numeric literal contains excessive digits making it hard to read and error-prone	code-quality	informational	\N	CWE-1099	A04: Insecure Design	Use scientific notation (1e18) or named constants for large numbers; add underscores for readability	["Replace 1000000000000000000 with 1e18", "Use 1_000_000 instead of 1000000", "Define named constants: uint constant DECIMALS = 1e18;"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#too-many-digits"]	{static}	0.15	{solidity}	\N	{}	2025-10-31 23:32:56.258565+00	2025-10-31 23:47:33.363055+00	t
BVD-EVM-COD-033	Missing Inheritance	Contract implements interface functions but does not explicitly inherit from interface	code-quality	informational	\N	CWE-1079	A04: Insecure Design	Explicitly inherit from interfaces to ensure type safety and compiler verification	["Add 'is IInterface' to contract declaration", "Import and inherit interface contracts", "Use interface inheritance for type checking"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#missing-inheritance"]	{static}	0.15	{solidity}	\N	{}	2025-10-31 23:32:56.273952+00	2025-10-31 23:47:33.378116+00	t
BVD-EVM-EVT-001	Missing Access Control Event	Access control function (onlyOwner, role changes) missing event emission for off-chain monitoring	events	low	SWC-108	CWE-223	A09: Logging Failures	Emit events for all access control changes to enable off-chain monitoring and audit trails	["Add event emission to role assignment functions", "Emit OwnershipTransferred events", "Log permission changes with indexed parameters"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#missing-events-access-control"]	{static}	0.2	{solidity}	\N	{}	2025-10-31 23:32:56.277549+00	2025-10-31 23:47:33.381709+00	t
BVD-EVM-EVT-002	Missing Arithmetic Event	Function modifying critical arithmetic parameters missing event emission for transparency	events	low	SWC-108	CWE-223	A09: Logging Failures	Emit events when modifying fees, rates, limits, or other critical numeric parameters	["Add event for fee changes", "Emit events for rate updates", "Log threshold modifications"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#missing-events-arithmetic"]	{static}	0.25	{solidity}	\N	{}	2025-10-31 23:32:56.280534+00	2025-10-31 23:47:33.384736+00	t
BVD-EVM-EVT-003	Unindexed ERC20 Event Parameters	ERC20 Transfer/Approval events missing indexed parameters reducing off-chain filtering efficiency	events	informational	\N	CWE-1099	A04: Insecure Design	Add 'indexed' keyword to address parameters in Transfer and Approval events per ERC20 standard	["event Transfer(address indexed from, address indexed to, uint256 value);", "event Approval(address indexed owner, address indexed spender, uint256 value);", "Follow ERC20 standard event signatures"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#unindexed-erc20-event-parameters", "https://eips.ethereum.org/EIPS/eip-20"]	{static}	0.1	{solidity}	\N	{}	2025-10-31 23:32:56.283318+00	2025-10-31 23:47:33.387828+00	t
BVD-EVM-ORA-008	Chainlink Feed Registry L2 Risk	Using Chainlink Feed Registry outside Ethereum Mainnet where it may not be supported or behave differently	oracle	low	\N	CWE-757	A04: Insecure Design	Use direct feed addresses on L2s/sidechains instead of Feed Registry; verify feed availability per network	["Use AggregatorV3Interface with direct feed addresses", "Check Chainlink docs for L2 feed availability", "Implement network-specific oracle configuration"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#chainlink-feed-registry", "https://docs.chain.link/data-feeds/feed-registry"]	{static}	0.2	{solidity}	\N	{}	2025-10-31 23:32:56.285946+00	2025-10-31 23:47:33.390811+00	t
BVD-EVM-INI-006	Function Initializing State	State variables initialized via non-constant function calls which may behave unexpectedly or fail to initialize properly	initialization	informational	\N	CWE-665	A04: Insecure Design	Initialize state variables with constants or in constructor; avoid function calls in state variable declarations	["Move initialization to constructor", "Use constant values for state initialization", "Implement explicit initialize() function for proxies"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#function-initializing-state"]	{static}	0.15	{solidity}	\N	{}	2025-10-31 23:32:56.289186+00	2025-10-31 23:47:33.394092+00	t
BVD-EVM-INI-007	Assert State Change	Assert statement modifies state which violates assert's intended use for invariant checking and wastes gas on failure	initialization	informational	SWC-110	CWE-670	A04: Insecure Design	Use require() for input validation; reserve assert() for invariant checking without state changes	["Replace assert with require for validation", "Remove state changes from assert statements", "Use assert only for post-condition checks"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#assert-state-change", "https://docs.soliditylang.org/en/latest/control-structures.html#error-handling-assert-require-revert-and-exceptions"]	{static}	0.1	{solidity}	\N	{}	2025-10-31 23:32:56.292617+00	2025-10-31 23:47:33.397737+00	t
BVD-EVM-GAS-011	Costly Operations in Loop	Loop contains expensive operations (storage writes, external calls) causing high gas costs and potential DoS	gas	informational	SWC-128	CWE-400	A05: Security Misconfiguration	Move expensive operations outside loops; use memory/calldata; implement pagination for unbounded loops	["Cache storage reads in memory before loop", "Batch process instead of per-iteration operations", "Implement pull-over-push pattern"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#costly-operations-inside-a-loop"]	{static}	0.2	{solidity}	\N	{}	2025-10-31 23:32:56.295732+00	2025-10-31 23:47:33.402413+00	t
BVD-EVM-REE-010	Reentrancy with Unlimited Gas	Reentrancy vulnerability where attacker receives unlimited gas forwarded via external call	reentrancy	informational	SWC-107	CWE-841	A04: Insecure Design	Apply checks-effects-interactions pattern; use reentrancy guards; limit gas forwarded to external calls	["Implement ReentrancyGuard", "Update state before external calls", "Limit gas sent to untrusted contracts"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#reentrancy-vulnerabilities"]	{static}	0.3	{solidity}	\N	{}	2025-10-31 23:32:56.298235+00	2025-10-31 23:47:33.405797+00	t
BVD-EVM-OPT-004	Uncached Array Length in Loop	Loop repeatedly reads array.length from storage without caching, wasting gas on redundant SLOAD operations	optimization	optimization	\N	CWE-1041	A05: Security Misconfiguration	Cache array length in local variable before loop to reduce gas costs from repeated storage reads	["uint length = array.length; for (uint i = 0; i < length; i++)", "Cache length in memory before loop iteration", "Use unchecked increment for gas savings: unchecked { i++ }"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#cache-array-length"]	{static}	0.1	{solidity}	\N	{}	2025-10-31 23:32:56.300917+00	2025-10-31 23:47:33.408895+00	t
BVD-EVM-OPT-006	Public Function Not Called Internally	Public function never called internally should be external to save gas by using calldata instead of memory for parameters	optimization	optimization	\N	CWE-1041	A05: Security Misconfiguration	Change visibility from public to external for functions never called internally; use calldata for parameters	["function process(bytes calldata data) external", "Change public to external when no internal calls", "Use calldata for array/string parameters in external functions"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#public-function-that-could-be-declared-external"]	{static}	0.15	{solidity}	\N	{}	2025-10-31 23:32:56.307419+00	2025-10-31 23:47:33.415382+00	t
BVD-EVM-OPT-007	State Variable Could Be Immutable	State variable set only in constructor but not marked immutable, missing gas optimization opportunities	optimization	optimization	\N	CWE-1041	A05: Security Misconfiguration	Add immutable keyword to state variables set only in constructor to reduce deployment and runtime gas costs	["address immutable owner;", "uint immutable deploymentTime;", "Mark constructor-only variables as immutable"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#state-variables-that-could-be-declared-immutable"]	{static}	0.1	{solidity}	\N	{}	2025-10-31 23:32:56.310591+00	2025-10-31 23:47:33.418703+00	t
BVD-EVM-OPT-008	Variable Read Using This	Contract reads own variable using 'this' keyword, adding unnecessary STATICCALL overhead	optimization	optimization	\N	CWE-1041	A05: Security Misconfiguration	Access storage variables directly instead of through 'this' to eliminate unnecessary external call overhead	["Replace 'this.myVar()' with 'myVar'", "Access state variables directly within contract", "Remove 'this' keyword for internal variable access"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#public-variable-read-in-external-context"]	{static}	0.1	{solidity}	\N	{}	2025-10-31 23:32:56.313227+00	2025-10-31 23:47:33.421516+00	t
BVD-VYPER-REE-002	Reentrancy without Ether Transfer in Vyper	Non-ether reentrancy where external calls allow state manipulation without transferring ETH	reentrancy	medium	SWC-107	CWE-841	A1: Reentrancy	Use @nonreentrant decorator for functions making external calls even without ETH transfer	[{"language": "vyper", "fixed_code": "@external\\n@nonreentrant('lock')\\ndef update_oracle():\\n    self.cached_price = self.oracle.getPrice()", "vulnerable_code": "@external\\ndef update_oracle():\\n    price: uint256 = self.oracle.getPrice()  # External call\\n    self.cached_price = price  # State update after"}]	["https://docs.vyperlang.org/", "https://swcregistry.io/docs/SWC-107"]	{static-analysis}	0.15	{vyper}	External contract call before state update without ether transfer in Vyper	{vyper,reentrancy,non-ether,"external call",@nonreentrant}	2025-10-31 23:32:56.318201+00	2025-10-31 23:47:33.427227+00	t
BVD-VYPER-REE-003	Benign Reentrancy in Vyper	Reentrancy that doesn't lead to direct exploitation but violates best practices	reentrancy	low	SWC-107	CWE-841	A1: Reentrancy	Apply @nonreentrant decorator even for benign cases to prevent future vulnerabilities	[{"language": "vyper", "fixed_code": "@external\\n@nonreentrant('lock')\\ndef log_activity():\\n    self.activity_count += 1\\n    self.logger.log(msg.sender)", "vulnerable_code": "@external\\ndef log_activity():\\n    self.logger.log(msg.sender)  # External call\\n    self.activity_count += 1"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.3	{vyper}	Non-exploitable reentrancy pattern in Vyper contract	{vyper,"benign reentrancy",@nonreentrant}	2025-10-31 23:32:56.321509+00	2025-10-31 23:47:33.430965+00	t
BVD-VYPER-REE-004	Reentrancy Affecting Events in Vyper	Reentrancy allows manipulation of event ordering or emission	reentrancy	low	SWC-107	CWE-841	A1: Reentrancy	Emit events before external calls or use @nonreentrant decorator	[{"language": "vyper", "fixed_code": "@external\\ndef transfer(to: address, amount: uint256):\\n    log Transfer(msg.sender, to, amount)  # Event before call\\n    send(to, amount)", "vulnerable_code": "@external\\ndef transfer(to: address, amount: uint256):\\n    send(to, amount)\\n    log Transfer(msg.sender, to, amount)  # Event after call"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.2	{vyper}	Event emission after external call allowing reentrancy in Vyper	{vyper,reentrancy,events,log}	2025-10-31 23:32:56.324245+00	2025-10-31 23:47:33.433516+00	t
BVD-VYPER-REE-005	Reentrancy via Transfer/Send in Vyper	Use of send() or transfer mechanisms that have limited reentrancy risk due to gas limits	reentrancy	informational	SWC-107	CWE-841	A1: Reentrancy	While send() limits gas, still follow checks-effects-interactions pattern	[{"language": "vyper", "fixed_code": "@external\\ndef withdraw():\\n    self.balances[msg.sender] = 0\\n    send(msg.sender, self.balances[msg.sender])", "vulnerable_code": "@external\\ndef withdraw():\\n    send(msg.sender, self.balances[msg.sender])\\n    self.balances[msg.sender] = 0"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.4	{vyper}	send() or transfer() used with state changes after call in Vyper	{vyper,send,transfer,"limited gas"}	2025-10-31 23:32:56.326875+00	2025-10-31 23:47:33.436135+00	t
BVD-VYPER-REE-007	Delegatecall in Loop in Vyper	Payable function using raw_call with delegatecall inside a loop enables complex reentrancy	reentrancy	high	SWC-113	CWE-841	A1: Reentrancy	Avoid delegatecall in loops, use @nonreentrant decorator, validate targets	[{"language": "vyper", "fixed_code": "@external\\n@nonreentrant('lock')\\n@payable\\ndef batch_delegate(targets: DynArray[address, 10]):\\n    # Validate targets first\\n    for target in targets:\\n        assert target in self.approved_contracts\\n        raw_call(target, b'', is_delegate_call=True)", "vulnerable_code": "@external\\n@payable\\ndef batch_delegate(targets: DynArray[address, 10]):\\n    for target in targets:\\n        raw_call(target, b'', is_delegate_call=True)"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.1	{vyper}	raw_call with delegatecall inside loop in Vyper payable function	{vyper,delegatecall,raw_call,loop,@payable}	2025-10-31 23:32:56.334051+00	2025-10-31 23:47:33.441734+00	t
BVD-VYPER-REE-008	External Calls in Loop in Vyper	Making external calls inside a loop can cause reentrancy and gas issues	reentrancy	medium	SWC-113	CWE-841	A1: Reentrancy	Restructure logic to avoid loops with external calls or use @nonreentrant	[{"language": "vyper", "fixed_code": "@external\\n@nonreentrant('lock')\\ndef notify_all(users: DynArray[address, 100]):\\n    for user in users:\\n        self.notifier.notify(user)", "vulnerable_code": "@external\\ndef notify_all(users: DynArray[address, 100]):\\n    for user in users:\\n        self.notifier.notify(user)  # External call in loop"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.2	{vyper}	External contract call inside loop in Vyper function	{vyper,"external call",loop,@nonreentrant}	2025-10-31 23:32:56.337989+00	2025-10-31 23:47:33.444329+00	t
BVD-VYPER-ACC-001	Suicidal Function Without Access Control in Vyper	Function with selfdestruct lacks proper access control, allowing anyone to destroy the contract	access-control	critical	SWC-106	CWE-284	A1: Broken Access Control	Add owner check before selfdestruct, use role-based access control	[{"language": "vyper", "fixed_code": "owner: public(address)\\n\\n@external\\ndef destroy():\\n    assert msg.sender == self.owner, \\"Only owner\\"\\n    selfdestruct(self.owner)", "vulnerable_code": "@external\\ndef destroy():\\n    selfdestruct(msg.sender)  # No access control"}]	["https://swcregistry.io/docs/SWC-106", "https://docs.vyperlang.org/"]	{static-analysis}	0.05	{vyper}	selfdestruct callable without authorization check in Vyper contract	{vyper,selfdestruct,"access control",owner,authorization}	2025-10-31 23:32:56.342556+00	2025-10-31 23:47:33.446984+00	t
BVD-VYPER-ACC-002	Unprotected Upgradeable Contract in Vyper	Upgradeable contract proxy functions lack access control	access-control	critical	SWC-106	CWE-284	A1: Broken Access Control	Implement owner-only upgrade functions with proper access checks	[{"language": "vyper", "fixed_code": "owner: public(address)\\n\\n@external\\ndef upgrade_to(new_implementation: address):\\n    assert msg.sender == self.owner, \\"Only owner\\"\\n    assert new_implementation != empty(address), \\"Invalid address\\"\\n    self.implementation = new_implementation\\n    log UpgradeExecuted(new_implementation)", "vulnerable_code": "@external\\ndef upgrade_to(new_implementation: address):\\n    self.implementation = new_implementation"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.05	{vyper}	Contract upgrade function without authorization in Vyper	{vyper,upgradeable,proxy,"access control",implementation}	2025-10-31 23:32:56.347245+00	2025-10-31 23:47:33.449559+00	t
BVD-VYPER-ACC-003	Arbitrary Ether Send Destination in Vyper	Function sends ETH to arbitrary address controlled by caller	access-control	high	SWC-105	CWE-284	A1: Broken Access Control	Validate destination address, use whitelist, or restrict to authorized addresses	[{"language": "vyper", "fixed_code": "approved_recipients: public(HashMap[address, bool])\\n\\n@external\\ndef send_funds(to: address, amount: uint256):\\n    assert self.approved_recipients[to], \\"Not approved\\"\\n    send(to, amount)", "vulnerable_code": "@external\\ndef send_funds(to: address, amount: uint256):\\n    send(to, amount)  # Arbitrary destination"}]	["https://swcregistry.io/docs/SWC-105"]	{static-analysis}	0.15	{vyper}	ETH transfer to caller-controlled address without validation in Vyper	{vyper,send,arbitrary,ether,validation}	2025-10-31 23:32:56.351836+00	2025-10-31 23:47:33.452302+00	t
BVD-VYPER-STA-011	Non-Immutable State Variable in Vyper	State variable set once in __init__ but not marked immutable, wasting gas	state-variables	informational	SWC-131	CWE-1164	A8: Software and Data Integrity Failures	Use immutable() for variables set only in __init__ to save gas on reads	[{"language": "vyper", "fixed_code": "owner: public(immutable(address))  # Immutable, cheaper reads\\n\\n@external\\ndef __init__(_owner: address):\\n    owner = _owner", "vulnerable_code": "owner: public(address)  # Set once in __init__, never changes\\n\\n@external\\ndef __init__(_owner: address):\\n    self.owner = _owner"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.15	{vyper}	State variable set once in constructor that could be immutable in Vyper	{vyper,immutable,"gas optimization",__init__}	2025-10-31 23:32:56.496906+00	2025-10-31 23:47:33.597116+00	t
BVD-VYPER-ACC-006	Controlled Delegatecall in Vyper	Delegatecall target controlled by caller without validation	access-control	critical	SWC-112	CWE-284	A1: Broken Access Control	Whitelist delegatecall targets, restrict to trusted contracts only	[{"language": "vyper", "fixed_code": "trusted_targets: public(HashMap[address, bool])\\n\\n@external\\ndef delegate_call(target: address, data: Bytes[1024]):\\n    assert self.trusted_targets[target], \\"Target not trusted\\"\\n    raw_call(target, data, is_delegate_call=True)", "vulnerable_code": "@external\\ndef delegate_call(target: address, data: Bytes[1024]):\\n    raw_call(target, data, is_delegate_call=True)"}]	["https://swcregistry.io/docs/SWC-112"]	{static-analysis}	0.05	{vyper}	raw_call with is_delegate_call to untrusted address in Vyper	{vyper,delegatecall,raw_call,is_delegate_call,validation}	2025-10-31 23:32:56.363809+00	2025-10-31 23:47:33.460469+00	t
BVD-VYPER-ACC-007	Dangerous tx.origin Usage in Vyper	Using tx.origin for authorization enables phishing attacks	access-control	medium	SWC-115	CWE-477	A1: Broken Access Control	Use msg.sender instead of tx.origin for access control	[{"language": "vyper", "fixed_code": "@external\\ndef admin_function():\\n    assert msg.sender == self.owner, \\"Not owner\\"  # Safe", "vulnerable_code": "@external\\ndef admin_function():\\n    assert tx.origin == self.owner, \\"Not owner\\"  # Vulnerable"}]	["https://swcregistry.io/docs/SWC-115", "https://docs.vyperlang.org/"]	{static-analysis}	0.1	{vyper}	tx.origin used for authorization in Vyper contract	{vyper,tx.origin,msg.sender,authorization,phishing}	2025-10-31 23:32:56.368632+00	2025-10-31 23:47:33.463474+00	t
BVD-VYPER-ACC-008	Missing Access Control Events in Vyper	Access control changes not logged with events for transparency	access-control	low	SWC-108	CWE-778	A9: Insufficient Logging	Emit events for all access control changes (ownership, roles, permissions)	[{"language": "vyper", "fixed_code": "event OwnershipTransferred:\\n    previous_owner: indexed(address)\\n    new_owner: indexed(address)\\n\\n@external\\ndef transfer_ownership(new_owner: address):\\n    assert msg.sender == self.owner\\n    old_owner: address = self.owner\\n    self.owner = new_owner\\n    log OwnershipTransferred(old_owner, new_owner)", "vulnerable_code": "@external\\ndef transfer_ownership(new_owner: address):\\n    self.owner = new_owner  # No event"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.2	{vyper}	Access control modification without event emission in Vyper	{vyper,events,log,"access control",transparency}	2025-10-31 23:32:56.37231+00	2025-10-31 23:47:33.467851+00	t
BVD-VYPER-ACC-009	Missing Zero Address Validation in Vyper	Function accepts zero address without validation, potentially locking funds	access-control	low	SWC-123	CWE-703	A5: Security Misconfiguration	Add zero address checks for critical address parameters	[{"language": "vyper", "fixed_code": "@external\\ndef set_owner(new_owner: address):\\n    assert new_owner != empty(address), \\"Zero address\\"\\n    self.owner = new_owner", "vulnerable_code": "@external\\ndef set_owner(new_owner: address):\\n    self.owner = new_owner  # No validation"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.25	{vyper}	Address parameter not validated against zero address in Vyper	{vyper,"zero address",empty,validation,assert}	2025-10-31 23:32:56.375257+00	2025-10-31 23:47:33.472077+00	t
BVD-VYPER-ACC-010	Protected Variables Access in Vyper	Protected state variables accessible without proper authorization	access-control	high	SWC-108	CWE-284	A1: Broken Access Control	Add authorization checks before modifying protected variables	[{"language": "vyper", "fixed_code": "critical_param: public(uint256)\\nowner: public(address)\\n\\n@external\\ndef set_param(value: uint256):\\n    assert msg.sender == self.owner, \\"Only owner\\"\\n    self.critical_param = value", "vulnerable_code": "critical_param: public(uint256)\\n\\n@external\\ndef set_param(value: uint256):\\n    self.critical_param = value  # No access control"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.15	{vyper}	State variable modification without authorization in Vyper	{vyper,"state variable","access control",authorization}	2025-10-31 23:32:56.378636+00	2025-10-31 23:47:33.478028+00	t
BVD-VYPER-ACC-011	Gelato Unprotected Randomness in Vyper	Gelato VRF randomness request without proper access control or validation	access-control	medium	SWC-120	CWE-330	A2: Cryptographic Failures	Validate Gelato operator, add request limits, verify randomness source	[{"language": "vyper", "fixed_code": "gelato_operator: public(address)\\n\\n@external\\ndef request_randomness():\\n    assert msg.sender == self.gelato_operator, \\"Only Gelato\\"\\n    assert not self.pending_request, \\"Request pending\\"\\n    self.pending_request = True\\n    self.gelato_vrf.request_random_number()", "vulnerable_code": "@external\\ndef request_randomness():\\n    self.gelato_vrf.request_random_number()  # No validation"}]	["https://docs.gelato.network/"]	{static-analysis}	0.2	{vyper}	Gelato VRF randomness without authorization in Vyper	{vyper,gelato,randomness,VRF,oracle}	2025-10-31 23:32:56.381389+00	2025-10-31 23:47:33.482885+00	t
BVD-VYPER-ACC-012	Pyth Unchecked PublishTime in Vyper	Pyth oracle price used without checking publishTime freshness	access-control	high	SWC-108	CWE-367	A4: Insecure Design	Validate publishTime against acceptable staleness threshold	[{"language": "vyper", "fixed_code": "MAX_STALENESS: constant(uint256) = 300  # 5 minutes\\n\\n@external\\ndef update_price():\\n    price_data: PriceData = self.pyth.get_price(self.price_id)\\n    age: uint256 = block.timestamp - price_data.publish_time\\n    assert age <= MAX_STALENESS, \\"Stale price\\"\\n    self.current_price = price_data.price", "vulnerable_code": "@external\\ndef update_price():\\n    price_data: PriceData = self.pyth.get_price(self.price_id)\\n    self.current_price = price_data.price  # No time check"}]	["https://docs.pyth.network/"]	{static-analysis}	0.1	{vyper}	Pyth oracle price used without publishTime validation in Vyper	{vyper,pyth,oracle,publishTime,staleness}	2025-10-31 23:32:56.385698+00	2025-10-31 23:47:33.486517+00	t
BVD-VYPER-INT-002	Incorrect Exponentiation in Vyper	Incorrect use of exponentiation operator causing unexpected results	arithmetic	high	SWC-101	CWE-682	A8: Software and Data Integrity Failures	Use correct exponentiation syntax, validate inputs, check for overflow	[{"language": "vyper", "fixed_code": "@external\\n@view\\ndef power(base: uint256, exp: uint256) -> uint256:\\n    return base ** exp  # ** is exponentiation", "vulnerable_code": "@external\\n@view\\ndef power(base: uint256, exp: uint256) -> uint256:\\n    return base ^ exp  # ^ is XOR not power"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.1	{vyper}	XOR operator used instead of exponentiation in Vyper	{vyper,exponentiation,power,XOR,operator}	2025-10-31 23:32:56.392472+00	2025-10-31 23:47:33.494809+00	t
BVD-VYPER-INT-004	Dangerous Unary Expression in Vyper	Unary operators used in dangerous way causing unexpected behavior	arithmetic	low	SWC-101	CWE-682	A8: Software and Data Integrity Failures	Explicit use parentheses, validate negation doesn't cause underflow	[{"language": "vyper", "fixed_code": "result: int256 = (-amount) + fee  # Clear with parentheses", "vulnerable_code": "result: int256 = -amount + fee  # Ambiguous precedence"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.3	{vyper}	Unary minus or plus with ambiguous precedence in Vyper	{vyper,unary,negation,precedence,arithmetic}	2025-10-31 23:32:56.401131+00	2025-10-31 23:47:33.503633+00	t
BVD-VYPER-INT-005	Missing Arithmetic Events in Vyper	Critical arithmetic operations not logged with events for auditing	arithmetic	low	SWC-108	CWE-778	A9: Insufficient Logging	Emit events for important calculations, token minting, fee changes	[{"language": "vyper", "fixed_code": "event TotalSupplyUpdated:\\n    old_supply: uint256\\n    new_supply: uint256\\n    amount_added: uint256\\n\\n@external\\ndef update_total_supply(amount: uint256):\\n    old: uint256 = self.total_supply\\n    self.total_supply += amount\\n    log TotalSupplyUpdated(old, self.total_supply, amount)", "vulnerable_code": "@external\\ndef update_total_supply(amount: uint256):\\n    self.total_supply += amount  # No event"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.4	{vyper}	Critical arithmetic without event logging in Vyper	{vyper,events,log,arithmetic,auditing}	2025-10-31 23:32:56.406483+00	2025-10-31 23:47:33.50766+00	t
BVD-VYPER-INT-007	Tautological Compare in Vyper	Comparison operation result is determined at compile time, indicating error	arithmetic	high	SWC-110	CWE-570	A8: Software and Data Integrity Failures	Fix comparison to use meaningful variables, verify logic correctness	[{"language": "vyper", "fixed_code": "@external\\ndef process(value: uint256):\\n    if value > self.threshold:  # Meaningful comparison\\n        self.process_special()", "vulnerable_code": "@external\\ndef process(value: uint256):\\n    if value > value:  # Always false\\n        self.process_special()"}]	["https://swcregistry.io/docs/SWC-110"]	{static-analysis}	0.05	{vyper}	Variable compared to itself in Vyper condition	{vyper,tautological,comparison,self-comparison}	2025-10-31 23:32:56.413527+00	2025-10-31 23:47:33.515464+00	t
BVD-VYPER-INT-008	Too Many Digits in Vyper	Numeric literal has excessive digits making it error-prone and hard to read	arithmetic	informational	SWC-100	CWE-1114	A8: Software and Data Integrity Failures	Use scientific notation, define constants with clear names, add underscores for readability	[{"language": "vyper", "fixed_code": "# Using scientific notation\\nTOTAL_SUPPLY: constant(uint256) = 10 ** 24\\n# Or with underscores\\nTOTAL_SUPPLY: constant(uint256) = 1_000_000_000_000_000_000_000_000", "vulnerable_code": "TOTAL_SUPPLY: constant(uint256) = 1000000000000000000000000  # Hard to read"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.3	{vyper}	Numeric literal with many consecutive digits in Vyper	{vyper,readability,"numeric literal",constant,digits}	2025-10-31 23:32:56.417893+00	2025-10-31 23:47:33.519458+00	t
BVD-VYPER-EXT-001	Unchecked Low-Level Call in Vyper	Low-level call (raw_call) return value is not checked, potentially hiding failures	external-calls	medium	SWC-104	CWE-252	A8: Software and Data Integrity Failures	Always check return value of raw_call, handle failures appropriately, use revert_on_failure parameter	[{"language": "vyper", "fixed_code": "@external\\ndef call_external(target: address, data: Bytes[1024]):\\n    success: bool = raw_call(target, data, revert_on_failure=False)\\n    assert success, \\"External call failed\\"", "vulnerable_code": "@external\\ndef call_external(target: address, data: Bytes[1024]):\\n    raw_call(target, data)  # Return value ignored"}]	["https://docs.vyperlang.org/", "https://swcregistry.io/docs/SWC-104"]	{static-analysis}	0.15	{vyper}	raw_call invoked without checking return value in Vyper	{vyper,raw_call,unchecked,low-level,"external call"}	2025-10-31 23:32:56.426+00	2025-10-31 23:47:33.527253+00	t
BVD-VYPER-EXT-002	Unchecked Send in Vyper	send() function result not checked, silently failing transfers can lead to fund loss	external-calls	medium	SWC-104	CWE-252	A8: Software and Data Integrity Failures	Check send() return value or use raw_call with revert_on_failure=True	[{"language": "vyper", "fixed_code": "@external\\ndef withdraw(amount: uint256):\\n    success: bool = send(msg.sender, amount)\\n    assert success, \\"Send failed\\"\\n    self.balances[msg.sender] = 0", "vulnerable_code": "@external\\ndef withdraw(amount: uint256):\\n    send(msg.sender, amount)  # Return not checked\\n    self.balances[msg.sender] = 0"}]	["https://docs.vyperlang.org/", "https://swcregistry.io/docs/SWC-104"]	{static-analysis}	0.1	{vyper}	send() call without checking boolean return value in Vyper	{vyper,send,unchecked,"ether transfer","return value"}	2025-10-31 23:32:56.429563+00	2025-10-31 23:47:33.530797+00	t
BVD-VYPER-EXT-003	Unchecked ERC20 Transfer in Vyper	ERC20 transfer/transferFrom return value not checked, may silently fail	external-calls	medium	SWC-104	CWE-252	A8: Software and Data Integrity Failures	Always check ERC20 transfer return values, use safe transfer wrappers	[{"language": "vyper", "fixed_code": "interface ERC20:\\n    def transfer(to: address, amount: uint256) -> bool: nonpayable\\n\\n@external\\ndef transfer_tokens(token: ERC20, to: address, amount: uint256):\\n    success: bool = token.transfer(to, amount)\\n    assert success, \\"Transfer failed\\"", "vulnerable_code": "interface ERC20:\\n    def transfer(to: address, amount: uint256) -> bool: nonpayable\\n\\n@external\\ndef transfer_tokens(token: ERC20, to: address, amount: uint256):\\n    token.transfer(to, amount)  # Return not checked"}]	["https://docs.vyperlang.org/", "https://swcregistry.io/docs/SWC-104"]	{static-analysis}	0.1	{vyper}	ERC20 transfer or transferFrom without checking return value in Vyper	{vyper,erc20,transfer,unchecked,token}	2025-10-31 23:32:56.43282+00	2025-10-31 23:47:33.53546+00	t
BVD-VYPER-EXT-004	Unused Return Value in Vyper	Function calls with return values that are not used or checked	external-calls	medium	SWC-104	CWE-252	A8: Software and Data Integrity Failures	Use or validate return values from all function calls, especially external ones	[{"language": "vyper", "fixed_code": "interface Oracle:\\n    def getPrice() -> uint256: view\\n\\n@external\\ndef update_price():\\n    price: uint256 = self.oracle.getPrice()\\n    assert price > 0, \\"Invalid price\\"\\n    self.cached_price = price", "vulnerable_code": "interface Oracle:\\n    def getPrice() -> uint256: view\\n\\n@external\\ndef update_price():\\n    self.oracle.getPrice()  # Return value not used"}]	["https://docs.vyperlang.org/", "https://swcregistry.io/docs/SWC-104"]	{static-analysis}	0.2	{vyper}	Function call with return value that is ignored in Vyper	{vyper,"unused return","return value","external call"}	2025-10-31 23:32:56.437333+00	2025-10-31 23:47:33.539944+00	t
BVD-VYPER-EXT-005	Low-Level Call Usage in Vyper	Use of raw_call poses risks if not properly validated and handled	external-calls	informational	SWC-112	CWE-477	A8: Software and Data Integrity Failures	Prefer interface-based calls, if raw_call needed validate targets and handle errors	[{"language": "vyper", "fixed_code": "@external\\ndef proxy_call(target: address, data: Bytes[1024]):\\n    # Validate target\\n    assert target in self.approved_contracts, \\"Untrusted target\\"\\n    # Check return and handle errors\\n    success: bool = raw_call(target, data, revert_on_failure=False)\\n    assert success, \\"Call failed\\"", "vulnerable_code": "@external\\ndef proxy_call(target: address, data: Bytes[1024]):\\n    raw_call(target, data)  # Low-level call without validation"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.3	{vyper}	raw_call usage without proper validation in Vyper	{vyper,raw_call,low-level,validation}	2025-10-31 23:32:56.440922+00	2025-10-31 23:47:33.543093+00	t
BVD-VYPER-EXT-006	Incorrect Return in Assembly in Vyper	Incorrect use of return opcode in inline assembly can cause unexpected behavior	external-calls	medium	SWC-127	CWE-682	A8: Software and Data Integrity Failures	Note: Vyper doesn't support inline assembly like Solidity; avoid low-level opcodes	[{"language": "vyper", "fixed_code": "# Use Vyper's built-in constructs instead of assembly\\n@external\\ndef safe_call(target: address) -> Bytes[32]:\\n    response: Bytes[32] = raw_call(\\n        target,\\n        b'',\\n        max_outsize=32,\\n        revert_on_failure=True\\n    )\\n    return response", "vulnerable_code": "# Vyper doesn't support inline assembly\\n# This pattern applies to potential future features\\n# or incorrect use of raw_call with return data"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.1	{vyper}	Incorrect return handling in low-level operations in Vyper	{vyper,return,assembly,raw_call,low-level}	2025-10-31 23:32:56.444127+00	2025-10-31 23:47:33.546132+00	t
BVD-VYPER-EXT-008	Return Bomb in Vyper	External call returns excessive data causing gas griefing or DoS	external-calls	low	SWC-113	CWE-400	A4: Insecure Design	Limit return data size using max_outsize parameter in raw_call	[{"language": "vyper", "fixed_code": "@external\\ndef get_data(target: address) -> Bytes[1024]:\\n    # Limit return data to reasonable size\\n    return raw_call(\\n        target,\\n        b'',\\n        max_outsize=1024,  # Safe limit\\n        revert_on_failure=True\\n    )", "vulnerable_code": "@external\\ndef get_data(target: address) -> Bytes[MAX_UINT256]:\\n    # No limit on return data size\\n    return raw_call(target, b'', max_outsize=MAX_UINT256)"}]	["https://docs.vyperlang.org/", "https://swcregistry.io/docs/SWC-113"]	{static-analysis}	0.25	{vyper}	Unbounded return data from external call in Vyper	{vyper,"return bomb","gas griefing",max_outsize,DoS}	2025-10-31 23:32:56.451416+00	2025-10-31 23:47:33.55305+00	t
BVD-VYPER-EXT-010	Chronicle Unchecked Price in Vyper	Chronicle oracle price data retrieved without validation checks	external-calls	medium	SWC-111	CWE-20	A3: Injection	Validate Chronicle oracle responses, check timestamps and validity flags	[{"language": "vyper", "fixed_code": "interface IChronicle:\\n    def read() -> uint256: view\\n    def readWithAge() -> (uint256, uint256): view\\n\\n@external\\n@view\\ndef get_price() -> uint256:\\n    price: uint256 = 0\\n    age: uint256 = 0\\n    (price, age) = self.chronicle.readWithAge()\\n    \\n    # Validate price is non-zero\\n    assert price > 0, \\"Invalid price\\"\\n    \\n    # Validate data freshness (e.g., within 1 hour)\\n    assert age < 3600, \\"Stale oracle data\\"\\n    \\n    return price", "vulnerable_code": "interface IChronicle:\\n    def read() -> uint256: view\\n\\n@external\\n@view\\ndef get_price() -> uint256:\\n    # No validation of oracle data\\n    return self.chronicle.read()"}]	["https://docs.chroniclelabs.org/", "https://docs.vyperlang.org/"]	{static-analysis}	0.15	{vyper}	Chronicle oracle data used without validation in Vyper	{vyper,chronicle,oracle,"price feed",validation}	2025-10-31 23:32:56.45868+00	2025-10-31 23:47:33.559034+00	t
BVD-VYPER-STA-001	Uninitialized State Variable in Vyper	State variable declared but never initialized, may lead to unexpected zero values	state-variables	high	SWC-109	CWE-665	A8: Software and Data Integrity Failures	Initialize all state variables explicitly in __init__ or at declaration	[{"language": "vyper", "fixed_code": "owner: public(address)\\nthreshold: uint256\\n\\n@external\\ndef __init__(_owner: address, _threshold: uint256):\\n    self.owner = _owner\\n    self.threshold = _threshold", "vulnerable_code": "owner: public(address)  # Uninitialized, will be zero address\\nthreshold: uint256  # Uninitialized, will be zero\\n\\n@external\\ndef __init__():\\n    pass  # No initialization"}]	["https://docs.vyperlang.org/", "https://swcregistry.io/docs/SWC-109"]	{static-analysis}	0.1	{vyper}	State variable declared without initialization in Vyper contract	{vyper,uninitialized,"state variable",__init__}	2025-10-31 23:32:56.462845+00	2025-10-31 23:47:33.561907+00	t
BVD-VYPER-STA-002	Uninitialized Storage Pointer in Vyper	Storage reference not properly initialized, can point to unexpected storage slots	state-variables	high	SWC-109	CWE-824	A8: Software and Data Integrity Failures	Vyper handles storage references safely; ensure struct/array initialization is explicit	[{"language": "vyper", "fixed_code": "struct User:\\n    balance: uint256\\n    active: bool\\n\\nusers: HashMap[address, User]\\n\\n@external\\ndef get_balance(addr: address) -> uint256:\\n    user: User = self.users[addr]\\n    assert user.active, \\"User not initialized\\"\\n    return user.balance", "vulnerable_code": "struct User:\\n    balance: uint256\\n    active: bool\\n\\nusers: HashMap[address, User]\\n\\n@external\\ndef get_balance(addr: address) -> uint256:\\n    # Direct access without checking initialization\\n    return self.users[addr].balance"}]	["https://docs.vyperlang.org/", "https://swcregistry.io/docs/SWC-109"]	{static-analysis}	0.15	{vyper}	Storage struct or array accessed without initialization check in Vyper	{vyper,storage,uninitialized,struct,HashMap}	2025-10-31 23:32:56.466753+00	2025-10-31 23:47:33.565556+00	t
BVD-VYPER-VER-002	Different Pragma Directives in Vyper	Multiple files using different Vyper versions causing inconsistencies	version	informational	SWC-103	CWE-937	A6: Vulnerable and Outdated Components	Use same Vyper version across all contract files in project	[{"language": "vyper", "fixed_code": "# File1.vy\\n# @version ^0.3.10\\n\\n# File2.vy\\n# @version ^0.3.10  # Same version", "vulnerable_code": "# File1.vy\\n# @version 0.3.7\\n\\n# File2.vy  \\n# @version 0.3.9  # Different version"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.15	{vyper}	Inconsistent Vyper version pragmas across contract files	{vyper,version,pragma,consistency}	2025-10-31 23:32:56.642546+00	2025-10-31 23:47:33.750704+00	t
BVD-VYPER-STA-004	Uninitialized Interface Pointer in Vyper	Interface variable not initialized to a valid contract address	state-variables	low	SWC-109	CWE-665	A8: Software and Data Integrity Failures	Initialize interface variables in __init__ or validate before use	[{"language": "vyper", "fixed_code": "interface IERC20:\\n    def transfer(to: address, amount: uint256) -> bool: nonpayable\\n\\ntoken: IERC20\\n\\n@external\\ndef __init__(token_addr: address):\\n    assert token_addr != empty(address), \\"Invalid token\\"\\n    self.token = IERC20(token_addr)\\n\\n@external\\ndef transfer_tokens(to: address, amount: uint256):\\n    assert self.token.address != empty(address), \\"Token not set\\"\\n    self.token.transfer(to, amount)", "vulnerable_code": "interface IERC20:\\n    def transfer(to: address, amount: uint256) -> bool: nonpayable\\n\\ntoken: IERC20  # Uninitialized interface\\n\\n@external\\ndef transfer_tokens(to: address, amount: uint256):\\n    self.token.transfer(to, amount)  # token is zero address"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.2	{vyper}	Interface variable used without address initialization in Vyper	{vyper,interface,uninitialized,"contract call"}	2025-10-31 23:32:56.472784+00	2025-10-31 23:47:33.574292+00	t
BVD-VYPER-STA-005	State Variable Name Collision in Vyper	State variable name conflicts with function or imported module	state-variables	high	SWC-119	CWE-710	A8: Software and Data Integrity Failures	Use unique names for state variables, avoid conflicts with functions and imports	[{"language": "vyper", "fixed_code": "balance: public(uint256)\\n\\n@external\\ndef get_balance() -> uint256:  # Unique function name\\n    return self.balance", "vulnerable_code": "balance: public(uint256)\\n\\n@external\\ndef balance() -> uint256:  # Name collision with state variable\\n    return self.balance"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.05	{vyper}	State variable name conflicts with function name in Vyper	{vyper,shadowing,"name collision","state variable"}	2025-10-31 23:32:56.475501+00	2025-10-31 23:47:33.578901+00	t
BVD-VYPER-STA-006	Module Variable Shadowing in Vyper	Variable name shadows imported module or interface	state-variables	high	SWC-119	CWE-710	A8: Software and Data Integrity Failures	Note: Vyper doesn't have inheritance; avoid shadowing imported modules and interfaces	[{"language": "vyper", "fixed_code": "from vyper.interfaces import ERC20\\n\\nerc20_token: public(address)  # Unique name, doesn't shadow", "vulnerable_code": "from vyper.interfaces import ERC20\\n\\nERC20: public(address)  # Shadows imported interface"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.1	{vyper}	Variable name shadows imported module or interface in Vyper	{vyper,shadowing,import,interface,module}	2025-10-31 23:32:56.481376+00	2025-10-31 23:47:33.582651+00	t
BVD-VYPER-STA-007	Local Variable Shadowing in Vyper	Local variable shadows state variable causing confusion	state-variables	low	SWC-119	CWE-710	A8: Software and Data Integrity Failures	Use distinct names for local variables to avoid shadowing state variables	[{"language": "vyper", "fixed_code": "owner: public(address)\\n\\n@external\\ndef update_owner(new_owner: address):  # Unique parameter name\\n    self.owner = new_owner", "vulnerable_code": "owner: public(address)\\n\\n@external\\ndef update_owner(owner: address):  # Parameter shadows state variable\\n    self.owner = owner"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.25	{vyper}	Function parameter or local variable shadows state variable in Vyper	{vyper,shadowing,"local variable",parameter}	2025-10-31 23:32:56.484303+00	2025-10-31 23:47:33.585775+00	t
BVD-VYPER-STA-008	Builtin Symbol Shadowing in Vyper	Variable name shadows Vyper builtin functions or keywords	state-variables	low	SWC-119	CWE-710	A8: Software and Data Integrity Failures	Avoid using Vyper builtin names (send, raw_call, block, msg, etc.) for variables	[{"language": "vyper", "fixed_code": "can_send: public(bool)  # Descriptive unique name\\nblock_number: uint256  # Unique name for block-related data", "vulnerable_code": "send: public(bool)  # Shadows builtin send() function\\nblock: uint256  # Shadows builtin block object"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.05	{vyper}	Variable shadows Vyper builtin function or keyword	{vyper,shadowing,builtin,keyword,reserved}	2025-10-31 23:32:56.487152+00	2025-10-31 23:47:33.58864+00	t
BVD-VYPER-STA-009	Unused State Variable in Vyper	State variable declared but never used, wastes storage and deployment gas	state-variables	informational	SWC-131	CWE-1164	A8: Software and Data Integrity Failures	Remove unused state variables to reduce storage costs and improve code clarity	[{"language": "vyper", "fixed_code": "owner: public(address)\\ntotal_supply: uint256\\n\\n@external\\ndef __init__():\\n    self.owner = msg.sender\\n    self.total_supply = 1000000", "vulnerable_code": "owner: public(address)\\nunused_var: uint256  # Never used anywhere\\ntotal_supply: uint256\\n\\n@external\\ndef __init__():\\n    self.owner = msg.sender\\n    self.total_supply = 1000000"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.1	{vyper}	State variable never read or written in Vyper contract	{vyper,unused,"state variable","gas optimization"}	2025-10-31 23:32:56.490199+00	2025-10-31 23:47:33.591487+00	t
BVD-VYPER-STA-010	Non-Constant State Variable in Vyper	State variable never changes after initialization, should use constant()	state-variables	informational	SWC-131	CWE-1164	A8: Software and Data Integrity Failures	Use constant() for compile-time constants to save gas	[{"language": "vyper", "fixed_code": "MAX_SUPPLY: public(constant(uint256)) = 1000000  # Compile-time constant", "vulnerable_code": "MAX_SUPPLY: public(uint256)  # Never changes but not constant\\n\\n@external\\ndef __init__():\\n    self.MAX_SUPPLY = 1000000"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.2	{vyper}	State variable that could be constant() in Vyper	{vyper,constant,immutable,"gas optimization"}	2025-10-31 23:32:56.493419+00	2025-10-31 23:47:33.594278+00	t
BVD-VYPER-STA-013	Write After Write in Vyper	State variable written twice consecutively without being read, first write is wasted	state-variables	high	SWC-131	CWE-563	A8: Software and Data Integrity Failures	Remove redundant writes, ensure logic flow is correct	[{"language": "vyper", "fixed_code": "@external\\ndef update_balance(amount: uint256):\\n    self.balance = amount  # Single write", "vulnerable_code": "@external\\ndef update_balance(amount: uint256):\\n    self.balance = 100  # First write\\n    self.balance = amount  # Second write, first is wasted"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.1	{vyper}	State variable assigned twice without intermediate read in Vyper	{vyper,"write after write",redundant,"gas waste"}	2025-10-31 23:32:56.505575+00	2025-10-31 23:47:33.602902+00	t
BVD-VYPER-STA-014	View Function State Change in Vyper	Function marked @view attempts to modify state variables	state-variables	medium	SWC-108	CWE-573	A8: Software and Data Integrity Failures	Remove @view decorator or remove state-changing operations, Vyper prevents this at compile time	[{"language": "vyper", "fixed_code": "@external\\ndef get_and_update() -> uint256:\\n    self.counter += 1  # Remove @view decorator\\n    return self.counter", "vulnerable_code": "@external\\n@view\\ndef get_and_update() -> uint256:\\n    self.counter += 1  # Compile error: view function cannot modify state\\n    return self.counter"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.05	{vyper}	Function with @view decorator modifying state in Vyper	{vyper,@view,"state change",pure,compilation}	2025-10-31 23:32:56.509255+00	2025-10-31 23:47:33.605754+00	t
BVD-VYPER-TIM-001	Block Timestamp Manipulation in Vyper	Using block.timestamp for critical logic can be manipulated by miners within bounds	timestamp	low	SWC-116	CWE-829	A8: Software and Data Integrity Failures	Avoid using block.timestamp for critical randomness or precise timing, use oracles for time-sensitive operations	[{"language": "vyper", "fixed_code": "@external\\ndef claim_reward():\\n    # Use block.number for more predictable timing\\n    assert block.number > self.deadline_block, \\"Too early\\"\\n    send(msg.sender, self.reward)\\n    # Or add buffer for timestamp checks\\n    # assert block.timestamp > self.deadline + 900, \\"Too early\\"", "vulnerable_code": "@external\\ndef claim_reward():\\n    # Miners can manipulate timestamp within ~15 seconds\\n    assert block.timestamp > self.deadline, \\"Too early\\"\\n    send(msg.sender, self.reward)"}]	["https://docs.vyperlang.org/", "https://swcregistry.io/docs/SWC-116"]	{static-analysis}	0.3	{vyper}	block.timestamp used for critical decision logic in Vyper	{vyper,block.timestamp,timestamp,manipulation,miner}	2025-10-31 23:32:56.51563+00	2025-10-31 23:47:33.611375+00	t
BVD-VYPER-GAS-001	Cache Array Length in Vyper	Array length read multiple times in loop, should cache for gas savings	gas-optimization	informational	SWC-128	CWE-1050	A8: Software and Data Integrity Failures	Cache array length in local variable before loop to save gas	[{"language": "vyper", "fixed_code": "@external\\ndef process_all(items: DynArray[uint256, 100]):\\n    length: uint256 = len(items)  # Cache length\\n    for i in range(length):\\n        self.process(items[i])", "vulnerable_code": "@external\\ndef process_all(items: DynArray[uint256, 100]):\\n    for i in range(len(items)):  # len() called each iteration\\n        self.process(items[i])"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.15	{vyper}	Array length accessed multiple times in loop in Vyper	{vyper,"gas optimization",cache,"array length",loop}	2025-10-31 23:32:56.522452+00	2025-10-31 23:47:33.617019+00	t
BVD-VYPER-VER-003	Deprecated Vyper Features in Vyper	Using deprecated Vyper syntax or features	version	informational	SWC-111	CWE-477	A6: Vulnerable and Outdated Components	Update to current Vyper syntax and avoid deprecated features	[{"language": "vyper", "fixed_code": "# Modern Vyper 0.3.x syntax\\n@external\\ndef foo():\\n    pass", "vulnerable_code": "# Old syntax (pre-0.3.x)\\ncontract SomeContract:\\n    def foo(): pass"}]	["https://docs.vyperlang.org/", "https://github.com/vyperlang/vyper/blob/master/CHANGELOG.md"]	{static-analysis}	0.2	{vyper}	Deprecated Vyper syntax or features in code	{vyper,deprecated,legacy,syntax}	2025-10-31 23:32:56.645661+00	2025-10-31 23:47:33.753262+00	t
BVD-EVM-TIM-002	Transaction Order Dependence	Contract behavior depends on transaction ordering (front-running)	time-manipulation	medium	SWC-114	CWE-362	A7: Front-Running	Use commit-reveal scheme or implement order-independent logic	["Implement commit-reveal", "Use submarine sends", "Add slippage protection"]	["https://swcregistry.io/docs/SWC-114"]	{static,symbolic}	0.35	{solidity,vyper}	State changes create value opportunity for observers who can execute transactions before target transaction	{front-running,MEV,ordering,"race condition",sandwich}	2025-10-31 23:32:55.678287+00	2025-10-31 23:47:32.751664+00	t
BVD-VYPER-GAS-003	Variable Read Using External Call in Vyper	Public state variable read via external call instead of direct access	gas-optimization	informational	SWC-128	CWE-1050	A8: Software and Data Integrity Failures	Access state variables directly instead of through public getter	[{"language": "vyper", "fixed_code": "balance: public(uint256)\\n\\n@internal\\ndef _get_double_balance() -> uint256:\\n    # Efficient: direct state access\\n    return self.balance * 2", "vulnerable_code": "balance: public(uint256)\\n\\n@internal\\ndef _get_double_balance() -> uint256:\\n    # Wasteful: calls public getter\\n    return self.balance() * 2"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.2	{vyper}	Internal function calls public state variable getter in Vyper	{vyper,"gas optimization","state variable",public,getter}	2025-10-31 23:32:56.529802+00	2025-10-31 23:47:33.623052+00	t
BVD-VYPER-GAS-004	Costly Loop Operations in Vyper	Expensive operations like storage writes inside loops waste gas	gas-optimization	informational	SWC-128	CWE-1050	A8: Software and Data Integrity Failures	Minimize storage operations in loops, batch updates, use memory variables	[{"language": "vyper", "fixed_code": "@external\\ndef update_all(values: DynArray[uint256, 100]):\\n    total_sum: uint256 = 0  # Memory accumulator\\n    for i in range(len(values)):\\n        self.data[i] = values[i]\\n        total_sum += values[i]  # Accumulate in memory\\n    self.total += total_sum  # Single storage write", "vulnerable_code": "@external\\ndef update_all(values: DynArray[uint256, 100]):\\n    for i in range(len(values)):\\n        self.data[i] = values[i]  # Storage write each iteration\\n        self.total += values[i]  # Storage read+write each iteration"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.25	{vyper}	Storage operations or expensive calls inside loop in Vyper	{vyper,"gas optimization",loop,storage,SSTORE}	2025-10-31 23:32:56.533104+00	2025-10-31 23:47:33.626088+00	t
BVD-VYPER-GAS-005	Array Passed By Value in Vyper	Storage array modified by copying to memory instead of direct storage manipulation	gas-optimization	high	SWC-128	CWE-1050	A8: Software and Data Integrity Failures	Modify storage arrays directly by index instead of copying to memory	[{"language": "vyper", "fixed_code": "items: DynArray[uint256, 100]\\n\\n@external\\ndef update_item(index: uint256, value: uint256):\\n    self.items[index] = value  # Direct storage modification", "vulnerable_code": "items: DynArray[uint256, 100]\\n\\n@external\\ndef update_item(index: uint256, value: uint256):\\n    temp: DynArray[uint256, 100] = self.items  # Copy to memory\\n    temp[index] = value\\n    self.items = temp  # Copy back to storage - wasteful"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.1	{vyper}	Storage array copied to memory and back in Vyper	{vyper,array,storage,memory,"gas waste"}	2025-10-31 23:32:56.536748+00	2025-10-31 23:47:33.629376+00	t
BVD-VYPER-GAS-006	Controlled Array Length in Vyper	DynArray length can be controlled by user leading to DoS via gas exhaustion	gas-optimization	medium	SWC-128	CWE-400	A4: Insecure Design	Limit array sizes, paginate operations, validate input lengths	[{"language": "vyper", "fixed_code": "MAX_BATCH_SIZE: constant(uint256) = 50\\n\\n@external\\ndef process_items(items: DynArray[uint256, 100]):\\n    assert len(items) <= MAX_BATCH_SIZE, \\"Batch too large\\"\\n    for item in items:\\n        self.process(item)", "vulnerable_code": "@external\\ndef process_items(items: DynArray[uint256, MAX_UINT256]):\\n    # Attacker can send huge array causing DoS\\n    for item in items:\\n        self.process(item)"}]	["https://docs.vyperlang.org/", "https://swcregistry.io/docs/SWC-128"]	{static-analysis}	0.15	{vyper}	User-controlled DynArray length without bounds checking in Vyper	{vyper,DynArray,DoS,gas,unbounded}	2025-10-31 23:32:56.540779+00	2025-10-31 23:47:33.632364+00	t
BVD-VYPER-GAS-007	Storage Signed Integer Array in Vyper	Signed integer arrays in storage are less gas efficient than unsigned	gas-optimization	medium	SWC-128	CWE-1050	A8: Software and Data Integrity Failures	Use uint256 arrays instead of int256 unless negative values are required	[{"language": "vyper", "fixed_code": "balances: DynArray[uint256, 100]  # Unsigned more efficient\\n# Or if negatives needed, document the reason", "vulnerable_code": "balances: DynArray[int256, 100]  # Signed integers less efficient"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.3	{vyper}	Storage array using int256 instead of uint256 in Vyper	{vyper,int256,uint256,"gas optimization",storage}	2025-10-31 23:32:56.543744+00	2025-10-31 23:47:33.635495+00	t
BVD-VYPER-GAS-008	Public Nested Mapping in Vyper	Public nested HashMap generates expensive getter with multiple parameters	gas-optimization	high	SWC-128	CWE-1050	A8: Software and Data Integrity Failures	Consider making nested mappings internal and create custom getter if needed	[{"language": "vyper", "fixed_code": "# Internal mapping with custom efficient getter\\nallowances: HashMap[address, HashMap[address, uint256]]\\n\\n@external\\n@view\\ndef get_allowance(owner: address, spender: address) -> uint256:\\n    return self.allowances[owner][spender]", "vulnerable_code": "# Public nested mapping generates complex getter\\nallowances: public(HashMap[address, HashMap[address, uint256]])"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.15	{vyper}	Public nested HashMap in Vyper contract	{vyper,HashMap,"nested mapping",public,gas}	2025-10-31 23:32:56.546513+00	2025-10-31 23:47:33.638699+00	t
BVD-EVM-EXT-001	External Contract Reference	Contract calls external address from user input	external-calls	medium	SWC-107	CWE-829	A1: Reentrancy	Whitelist allowed external contracts	["Hardcode external addresses", "Maintain whitelist", "Validate contract code"]	["https://consensys.github.io/smart-contract-best-practices/development-recommendations/general/external-calls/"]	{static}	0.25	{solidity,vyper}	Contract makes call to address provided by user without validation	{"external call",arbitrary,untrusted,"user input"}	2025-10-31 23:32:55.722094+00	2025-10-31 23:47:32.804221+00	t
BVD-VYPER-GAS-010	Locked Ether in Vyper	Contract can receive Ether but has no withdrawal mechanism	gas-optimization	high	SWC-132	CWE-284	A5: Security Misconfiguration	Add @payable functions and withdrawal mechanism, or prevent Ether reception	[{"language": "vyper", "fixed_code": "owner: public(address)\\n\\n@external\\ndef __init__():\\n    self.owner = msg.sender\\n\\n@external\\n@payable\\ndef __default__():\\n    # Accept Ether\\n    pass\\n\\n@external\\ndef withdraw():\\n    assert msg.sender == self.owner, \\"Not owner\\"\\n    send(self.owner, self.balance)", "vulnerable_code": "# Contract with no @payable functions or default function\\n# Ether sent will be locked\\n\\n@external\\ndef some_function():\\n    pass"}]	["https://docs.vyperlang.org/", "https://swcregistry.io/docs/SWC-132"]	{static-analysis}	0.1	{vyper}	Vyper contract lacks withdrawal function but can receive Ether	{vyper,"locked ether",@payable,withdrawal,"stuck funds"}	2025-10-31 23:32:56.552791+00	2025-10-31 23:47:33.647977+00	t
BVD-VYPER-GAS-011	View Function with Complex Logic in Vyper	View function marked as constant but contains complex computations	gas-optimization	medium	SWC-128	CWE-1050	A8: Software and Data Integrity Failures	Note: Vyper doesn't support inline assembly; cache results for complex view functions	[{"language": "vyper", "fixed_code": "cached_result: public(uint256)\\nlast_update: public(uint256)\\n\\n@external\\ndef update_cache():\\n    result: uint256 = 0\\n    for i in range(1000):\\n        result += i * i\\n    self.cached_result = result\\n    self.last_update = block.number\\n\\n@external\\n@view\\ndef calculate_complex() -> uint256:\\n    return self.cached_result", "vulnerable_code": "@external\\n@view\\ndef calculate_complex() -> uint256:\\n    # Complex computation on every call\\n    result: uint256 = 0\\n    for i in range(1000):\\n        result += i * i\\n    return result"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.3	{vyper}	View function with complex computation in Vyper	{vyper,@view,"gas optimization",caching,computation}	2025-10-31 23:32:56.557048+00	2025-10-31 23:47:33.653885+00	t
BVD-VYPER-GAS-013	Function Initializing State in Vyper	Function initializes multiple state variables, could be optimized	gas-optimization	informational	SWC-128	CWE-1050	A8: Software and Data Integrity Failures	Batch state initialization in __init__ when possible, use struct packing	[{"language": "vyper", "fixed_code": "struct Config:\\n    var1: uint256\\n    var2: uint256\\n    var3: uint256\\n\\nconfig: Config\\n\\n@external\\ndef initialize(a: uint256, b: uint256, c: uint256):\\n    # More efficient with struct\\n    self.config = Config({var1: a, var2: b, var3: c})", "vulnerable_code": "var1: uint256\\nvar2: uint256\\nvar3: uint256\\n\\n@external\\ndef initialize(a: uint256, b: uint256, c: uint256):\\n    self.var1 = a  # 3 separate SSTORE operations\\n    self.var2 = b\\n    self.var3 = c"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.3	{vyper}	Function performing multiple state variable initializations in Vyper	{vyper,initialization,"state variables",gas,struct}	2025-10-31 23:32:56.564759+00	2025-10-31 23:47:33.665187+00	t
BVD-VYPER-LOG-001	Dead Code in Vyper	Unreachable code or unused functions that will never execute	logic	informational	SWC-135	CWE-561	A8: Software and Data Integrity Failures	Remove dead code to reduce contract size and improve readability	[{"language": "vyper", "fixed_code": "@external\\ndef process(value: uint256) -> uint256:\\n    if value > 100:\\n        return value * 2\\n    else:\\n        return value", "vulnerable_code": "@external\\ndef process(value: uint256) -> uint256:\\n    if value > 100:\\n        return value * 2\\n    else:\\n        return value\\n    # Dead code - unreachable\\n    return 0"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.1	{vyper}	Unreachable code after return or in impossible branch in Vyper	{vyper,"dead code",unreachable,unused}	2025-10-31 23:32:56.568469+00	2025-10-31 23:47:33.669329+00	t
BVD-VYPER-LOG-003	Boolean Constant Misuse in Vyper	Using boolean constants in conditional statements indicates logic error	logic	medium	SWC-110	CWE-670	A8: Software and Data Integrity Failures	Remove constant boolean conditions or fix the logic	[{"language": "vyper", "fixed_code": "@external\\ndef check_status() -> bool:\\n    return self.is_active  # Simplified logic", "vulnerable_code": "@external\\ndef check_status() -> bool:\\n    if True:  # Always true - logic error\\n        return self.is_active\\n    return False"}]	["https://docs.vyperlang.org/", "https://swcregistry.io/docs/SWC-110"]	{static-analysis}	0.15	{vyper}	Boolean constant (True/False) in conditional expression in Vyper	{vyper,"boolean constant",True,False,condition}	2025-10-31 23:32:56.575282+00	2025-10-31 23:47:33.680078+00	t
BVD-VYPER-LOG-004	Boolean Equality Check in Vyper	Explicitly comparing boolean to True/False is redundant	logic	informational	SWC-110	CWE-1126	A8: Software and Data Integrity Failures	Use boolean variable directly without explicit == True/False comparison	[{"language": "vyper", "fixed_code": "@external\\ndef check() -> bool:\\n    return self.is_active  # Direct return", "vulnerable_code": "@external\\ndef check() -> bool:\\n    if self.is_active == True:  # Redundant\\n        return True\\n    return False"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.1	{vyper}	Boolean variable compared to True or False in Vyper	{vyper,boolean,redundant,comparison}	2025-10-31 23:32:56.57824+00	2025-10-31 23:47:33.684114+00	t
BVD-VYPER-LOG-005	Incorrect Decorator Usage in Vyper	Decorator misapplied or mutually exclusive decorators used together	logic	low	SWC-123	CWE-573	A8: Software and Data Integrity Failures	Note: Vyper uses decorators (@external, @internal, @view, @pure, @payable, @nonreentrant) not modifiers	[{"language": "vyper", "fixed_code": "@external  # Choose appropriate visibility\\ndef process():\\n    pass\\n# OR\\n@internal\\ndef _process():\\n    pass", "vulnerable_code": "@external\\n@internal  # Conflicting decorators\\ndef process():\\n    pass"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.05	{vyper}	Conflicting or incorrect decorators on Vyper function	{vyper,decorator,@external,@internal,@view}	2025-10-31 23:32:56.581554+00	2025-10-31 23:47:33.688594+00	t
BVD-VYPER-LOG-006	Empty Constructor in Vyper	__init__ function defined but does nothing, wastes gas	logic	low	SWC-135	CWE-1164	A8: Software and Data Integrity Failures	Remove empty __init__ or add necessary initialization	[{"language": "vyper", "fixed_code": "# Remove empty __init__ entirely\\n# Or add initialization:\\n@external\\ndef __init__(_owner: address):\\n    self.owner = _owner", "vulnerable_code": "@external\\ndef __init__():\\n    pass  # Empty constructor wastes gas"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.15	{vyper}	Empty __init__ function in Vyper contract	{vyper,__init__,constructor,empty}	2025-10-31 23:32:56.584794+00	2025-10-31 23:47:33.69245+00	t
BVD-VYPER-LOG-007	Redundant Statement in Vyper	Statement that has no effect or is immediately overwritten	logic	informational	SWC-135	CWE-1164	A8: Software and Data Integrity Failures	Remove redundant statements to improve code clarity	[{"language": "vyper", "fixed_code": "@external\\ndef calculate(x: uint256) -> uint256:\\n    result: uint256 = x * 2\\n    return result", "vulnerable_code": "@external\\ndef calculate(x: uint256) -> uint256:\\n    result: uint256 = 0\\n    result = x  # Redundant assignment\\n    result = x * 2  # Previous assignment has no effect\\n    return result"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.2	{vyper}	Statement with no effect in Vyper	{vyper,redundant,"no effect",useless}	2025-10-31 23:32:56.58778+00	2025-10-31 23:47:33.696419+00	t
BVD-VYPER-LOG-008	Unimplemented Function in Vyper	Function declared but contains only pass or raises NotImplemented	logic	informational	SWC-135	CWE-440	A8: Software and Data Integrity Failures	Implement function logic or remove if not needed	[{"language": "vyper", "fixed_code": "@external\\ndef future_feature():\\n    # Implement actual logic\\n    self.process_data()\\n    log FeatureExecuted()\\n\\n@internal\\ndef _helper():\\n    # Actual implementation\\n    return self.calculate_value()", "vulnerable_code": "@external\\ndef future_feature():\\n    pass  # Not implemented\\n\\n@internal\\ndef _helper():\\n    raise \\"Not implemented\\""}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.1	{vyper}	Function with only pass statement or NotImplemented in Vyper	{vyper,unimplemented,pass,stub}	2025-10-31 23:32:56.590493+00	2025-10-31 23:47:33.699339+00	t
BVD-VYPER-LOG-009	Incorrect Interface Implementation in Vyper	Contract implements interface incorrectly or incompletely	logic	informational	SWC-126	CWE-573	A8: Software and Data Integrity Failures	Note: Vyper doesn't have using-for; ensure interface implementations are complete and correct	[{"language": "vyper", "fixed_code": "interface IERC20:\\n    def transfer(to: address, amount: uint256) -> bool: nonpayable\\n    def balanceOf(account: address) -> uint256: view\\n\\n# Complete implementation\\n@external\\ndef transfer(to: address, amount: uint256) -> bool:\\n    self.balances[msg.sender] -= amount\\n    self.balances[to] += amount\\n    return True\\n\\n@external\\n@view\\ndef balanceOf(account: address) -> uint256:\\n    return self.balances[account]", "vulnerable_code": "# Interface definition\\ninterface IERC20:\\n    def transfer(to: address, amount: uint256) -> bool: nonpayable\\n    def balanceOf(account: address) -> uint256: view\\n\\n# Incomplete implementation\\n@external\\ndef transfer(to: address, amount: uint256) -> bool:\\n    return True\\n# Missing balanceOf implementation"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.15	{vyper}	Incomplete or incorrect interface implementation in Vyper	{vyper,interface,implementation,ERC20}	2025-10-31 23:32:56.594738+00	2025-10-31 23:47:33.702054+00	t
BVD-VYPER-LOG-011	Multiple Constructor Patterns in Vyper	Attempting to create multiple constructor-like initialization functions	logic	high	SWC-123	CWE-665	A8: Software and Data Integrity Failures	Note: Vyper only supports one __init__ function; use factory pattern if multiple constructors needed	[{"language": "vyper", "fixed_code": "@external\\ndef __init__(owner: address):\\n    # Single __init__ with parameter\\n    self.owner = owner if owner != empty(address) else msg.sender", "vulnerable_code": "@external\\ndef __init__():\\n    self.owner = msg.sender\\n\\n# This will cause compile error - can't have multiple __init__\\n@external\\ndef __init__(owner: address):\\n    self.owner = owner"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.05	{vyper}	Multiple __init__ definitions in Vyper (compile error)	{vyper,__init__,constructor,multiple}	2025-10-31 23:32:56.601694+00	2025-10-31 23:47:33.710362+00	t
BVD-VYPER-LOG-012	Missing Interface Declaration in Vyper	Contract implements token-like functionality without declaring standard interface	logic	informational	SWC-126	CWE-1127	A8: Software and Data Integrity Failures	Note: Vyper doesn't have inheritance; explicitly implement standard interfaces (ERC20, ERC721, etc.)	[{"language": "vyper", "fixed_code": "# Explicitly use standard ERC20 interface\\nfrom vyper.interfaces import ERC20\\n\\nimplements: ERC20\\n\\nbalances: HashMap[address, uint256]\\n\\n@external\\ndef transfer(to: address, amount: uint256) -> bool:\\n    self.balances[msg.sender] -= amount\\n    self.balances[to] += amount\\n    log Transfer(msg.sender, to, amount)\\n    return True", "vulnerable_code": "# Token-like contract without standard interface\\nbalances: HashMap[address, uint256]\\n\\n@external\\ndef transfer(to: address, amount: uint256):\\n    self.balances[msg.sender] -= amount\\n    self.balances[to] += amount"}]	["https://docs.vyperlang.org/", "https://eips.ethereum.org/EIPS/eip-20"]	{static-analysis}	0.25	{vyper}	Contract missing implements declaration for standard interface in Vyper	{vyper,interface,implements,ERC20,standard}	2025-10-31 23:32:56.605129+00	2025-10-31 23:47:33.712952+00	t
BVD-VYPER-DAT-001	Hash Collision in Vyper Encoding	Using concat() for hashing dynamic types can lead to collisions	data-handling	high	SWC-133	CWE-294	A2: Cryptographic Failures	Use _abi_encode() instead of concat() for signature generation and hashing	[{"language": "vyper", "fixed_code": "@external\\n@view\\ndef get_hash(a: String[100], b: String[100]) -> bytes32:\\n    # Safe: _abi_encode prevents collisions\\n    return keccak256(_abi_encode(a, b))", "vulnerable_code": "@external\\n@view\\ndef get_hash(a: String[100], b: String[100]) -> bytes32:\\n    # Vulnerable: concat can cause collisions\\n    # \\"abc\\" + \\"def\\" == \\"ab\\" + \\"cdef\\"\\n    return keccak256(concat(a, b))"}]	["https://docs.vyperlang.org/", "https://swcregistry.io/docs/SWC-133"]	{static-analysis}	0.1	{vyper}	concat() used with dynamic types for hashing in Vyper	{vyper,concat,_abi_encode,"hash collision",keccak256}	2025-10-31 23:32:56.60871+00	2025-10-31 23:47:33.716463+00	t
BVD-VYPER-DAT-002	Dynamic Array in Struct Storage in Vyper	Vyper doesn't support dynamic arrays in structs, attempting to use them causes compilation error	data-handling	high	SWC-128	CWE-704	A8: Software and Data Integrity Failures	Note: Vyper prevents this at compile time; use DynArray at contract level, not in structs	[{"language": "vyper", "fixed_code": "# Use HashMap or separate storage\\nstruct User:\\n    balance_count: uint256\\n\\nuser_balances: HashMap[address, DynArray[uint256, 100]]\\n\\n@external\\ndef add_balance(user: address, amount: uint256):\\n    self.user_balances[user].append(amount)", "vulnerable_code": "# This will NOT compile in Vyper\\nstruct User:\\n    balances: DynArray[uint256, 100]  # Compile error"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.05	{vyper}	Attempt to use DynArray inside struct in Vyper	{vyper,DynArray,struct,storage,compilation}	2025-10-31 23:32:56.612126+00	2025-10-31 23:47:33.719555+00	t
BVD-VYPER-DAT-003	Dangerous Type Conversion in Vyper	Unsafe type conversion using convert() without bounds checking	data-handling	high	SWC-133	CWE-704	A8: Software and Data Integrity Failures	Validate ranges before using convert(), especially for downcasting	[{"language": "vyper", "fixed_code": "@external\\ndef downcast(value: uint256) -> uint8:\\n    # Safe: validate range first\\n    assert value <= 255, \\"Value too large for uint8\\"\\n    return convert(value, uint8)", "vulnerable_code": "@external\\ndef downcast(value: uint256) -> uint8:\\n    # Unsafe: truncates without checking\\n    return convert(value, uint8)"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.15	{vyper}	Unsafe convert() downcast without bounds check in Vyper	{vyper,convert,"type conversion",downcast,overflow}	2025-10-31 23:32:56.615275+00	2025-10-31 23:47:33.722385+00	t
BVD-VYPER-DAT-004	Incorrect ERC20 Interface in Vyper	ERC20 interface implementation missing required functions or has wrong signatures	data-handling	high	SWC-126	CWE-573	A8: Software and Data Integrity Failures	Use standard ERC20 interface from vyper.interfaces or ensure complete implementation	[{"language": "vyper", "fixed_code": "from vyper.interfaces import ERC20\\n\\nimplements: ERC20\\n\\nevent Transfer:\\n    sender: indexed(address)\\n    receiver: indexed(address)\\n    amount: uint256\\n\\n@external\\ndef transfer(to: address, amount: uint256) -> bool:\\n    self.balances[msg.sender] -= amount\\n    self.balances[to] += amount\\n    log Transfer(msg.sender, to, amount)\\n    return True", "vulnerable_code": "# Incomplete ERC20 implementation\\n@external\\ndef transfer(to: address, amount: uint256):\\n    self.balances[msg.sender] -= amount\\n    self.balances[to] += amount\\n    # Missing: return value, Transfer event"}]	["https://docs.vyperlang.org/", "https://eips.ethereum.org/EIPS/eip-20"]	{static-analysis}	0.1	{vyper}	Incomplete or incorrect ERC20 interface implementation in Vyper	{vyper,ERC20,interface,token,standard}	2025-10-31 23:32:56.618066+00	2025-10-31 23:47:33.725903+00	t
BVD-VYPER-DAT-006	Unindexed ERC20 Event Parameters in Vyper	ERC20 Transfer/Approval events missing indexed parameters for efficient filtering	data-handling	informational	SWC-126	CWE-1126	A8: Software and Data Integrity Failures	Use indexed() for from, to, and owner/spender in Transfer and Approval events	[{"language": "vyper", "fixed_code": "event Transfer:\\n    sender: indexed(address)  # Indexed for filtering\\n    receiver: indexed(address)  # Indexed for filtering\\n    amount: uint256  # Amount typically not indexed", "vulnerable_code": "event Transfer:\\n    sender: address  # Not indexed\\n    receiver: address  # Not indexed\\n    amount: uint256"}]	["https://docs.vyperlang.org/", "https://eips.ethereum.org/EIPS/eip-20"]	{static-analysis}	0.1	{vyper}	ERC20 events without indexed parameters in Vyper	{vyper,event,indexed,ERC20,Transfer}	2025-10-31 23:32:56.624341+00	2025-10-31 23:47:33.732192+00	t
BVD-VYPER-DAT-007	Name Reused in Vyper	Variable, function, or event name reused causing confusion or shadowing	data-handling	high	SWC-119	CWE-1021	A8: Software and Data Integrity Failures	Use unique names across all identifiers in contract	[{"language": "vyper", "fixed_code": "event Transfer:\\n    amount: uint256\\n\\ntransfer_count: uint256  # Unique name", "vulnerable_code": "event Transfer:\\n    amount: uint256\\n\\nTransfer: uint256  # Reuses event name - confusing"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.1	{vyper}	Identifier name reused for different purposes in Vyper	{vyper,"name reuse",shadowing,collision}	2025-10-31 23:32:56.627546+00	2025-10-31 23:47:33.735043+00	t
BVD-VYPER-DAT-008	Right-to-Left Override Character in Vyper	Unicode RTLO character used to obscure malicious code	data-handling	high	SWC-130	CWE-451	A3: Injection	Remove all RTLO (U+202E) and other directional override characters from source	[{"language": "vyper", "fixed_code": "# Clean code without RTLO\\n@external\\ndef set_owner():\\n    self.owner = msg.sender", "vulnerable_code": "# Contains hidden RTLO character (U+202E)\\n# Visual: owner = msg.sender\\n# Actual: owner = rednesmsg.sender (reversed)\\n@external\\ndef set_owner():\\n    self.owner = msg.sender‮rednesmsg.  # RTLO character present"}]	["https://docs.vyperlang.org/", "https://swcregistry.io/docs/SWC-130"]	{static-analysis}	0.01	{vyper}	Right-to-left override unicode character in Vyper source	{vyper,RTLO,unicode,obfuscation,U+202E}	2025-10-31 23:32:56.630477+00	2025-10-31 23:47:33.73773+00	t
BVD-VYPER-DAT-009	EIP712 Domain Separator Collision in Vyper	EIP-712 domain separator not unique across chains causing signature replay	data-handling	medium	SWC-117	CWE-345	A2: Cryptographic Failures	Include chain ID in domain separator and validate signatures properly	[{"language": "vyper", "fixed_code": "# Include chain ID to prevent cross-chain replay\\n@external\\n@view\\ndef domain_separator() -> bytes32:\\n    return keccak256(\\n        _abi_encode(\\n            keccak256(\\"EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)\\"),\\n            keccak256(\\"MyContract\\"),\\n            keccak256(\\"1\\"),\\n            chain.id,\\n            self\\n        )\\n    )", "vulnerable_code": "# Domain separator without chain ID\\n@external\\n@view\\ndef domain_separator() -> bytes32:\\n    return keccak256(\\n        _abi_encode(\\n            keccak256(\\"EIP712Domain(string name,string version,address verifyingContract)\\"),\\n            keccak256(\\"MyContract\\"),\\n            keccak256(\\"1\\"),\\n            self\\n        )\\n    )"}]	["https://eips.ethereum.org/EIPS/eip-712", "https://docs.vyperlang.org/"]	{static-analysis}	0.1	{vyper}	EIP-712 domain separator missing chain ID in Vyper	{vyper,EIP-712,"domain separator","chain ID",signature}	2025-10-31 23:32:56.633242+00	2025-10-31 23:47:33.741494+00	t
BVD-VYPER-VER-001	Incorrect Vyper Version in Vyper	Using outdated or vulnerable Vyper compiler version	version	informational	SWC-102	CWE-937	A6: Vulnerable and Outdated Components	Use latest stable Vyper version (0.3.x or newer), avoid versions with known bugs	[{"language": "vyper", "fixed_code": "# @version ^0.3.10  # Use latest stable version", "vulnerable_code": "# @version 0.2.16  # Outdated version with known issues"}]	["https://docs.vyperlang.org/", "https://github.com/vyperlang/vyper/releases"]	{static-analysis}	0.1	{vyper}	Vyper version pragma specifies outdated or vulnerable compiler	{vyper,version,pragma,compiler,upgrade}	2025-10-31 23:32:56.639395+00	2025-10-31 23:47:33.747354+00	t
BVD-EVM-REE-001	Reentrancy Attack	External call followed by state change allows attacker to re-enter contract and manipulate state	reentrancy	critical	SWC-107	CWE-841	A1: Reentrancy	Use checks-effects-interactions pattern, reentrancy guards, or pull payment pattern	["Use ReentrancyGuard from OpenZeppelin", "Move state changes before external calls", "Use .transfer() instead of .call{value}()"]	["https://consensys.github.io/smart-contract-best-practices/attacks/reentrancy/", "https://swcregistry.io/docs/SWC-107"]	{static,symbolic}	0.15	{solidity,vyper}	Function makes external call to untrusted contract then modifies state variables, creating opportunity for recursive callback exploitation	{reentrancy,"external call","state change",callback,recursive}	2025-10-31 23:32:55.456333+00	2025-10-31 23:47:32.57953+00	t
BVD-EVM-ACC-001	Missing Access Control	Critical function lacks access control modifiers allowing unauthorized execution	access-control	critical	SWC-105	CWE-284	A2: Access Control	Add onlyOwner, onlyRole, or custom access control modifiers	["Use OpenZeppelin Ownable", "Implement AccessControl with roles", "Add require(msg.sender == owner)"]	["https://swcregistry.io/docs/SWC-105"]	{static}	0.1	{solidity,vyper}	Function that modifies critical state or transfers value has no sender verification	{"access control",authorization,onlyOwner,permission,unauthorized}	2025-10-31 23:32:55.568156+00	2025-10-31 23:47:32.656184+00	t
BVD-EVM-COD-021	Incorrect Modifier Use	Modifier used incorrectly or in wrong context	code-quality	low	SWC-128	CWE-710	A9: Code Quality	Review modifier usage and fix incorrect applications	["Apply modifier to correct function type", "Fix modifier parameter passing"]	["https://docs.soliditylang.org/en/latest/contracts.html#function-modifiers"]	{static}	0.2	{solidity}	Modifier applied to incompatible function or with wrong parameters	{modifier,"incorrect usage"}	2025-10-31 23:32:56.074407+00	2025-10-31 23:47:33.164716+00	t
BVD-VYPER-VER-005	Inline Assembly Attempt in Vyper	Attempting to use inline assembly which Vyper does not support	version	informational	SWC-127	CWE-477	A8: Software and Data Integrity Failures	Note: Vyper intentionally doesn't support inline assembly for safety; use raw_call for low-level operations	[{"language": "vyper", "fixed_code": "# Use Vyper's built-in features instead\\n# For low-level calls, use raw_call\\n@external\\ndef low_level_call(target: address, data: Bytes[1024]) -> Bytes[32]:\\n    return raw_call(\\n        target,\\n        data,\\n        max_outsize=32,\\n        revert_on_failure=True\\n    )", "vulnerable_code": "# Vyper does NOT support inline assembly\\n# This would be a compile error\\n# assembly:\\n#     sstore(0, 1)"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.05	{vyper}	Attempt to use inline assembly in Vyper	{vyper,assembly,"inline assembly",raw_call}	2025-10-31 23:32:56.65213+00	2025-10-31 23:47:33.760579+00	t
BVD-VYPER-VER-006	Optimism Deprecated Predeploy in Vyper	Using deprecated Optimism predeploy contracts or functions	version	low	SWC-111	CWE-477	A6: Vulnerable and Outdated Components	Update to current Optimism predeploys and avoid deprecated L1/L2 messaging	[{"language": "vyper", "fixed_code": "# Current Optimism L1Block predeploy\\nL1_BLOCK: constant(address) = 0x4200000000000000000000000000000000000015\\n\\n# Use current interface\\ninterface L1Block:\\n    def number() -> uint256: view\\n    def timestamp() -> uint256: view", "vulnerable_code": "# Deprecated Optimism L1Block predeploy address\\nL1_BLOCK_DEPRECATED: constant(address) = 0x4200000000000000000000000000000000000015"}]	["https://docs.optimism.io/", "https://docs.vyperlang.org/"]	{static-analysis}	0.15	{vyper}	Deprecated Optimism predeploy contract usage in Vyper	{vyper,optimism,L2,predeploy,deprecated}	2025-10-31 23:32:56.655873+00	2025-10-31 23:47:33.7639+00	t
BVD-VYPER-VER-008	AI Generated Code Indicators in Vyper	Code shows patterns typical of AI-generated code requiring extra review	version	low	SWC-103	CWE-1295	A8: Software and Data Integrity Failures	Review AI-generated code carefully, verify logic, add proper validation and tests	[{"language": "vyper", "fixed_code": "# Human-reviewed code:\\n@external\\ndef calculate_fee(amount: uint256) -> uint256:\\n    fee: uint256 = amount * self.fee_rate / 10000\\n    assert fee <= self.max_fee, \\"Fee exceeds maximum\\"\\n    return fee", "vulnerable_code": "# AI-generated code often has:\\n# - Generic variable names (data, value, result)\\n# - Excessive comments\\n# - Unusual patterns\\n@external\\ndef process_data(data: uint256) -> uint256:  # Generic naming\\n    # This function processes the data  # Obvious comment\\n    result: uint256 = data  # Step by step\\n    return result  # Returns result"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.4	{vyper}	Code patterns suggesting AI generation in Vyper	{vyper,"AI generated","code review",ChatGPT,Copilot}	2025-10-31 23:32:56.667325+00	2025-10-31 23:47:33.77468+00	t
BVD-EVM-REE-005	Protocol Read-Only Reentrancy	Read-only reentrancy in DeFi protocols (Balancer, Curve, Compound)	reentrancy	high	SWC-107	CWE-841	A1: Reentrancy	Use reentrancy locks on view functions, validate pool state	["Check Balancer vault lock status", "Validate Curve pool before reading price", "Use Compound's borrowBalanceCurrent with checks"]	["https://chainsecurity.com/heartbreaks-curve-lp-oracles/", "https://github.com/Decurity/semgrep-smart-contracts"]	{static}	0.2	{solidity}	Reading state from DeFi protocol during reentrancy window returns manipulated values	{read-only,reentrancy,balancer,curve,compound,oracle,getRate,get_virtual_price}	2025-10-31 23:32:55.736075+00	2025-10-31 23:47:32.818628+00	t
BVD-EVM-TOK-004	Token Approval Vulnerability	Allowance can be stolen via transferFrom implementation bug	token	high	\N	CWE-20	A2: Access Control	Properly implement transferFrom with allowance checks	["Check and update allowances correctly", "Use OpenZeppelin ERC20", "Add require(_allowances[from][msg.sender] >= amount)"]	["https://github.com/Decurity/semgrep-smart-contracts"]	{static}	0.15	{solidity}	Custom transferFrom implementation with incorrect allowance handling enabling theft	{approval,allowance,transferFrom,ERC20,token}	2025-10-31 23:32:55.75783+00	2025-10-31 23:47:32.843295+00	t
BVD-EVM-ACC-005	Unrestricted Ownership Transfer	transferOwnership lacks access control allowing takeover	access-control	critical	SWC-105	CWE-284	A2: Access Control	Add onlyOwner modifier to transferOwnership	["function transferOwnership(...) public onlyOwner", "Use OpenZeppelin Ownable", "Implement two-step transfer"]	["https://docs.openzeppelin.com/contracts/4.x/api/access#Ownable"]	{static}	0.05	{solidity}	Ownership transfer function public without onlyOwner allowing contract takeover	{ownership,transfer,takeover,"access control",onlyOwner}	2025-10-31 23:32:55.791121+00	2025-10-31 23:47:32.888348+00	t
BVD-EVM-DEP-002	Deprecated sha3 Function	Usage of deprecated sha3() function instead of keccak256()	deprecated	low	\N	CWE-477	\N	Replace sha3() with keccak256()	["Use keccak256() instead of sha3()", "Update to modern Solidity hashing functions"]	["https://docs.soliditylang.org/en/latest/050-breaking-changes.html"]	{static}	0.05	{solidity}	Deprecated sha3 cryptographic function replaced by keccak256 in modern Solidity	{deprecated,sha3,keccak256,hash,cryptography}	2025-10-31 23:32:55.8324+00	2025-10-31 23:47:32.929346+00	t
BVD-EVM-ACC-006	tx.origin Authentication	Using tx.origin for authentication enables phishing attacks	access-control	high	SWC-115	CWE-283	A2: Access Control	Use msg.sender instead of tx.origin for authentication	["require(msg.sender == owner)", "Never use tx.origin for authorization", "tx.origin only valid for rejecting external calls"]	["https://swcregistry.io/docs/SWC-115", "https://consensys.github.io/smart-contract-best-practices/development-recommendations/solidity-specific/tx-origin/"]	{static}	0.1	{solidity}	tx.origin used for authentication allowing phishing attacks via intermediary malicious contracts	{tx.origin,authentication,phishing,authorization,msg.sender}	2025-10-31 23:32:55.838699+00	2025-10-31 23:47:32.936527+00	t
BVD-EVM-DAT-001	Storage Array Memory Assignment	Assigning storage array to memory variable doesn't create copy	data-structure	high	SWC-128	CWE-664	A4: Data Integrity	Explicitly copy array elements or use storage pointer	["Use storage pointer: uint[] storage copy = original", "Manually copy elements in loop"]	["https://docs.soliditylang.org/en/latest/types.html#data-location"]	{static}	0.1	{solidity}	Assignment from storage to memory creates reference not copy, causing unexpected behavior	{storage,memory,array,reference,copy}	2025-10-31 23:32:55.874805+00	2025-10-31 23:47:32.963861+00	t
BVD-EVM-LOG-008	Dangerous Unary Operator	Unary operator (++/--) used on expression instead of simple variable	logic	high	SWC-128	CWE-682	A1: Logic Errors	Only use ++ or -- on simple variable references	["Replace arr[i++]++ with proper indexing", "Separate increment operations"]	["https://docs.soliditylang.org/en/latest/types.html#operators"]	{static}	0.1	{solidity}	Applying ++ or -- to complex expressions can cause undefined behavior	{unary,increment,decrement,operator}	2025-10-31 23:32:55.917007+00	2025-10-31 23:47:33.004016+00	t
BVD-EVM-GAS-006	Require/Revert in Loop	Require or revert in loop can cause excessive gas usage	gas	low	SWC-113	CWE-400	A5: Gas Optimization	Validate before loop or restructure logic	["Move validation outside loop", "Pre-validate array elements"]	[]	{static}	0.2	{solidity}	Validation inside loop multiplies gas cost	{require,revert,loop,gas}	2025-10-31 23:32:55.965387+00	2025-10-31 23:47:33.048197+00	t
BVD-EVM-GAS-007	State Variable Read in External Call	State variable read in external function, use calldata	gas	low	SWC-110	CWE-1164	A5: Gas Optimization	Use calldata for external function parameters	["Change 'memory' to 'calldata' for arrays", "Cache state variable in local variable"]	[]	{static}	0.25	{solidity}	Reading state in external function wastes gas on SLOAD	{calldata,gas,external}	2025-10-31 23:32:55.972871+00	2025-10-31 23:47:33.051423+00	t
BVD-EVM-PRA-001	Unspecific Solidity Pragma	Pragma uses floating version allowing any compiler	compiler	low	SWC-103	CWE-664	A9: Code Quality	Use specific compiler version or narrow range	["Change ^0.8.0 to 0.8.19", "Use narrow range: >=0.8.19 <0.9.0"]	["https://swcregistry.io/docs/SWC-103"]	{static}	0.15	{solidity}	Floating pragma allows untested compiler versions	{pragma,compiler,version}	2025-10-31 23:32:55.984417+00	2025-10-31 23:47:33.062538+00	t
BVD-EVM-VAL-001	Missing Address Zero Check	Address parameter not validated against zero address	validation	low	SWC-123	CWE-20	A3: Input Validation	Add require(address != address(0)) check	["require(addr != address(0), \\"Zero address\\")", "Use OpenZeppelin Address utilities"]	["https://swcregistry.io/docs/SWC-123"]	{static}	0.2	{solidity}	Address parameter accepted without zero address validation	{address,validation,"zero address"}	2025-10-31 23:32:55.987347+00	2025-10-31 23:47:33.067822+00	t
BVD-EVM-COD-013	Boolean Equality	Comparing boolean with true/false is redundant	code-quality	low	SWC-110	CWE-1164	A9: Code Quality	Use boolean directly in condition	["Replace 'if (x == true)' with 'if (x)'", "Replace 'if (x == false)' with 'if (!x)'"]	[]	{static}	0.1	{solidity}	Explicit boolean comparison is verbose and unnecessary	{boolean,comparison,redundant}	2025-10-31 23:32:56.025072+00	2025-10-31 23:47:33.11733+00	t
BVD-EVM-TOK-008	Arbitrary ERC20 Transfer	Unsafe use of transferFrom without validating msg.sender allows unauthorized token transfers	token	high	SWC-105	CWE-284	A1: Access Control	Validate msg.sender before calling transferFrom or use safeTransferFrom with allowance checks	["require(msg.sender == from || allowance[from][msg.sender] >= amount)", "Use OpenZeppelin SafeERC20 library", "Implement proper allowance validation"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#arbitrary-send-erc20", "https://docs.openzeppelin.com/contracts/api/token/erc20#SafeERC20"]	{static}	0.1	{solidity}	Function calls token.transferFrom without validating that msg.sender has permission to transfer tokens from the 'from' address	{erc20,transferFrom,"arbitrary transfer",unauthorized,token}	2025-10-31 23:32:56.099874+00	2025-10-31 23:47:33.194413+00	t
BVD-EVM-ARI-001	Incorrect Shift Operation	Reversed operands in shift operations (left/right) produce incorrect results	arithmetic	high	SWC-129	CWE-682	A1: Logic Errors	Verify shift operand order: value << bits (left shift) or value >> bits (right shift)	["value << 8 // shifts value left by 8 bits", "value >> 4 // shifts value right by 4 bits", "Review all shift operations for correct operand order"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#incorrect-shift"]	{static}	0.05	{solidity}	Shift operation has operands in reversed order, likely a copy-paste error	{shift,bitwise,operator,arithmetic,typo}	2025-10-31 23:32:56.106537+00	2025-10-31 23:47:33.202487+00	t
BVD-EVM-CON-002	Multiple Constructor Definitions	Contract defines multiple constructors using both old-style (function with contract name) and new-style (constructor keyword)	construction	medium	SWC-118	CWE-670	A6: Configuration	Remove old-style constructor, use only 'constructor()' keyword (Solidity 0.4.22+)	["Remove function MyContract() constructor", "Use constructor() { ... } only", "Upgrade to Solidity 0.5.0+ which disallows old-style constructors"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#multiple-constructor-schemes"]	{static}	0	{solidity}	Contract defines both old-style constructor (function with contract name) and new-style constructor keyword	{constructor,initialization,multiple,old-style,new-style}	2025-10-31 23:32:56.109595+00	2025-10-31 23:47:33.207038+00	t
BVD-EVM-UPG-001	Unprotected Upgradeable Contract	Upgradeable contract (proxy/implementation pattern) lacks initialization protection, allowing attacker takeover	access-control	critical	SWC-105	CWE-665	A1: Access Control	Use initializer modifier, disable initializers in implementation contract, protect upgrade functions	["function initialize() external initializer { ... }", "constructor() { _disableInitializers(); }", "Use OpenZeppelin's Initializable.sol", "Protect upgradeTo functions with onlyOwner"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#unprotected-upgradeable", "https://docs.openzeppelin.com/upgrades-plugins/writing-upgradeable"]	{static}	0.05	{solidity}	Contract uses upgradeable proxy pattern but initialize function lacks protection or can be called multiple times	{upgradeable,proxy,initialization,takeover,delegatecall}	2025-10-31 23:32:56.129421+00	2025-10-31 23:47:33.226455+00	t
BVD-EVM-SHA-002	Abstract Contract Variable Shadowing	State variable shadows variable from abstract contract, causing inheritance confusion	data-structure	high	SWC-119	CWE-1109	A1: Logic Errors	Rename variable in derived contract to avoid shadowing abstract contract variables	["Use unique variable names in concrete implementations", "Prefix variables with contract-specific identifiers", "Review abstract contract API before implementation"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#shadowing-abstract"]	{static}	0.1	{solidity}	Concrete contract shadows state variable declared in abstract base contract	{shadowing,abstract,inheritance,"state variable","name collision"}	2025-10-31 23:32:56.134945+00	2025-10-31 23:47:33.232239+00	t
BVD-EVM-TOK-009	Arbitrary ERC20 Transfer with Permit	Unsafe use of transferFrom with permit functionality where msg.sender is not validated as the from parameter, enabling unauthorized token transfers	token	high	SWC-105	CWE-284	A1: Access Control	Ensure the underlying ERC20 token correctly implements the permit function per EIP-2612 standards. Validate msg.sender is authorized to transfer tokens from the from address.	["Verify ERC20 token implements genuine permit per EIP-2612", "Add validation: require(msg.sender == from || allowance[from][msg.sender] >= amount)", "Use SafeERC20 library with permit validation"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#arbitrary-send-erc20-permit", "https://eips.ethereum.org/EIPS/eip-2612"]	{static}	0.1	{solidity}	Function calls transferFrom with permit signatures but does not use msg.sender as the from parameter, allowing attackers to exploit permit signatures for unauthorized transfers	{erc20,transferFrom,permit,eip-2612,"arbitrary transfer",unauthorized}	2025-10-31 23:32:56.137859+00	2025-10-31 23:47:33.236472+00	t
BVD-EVM-ARB-001	Arbitrary Send Ether	Unprotected functions send Ether to user-controlled addresses without proper access controls, enabling unauthorized fund drainage	access-control	high	SWC-105	CWE-284	A1: Access Control	Implement access controls to prevent arbitrary users from authorizing fund transfers. Use onlyOwner or role-based permissions.	["Add onlyOwner modifier to withdrawal functions", "Implement role-based access control (RBAC)", "Use pull payment pattern instead of push payments", "Validate msg.sender has permission to withdraw to specified address"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#arbitrary-send-eth", "https://consensys.github.io/smart-contract-best-practices/attacks/denial-of-service/"]	{static}	0.1	{solidity}	Function sends Ether to address controlled by function parameters or user input without verifying caller authorization	{ether,send,transfer,arbitrary,"access control",unauthorized}	2025-10-31 23:32:56.145082+00	2025-10-31 23:47:33.244285+00	t
BVD-EVM-ARI-002	Incorrect Exponentiation Operator	Bitwise XOR operator (^) used instead of exponentiation operator (**), producing incorrect mathematical results	arithmetic	high	SWC-129	CWE-682	A1: Logic Errors	Replace ^ with ** to correctly perform exponentiation operations. Review all power calculations.	["Use ** for exponentiation: value ** 2 instead of value ^ 2", "For XOR use explicit naming: valueXOR instead of value^", "Add comments to clarify XOR vs exponentiation intent", "Use SafeMath power functions for overflow protection"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#incorrect-exp", "https://docs.soliditylang.org/en/latest/types.html#exponentiation"]	{static}	0.05	{solidity}	Expression uses ^ operator in context where exponentiation is expected, indicating likely operator confusion	{exponentiation,xor,operator,arithmetic,typo,**,^}	2025-10-31 23:32:56.155579+00	2025-10-31 23:47:33.257884+00	t
BVD-EVM-DAT-004	Mapping Deletion in Struct	Deleting structures containing mappings does not delete the nested mappings themselves, potentially leaving sensitive data accessible	data-structure	medium	SWC-131	CWE-459	A6: Security Misconfiguration	Use alternative mechanisms like locks or flags instead of deletion for structures containing mappings. Explicitly clear critical mapping entries if needed.	["Use isActive flag instead of delete: struct.isActive = false", "Implement lock mechanism instead of deletion", "Manually clear critical mapping entries before struct deletion", "Document that mappings persist after struct deletion"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#mapping-deletion", "https://docs.soliditylang.org/en/latest/types.html#delete"]	{static}	0.1	{solidity}	Code deletes struct containing mapping, but Solidity delete operator does not clear nested mappings	{mapping,delete,struct,persistence,"data retention"}	2025-10-31 23:32:56.160433+00	2025-10-31 23:47:33.261266+00	t
BVD-EVM-ARI-003	Divide Before Multiply Precision Loss	Integer division performed before multiplication causes precision loss due to truncation, leading to inaccurate calculations in financial operations	arithmetic	medium	SWC-101	CWE-682	A1: Logic Errors	Reorder arithmetic operations to perform multiplication before division. This preserves precision by maximizing intermediate result magnitude before truncation.	["Change (a / b) * c to (a * c) / b", "Use fixed-point arithmetic libraries for high-precision calculations", "For percentages: (amount * percentage) / 100 instead of (amount / 100) * percentage", "Consider using WAD (18 decimals) or RAY (27 decimals) math for DeFi"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#divide-before-multiply", "https://docs.soliditylang.org/en/latest/types.html#division", "https://consensys.github.io/smart-contract-best-practices/development-recommendations/solidity-specific/integer-division/"]	{static}	0.15	{solidity}	Expression contains division operation followed by multiplication, causing intermediate truncation and loss of precision	{division,multiplication,precision,truncation,rounding,arithmetic}	2025-10-31 23:32:56.187208+00	2025-10-31 23:47:33.286077+00	t
BVD-EVM-COD-023	Boolean Constant Misuse	Boolean constants (true/false) used in conditionals or complex expressions indicate code errors or incomplete refactoring	code-quality	medium	SWC-110	CWE-570	A1: Logic Errors	Simplify expressions with boolean constants. Remove unreachable code blocks. Verify conditional logic accurately reflects intended behavior.	["Remove unreachable code: delete 'if (false)' blocks", "Simplify expressions: change 'return (b || true)' to 'return true'", "Remove redundant conditions: 'if (true && condition)' becomes 'if (condition)'", "Clean up incomplete refactoring that left boolean literals"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#boolean-constant-misuse", "https://docs.soliditylang.org/en/latest/types.html#booleans", "https://consensys.github.io/smart-contract-best-practices/development-recommendations/general/code-quality/"]	{static}	0.2	{solidity}	Boolean literal values used directly in conditional statements or complex boolean expressions	{"boolean constant","unreachable code","dead code","code quality",refactoring}	2025-10-31 23:32:56.206134+00	2025-10-31 23:47:33.307368+00	t
BVD-EVM-TYP-001	Dangerous Unary Expression	Unary expressions like '=+' or '=-' likely represent typos confusing assignment operators with arithmetic assignment operators	typo	low	SWC-129	CWE-480	A1: Logic Errors	Replace unary operators with correct arithmetic assignment operators. Review logic to ensure intended operation is performed.	["Change 'x =+ 1' to 'x += 1' for increment", "Change 'y =- 2' to 'y -= 2' for decrement", "Remove unary plus if assignment is intended: 'x = +1' becomes 'x = 1'", "Review all unary operators to verify intended operation"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#dangerous-unary-expressions", "https://docs.soliditylang.org/en/latest/types.html#operators", "https://swcregistry.io/docs/SWC-129"]	{static}	0.1	{solidity}	Expression uses unary operator in context suggesting typo or operator confusion	{typo,"unary operator","operator confusion","syntax error","code quality"}	2025-10-31 23:32:56.225974+00	2025-10-31 23:47:33.328866+00	t
BVD-EVM-COD-032	Unimplemented Function	Interface or abstract function not implemented in derived contract	code-quality	informational	\N	CWE-573	A04: Insecure Design	Implement all required interface/abstract functions in derived contracts	["Add missing function implementations", "Override abstract functions", "Mark contract as abstract if intentionally incomplete"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#unimplemented-functions"]	{static}	0.05	{solidity}	\N	{}	2025-10-31 23:32:56.270686+00	2025-10-31 23:47:33.374554+00	t
BVD-EVM-OPT-005	State Variable Could Be Constant	State variable never changes after deployment but not marked constant, wasting gas on storage operations	optimization	optimization	\N	CWE-1041	A05: Security Misconfiguration	Add constant keyword to state variables that never change to optimize gas usage	["uint constant MAX_SUPPLY = 1000000;", "address constant TREASURY = 0x...; ", "Mark unchanging state variables as constant"]	["https://github.com/crytic/slither/wiki/Detector-Documentation#state-variables-that-could-be-declared-constant"]	{static}	0.1	{solidity}	\N	{}	2025-10-31 23:32:56.303765+00	2025-10-31 23:47:33.411987+00	t
BVD-VYPER-REE-001	Reentrancy via External Call in Vyper	Function performs external call before updating state variables, allowing reentrancy attacks in Vyper contracts	reentrancy	high	SWC-107	CWE-841	A1: Reentrancy	Use @nonreentrant decorator or follow checks-effects-interactions pattern by updating state before external calls	[{"language": "vyper", "fixed_code": "@external\\n@nonreentrant('lock')\\ndef withdraw():\\n    amount: uint256 = self.balances[msg.sender]\\n    self.balances[msg.sender] = 0  # State update first\\n    send(msg.sender, amount)  # External call after", "vulnerable_code": "@external\\ndef withdraw():\\n    amount: uint256 = self.balances[msg.sender]\\n    send(msg.sender, amount)  # External call first\\n    self.balances[msg.sender] = 0  # State update after"}]	["https://docs.vyperlang.org/", "https://github.com/vyperlang/vyper/security", "https://swcregistry.io/docs/SWC-107"]	{static-analysis}	0.1	{vyper}	External call to untrusted address before state variable update in Vyper function	{vyper,reentrancy,send,"external call",@nonreentrant,"state change"}	2025-10-31 23:32:56.315703+00	2025-10-31 23:47:33.424462+00	t
BVD-VYPER-REE-006	msg.value in Loop in Vyper	Using msg.value inside a loop can lead to incorrect fund distribution and reentrancy issues	reentrancy	high	SWC-113	CWE-841	A1: Reentrancy	Calculate total payment before loop and send individual amounts without using msg.value	[{"language": "vyper", "fixed_code": "@external\\n@payable\\ndef distribute(recipients: DynArray[address, 10]):\\n    amount_per: uint256 = msg.value / len(recipients)\\n    for recipient in recipients:\\n        send(recipient, amount_per)", "vulnerable_code": "@external\\n@payable\\ndef distribute(recipients: DynArray[address, 10]):\\n    for recipient in recipients:\\n        send(recipient, msg.value / len(recipients))  # msg.value in loop"}]	["https://docs.vyperlang.org/", "https://swcregistry.io/docs/SWC-113"]	{static-analysis}	0.05	{vyper}	msg.value accessed inside loop iteration in Vyper	{vyper,msg.value,loop,reentrancy}	2025-10-31 23:32:56.329726+00	2025-10-31 23:47:33.438795+00	t
BVD-VYPER-ACC-004	Arbitrary From in transferFrom in Vyper	transferFrom allows arbitrary from parameter enabling unauthorized token transfers	access-control	critical	SWC-105	CWE-284	A1: Broken Access Control	Validate from address, check allowances properly, ensure msg.sender authorization	[{"language": "vyper", "fixed_code": "@external\\ndef transferFrom(from_addr: address, to: address, amount: uint256):\\n    assert self.allowances[from_addr][msg.sender] >= amount, \\"Insufficient allowance\\"\\n    self.allowances[from_addr][msg.sender] -= amount\\n    self.balances[from_addr] -= amount\\n    self.balances[to] += amount", "vulnerable_code": "@external\\ndef transferFrom(from_addr: address, to: address, amount: uint256):\\n    self.balances[from_addr] -= amount\\n    self.balances[to] += amount"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.05	{vyper}	transferFrom without allowance check in Vyper ERC20	{vyper,transferFrom,allowance,ERC20,authorization}	2025-10-31 23:32:56.356331+00	2025-10-31 23:47:33.454973+00	t
BVD-VYPER-ACC-005	Arbitrary From with Permit in Vyper	Permit function allows transferFrom with arbitrary from without proper signature validation	access-control	high	SWC-105	CWE-284	A1: Broken Access Control	Properly validate EIP-2612 permit signatures, check nonces, verify deadline	[{"language": "vyper", "fixed_code": "@external\\ndef permit_transfer(from_addr: address, to: address, amount: uint256, deadline: uint256, v: uint8, r: bytes32, s: bytes32):\\n    assert block.timestamp <= deadline, \\"Expired\\"\\n    # Verify signature\\n    digest: bytes32 = self._get_permit_digest(from_addr, msg.sender, amount, self.nonces[from_addr], deadline)\\n    assert ecrecover(digest, v, r, s) == from_addr, \\"Invalid signature\\"\\n    self.nonces[from_addr] += 1\\n    self.balances[from_addr] -= amount\\n    self.balances[to] += amount", "vulnerable_code": "@external\\ndef permit_transfer(from_addr: address, to: address, amount: uint256):\\n    self.balances[from_addr] -= amount\\n    self.balances[to] += amount"}]	["https://eips.ethereum.org/EIPS/eip-2612"]	{static-analysis}	0.1	{vyper}	EIP-2612 permit without signature validation in Vyper	{vyper,permit,EIP-2612,signature,ecrecover}	2025-10-31 23:32:56.360101+00	2025-10-31 23:47:33.457653+00	t
BVD-VYPER-INT-001	Divide Before Multiply in Vyper	Division performed before multiplication causes precision loss in integer arithmetic	arithmetic	medium	SWC-101	CWE-682	A8: Software and Data Integrity Failures	Perform multiplication before division to minimize precision loss	[{"language": "vyper", "fixed_code": "@external\\n@view\\ndef calculate_fee(amount: uint256, rate: uint256) -> uint256:\\n    return (amount * rate) / 1000  # Multiply first preserves precision", "vulnerable_code": "@external\\n@view\\ndef calculate_fee(amount: uint256, rate: uint256) -> uint256:\\n    return (amount / 1000) * rate  # Division first loses precision"}]	["https://docs.vyperlang.org/", "https://swcregistry.io/docs/SWC-101"]	{static-analysis}	0.15	{vyper}	Integer division followed by multiplication in Vyper arithmetic	{vyper,division,multiplication,precision,integer}	2025-10-31 23:32:56.388498+00	2025-10-31 23:47:33.489798+00	t
BVD-VYPER-INT-003	Incorrect Shift in Assembly in Vyper	Bit shift operation in inline assembly has incorrect direction or magnitude	arithmetic	high	SWC-101	CWE-682	A8: Software and Data Integrity Failures	Verify shift direction (left vs right), validate shift amount, add bounds checks	[{"language": "vyper", "fixed_code": "# Validate shift amount\\nassert shift_amount < 256, \\"Shift too large\\"\\nresult: uint256 = value << shift_amount", "vulnerable_code": "# Note: Vyper doesn't support inline assembly like Solidity\\n# This pattern would apply if using low-level operations\\nresult: uint256 = value << 256  # Shifts beyond uint256"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.1	{vyper}	Bit shift with incorrect direction or overflow in Vyper	{vyper,shift,bitwise,overflow,assembly}	2025-10-31 23:32:56.395929+00	2025-10-31 23:47:33.499457+00	t
BVD-VYPER-INT-006	Tautology or Contradiction in Vyper	Logical condition is always true or always false indicating logic error	arithmetic	high	SWC-110	CWE-570	A8: Software and Data Integrity Failures	Review conditional logic, fix comparison operators, verify intended behavior	[{"language": "vyper", "fixed_code": "@external\\n@view\\ndef check_balance(amount: uint256, minimum: uint256) -> bool:\\n    return amount >= minimum  # Meaningful comparison", "vulnerable_code": "@external\\n@view\\ndef check_balance(amount: uint256) -> bool:\\n    # uint256 is always >= 0, this is always true\\n    return amount >= 0"}]	["https://swcregistry.io/docs/SWC-110"]	{static-analysis}	0.1	{vyper}	Condition that is always true or always false in Vyper	{vyper,tautology,contradiction,logic,condition}	2025-10-31 23:32:56.409549+00	2025-10-31 23:47:33.512111+00	t
BVD-VYPER-INT-009	Weak Pseudo-Random Number Generator in Vyper	Using predictable sources like block attributes for randomness	arithmetic	medium	SWC-120	CWE-330	A2: Cryptographic Failures	Use Chainlink VRF, API3 QRNG, or other secure randomness oracles	[{"language": "vyper", "fixed_code": "# Use Chainlink VRF or similar oracle\\nvrf_coordinator: public(address)\\n\\n@external\\ndef request_randomness():\\n    # Request from VRF oracle\\n    self.vrf.request_random_words()", "vulnerable_code": "@external\\n@view\\ndef get_random() -> uint256:\\n    # Predictable - miners can manipulate\\n    return convert(blockhash(block.number - 1), uint256) % 100"}]	["https://swcregistry.io/docs/SWC-120", "https://docs.chain.link/vrf"]	{static-analysis}	0.15	{vyper}	Randomness derived from block attributes in Vyper	{vyper,randomness,PRNG,blockhash,VRF,oracle}	2025-10-31 23:32:56.422147+00	2025-10-31 23:47:33.523048+00	t
BVD-VYPER-EXT-007	Return Instead of Leave in Vyper	Incorrect control flow in low-level code using return instead of proper exit	external-calls	medium	SWC-127	CWE-670	A8: Software and Data Integrity Failures	Vyper handles control flow automatically; avoid manual return manipulation	[{"language": "vyper", "fixed_code": "@internal\\ndef _safe_exit() -> uint256:\\n    result: uint256 = 0\\n    # Proper Vyper control flow\\n    if self.some_condition:\\n        result = self.calculate_value()\\n    return result", "vulnerable_code": "# Vyper doesn't expose low-level return/leave\\n# This is a preventive pattern for future features\\n@internal\\ndef _unsafe_exit() -> uint256:\\n    # Attempting to manipulate control flow\\n    return 0  # Potential incorrect early exit"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.2	{vyper}	Incorrect control flow handling in Vyper functions	{vyper,return,leave,"control flow"}	2025-10-31 23:32:56.44752+00	2025-10-31 23:47:33.548931+00	t
BVD-VYPER-EXT-009	Chainlink Feed Registry Usage in Vyper	Direct use of Chainlink Feed Registry which is deprecated in favor of specific feeds	external-calls	low	SWC-111	CWE-477	A6: Vulnerable and Outdated Components	Use specific Chainlink price feeds instead of the Feed Registry	[{"language": "vyper", "fixed_code": "interface AggregatorV3:\\n    def latestRoundData() -> (uint80, int256, uint256, uint256, uint80): view\\n\\n@external\\n@view\\ndef get_price() -> int256:\\n    # Use specific price feed\\n    roundId: uint80 = 0\\n    answer: int256 = 0\\n    startedAt: uint256 = 0\\n    updatedAt: uint256 = 0\\n    answeredInRound: uint80 = 0\\n    (roundId, answer, startedAt, updatedAt, answeredInRound) = self.price_feed.latestRoundData()\\n    assert answer > 0, \\"Invalid price\\"\\n    return answer", "vulnerable_code": "interface FeedRegistry:\\n    def latestRoundData(base: address, quote: address) -> (uint80, int256, uint256, uint256, uint80): view\\n\\n@external\\n@view\\ndef get_price(base: address, quote: address) -> int256:\\n    # Using deprecated Feed Registry\\n    roundId: uint80 = 0\\n    answer: int256 = 0\\n    startedAt: uint256 = 0\\n    updatedAt: uint256 = 0\\n    answeredInRound: uint80 = 0\\n    (roundId, answer, startedAt, updatedAt, answeredInRound) = self.feed_registry.latestRoundData(base, quote)\\n    return answer"}]	["https://docs.chain.link/", "https://docs.vyperlang.org/"]	{static-analysis}	0.1	{vyper}	Chainlink Feed Registry interface usage in Vyper contract	{vyper,chainlink,"feed registry",oracle,deprecated}	2025-10-31 23:32:56.455496+00	2025-10-31 23:47:33.556144+00	t
BVD-VYPER-STA-003	Uninitialized Local Variable in Vyper	Local variable used before being assigned a value	state-variables	medium	SWC-109	CWE-457	A8: Software and Data Integrity Failures	Initialize all local variables before use, Vyper enforces this at compile time	[{"language": "vyper", "fixed_code": "@external\\ndef calculate() -> uint256:\\n    result: uint256 = 0  # Initialize to default\\n    if self.some_condition:\\n        result = 100\\n    return result", "vulnerable_code": "@external\\ndef calculate() -> uint256:\\n    result: uint256\\n    # Vyper will error if result used without initialization\\n    if self.some_condition:\\n        result = 100\\n    return result  # May be uninitialized"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.05	{vyper}	Local variable declaration without initialization in Vyper	{vyper,"local variable",uninitialized,compilation}	2025-10-31 23:32:56.469844+00	2025-10-31 23:47:33.569572+00	t
BVD-VYPER-STA-012	Pre-Declaration Variable Usage in Vyper	Variable used before it is declared in code, Vyper prevents this at compile time	state-variables	low	SWC-131	CWE-665	A8: Software and Data Integrity Failures	Vyper enforces declaration before use; this is a compile-time error	[{"language": "vyper", "fixed_code": "value: uint256  # Declare before use\\n\\n@external\\ndef get_value() -> uint256:\\n    temp: uint256 = self.value\\n    return temp", "vulnerable_code": "@external\\ndef get_value() -> uint256:\\n    temp: uint256 = self.value  # Compiler error if value not declared\\n    return temp\\n\\nvalue: uint256  # Declaration after use - compile error"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.05	{vyper}	Variable referenced before declaration in Vyper (compile error)	{vyper,declaration,scope,compilation}	2025-10-31 23:32:56.500962+00	2025-10-31 23:47:33.599912+00	t
BVD-VYPER-STA-015	Assert State Change in Vyper	State-changing operation inside assert statement, may have side effects	state-variables	informational	SWC-110	CWE-670	A8: Software and Data Integrity Failures	Separate state changes from assertions for clarity and predictability	[{"language": "vyper", "fixed_code": "@external\\ndef process():\\n    # Separate state change from assertion\\n    new_counter: uint256 = self._increment_counter()\\n    assert new_counter > 0, \\"Failed\\"\\n\\n@internal\\ndef _increment_counter() -> uint256:\\n    self.counter += 1\\n    return self.counter", "vulnerable_code": "@external\\ndef process():\\n    # State change in assert condition\\n    assert self._increment_counter() > 0, \\"Failed\\"\\n\\n@internal\\ndef _increment_counter() -> uint256:\\n    self.counter += 1\\n    return self.counter"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.2	{vyper}	State-modifying function called within assert in Vyper	{vyper,assert,"state change","side effects"}	2025-10-31 23:32:56.512319+00	2025-10-31 23:47:33.608521+00	t
BVD-VYPER-TIM-002	Out of Order Retryable Transactions in Vyper	Arbitrum retryable tickets can execute out of order causing state inconsistencies	timestamp	medium	SWC-114	CWE-841	A8: Software and Data Integrity Failures	Implement sequence numbers or nonces for L1->L2 messages on Arbitrum	[{"language": "vyper", "fixed_code": "# On Arbitrum L2\\nlast_processed_nonce: public(uint256)\\n\\n@external\\ndef process_l1_message(nonce: uint256, data: Bytes[1024]):\\n    # Enforce ordering\\n    assert nonce == self.last_processed_nonce + 1, \\"Out of order\\"\\n    self.last_processed_nonce = nonce\\n    self.process_data(data)", "vulnerable_code": "# On Arbitrum L2\\n@external\\ndef process_l1_message(data: Bytes[1024]):\\n    # No ordering guarantee\\n    self.process_data(data)"}]	["https://docs.arbitrum.io/", "https://docs.vyperlang.org/"]	{static-analysis}	0.2	{vyper}	L1 to L2 message handling without ordering guarantees in Vyper on Arbitrum	{vyper,arbitrum,retryable,L2,ordering,nonce}	2025-10-31 23:32:56.518732+00	2025-10-31 23:47:33.614057+00	t
BVD-VYPER-GAS-002	Public Function Should Be External in Vyper	Function marked public but never called internally, should use external	gas-optimization	informational	SWC-128	CWE-1050	A8: Software and Data Integrity Failures	Note: Vyper only has @external and @internal, this is less relevant than Solidity	[{"language": "vyper", "fixed_code": "# In Vyper, @external is the correct decorator\\n# @internal for functions only called within contract\\n@external\\ndef get_balance() -> uint256:\\n    return self.balance\\n\\n@internal\\ndef _internal_helper() -> uint256:\\n    return self.balance * 2", "vulnerable_code": "# Vyper doesn't have 'public' functions like Solidity\\n# All external-facing functions use @external\\n@external\\ndef get_balance() -> uint256:\\n    return self.balance"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.4	{vyper}	Function visibility optimization in Vyper (@external vs @internal)	{vyper,"gas optimization",@external,@internal,visibility}	2025-10-31 23:32:56.526434+00	2025-10-31 23:47:33.619959+00	t
BVD-VYPER-GAS-009	Mapping Deletion with Struct in Vyper	Deleting HashMap entry containing struct doesn't free all storage slots	gas-optimization	high	SWC-131	CWE-1091	A8: Software and Data Integrity Failures	Manually set struct fields to zero/empty before or instead of deletion	[{"language": "vyper", "fixed_code": "struct User:\\n    balance: uint256\\n    active: bool\\n    data: Bytes[100]\\n\\nusers: HashMap[address, User]\\n\\n@external\\ndef remove_user(addr: address):\\n    # Explicitly clear all fields\\n    self.users[addr].balance = 0\\n    self.users[addr].active = False\\n    self.users[addr].data = b\\"\\"", "vulnerable_code": "struct User:\\n    balance: uint256\\n    active: bool\\n    data: Bytes[100]\\n\\nusers: HashMap[address, User]\\n\\n@external\\ndef remove_user(addr: address):\\n    # Delete doesn't fully clear struct storage\\n    self.users[addr] = empty(User)"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.2	{vyper}	HashMap with struct values deleted without explicit field clearing in Vyper	{vyper,HashMap,struct,deletion,storage,clear}	2025-10-31 23:32:56.549826+00	2025-10-31 23:47:33.642809+00	t
BVD-VYPER-GAS-012	High Cyclomatic Complexity in Vyper	Function has excessive branching and complexity making it expensive and hard to audit	gas-optimization	informational	SWC-128	CWE-1121	A8: Software and Data Integrity Failures	Refactor complex functions into smaller, focused functions	[{"language": "vyper", "fixed_code": "@external\\ndef complex_logic(a: uint256, b: uint256, c: uint256) -> uint256:\\n    return self._calculate(a, b, c)\\n\\n@internal\\ndef _calculate(a: uint256, b: uint256, c: uint256) -> uint256:\\n    if a <= 10:\\n        return 0\\n    return self._calculate_high_a(a, b, c)\\n\\n@internal\\ndef _calculate_high_a(a: uint256, b: uint256, c: uint256) -> uint256:\\n    if b > 20 and c > 30:\\n        return a + b + c\\n    elif b > 20:\\n        return a + b\\n    elif c > 30:\\n        return a + c\\n    else:\\n        return a", "vulnerable_code": "@external\\ndef complex_logic(a: uint256, b: uint256, c: uint256) -> uint256:\\n    result: uint256 = 0\\n    if a > 10:\\n        if b > 20:\\n            if c > 30:\\n                result = a + b + c\\n            else:\\n                result = a + b\\n        else:\\n            if c > 30:\\n                result = a + c\\n            else:\\n                result = a\\n    else:\\n        # Many more nested conditions...\\n        result = 0\\n    return result"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.25	{vyper}	Function with high cyclomatic complexity in Vyper	{vyper,complexity,refactor,maintainability}	2025-10-31 23:32:56.560612+00	2025-10-31 23:47:33.660452+00	t
BVD-VYPER-LOG-002	Dangerous Strict Equality in Vyper	Using == for balance or timestamp checks can be manipulated or fail unexpectedly	logic	high	SWC-132	CWE-670	A8: Software and Data Integrity Failures	Use >= or <= for balance/timestamp comparisons instead of strict equality	[{"language": "vyper", "fixed_code": "@external\\ndef claim_reward():\\n    # Safe: threshold check\\n    assert self.balance >= 1000000000000000000, \\"Insufficient balance\\"\\n    send(msg.sender, self.reward)", "vulnerable_code": "@external\\ndef claim_reward():\\n    # Dangerous: exact balance check\\n    assert self.balance == 1000000000000000000, \\"Wrong balance\\"\\n    send(msg.sender, self.reward)"}]	["https://docs.vyperlang.org/", "https://swcregistry.io/docs/SWC-132"]	{static-analysis}	0.2	{vyper}	Strict equality check on balance, timestamp, or block number in Vyper	{vyper,"strict equality",balance,timestamp,==}	2025-10-31 23:32:56.572093+00	2025-10-31 23:47:33.674348+00	t
BVD-VYPER-LOG-010	Duplicate Initialization Logic in Vyper	Initialization logic duplicated across multiple functions	logic	medium	SWC-119	CWE-665	A8: Software and Data Integrity Failures	Note: Vyper only has __init__ constructor; avoid duplicate initialization patterns	[{"language": "vyper", "fixed_code": "initialized: bool\\n\\n@external\\ndef __init__():\\n    self.owner = msg.sender\\n    self.initialized = True\\n\\n@external\\ndef transfer_ownership(new_owner: address):\\n    assert msg.sender == self.owner, \\"Not owner\\"\\n    assert self.initialized, \\"Not initialized\\"\\n    self.owner = new_owner", "vulnerable_code": "initialized: bool\\n\\n@external\\ndef __init__():\\n    self.owner = msg.sender\\n    self.initialized = True\\n\\n@external\\ndef reinitialize():  # Dangerous: allows reinitialization\\n    self.owner = msg.sender\\n    self.initialized = True"}]	["https://docs.vyperlang.org/"]	{static-analysis}	0.2	{vyper}	Multiple functions performing initialization in Vyper	{vyper,initialization,__init__,reinitialization}	2025-10-31 23:32:56.597492+00	2025-10-31 23:47:33.70571+00	t
BVD-VYPER-DAT-005	Incorrect ERC721 Interface in Vyper	ERC721 NFT interface implementation missing required functions or events	data-handling	high	SWC-126	CWE-573	A8: Software and Data Integrity Failures	Use standard ERC721 interface and implement all required functions and events	[{"language": "vyper", "fixed_code": "from vyper.interfaces import ERC721\\n\\nimplements: ERC721\\n\\nevent Transfer:\\n    sender: indexed(address)\\n    receiver: indexed(address)\\n    token_id: indexed(uint256)\\n\\nowners: HashMap[uint256, address]\\n\\n@external\\ndef transferFrom(from_addr: address, to: address, token_id: uint256):\\n    assert self.owners[token_id] == from_addr, \\"Not owner\\"\\n    assert to != empty(address), \\"Invalid recipient\\"\\n    self.owners[token_id] = to\\n    log Transfer(from_addr, to, token_id)", "vulnerable_code": "# Incomplete ERC721\\nowners: HashMap[uint256, address]\\n\\n@external\\ndef transferFrom(from_addr: address, to: address, token_id: uint256):\\n    self.owners[token_id] = to"}]	["https://docs.vyperlang.org/", "https://eips.ethereum.org/EIPS/eip-721"]	{static-analysis}	0.1	{vyper}	Incomplete or incorrect ERC721 interface implementation in Vyper	{vyper,ERC721,NFT,interface,standard}	2025-10-31 23:32:56.621216+00	2025-10-31 23:47:33.729258+00	t
BVD-VYPER-DAT-010	Pyth Oracle Unchecked Confidence in Vyper	Pyth Network price feed used without validating confidence interval	data-handling	high	SWC-111	CWE-20	A3: Injection	Check Pyth price confidence interval before using price data	[{"language": "vyper", "fixed_code": "interface IPyth:\\n    def getPriceUnsafe(id: bytes32) -> (int64, uint64, int32, uint256): view\\n\\nMAX_CONFIDENCE_RATIO: constant(uint256) = 100  # 1% max confidence\\n\\n@external\\n@view\\ndef get_price(price_id: bytes32) -> int64:\\n    price: int64 = 0\\n    conf: uint64 = 0\\n    expo: int32 = 0\\n    timestamp: uint256 = 0\\n    (price, conf, expo, timestamp) = self.pyth.getPriceUnsafe(price_id)\\n    \\n    # Validate confidence interval\\n    abs_price: uint256 = convert(price if price > 0 else -price, uint256)\\n    confidence_ratio: uint256 = (convert(conf, uint256) * 10000) / abs_price\\n    assert confidence_ratio <= MAX_CONFIDENCE_RATIO, \\"Price confidence too low\\"\\n    \\n    return price", "vulnerable_code": "interface IPyth:\\n    def getPrice(id: bytes32) -> (int64, uint64, int32, uint256): view\\n\\n@external\\n@view\\ndef get_price(price_id: bytes32) -> int64:\\n    price: int64 = 0\\n    conf: uint64 = 0\\n    expo: int32 = 0\\n    timestamp: uint256 = 0\\n    (price, conf, expo, timestamp) = self.pyth.getPrice(price_id)\\n    # Confidence not checked\\n    return price"}]	["https://docs.pyth.network/", "https://docs.vyperlang.org/"]	{static-analysis}	0.15	{vyper}	Pyth oracle price used without confidence validation in Vyper	{vyper,pyth,oracle,confidence,"price feed"}	2025-10-31 23:32:56.636339+00	2025-10-31 23:47:33.744443+00	t
BVD-VYPER-VER-004	Naming Convention Violation in Vyper	Code doesn't follow Vyper naming conventions	version	informational	SWC-103	CWE-1099	A8: Software and Data Integrity Failures	Follow Vyper conventions: CONSTANTS, snake_case functions/variables, internal functions with _prefix	[{"language": "vyper", "fixed_code": "MAX_SUPPLY: constant(uint256) = 1000000  # Constants in CAPS\\nbalance: uint256  # Variables in snake_case\\n\\n@external\\ndef get_balance() -> uint256:  # Functions in snake_case\\n    return self.balance\\n\\n@internal\\ndef _internal_helper() -> uint256:  # Internal with _ prefix\\n    return self.balance * 2", "vulnerable_code": "MaxSupply: uint256  # Should be CONSTANT or snake_case\\n\\ndef GetBalance() -> uint256:  # Should be snake_case\\n    return self.Balance  # Should be snake_case"}]	["https://docs.vyperlang.org/", "https://vyper.readthedocs.io/en/stable/style-guide.html"]	{static-analysis}	0.25	{vyper}	Identifier naming not following Vyper conventions	{vyper,"naming convention",snake_case,"style guide"}	2025-10-31 23:32:56.649066+00	2025-10-31 23:47:33.757258+00	t
BVD-VYPER-VER-007	Pyth Network Deprecated Functions in Vyper	Using deprecated Pyth Network oracle functions	version	high	SWC-111	CWE-477	A6: Vulnerable and Outdated Components	Update to current Pyth interface: use getPriceUnsafe or getPriceNoOlderThan	[{"language": "vyper", "fixed_code": "interface IPyth:\\n    def getPriceUnsafe(id: bytes32) -> (int64, uint64, int32, uint256): view\\n\\n@external\\n@view\\ndef get_price(price_id: bytes32) -> int64:\\n    price: int64 = 0\\n    conf: uint64 = 0\\n    expo: int32 = 0\\n    publish_time: uint256 = 0\\n    (price, conf, expo, publish_time) = self.pyth.getPriceUnsafe(price_id)\\n    \\n    # Validate freshness\\n    assert block.timestamp - publish_time < 60, \\"Price too old\\"\\n    return price", "vulnerable_code": "interface IPythDeprecated:\\n    def getPrice(id: bytes32) -> (int64, uint64): view  # Deprecated\\n\\n@external\\n@view\\ndef get_price(price_id: bytes32) -> int64:\\n    price: int64 = 0\\n    conf: uint64 = 0\\n    (price, conf) = self.pyth.getPrice(price_id)\\n    return price"}]	["https://docs.pyth.network/", "https://docs.vyperlang.org/"]	{static-analysis}	0.1	{vyper}	Deprecated Pyth Network function usage in Vyper	{vyper,pyth,oracle,deprecated,"price feed"}	2025-10-31 23:32:56.661176+00	2025-10-31 23:47:33.768893+00	t
BVD-SOLANA-ACC-001	Account Data Matching Vulnerability	Account data validation mismatches where account discriminators or data fields are not properly verified before use. In Solana's account-based model, accounts store arbitrary data and programs must validate that the account data structure matches expected types. Missing validation can lead to type confusion attacks where malicious accounts are passed to instruction handlers.	account-validation	high	\N	CWE-20	A03:2021	Implement proper account discriminator validation and data structure verification before processing accounts.	[{"language": "solana", "fixed_code": ": Validate discriminator\\nuse anchor_lang::prelude::*;\\n\\n#[account]\\npub struct MyAccount {\\n    pub discriminator: [u8; 8],\\n    pub value: u64,\\n}\\n\\npub fn process_instruction(ctx: Context<ProcessAccounts>) -> Result<()> {\\n    // Anchor automatically validates discriminator\\n    let account = &ctx.accounts.my_account;\\n    require!(account.discriminator == MyAccount::discriminator(), ErrorCode::InvalidAccount);\\n    Ok(())\\n}", "vulnerable_code": "No discriminator check\\npub fn process_instruction(accounts: &[AccountInfo]) -> ProgramResult {\\n    let account = &accounts[0];\\n    let data = AccountData::try_from_slice(&account.data.borrow())?;\\n    // Use data without validation\\n}"}]	["https://github.com/coral-xyz/sealevel-attacks/tree/master/programs/6-account-data-matching", "https://docs.solana.com/developing/programming-model/accounts"]	\N	0	{solana}	\N	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
BVD-SOLANA-ACC-002	Account Data Reallocation Vulnerability	Improper reassignment of account resources where account data is reallocated without proper validation or cleanup. In Solana, accounts can be resized using realloc, but improper handling can lead to data corruption, loss of lamports, or unauthorized state changes. This vulnerability occurs when reallocation doesn't properly validate ownership, check size constraints, or handle existing data.	account-validation	high	\N	CWE-664	A04:2021	Validate account ownership and implement proper size checks before reallocating account data. Ensure existing data is properly handled during reallocation.	[{"language": "solana", "fixed_code": ": Validate before reallocation\\nuse anchor_lang::prelude::*;\\n\\npub fn reallocate_account(ctx: Context<ReallocateAccounts>, new_size: usize) -> Result<()> {\\n    let account = &ctx.accounts.my_account.to_account_info();\\n    \\n    // Validate ownership\\n    require!(account.owner == ctx.program_id, ErrorCode::InvalidOwner);\\n    \\n    // Validate size constraints\\n    require!(new_size >= MIN_SIZE && new_size <= MAX_SIZE, ErrorCode::InvalidSize);\\n    \\n    // Check rent exemption\\n    let rent = Rent::get()", "vulnerable_code": "Unchecked reallocation\\naccount.realloc(new_size, false)?;"}]	["https://docs.solana.com/developing/programming-model/accounts#realloc", "https://github.com/coral-xyz/anchor/discussions/2046"]	\N	0	{solana}	\N	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
BVD-SOLANA-ACC-003	Account Reinitialization Vulnerability	Unsafe account reset operations that allow accounts to be reinitialized after creation, leading to state manipulation attacks. In Solana, once an account is initialized, it should not be reinitialized unless explicitly designed to be reusable. Missing initialization checks allow attackers to reset account state, potentially bypassing access controls or manipulating balances.	account-validation	high	\N	CWE-665	A04:2021	Implement initialization flags and use the `init` constraint in Anchor to prevent reinitialization. Check that accounts are not already initialized before creating new state.	[{"language": "solana", "fixed_code": ": Prevent reinitialization with Anchor\\n#[derive(Accounts)]\\npub struct Initialize<'info> {\\n    #[account(\\n        init,\\n        payer = authority,\\n        space = 8 + MyAccount::INIT_SPACE\\n    )]\\n    pub my_account: Account<'info, MyAccount>,\\n    #[account(mut)]\\n    pub authority: Signer<'info>,\\n    pub system_program: Program<'info, System>,\\n}", "vulnerable_code": "No initialization check\\npub fn initialize(ctx: Context<Initialize>) -> Result<()> {\\n    let account = &mut ctx.accounts.my_account;\\n    account.authority = ctx.accounts.authority.key();\\n    account.value = 0;\\n    Ok(())\\n}"}]	["https://github.com/coral-xyz/sealevel-attacks/tree/master/programs/2-reinitialization", "https://www.anchor-lang.com/docs/account-constraints"]	\N	0	{solana}	\N	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
BVD-SOLANA-ACC-004	Missing Owner Check	Operations lacking ownership verification where programs fail to validate that accounts are owned by the expected program. In Solana's security model, programs can only modify accounts they own. Missing owner checks allow malicious programs to pass fake accounts that will be accepted and processed, potentially leading to unauthorized state changes or fund theft.	account-validation	critical	\N	CWE-862	A01:2021	Always validate account ownership before processing. Use Anchor's Account types which automatically validate ownership, or manually check the owner field.	[{"language": "solana", "fixed_code": ": Validate account owner\\npub fn process_instruction(\\n    program_id: &Pubkey,\\n    accounts: &[AccountInfo],\\n) -> ProgramResult {\\n    let account = &accounts[0];\\n    \\n    // Check that account is owned by this program\\n    if account.owner != program_id {\\n        return Err(ProgramError::IncorrectProgramId);\\n    }\\n    \\n    // Or check for specific program (e.g., Token Program)\\n    if account.owner != &spl_token::id() {\\n        return Err(ProgramError::InvalidAccountOwner);\\n    }\\n    \\n    Ok(())\\n}", "vulnerable_code": "No owner check\\npub fn process_instruction(\\n    program_id: &Pubkey,\\n    accounts: &[AccountInfo],\\n) -> ProgramResult {\\n    let account = &accounts[0];\\n    // Process account without checking owner\\n    Ok(())\\n}"}]	["https://github.com/coral-xyz/sealevel-attacks/tree/master/programs/3-owner-checks", "https://docs.solana.com/developing/programming-model/accounts#ownership"]	\N	0	{solana}	\N	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
BVD-SOLANA-ACC-005	Missing Signer Check	Missing signer validation in privileged operations where instruction handlers fail to verify that required accounts have actually signed the transaction. In Solana, the is_signer flag indicates whether an account has provided a valid signature. Missing signer checks allow unauthorized users to perform privileged operations by simply passing their account without signing.	account-validation	critical	\N	CWE-306	A07:2021	Always verify that privileged accounts have signed the transaction using the is_signer flag. Use Anchor's Signer type for automatic validation.	[{"language": "solana", "fixed_code": ": Validate signer\\npub fn withdraw(\\n    accounts: &[AccountInfo],\\n    amount: u64,\\n) -> ProgramResult {\\n    let authority = &accounts[0];\\n    let vault = &accounts[1];\\n    \\n    // Check that authority has signed\\n    if !authority.is_signer {\\n        return Err(ProgramError::MissingRequiredSignature);\\n    }\\n    \\n    **vault.lamports.borrow_mut() -= amount;\\n    **authority.lamports.borrow_mut() += amount;\\n    Ok(())\\n}", "vulnerable_code": "No signer check\\npub fn withdraw(\\n    accounts: &[AccountInfo],\\n    amount: u64,\\n) -> ProgramResult {\\n    let authority = &accounts[0];\\n    let vault = &accounts[1];\\n    \\n    // Transfer without checking if authority signed\\n    **vault.lamports.borrow_mut() -= amount;\\n    **authority.lamports.borrow_mut() += amount;\\n    Ok(())\\n}"}]	["https://github.com/coral-xyz/sealevel-attacks/tree/master/programs/4-signer-authorization", "https://docs.solana.com/developing/programming-model/transactions#signatures"]	\N	0	{solana}	\N	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
BVD-SOLANA-ACC-006	Unvalidated Sysvar Accounts	System variable (sysvar) accounts used without proper validation. Sysvars provide access to cluster state (Clock, Rent, EpochSchedule, etc.) but programs must verify they are receiving the correct sysvar account. Passing fake sysvar accounts can manipulate program logic that depends on blockchain state.	account-validation	medium	\N	CWE-20	A03:2021	Validate sysvar account addresses against known sysvar IDs before use. Use the sysvar::* modules' ID constants for validation.	[{"language": "solana", "fixed_code": ": Validate sysvar account\\nuse solana_program::{\\n    clock::Clock,\\n    sysvar::{self, Sysvar},\\n};\\n\\npub fn process(\\n    accounts: &[AccountInfo],\\n) -> ProgramResult {\\n    let clock_account = &accounts[0];\\n    \\n    // Validate this is the real Clock sysvar\\n    if clock_account.key != &sysvar::clock::id() {\\n        return Err(ProgramError::InvalidArgument);\\n    }\\n    \\n    let clock = Clock::from_account_info(clock_account)?;\\n    Ok(())\\n}", "vulnerable_code": "No sysvar validation\\nuse solana_program::clock::Clock;\\n\\npub fn process(\\n    accounts: &[AccountInfo],\\n) -> ProgramResult {\\n    let clock_account = &accounts[0];\\n    let clock = Clock::from_account_info(clock_account)?;\\n    // Use clock without validation\\n    Ok(())\\n}"}]	["https://docs.solana.com/developing/runtime-facilities/sysvars", "https://docs.rs/solana-program/latest/solana_program/sysvar/index.html"]	\N	0	{solana}	\N	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
BVD-SOLANA-CPI-003	Unchecked CPI Return Value	Cross-program invocation calls where the return value or error status is not properly validated. In Solana, CPIs can fail silently if errors are not checked, leading to programs continuing execution under the assumption that the CPI succeeded when it actually failed. This can cause state inconsistencies and loss of funds.	cross-program-invocation	high	\N	CWE-252	A04:2021	Always check the Result returned from invoke() or invoke_signed() calls. Use the ? operator or explicit error handling to ensure CPI success before continuing.	[{"language": "solana", "fixed_code": ": Check CPI result\\npub fn process() -> ProgramResult {\\n    // Propagate errors with ?\\n    invoke(&instruction, &accounts)?;\\n    \\n    // Only continue if CPI succeeded\\n    update_state();\\n    Ok(())\\n}", "vulnerable_code": "Ignored CPI result\\nuse solana_program::program::invoke;\\n\\npub fn process() -> ProgramResult {\\n    let result = invoke(&instruction, &accounts);\\n    // Continue regardless of CPI success/failure!\\n    \\n    update_state();\\n    Ok(())\\n}"}]	["https://docs.solana.com/developing/programming-model/calling-between-programs#handling-errors", "https://www.anchor-lang.com/docs/cross-program-invocations"]	\N	0	{solana}	\N	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
BVD-SOLANA-ACC-007	Insecure Account Closure	Vulnerabilities in account closure logic that can lead to fund draining, account resurrection, or improper cleanup. In Solana, closing accounts requires transferring all lamports out and zeroing data, but missing validation can allow accounts to be closed prematurely, closed by unauthorized users, or revived after closure.	account-validation	high	\N	CWE-404	A04:2021	Implement proper authorization checks before closing accounts, validate that account is in a closeable state, zero out account data, and transfer lamports to the correct recipient. Use Anchor's close constraint for automatic safe closure.	[{"language": "solana", "fixed_code": ": Proper account closure\\npub fn close_account(\\n    program_id: &Pubkey,\\n    accounts: &[AccountInfo],\\n) -> ProgramResult {\\n    let account = &accounts[0];\\n    let authority = &accounts[1];\\n    let destination = &accounts[2];\\n    \\n    // Validate ownership\\n    if account.owner != program_id {\\n        return Err(ProgramError::IncorrectProgramId);\\n    }\\n    \\n    // Validate authority signed\\n    if !authority.is_signer {\\n        return Err(ProgramError::MissingRequiredSignature);\\n    }\\n    \\n    // V", "vulnerable_code": "Insecure account closure\\npub fn close_account(accounts: &[AccountInfo]) -> ProgramResult {\\n    let account = &accounts[0];\\n    let destination = &accounts[1];\\n    \\n    // Transfer lamports without checks\\n    **destination.lamports.borrow_mut() += account.lamports();\\n    **account.lamports.borrow_mut() = 0;\\n    Ok(())\\n}"}]	["https://github.com/coral-xyz/sealevel-attacks/tree/master/programs/7-closing-accounts", "https://www.anchor-lang.com/docs/account-constraints#close"]	\N	0	{solana}	\N	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
BVD-SOLANA-ACC-008	Unverified Parsed Account Data	Account data parsed and used without prior validation of structure, discriminator, or constraints. This occurs when programs deserialize account data without verifying the account type, leading to type confusion where malicious accounts with incompatible data structures are accepted and processed.	account-validation	high	\N	CWE-20	A03:2021	Always validate account discriminators and data structure integrity before deserializing. Use Anchor's typed Account wrappers which automatically validate discriminators and structure.	[{"language": "solana", "fixed_code": ": Validate before parsing\\npub fn process(\\n    program_id: &Pubkey,\\n    accounts: &[AccountInfo],\\n) -> ProgramResult {\\n    let account = &accounts[0];\\n    \\n    // Validate owner\\n    if account.owner != program_id {\\n        return Err(ProgramError::IncorrectProgramId);\\n    }\\n    \\n    // Validate discriminator\\n    let data_slice = account.data.borrow();\\n    if data_slice.len() < 8 {\\n        return Err(ProgramError::InvalidAccountData);\\n    }\\n    \\n    let discriminator = &data_slice[0..8];\\n    if di", "vulnerable_code": "Parse without validation\\nuse borsh::BorshDeserialize;\\n\\npub fn process(accounts: &[AccountInfo]) -> ProgramResult {\\n    let account = &accounts[0];\\n    \\n    // Deserialize without checking discriminator or owner\\n    let data = MyAccount::try_from_slice(&account.data.borrow())?;\\n    \\n    // Use data - could be wrong type!\\n    process_data(&data);\\n    Ok(())\\n}"}]	["https://docs.solana.com/developing/programming-model/accounts#data", "https://www.anchor-lang.com/docs/account-types"]	\N	0	{solana}	\N	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
BVD-SOLANA-CPI-001	Arbitrary Cross-Program Invocation	Unrestricted cross-program invocations (CPI) where programs accept arbitrary program IDs without validation. In Solana, CPI allows programs to call other programs, but without proper validation, malicious programs can be invoked instead of legitimate ones. This can lead to unauthorized state changes, fund theft, or complete program compromise.	cross-program-invocation	critical	\N	CWE-749	A03:2021	Always validate that CPI target program IDs match expected addresses. Use hardcoded program IDs or verify against known addresses before invoking.	[{"language": "solana", "fixed_code": ": Validate CPI target\\nuse solana_program::program::invoke;\\nuse spl_token::id as token_program_id;\\n\\npub fn process(\\n    accounts: &[AccountInfo],\\n) -> ProgramResult {\\n    let target_program = &accounts[0];\\n    \\n    // Validate program ID before CPI\\n    if target_program.key != &token_program_id() {\\n        return Err(ProgramError::IncorrectProgramId);\\n    }\\n    \\n    invoke(\\n        &instruction,\\n        &[target_program.clone()],\\n    )?;\\n    Ok(())\\n}", "vulnerable_code": "Arbitrary CPI target\\nuse solana_program::program::invoke;\\n\\npub fn process(\\n    accounts: &[AccountInfo],\\n) -> ProgramResult {\\n    let target_program = &accounts[0];\\n    \\n    // No validation - can call ANY program!\\n    invoke(\\n        &instruction,\\n        &[target_program.clone()],\\n    )?;\\n    Ok(())\\n}"}]	["https://github.com/coral-xyz/sealevel-attacks/tree/master/programs/8-arbitrary-cpi", "https://docs.solana.com/developing/programming-model/calling-between-programs"]	\N	0	{solana}	\N	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
BVD-SOLANA-CPI-002	Duplicate Mutable Accounts in CPI	Mutable accounts passed multiple times in instruction account lists, enabling double-spend and state manipulation attacks. When the same account is provided as two different mutable references, the program can modify it multiple times in ways that violate invariants, such as withdrawing funds twice from the same account.	cross-program-invocation	critical	\N	CWE-837	A04:2021	Validate that mutable accounts are unique before processing. Check account keys to ensure no duplicates exist in critical operations.	[{"language": "solana", "fixed_code": ": Validate accounts are different\\npub fn transfer_between(\\n    from: &AccountInfo,\\n    to: &AccountInfo,\\n    amount: u64,\\n) -> ProgramResult {\\n    // Prevent same account being passed twice\\n    if from.key == to.key {\\n        return Err(ProgramError::InvalidArgument);\\n    }\\n    \\n    **from.lamports.borrow_mut() -= amount;\\n    **to.lamports.borrow_mut() += amount;\\n    Ok(())\\n}", "vulnerable_code": "No duplicate check\\npub fn transfer_between(\\n    from: &AccountInfo,\\n    to: &AccountInfo,\\n    amount: u64,\\n) -> ProgramResult {\\n    // If from == to, double the amount!\\n    **from.lamports.borrow_mut() -= amount;\\n    **to.lamports.borrow_mut() += amount;\\n    Ok(())\\n}"}]	["https://github.com/coral-xyz/sealevel-attacks/tree/master/programs/9-duplicate-mutable-accounts", "https://www.anchor-lang.com/docs/account-constraints"]	\N	0	{solana}	\N	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
BVD-SOLANA-PDA-001	Missing PDA Bump Seed Canonicalization	Program Derived Addresses (PDAs) created or validated without using canonical bump seeds. PDAs in Solana are derived from seeds and a bump value that ensures the address doesn't have a corresponding private key. Multiple bump values can produce valid PDAs, but only the canonical bump (highest value that produces a valid PDA) should be used. Missing canonicalization allows attackers to create alternative PDAs with different bump seeds, potentially bypassing access controls.	program-derived-address	high	\N	CWE-353	A04:2021	Always use find_program_address() to derive canonical PDAs and store the bump seed. When validating PDAs, verify the stored bump matches the canonical bump.	[{"language": "solana", "fixed_code": ": Use canonical bump\\npub fn create_pda(\\n    seeds: &[&[u8]],\\n    program_id: &Pubkey,\\n) -> (Pubkey, u8) {\\n    // find_program_address returns canonical bump\\n    let (pda, bump) = Pubkey::find_program_address(\\n        seeds,\\n        program_id,\\n    );\\n    \\n    // Store bump for later validation\\n    (pda, bump)\\n}\\n\\npub fn validate_pda(\\n    pda: &Pubkey,\\n    seeds: &[&[u8]],\\n    stored_bump: u8,\\n    program_id: &Pubkey,\\n) -> ProgramResult {\\n    // Verify PDA with stored bump\\n    let derived_pda = Pu", "vulnerable_code": "No bump validation\\nuse solana_program::pubkey::Pubkey;\\n\\npub fn create_pda(\\n    seeds: &[&[u8]],\\n    program_id: &Pubkey,\\n) -> ProgramResult {\\n    // Any bump value accepted\\n    let bump = 255;\\n    let pda = Pubkey::create_program_address(\\n        &[seeds[0], &[bump]],\\n        program_id,\\n    )?;\\n    // Use PDA without canonical bump\\n    Ok(())\\n}"}]	["https://docs.solana.com/developing/programming-model/calling-between-programs#program-derived-addresses", "https://www.anchor-lang.com/docs/pdas"]	\N	0	{solana}	\N	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
BVD-SOLANA-PDA-002	Insecure PDA Seed Construction	Program Derived Addresses created with insufficiently unique or predictable seeds, allowing attackers to derive PDAs for unauthorized resources. PDA security relies on using unique, unpredictable seeds that properly scope access. Using only constant seeds or easily guessable values allows attackers to compute PDAs for other users' resources.	program-derived-address	high	\N	CWE-330	A02:2021	Include user-specific data (public keys) and resource identifiers in PDA seeds to ensure uniqueness. Avoid using only constant strings or sequential numbers.	[{"language": "solana", "fixed_code": ": User-specific seeds\\nlet (pda, bump) = Pubkey::find_program_address(\\n    &[\\n        b\\"vault\\",\\n        authority.key().as_ref(),  // Unique per user\\n    ],\\n    program_id,\\n);", "vulnerable_code": "Constant-only seeds\\nlet (pda, bump) = Pubkey::find_program_address(\\n    &[b\\"vault\\"],  // Anyone can derive this!\\n    program_id,\\n);\\n\\n Predictable seeds\\nlet (pda, bump) = Pubkey::find_program_address(\\n    &[\\n        b\\"user\\",\\n        &user_id.to_le_bytes(),  // Sequential IDs are predictable\\n    ],\\n    program_id,\\n);"}]	["https://docs.solana.com/developing/programming-model/calling-between-programs#program-derived-addresses", "https://www.anchor-lang.com/docs/pdas#seeds"]	\N	0	{solana}	\N	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
BVD-SOLANA-PDA-003	PDA Signer Authorization Missing	Program Derived Addresses used in CPI calls without proper signer authorization. PDAs can sign for CPI calls using invoke_signed(), but programs must validate that the PDA derivation is correct before using it as a signer. Missing validation allows unauthorized programs to create fake PDAs and sign transactions.	program-derived-address	high	\N	CWE-862	A01:2021	Always verify PDA derivation before using it as a signer in CPI calls. Validate seeds and bump match expected values.	[{"language": "solana", "fixed_code": ": Validate PDA before signing\\npub fn transfer_from_pda(\\n    pda: &AccountInfo,\\n    authority: &Pubkey,\\n    program_id: &Pubkey,\\n) -> ProgramResult {\\n    // Derive and validate PDA\\n    let seeds = &[b\\"vault\\", authority.as_ref()];\\n    let (derived_pda, bump) = Pubkey::find_program_address(\\n        seeds,\\n        program_id,\\n    );\\n    \\n    // Verify PDA matches expected address\\n    if pda.key != &derived_pda {\\n        return Err(ProgramError::InvalidSeeds);\\n    }\\n    \\n    // Now safe to use as sig", "vulnerable_code": "No PDA validation before signing\\nuse solana_program::program::invoke_signed;\\n\\npub fn transfer_from_pda(\\n    pda: &AccountInfo,\\n    seeds: &[&[u8]],\\n) -> ProgramResult {\\n    // Use PDA as signer without validating derivation\\n    invoke_signed(\\n        &transfer_instruction,\\n        &[pda.clone(), destination.clone()],\\n        &[seeds],  // Unvalidated seeds!\\n    )?;\\n    Ok(())\\n}"}]	["https://docs.solana.com/developing/programming-model/calling-between-programs#program-signed-accounts", "https://www.anchor-lang.com/docs/pdas#signing-with-pdas"]	\N	0	{solana}	\N	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
BVD-SOLANA-PDA-004	Shared PDA Across Users	Program Derived Addresses shared across multiple users instead of being user-specific, creating unauthorized access and state collision vulnerabilities. When PDAs are not properly scoped to individual users or resources, different users can access or modify each other's data.	program-derived-address	medium	\N	CWE-668	A01:2021	Design PDA seeds to ensure proper isolation between users and resources. Include user public keys in seeds for user-specific PDAs.	[{"language": "solana", "fixed_code": ": User-specific PDAs\\nlet (user_config_pda, _) = Pubkey::find_program_address(\\n    &[\\n        b\\"config\\",\\n        user.key().as_ref(),  // Unique per user\\n    ],\\n    program_id,\\n);\\n\\n// Each user has their own config\\nlet config = Config::load(user_config_pda)?;\\nconfig.value = new_value;", "vulnerable_code": "Global PDA shared by all users\\nlet (config_pda, _) = Pubkey::find_program_address(\\n    &[b\\"config\\"],  // All users share this!\\n    program_id,\\n);\\n\\n// All users can modify the same config\\nlet config = Config::load(config_pda)?;\\nconfig.value = new_value;"}]	["https://www.anchor-lang.com/docs/pdas#pda-sharing", "https://docs.solana.com/developing/programming-model/calling-between-programs#program-derived-addresses"]	\N	0	{solana}	\N	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
BVD-SOLANA-INT-001	Unchecked Arithmetic Operations	Arithmetic operations performed without overflow/underflow checks in Solana Rust programs. While Rust has built-in overflow checking in debug mode, release builds use wrapping arithmetic by default. Programs must explicitly use checked arithmetic methods to prevent integer overflow/underflow vulnerabilities that can lead to incorrect calculations, unauthorized minting, or fund theft.	arithmetic	high	\N	CWE-190	A04:2021	Use checked arithmetic methods (checked_add, checked_sub, checked_mul, checked_div) that return Option<T> and handle None cases. Never unwrap() results without validation.	[{"language": "solana", "fixed_code": ": Proper checked arithmetic\\npub fn deposit(account: &mut Account, amount: u64) -> ProgramResult {\\n    account.balance = account.balance\\n        .checked_add(amount)\\n        .ok_or(ProgramError::Arithmetic overflow)?;\\n    Ok(())\\n}\\n\\npub fn withdraw(account: &mut Account, amount: u64) -> ProgramResult {\\n    account.balance = account.balance\\n        .checked_sub(amount)\\n        .ok_or(ProgramError::InsufficientFunds)?;\\n    Ok(())\\n}", "vulnerable_code": "Unchecked arithmetic\\npub fn deposit(account: &mut Account, amount: u64) {\\n    // Can overflow in release mode!\\n    account.balance = account.balance + amount;\\n}\\n\\npub fn withdraw(account: &mut Account, amount: u64) -> ProgramResult {\\n    // Can underflow!\\n    account.balance = account.balance - amount;\\n    Ok(())\\n}\\n\\n Unwrapping checked operations\\npub fn deposit_unwrap(account: &mut Account, amount: u64) {\\n    // Panics on overflow instead of returning error!\\n    account.balance = account.balance."}]	["https://doc.rust-lang.org/book/ch03-02-data-types.html#integer-overflow", "https://docs.rs/solana-program/latest/solana_program/macro.checked_add.html"]	\N	0	{solana}	\N	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
BVD-SOLANA-INT-002	Unsafe Saturating Arithmetic	Inappropriate use of saturating arithmetic (saturating_add, saturating_sub, saturating_mul) in contexts where overflow/underflow should be an error. Saturating arithmetic silently clamps values at numeric boundaries instead of failing, which can mask critical errors in financial calculations, access control, or state transitions.	arithmetic	medium	\N	CWE-190	A04:2021	Use saturating arithmetic only when saturation is the intended behavior (e.g., calculating rewards caps). For financial operations, always use checked arithmetic that returns errors.	[{"language": "solana", "fixed_code": ": Checked arithmetic for financial operations\\npub fn transfer(\\n    from: &mut Account,\\n    to: &mut Account,\\n    amount: u64,\\n) -> ProgramResult {\\n    from.balance = from.balance\\n        .checked_sub(amount)\\n        .ok_or(ProgramError::InsufficientFunds)?;\\n    \\n    to.balance = to.balance\\n        .checked_add(amount)\\n        .ok_or(ProgramError::ArithmeticOverflow)?;\\n    \\n    Ok(())\\n}", "vulnerable_code": "Saturating arithmetic in financial operations\\npub fn transfer(from: &mut Account, to: &mut Account, amount: u64) {\\n    // Silently fails if from.balance < amount!\\n    from.balance = from.balance.saturating_sub(amount);\\n    to.balance = to.balance.saturating_add(amount);\\n    // User loses funds without error\\n}\\n\\n Saturating in access control\\npub fn consume_credits(user: &mut User, cost: u64) -> bool {\\n    user.credits = user.credits.saturating_sub(cost);\\n    // Always returns true even if insuffic"}]	["https://doc.rust-lang.org/std/primitive.u64.html#method.saturating_add", "https://docs.solana.com/developing/on-chain-programs/developing-rust#arithmetic"]	\N	0	{solana}	\N	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
BVD-SOLANA-INT-003	Integer Division Precision Loss	Integer division operations that cause precision loss in financial calculations. In Rust, division of integers truncates the fractional part, which can lead to rounding errors in token amounts, fee calculations, or reward distributions. Repeated division operations can accumulate significant errors.	arithmetic	medium	\N	CWE-682	A04:2021	For financial calculations, perform multiplication before division to minimize precision loss. Consider using fixed-point arithmetic libraries or scaling factors. Document any intentional rounding behavior.	[{"language": "solana", "fixed_code": ": Multiplication before division\\npub fn calculate_fee(amount: u64, fee_rate: u64) -> Result<u64, ProgramError> {\\n    // Multiply first, then divide\\n    amount\\n        .checked_mul(fee_rate)\\n        .and_then(|v| v.checked_div(100))\\n        .ok_or(ProgramError::ArithmeticOverflow)\\n}\\n\\n// Example: amount = 999, fee_rate = 5\\n// Result: (999 * 5) / 100 = 4995 / 100 = 49 ✓", "vulnerable_code": "Division before multiplication\\npub fn calculate_fee(amount: u64, fee_rate: u64) -> u64 {\\n    // If fee_rate is a percentage (e.g., 5 for 5%)\\n    // This loses precision!\\n    (amount / 100) * fee_rate\\n}\\n\\n// Example: amount = 999, fee_rate = 5\\n// Result: (999 / 100) * 5 = 9 * 5 = 45\\n// Expected: 999 * 0.05 = 49.95 ≈ 49\\n\\n Multiple divisions\\npub fn distribute_rewards(total: u64, users: u64) -> u64 {\\n    let per_user = total / users;  // Precision loss\\n    let per_day = per_user / 30;   // More preci"}]	["https://doc.rust-lang.org/book/ch03-02-data-types.html#integer-types", "https://docs.solana.com/developing/on-chain-programs/developing-rust#precision"]	\N	0	{solana}	\N	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
BVD-SOLANA-INT-004	Unsafe Type Conversion in Arithmetic	Unsafe casting between integer types (e.g., u64 to u32, i64 to u64) in arithmetic operations without validating the conversion is safe. In Solana programs handling lamports (u64) or token amounts, incorrect type conversions can cause silent truncation, sign extension errors, or wraparound.	arithmetic	high	\N	CWE-681	A04:2021	Use try_from/try_into for safe type conversions that return Result. Validate that values fit within target type bounds before casting.	[{"language": "solana", "fixed_code": ": Safe type conversion with validation\\npub fn process_lamports(lamports: u64) -> ProgramResult {\\n    let lamports_u32: u32 = lamports\\n        .try_into()\\n        .map_err(|_| ProgramError::InvalidArgument)?;\\n    \\n    // Use lamports_u32 safely\\n    Ok(())\\n}", "vulnerable_code": "Unchecked downcasting\\nuse std::convert::TryInto;\\n\\npub fn process_lamports(lamports: u64) -> u32 {\\n    // Silently truncates if lamports > u32::MAX!\\n    lamports as u32\\n}\\n\\n Unchecked signed/unsigned conversion\\npub fn calculate_difference(a: u64, b: u64) -> i64 {\\n    // Can overflow if a - b > i64::MAX\\n    (a - b) as i64\\n}\\n\\n Using u32 for token amounts\\npub fn transfer_tokens(amount: u32) -> ProgramResult {\\n    // Many tokens use u64 amounts (e.g., USDC has 6 decimals)\\n    // Can't represent large "}]	["https://doc.rust-lang.org/book/ch03-02-data-types.html#numeric-types", "https://docs.rs/solana-program/latest/solana_program/native_token/index.html"]	\N	0	{solana}	\N	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
BVD-SOLANA-TYP-001	Account Type Confusion (Type Cosplay)	Type confusion vulnerabilities where incompatible account types are treated as compatible due to missing or insufficient type validation. In Solana, accounts store raw bytes that programs must deserialize into specific struct types. Without proper discriminator validation, attackers can pass accounts of one type where another is expected, potentially bypassing authorization checks or corrupting state.	type-safety	critical	\N	CWE-843	A03:2021	Always validate account discriminators before deserializing account data. Use Anchor's Account types which automatically validate discriminators, or manually check discriminator bytes.	[{"language": "solana", "fixed_code": ": Manual discriminator validation\\nconst ADMIN_ACCOUNT_DISCRIMINATOR: [u8; 8] = [1, 2, 3, 4, 5, 6, 7, 8];\\n\\npub fn admin_withdraw(\\n    account: &AccountInfo,\\n    amount: u64,\\n) -> ProgramResult {\\n    let data = account.data.borrow();\\n    \\n    // Validate discriminator\\n    if data.len() < 8 {\\n        return Err(ProgramError::InvalidAccountData);\\n    }\\n    \\n    let discriminator = &data[0..8];\\n    if discriminator != ADMIN_ACCOUNT_DISCRIMINATOR {\\n        return Err(ProgramError::InvalidAccountData);", "vulnerable_code": "No type validation\\nuse borsh::{BorshDeserialize, BorshSerialize};\\n\\n#[derive(BorshDeserialize, BorshSerialize)]\\npub struct AdminAccount {\\n    pub authority: Pubkey,\\n    pub permissions: u64,\\n}\\n\\n#[derive(BorshDeserialize, BorshSerialize)]\\npub struct UserAccount {\\n    pub owner: Pubkey,\\n    pub balance: u64,\\n}\\n\\npub fn admin_withdraw(account: &AccountInfo, amount: u64) -> ProgramResult {\\n    // Attacker can pass UserAccount instead of AdminAccount!\\n    // Both have same layout: Pubkey (32 bytes) + u"}]	["https://github.com/coral-xyz/sealevel-attacks/tree/master/programs/6-account-data-matching", "https://www.anchor-lang.com/docs/account-types#discriminator"]	\N	0	{solana}	\N	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
BVD-SOLANA-TYP-002	Struct Layout Compatibility Confusion	Type confusion where two structs with compatible memory layouts but different semantics are used interchangeably. Even with discriminator checks, structs with identical field types in the same order can be confused, leading to misinterpretation of data fields and unauthorized access.	type-safety	high	\N	CWE-843	A04:2021	Use unique discriminators for all account types, even those with similar layouts. Validate both discriminator and account owner. Use type-safe wrappers and explicit type annotations.	[{"language": "solana", "fixed_code": ": Add discriminators and unique identifiers\\nuse anchor_lang::prelude::*;\\n\\n#[account]\\npub struct TokenVault {\\n    pub discriminator: [u8; 8],  // Unique discriminator\\n    pub vault_type: VaultType,   // Additional type identifier\\n    pub mint: Pubkey,\\n    pub authority: Pubkey,\\n    pub amount: u64,\\n}\\n\\n#[account]\\npub struct EscrowAccount {\\n    pub discriminator: [u8; 8],  // Different discriminator\\n    pub escrow_id: u64,          // Unique identifier\\n    pub seller: Pubkey,\\n    pub buyer: Pubkey,", "vulnerable_code": "Structs with same layout\\n#[derive(BorshDeserialize, BorshSerialize)]\\npub struct TokenVault {\\n    pub mint: Pubkey,         // 32 bytes\\n    pub authority: Pubkey,    // 32 bytes\\n    pub amount: u64,          // 8 bytes\\n}\\n\\n#[derive(BorshDeserialize, BorshSerialize)]\\npub struct EscrowAccount {\\n    pub seller: Pubkey,       // 32 bytes  \\n    pub buyer: Pubkey,        // 32 bytes\\n    pub price: u64,           // 8 bytes\\n}\\n\\n// Both have identical layout! Can be confused without discriminators.\\n\\npub fn"}]	["https://doc.rust-lang.org/reference/type-layout.html", "https://www.anchor-lang.com/docs/space"]	\N	0	{solana}	\N	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
BVD-SOLANA-TYP-003	Enum Variant Confusion	Type confusion in enum deserialization where programs don't properly validate enum discriminants, allowing invalid or unexpected variants to be processed. In Borsh serialization, enums are prefixed with a variant index, but missing validation can allow out-of-range indices or mismatched variants.	type-safety	medium	\N	CWE-843	A03:2021	Use Rust's type system and Borsh's built-in validation. Avoid manual enum deserialization. Use match statements with explicit patterns and no wildcards for critical logic.	[{"language": "solana", "fixed_code": ": Explicit variant matching\\n#[derive(BorshDeserialize, BorshSerialize, PartialEq, Debug)]\\npub enum InstructionType {\\n    Initialize,\\n    Deposit,\\n    Withdraw,\\n}\\n\\npub fn process_instruction(\\n    instruction_data: &[u8],\\n) -> ProgramResult {\\n    let instruction_type = InstructionType::try_from_slice(instruction_data)\\n        .map_err(|_| ProgramError::InvalidInstructionData)?;\\n    \\n    // Explicit match with no wildcards\\n    match instruction_type {\\n        InstructionType::Initialize => initiali", "vulnerable_code": "Unsafe enum handling\\n#[derive(BorshDeserialize, BorshSerialize)]\\npub enum InstructionType {\\n    Initialize = 0,\\n    Deposit = 1,\\n    Withdraw = 2,\\n}\\n\\npub fn process_instruction(\\n    instruction_data: &[u8],\\n) -> ProgramResult {\\n    // Borsh deserializes any u8 into the enum\\n    // Value 255 would panic or create invalid variant\\n    let instruction_type = InstructionType::try_from_slice(instruction_data)?;\\n    \\n    // Wildcard catches invalid variants silently\\n    match instruction_type {\\n       "}]	["https://borsh.io/", "https://doc.rust-lang.org/book/ch06-01-defining-an-enum.html"]	\N	0	{solana}	\N	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
BVD-SOLANA-SEC-001	Malicious Transaction Simulation	Programs that simulate transactions or perform operations based on simulated results without proper validation. Transaction simulation in Solana is meant for testing and pre-flight checks, not for making security decisions. Programs that rely on simulation results can be manipulated by attackers who provide fake simulation data or manipulate simulation parameters.	security	high	\N	CWE-94	A03:2021	Never use simulation results for security decisions or authorization checks. Simulations should only be used off-chain for UI/UX purposes. All security checks must be performed on-chain during actual transaction execution.	[{"language": "solana", "fixed_code": ": Simulation only for UI/estimates\\nuse solana_client::rpc_client::RpcClient;\\nuse solana_sdk::transaction::Transaction;\\n\\n// Off-chain code for UI\\npub async fn estimate_transaction_cost(\\n    client: &RpcClient,\\n    transaction: &Transaction,\\n) -> Result<u64, Box<dyn std::error::Error>> {\\n    // Simulation is OK for estimates, not authorization\\n    let simulation = client.simulate_transaction(transaction)?;\\n    \\n    // Use simulation only for displaying estimate to user\\n    let cost = simulation.va", "vulnerable_code": "Using simulation for authorization\\nuse solana_client::rpc_client::RpcClient;\\nuse solana_sdk::transaction::Transaction;\\n\\npub fn authorize_transaction(\\n    client: &RpcClient,\\n    transaction: &Transaction,\\n) -> Result<bool, Box<dyn std::error::Error>> {\\n    // Simulating transaction to check if it would succeed\\n    let simulation = client.simulate_transaction(transaction)?;\\n    \\n    // DANGEROUS: Making security decision based on simulation!\\n    if simulation.value.err.is_none() {\\n        // Atta"}]	["https://docs.solana.com/api/http#simulatetransaction", "https://docs.solana.com/developing/clients/jsonrpc-api#simulatetransaction"]	\N	0	{solana}	\N	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
BVD-SOLANA-LOG-001	Incorrect Loop Termination Logic	Loops with flawed break conditions, unreachable exits, or incorrect iteration logic that can cause infinite loops, incomplete processing, or incorrect state updates. In Solana programs with compute unit limits, infinite loops will exhaust the budget and cause transaction failure, but incorrect loop logic can also lead to partial state updates or skipped validation.	logic-errors	medium	\N	CWE-835	A04:2021	Ensure loop conditions are correct and reachable. Use bounded loops with explicit limits. Validate loop invariants and ensure all items are processed correctly.	[{"language": "solana", "fixed_code": ": Correct loop with bounds\\npub fn process_items(items: &[Item]) -> ProgramResult {\\n    // Use iterator with explicit bound\\n    for item in items.iter() {\\n        process_item(item)?;\\n    }\\n    Ok(())\\n}\\n\\npub fn process_items_indexed(items: &[Item]) -> ProgramResult {\\n    // Explicit iteration with correct bounds\\n    for i in 0..items.len() {\\n        process_item(&items[i])?;\\n    }\\n    Ok(())\\n}", "vulnerable_code": "Unreachable break condition\\npub fn process_items(items: &[Item]) -> ProgramResult {\\n    let mut i = 0;\\n    loop {\\n        if i >= items.len() {\\n            break;  // Correct condition\\n        }\\n        \\n        process_item(&items[i])?;\\n        \\n        // MISSING: i increment - infinite loop!\\n    }\\n    Ok(())\\n}\\n\\n Off-by-one error\\npub fn distribute_rewards(users: &mut [User], total: u64) -> ProgramResult {\\n    let per_user = total / users.len() as u64;\\n    \\n    // Skips last user!\\n    for i in "}]	["https://docs.solana.com/developing/programming-model/runtime#compute-budget", "https://docs.solana.com/developing/on-chain-programs/limitations#compute-budget"]	\N	0	{solana}	\N	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
BVD-SOLANA-LOG-002	Incorrect Conditional Logic	Flawed conditional checks including wrong comparison operators, inverted logic, missing conditions, or incorrect boolean combinations. These errors can bypass security checks, cause incorrect state transitions, or allow unauthorized operations.	logic-errors	medium	\N	CWE-697	A04:2021	Carefully review all conditional logic. Use explicit comparisons, avoid double negatives, and test boundary conditions. Use Anchor's require! macro for clear assertions.	[{"language": "solana", "fixed_code": ": Correct comparison\\npub fn check_balance(balance: u64, minimum: u64) -> ProgramResult {\\n    if balance >= minimum {\\n        return Ok(());\\n    }\\n    Err(ProgramError::InsufficientFunds)\\n}", "vulnerable_code": "Wrong comparison operator\\npub fn check_balance(balance: u64, minimum: u64) -> ProgramResult {\\n    // Should be >= not >\\n    if balance > minimum {\\n        return Ok(());\\n    }\\n    Err(ProgramError::InsufficientFunds)\\n}\\n\\n Inverted logic\\npub fn authorize_withdrawal(is_authorized: bool) -> ProgramResult {\\n    // Logic is inverted!\\n    if !is_authorized {\\n        return Ok(());  // Allows unauthorized users\\n    }\\n    Err(ProgramError::Unauthorized)\\n}\\n\\n Missing condition\\npub fn validate_amount(amount"}]	["https://doc.rust-lang.org/book/ch03-05-control-flow.html", "https://www.anchor-lang.com/docs/errors"]	\N	0	{solana}	\N	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
BVD-SOLANA-LOG-003	Incorrect Exponentiation Logic	Flawed power/exponentiation calculations that can cause overflow, incorrect results, or inefficient computation. Exponentiation in Solana programs must handle potential overflow and use appropriate methods for large numbers.	logic-errors	medium	\N	CWE-682	A04:2021	Use checked_pow() for exponentiation to detect overflow. For large exponents, consider using libraries like num-bigint or implement custom algorithms with overflow detection.	[{"language": "solana", "fixed_code": ": Checked exponentiation\\npub fn calculate_power(\\n    base: u64,\\n    exp: u32,\\n) -> Result<u64, ProgramError> {\\n    base.checked_pow(exp)\\n        .ok_or(ProgramError::ArithmeticOverflow)\\n}", "vulnerable_code": "Unchecked exponentiation\\npub fn calculate_compound_interest(\\n    principal: u64,\\n    rate: u64,  // Rate in basis points\\n    periods: u32,\\n) -> u64 {\\n    // Can easily overflow!\\n    let multiplier = (10000 + rate).pow(periods);\\n    (principal * multiplier) / 10000_u64.pow(periods)\\n}\\n\\n No overflow check\\npub fn calculate_power(base: u64, exp: u32) -> u64 {\\n    base.pow(exp)  // Panics on overflow in debug, wraps in release\\n}\\n\\n Inefficient repeated multiplication\\npub fn power_iterative(base: u64, e"}]	["https://doc.rust-lang.org/std/primitive.u64.html#method.pow", "https://doc.rust-lang.org/std/primitive.u64.html#method.checked_pow"]	\N	0	{solana}	\N	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
BVD-SOLANA-LOG-004	Division by Zero	Division or modulo operations without checking for zero divisor. In Rust, division by zero causes a panic in debug mode and undefined behavior in release mode, leading to program crashes or incorrect results.	logic-errors	high	\N	CWE-369	A04:2021	Always use checked_div() and checked_rem() which return Option<T>. Explicitly validate divisors are non-zero before division operations.	[{"language": "solana", "fixed_code": ": Explicit zero check\\npub fn calculate_average(\\n    total: u64,\\n    count: u64,\\n) -> Result<u64, ProgramError> {\\n    if count == 0 {\\n        return Err(ProgramError::InvalidArgument);\\n    }\\n    Ok(total / count)\\n}", "vulnerable_code": "No zero check\\npub fn calculate_average(total: u64, count: u64) -> u64 {\\n    total / count  // Panics if count == 0\\n}\\n\\npub fn distribute_evenly(amount: u64, recipients: u64) -> u64 {\\n    amount / recipients  // Undefined behavior if recipients == 0\\n}\\n\\npub fn get_remainder(value: u64, divisor: u64) -> u64 {\\n    value % divisor  // Panics if divisor == 0\\n}\\n\\n Incorrect zero check\\npub fn calculate_ratio(numerator: u64, denominator: u64) -> u64 {\\n    if numerator == 0 {  // Wrong variable!\\n        ret"}]	["https://doc.rust-lang.org/book/ch03-02-data-types.html#integer-division", "https://doc.rust-lang.org/std/primitive.u64.html#method.checked_div"]	\N	0	{solana}	\N	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
BVD-SOLANA-LOG-005	Incorrect Token Amount Calculations	Flawed calculations involving token amounts, particularly when handling different decimal precisions, conversions between token units, or fee deductions. Token math errors can lead to incorrect balances, lost funds, or unauthorized minting.	logic-errors	high	\N	CWE-682	A04:2021	Always account for token decimals when converting between UI amounts and raw amounts. Use checked arithmetic for all token calculations. Validate amounts before and after conversions.	[{"language": "solana", "fixed_code": ": Proper decimal handling\\npub fn transfer_tokens_with_decimals(\\n    amount_ui: u64,\\n    decimals: u8,\\n) -> Result<u64, ProgramError> {\\n    // Convert UI amount to raw amount\\n    let multiplier = 10_u64\\n        .checked_pow(decimals as u32)\\n        .ok_or(ProgramError::ArithmeticOverflow)?;\\n    \\n    amount_ui\\n        .checked_mul(multiplier)\\n        .ok_or(ProgramError::ArithmeticOverflow)\\n}", "vulnerable_code": "Ignoring token decimals\\npub fn transfer_tokens(\\n    amount_ui: u64,  // User inputs \\"100 USDC\\"\\n) -> ProgramResult {\\n    // USDC has 6 decimals, should be 100_000_000 not 100!\\n    transfer(amount_ui)?;\\n    Ok(())\\n}\\n\\n Incorrect decimal conversion\\npub fn convert_to_raw_amount(ui_amount: u64, decimals: u8) -> u64 {\\n    // Overflow if decimals large!\\n    ui_amount * 10_u64.pow(decimals as u32)\\n}\\n\\n Fee calculation with precision loss\\npub fn calculate_fee(amount: u64, fee_bps: u64) -> u64 {\\n    // Divi"}]	["https://spl.solana.com/token", "https://docs.rs/spl-token/latest/spl_token/"]	\N	0	{solana}	\N	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
BVD-SOLANA-INT-005	Integer Addition Overflow	Addition operations that may exceed maximum integer values without proper overflow checking. In Solana Rust programs, unchecked addition can cause arithmetic overflow where the result wraps around to a small value, leading to incorrect calculations in financial logic, token amounts, or access control checks. This is distinct from general unchecked arithmetic as it specifically targets addition operations.	arithmetic	high	\N	CWE-190	A04:2021	Use checked_add() for all addition operations to detect overflow. Never use the + operator directly on values that could potentially overflow.	[{"language": "solana", "fixed_code": ": Checked addition\\npub fn add_balance(\\n    account: &mut Account,\\n    amount: u64,\\n) -> Result<(), ProgramError> {\\n    account.balance = account.balance\\n        .checked_add(amount)\\n        .ok_or(ProgramError::ArithmeticOverflow)?;\\n    Ok(())\\n}\\n\\npub fn calculate_total(\\n    a: u64,\\n    b: u64,\\n    c: u64,\\n) -> Result<u64, ProgramError> {\\n    let sum_ab = a\\n        .checked_add(b)\\n        .ok_or(ProgramError::ArithmeticOverflow)?;\\n    \\n    sum_ab\\n        .checked_add(c)\\n        .ok_or(ProgramErro", "vulnerable_code": "Unchecked addition\\npub fn add_balance(account: &mut Account, amount: u64) {\\n    // Can overflow silently in release mode!\\n    account.balance = account.balance + amount;\\n}\\n\\npub fn calculate_total(a: u64, b: u64, c: u64) -> u64 {\\n    // Multiple additions increase overflow risk\\n    a + b + c\\n}"}]	["https://doc.rust-lang.org/book/ch03-02-data-types.html#integer-overflow", "https://docs.rs/solana-program/latest/solana_program/macro.checked_add.html"]	\N	0	{solana}	\N	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
BVD-SOLANA-INT-006	Integer Multiplication Overflow	Multiplication operations that risk numeric overflow without proper checking. In Solana programs, unchecked multiplication is particularly dangerous as products grow exponentially and can easily exceed u64::MAX. This commonly occurs in token calculations with decimal conversions, fee calculations, and compound interest formulas.	arithmetic	high	\N	CWE-190	A04:2021	Use checked_mul() for all multiplication operations. Be especially careful with token decimal conversions and fee calculations where multiplication is common.	[{"language": "solana", "fixed_code": ": Checked multiplication\\npub fn convert_tokens(\\n    amount: u64,\\n    rate: u64,\\n) -> Result<u64, ProgramError> {\\n    amount\\n        .checked_mul(rate)\\n        .ok_or(ProgramError::ArithmeticOverflow)\\n}\\n\\npub fn calculate_fee(\\n    amount: u64,\\n    fee_bps: u64,\\n) -> Result<u64, ProgramError> {\\n    amount\\n        .checked_mul(fee_bps)\\n        .and_then(|v| v.checked_div(10000))\\n        .ok_or(ProgramError::ArithmeticOverflow)\\n}\\n\\npub fn compound_interest(\\n    principal: u64,\\n    rate: u64,\\n    perio", "vulnerable_code": "Unchecked multiplication\\npub fn convert_tokens(amount: u64, rate: u64) -> u64 {\\n    // Can easily overflow!\\n    amount * rate\\n}\\n\\npub fn calculate_fee(amount: u64, fee_bps: u64) -> u64 {\\n    // Overflow before division\\n    (amount * fee_bps) / 10000\\n}\\n\\npub fn compound_interest(principal: u64, rate: u64, periods: u32) -> u64 {\\n    // Repeated multiplication causes overflow\\n    let mut result = principal;\\n    for _ in 0..periods {\\n        result = result * rate / 100;\\n    }\\n    result\\n}"}]	["https://doc.rust-lang.org/book/ch03-02-data-types.html#integer-overflow", "https://docs.rs/solana-program/latest/solana_program/macro.checked_mul.html"]	\N	0	{solana}	\N	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
BVD-SOLANA-INT-007	Integer Division Overflow	Division operations that may overflow in edge cases, particularly when dividing minimum integer values by -1. While less common than addition or multiplication overflow, division overflow can occur with signed integers and cause unexpected panics or incorrect results. In unsigned arithmetic, this pattern also catches potential division by zero which causes panics.	arithmetic	high	\N	CWE-190	A04:2021	Use checked_div() for all division operations to handle both overflow and division by zero. Always validate divisors are non-zero before division.	[{"language": "solana", "fixed_code": ": Checked division\\npub fn calculate_average(\\n    total: u64,\\n    count: u64,\\n) -> Result<u64, ProgramError> {\\n    total\\n        .checked_div(count)\\n        .ok_or(ProgramError::InvalidArgument)\\n}\\n\\npub fn distribute_equally(\\n    amount: u64,\\n    recipients: u64,\\n) -> Result<u64, ProgramError> {\\n    if recipients == 0 {\\n        return Err(ProgramError::InvalidArgument);\\n    }\\n    \\n    Ok(amount / recipients)\\n}\\n\\npub fn calculate_ratio(\\n    numerator: i64,\\n    denominator: i64,\\n) -> Result<i64, Prog", "vulnerable_code": "Unchecked division\\npub fn calculate_average(total: u64, count: u64) -> u64 {\\n    // Panics if count == 0\\n    total / count\\n}\\n\\npub fn distribute_equally(amount: u64, recipients: u64) -> u64 {\\n    // No validation\\n    amount / recipients\\n}\\n\\npub fn calculate_ratio(numerator: i64, denominator: i64) -> i64 {\\n    // Can overflow with i64::MIN / -1\\n    numerator / denominator\\n}"}]	["https://doc.rust-lang.org/book/ch03-02-data-types.html#integer-overflow", "https://docs.rs/solana-program/latest/solana_program/macro.checked_div.html"]	\N	0	{solana}	\N	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
BVD-SOLANA-ACC-009	Unvalidated Account Data	Account data used without confirming its authenticity or integrity. In Solana's account model, programs receive raw account data that could be from any source. Without validation of account ownership, discriminators, or data structure, programs may process malicious or corrupted data leading to unauthorized state changes, fund theft, or program compromise. This is broader than just discriminator validation - it includes all forms of account data validation.	account-validation	high	\N	CWE-345	A03:2021	Implement comprehensive account validation: verify ownership, validate discriminators, check data structure integrity, and validate relationships between accounts. Use Anchor's account constraints for automatic validation.	[{"language": "solana", "fixed_code": ": Comprehensive validation\\npub fn process_transfer(\\n    program_id: &Pubkey,\\n    from_account: &AccountInfo,\\n    to_account: &AccountInfo,\\n    amount: u64,\\n) -> ProgramResult {\\n    // 1. Validate ownership\\n    if from_account.owner != program_id {\\n        return Err(ProgramError::IncorrectProgramId);\\n    }\\n    if to_account.owner != program_id {\\n        return Err(ProgramError::IncorrectProgramId);\\n    }\\n    \\n    // 2. Validate data size\\n    if from_account.data_len() < UserAccount::LEN {\\n      ", "vulnerable_code": "No account validation\\nuse borsh::BorshDeserialize;\\n\\npub fn process_transfer(\\n    from_account: &AccountInfo,\\n    to_account: &AccountInfo,\\n    amount: u64,\\n) -> ProgramResult {\\n    // Directly deserialize without any checks!\\n    let from = UserAccount::try_from_slice(&from_account.data.borrow())?;\\n    let to = UserAccount::try_from_slice(&to_account.data.borrow())?;\\n    \\n    // Process without validating accounts are legitimate\\n    transfer(from, to, amount)?;\\n    Ok(())\\n}\\n\\n Partial validation\\np"}]	["https://docs.solana.com/developing/programming-model/accounts", "https://www.anchor-lang.com/docs/account-constraints"]	\N	0	{solana}	\N	\N	2025-11-01 15:54:04.255262+00	2025-11-01 15:54:04.255262+00	t
BVD-CAIRO-ACC-001	Controlled Library Call Vulnerability	Library calls using user-controlled class hashes allow attackers to redirect contract execution to malicious implementations. In Cairo/Starknet, library calls execute code from another contract's class using its class hash. If the class hash is derived from user input without validation, an attacker can supply a malicious contract's class hash, leading to arbitrary code execution within the calling contract's context.	access-control	high	\N	CWE-494	A03:2021	Always validate library call class hashes against a whitelist of approved contracts. Never derive class hashes directly from user input. Use hardcoded or admin-controlled class hashes for library calls.	[{"language": "cairo", "fixed_code": ": Whitelist validation\\n#[storage]\\nstruct Storage {\\n    approved_libraries: LegacyMap<ClassHash, bool>,\\n}\\n\\n#[external(v0)]\\nfn execute_library_call(ref self: ContractState, class_hash: ClassHash, selector: felt252) {\\n    assert(self.approved_libraries.read(class_hash), 'Unauthorized library');\\n    library_call_syscall(class_hash, selector, array![].span()).unwrap();\\n}", "vulnerable_code": "User-controlled library call\\n#[external(v0)]\\nfn execute_library_call(ref self: ContractState, class_hash: ClassHash, selector: felt252) {\\n    library_call_syscall(class_hash, selector, array![].span()).unwrap();\\n}"}]	["https://github.com/crytic/caracal", "https://docs.starknet.io/documentation/architecture_and_concepts/Smart_Contracts/class-hash/"]	\N	0	{cairo}	\N	\N	2025-11-01 16:25:08.767942+00	2025-11-01 16:25:08.767942+00	t
BVD-CAIRO-ACC-002	Transaction Origin Authentication	Using tx.origin (get_tx_info().account_contract_address) for authentication is vulnerable to phishing attacks. Unlike msg.sender, tx.origin always refers to the original transaction initiator, not the immediate caller. If a user is tricked into calling a malicious contract, that contract can call your contract and the tx.origin check will pass, granting unauthorized access.	access-control	medium	\N	CWE-862	A01:2021	Use get_caller_address() instead of get_tx_info().account_contract_address for access control. The caller address represents the immediate caller, preventing phishing-based attacks. Implement role-based access control with explicit authorization checks.	[{"language": "cairo", "fixed_code": ": Caller address check\\nuse starknet::get_caller_address;\\n\\n#[external(v0)]\\nfn withdraw(ref self: ContractState, amount: u256) {\\n    let caller = get_caller_address();\\n    assert(caller == self.owner.read(), 'Not owner');\\n    // Safe from phishing attacks\\n}", "vulnerable_code": "TX origin check\\nuse starknet::get_tx_info;\\n\\n#[external(v0)]\\nfn withdraw(ref self: ContractState, amount: u256) {\\n    let tx_info = get_tx_info().unbox();\\n    assert(tx_info.account_contract_address == self.owner.read(), 'Not owner');\\n    // Attacker can trick owner into calling malicious contract that calls this\\n}"}]	["https://github.com/crytic/caracal", "https://docs.starknet.io/documentation/architecture_and_concepts/Smart_Contracts/system-calls-cairo1/"]	\N	0	{cairo}	\N	\N	2025-11-01 16:25:08.767942+00	2025-11-01 16:25:08.767942+00	t
BVD-CAIRO-L2S-001	Unchecked L1 Handler Origin	L1 message handlers that don't validate the sender address on L1 can be exploited by malicious L1 contracts. Starknet allows L1 Ethereum contracts to send messages to L2 Cairo contracts via L1 handlers. Without validating the from_address parameter, any L1 contract can trigger the handler, potentially bypassing intended access controls or injecting malicious data.	layer2-security	high	\N	CWE-346	A07:2021	Always validate the from_address parameter in L1 handlers against a whitelist of authorized L1 contracts. Store approved L1 addresses in storage and check them before processing messages. Use the #[l1_handler] attribute correctly and implement strict origin validation.	[{"language": "cairo", "fixed_code": ": L1 origin validation\\n#[storage]\\nstruct Storage {\\n    authorized_l1_bridge: felt252,\\n    balance: u256,\\n}\\n\\n#[l1_handler]\\nfn process_l1_message(ref self: ContractState, from_address: felt252, amount: u256) {\\n    assert(from_address == self.authorized_l1_bridge.read(), 'Unauthorized L1 sender');\\n    self.balance.write(self.balance.read() + amount);\\n}", "vulnerable_code": "No L1 origin validation\\n#[l1_handler]\\nfn process_l1_message(ref self: ContractState, from_address: felt252, amount: u256) {\\n    // Any L1 contract can send this message\\n    self.balance.write(self.balance.read() + amount);\\n}"}]	["https://github.com/crytic/caracal", "https://docs.starknet.io/documentation/architecture_and_concepts/L1-L2_Communication/messaging-mechanism/"]	\N	0	{cairo}	\N	\N	2025-11-01 16:25:08.767942+00	2025-11-01 16:25:08.767942+00	t
BVD-CAIRO-ARI-001	Felt252 Unsafe Arithmetic Operations	The felt252 type in Cairo is not overflow/underflow safe. Unlike u256 or u128, felt252 operations wrap around modulo the Cairo prime (2^251 + 17 * 2^192 + 1) without raising errors. When user-controlled values are used in felt252 arithmetic without bounds checking, attackers can exploit wraparound behavior to manipulate calculations, bypass validations, or drain funds.	arithmetic	medium	\N	CWE-190	A04:2021	Use unsigned integer types (u8, u16, u32, u64, u128, u256) instead of felt252 for arithmetic operations. These types have built-in overflow/underflow checks. If felt252 is necessary, implement explicit bounds checking before operations. For financial calculations, always use u256 or implement safe math libraries.	[{"language": "cairo", "fixed_code": ": Use u256 with automatic checks\\n#[external(v0)]\\nfn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) {\\n    let sender = get_caller_address();\\n    let sender_balance: u256 = self.balances.read(sender);\\n    \\n    // These operations automatically check for overflow/underflow\\n    assert(sender_balance >= amount, 'Insufficient balance');\\n    self.balances.write(sender, sender_balance - amount);\\n    \\n    let recipient_balance = self.balances.read(recipient);\\n    self.balance", "vulnerable_code": "felt252 arithmetic without bounds checking\\n#[external(v0)]\\nfn transfer(ref self: ContractState, recipient: ContractAddress, amount: felt252) {\\n    let sender_balance: felt252 = self.balances.read(get_caller_address());\\n    // Subtraction can underflow, addition can overflow\\n    let new_sender_balance = sender_balance - amount;\\n    let recipient_balance = self.balances.read(recipient);\\n    let new_recipient_balance = recipient_balance + amount;\\n    \\n    self.balances.write(get_caller_address(), n"}]	["https://github.com/crytic/caracal", "https://oxor.io/blog/2024-08-16-overflow-and-underflow-vulnerabilities-in-cairo/", "https://book.cairo-lang.org/ch02-02-data-types.html"]	\N	0	{cairo}	\N	\N	2025-11-01 16:25:08.767942+00	2025-11-01 16:25:08.767942+00	t
BVD-CAIRO-STA-001	Unenforced View Function Constraint	Functions decorated with #[view] or marked as view are intended to be read-only and should not modify contract state. However, Cairo compiler doesn't strictly enforce this constraint. If a view function modifies storage or calls non-view external functions, it violates the expected behavior and can lead to unexpected state changes during what should be read-only operations.	state-consistency	medium	\N	CWE-665	A04:2021	Ensure view functions only read state and never write to storage. Avoid calling external functions from view functions unless those functions are also guaranteed to be view. Use read-only storage access patterns. Consider using @view decorator in Cairo 0 or proper view semantics in Cairo 1/2.	[{"language": "cairo", "fixed_code": ": Pure read-only view function\\n#[external(v0)]\\nfn get_balance(self: @ContractState, account: ContractAddress) -> u256 {\\n    self.balances.read(account)\\n}", "vulnerable_code": "View function modifying state\\n#[external(v0)]\\nfn get_balance(self: @ContractState, account: ContractAddress) -> u256 {\\n    let balance = self.balances.read(account);\\n    // View function should not write!\\n    self.last_query_time.write(get_block_timestamp());\\n    balance\\n}"}]	["https://github.com/crytic/caracal", "https://book.cairo-lang.org/ch99-01-02-a-simple-contract.html"]	\N	0	{cairo}	\N	\N	2025-11-01 16:25:08.767942+00	2025-11-01 16:25:08.767942+00	t
BVD-CAIRO-MEM-001	Use After Array Modification	Using an array or span after removing elements with pop_front() can lead to accessing invalid memory or unexpected behavior. When pop_front() is called on an array, it modifies the array's internal structure. Subsequent access to the array without accounting for the modification can result in reading stale data, accessing out-of-bounds memory, or logic errors.	memory-safety	low	\N	CWE-416	A04:2021	After calling pop_front() on an array or span, ensure you work with the returned modified array, not the original reference. Always use the updated array reference returned by pop_front(). Consider using explicit array copies or iterators to avoid confusion. Document array modification points clearly.	[{"language": "cairo", "fixed_code": ": Properly handle modified array\\nfn process_items(mut items: Span<u256>) {\\n    if items.is_empty() {\\n        return;\\n    }\\n    let first = *items.pop_front().unwrap();\\n    // items is now the tail, handle accordingly\\n    while let Option::Some(item) = items.pop_front() {\\n        process_item(*item);\\n    }\\n}", "vulnerable_code": "Using array after pop_front\\nfn process_items(mut items: Span<u256>) {\\n    let first = *items.pop_front().unwrap();\\n    // items is now modified but code might expect original length\\n    let len = items.len(); // Wrong length assumption\\n    process_remaining(items);\\n}"}]	["https://github.com/crytic/caracal", "https://book.cairo-lang.org/ch03-01-arrays.html"]	\N	0	{cairo}	\N	\N	2025-11-01 16:25:08.767942+00	2025-11-01 16:25:08.767942+00	t
BVD-CAIRO-REE-001	Classic Reentrancy Vulnerability	Classic reentrancy occurs when a storage variable is read before an external call and written after it, allowing the called contract to re-enter and manipulate state. In Cairo/Starknet, when contract A calls contract B, contract B can call back into contract A before the first call completes. If contract A reads state, makes an external call, then updates state based on the earlier read, the reentering call can exploit the stale state.	reentrancy	medium	\N	CWE-841	A04:2021	Follow the checks-effects-interactions pattern: (1) validate inputs, (2) update state variables, (3) make external calls. Implement reentrancy guards using storage flags. Use OpenZeppelin's ReentrancyGuard component for Cairo contracts. Ensure all state changes happen before external calls.	[{"language": "cairo", "fixed_code": ": State update before external call (Checks-Effects-Interactions)\\n#[external(v0)]\\nfn withdraw(ref self: ContractState, amount: u256) {\\n    let caller = get_caller_address();\\n    let balance = self.balances.read(caller);\\n    assert(balance >= amount, 'Insufficient balance');\\n    \\n    // Update state BEFORE external call\\n    self.balances.write(caller, balance - amount);\\n    \\n    // External call after state is consistent\\n    IERC20Dispatcher { contract_address: self.token.read() }\\n        .transf", "vulnerable_code": "State update after external call\\n#[external(v0)]\\nfn withdraw(ref self: ContractState, amount: u256) {\\n    let caller = get_caller_address();\\n    let balance = self.balances.read(caller);\\n    assert(balance >= amount, 'Insufficient balance');\\n    \\n    // External call before state update\\n    IERC20Dispatcher { contract_address: self.token.read() }\\n        .transfer(caller, amount);\\n    \\n    // Attacker can re-enter here and withdraw again with old balance\\n    self.balances.write(caller, balance -"}]	["https://github.com/crytic/caracal", "https://docs.starknet.io/documentation/architecture_and_concepts/Smart_Contracts/system-calls-cairo1/"]	\N	0	{cairo}	\N	\N	2025-11-01 16:25:08.767942+00	2025-11-01 16:25:08.767942+00	t
BVD-CAIRO-REE-002	Read-Only Reentrancy	Read-only reentrancy occurs in view functions that read storage variables that can be modified by external calls in other functions. When a view function reads state after an external call in a non-view function, it may return stale or inconsistent data. This can be exploited in DeFi protocols where price oracles, collateral ratios, or other critical values are queried while the contract is in an inconsistent state.	reentrancy	medium	\N	CWE-841	A04:2021	Implement reentrancy guards even for view functions that read critical state. Ensure state consistency before allowing external contracts to query values. Use snapshots or checkpoints for values that must remain consistent during execution. Consider using the OpenZeppelin ReentrancyGuard for all state-reading functions in sensitive contexts.	[{"language": "cairo", "fixed_code": ": Reentrancy guard for state consistency\\nuse openzeppelin::security::reentrancyguard::ReentrancyGuardComponent;\\n\\n#[external(v0)]\\nfn update_oracle(ref self: ContractState) {\\n    self.reentrancy_guard.start();\\n    let old_price = self.price.read();\\n    let new_price = IOracleDispatcher { contract_address: self.oracle.read() }\\n        .get_price();\\n    self.price.write(new_price);\\n    self.reentrancy_guard.end();\\n}\\n\\n#[external(v0)]\\nfn get_collateral_ratio(self: @ContractState, user: ContractAddress", "vulnerable_code": "View function reading inconsistent state\\n#[external(v0)]\\nfn update_oracle(ref self: ContractState) {\\n    let old_price = self.price.read();\\n    // External call that could re-enter\\n    let new_price = IOracleDispatcher { contract_address: self.oracle.read() }\\n        .get_price();\\n    self.price.write(new_price);\\n}\\n\\n#[external(v0)]\\nfn get_collateral_ratio(self: @ContractState, user: ContractAddress) -> u256 {\\n    let price = self.price.read(); // May read stale price during reentrancy\\n    let co"}]	["https://github.com/crytic/caracal", "https://medium.com/immunefi/read-only-reentrancy-a-deep-dive-8ea3dbe5f275"]	\N	0	{cairo}	\N	\N	2025-11-01 16:25:08.767942+00	2025-11-01 16:25:08.767942+00	t
BVD-CAIRO-REE-003	Benign Reentrancy	Benign reentrancy occurs when a storage variable is written after an external call but was not read before it. While not immediately exploitable, benign reentrancy indicates potential issues with state consistency and can become critical if the code evolves to read the variable before the call. It also increases code complexity and makes future modifications more dangerous.	reentrancy	low	\N	CWE-841	A04:2021	Follow the checks-effects-interactions pattern consistently even when current code doesn't read the variable. Move all state updates before external calls. This prevents future modifications from inadvertently introducing vulnerabilities. Use reentrancy guards as a defense-in-depth measure.	[]	["https://github.com/crytic/caracal"]	\N	0	{cairo}	\N	\N	2025-11-01 16:25:08.767942+00	2025-11-01 16:25:08.767942+00	t
BVD-CAIRO-REE-004	Reentrancy Affecting Events	Events emitted after external calls can lead to out-of-order or misleading event logs. When an external call allows reentrancy, events emitted after the call may appear in the wrong sequence relative to state changes. This can cause off-chain systems, indexers, and frontends to display incorrect information or process events in the wrong order, leading to user confusion or system inconsistencies.	reentrancy	low	\N	CWE-841	A04:2021	Emit all events before making external calls to ensure correct event ordering. Follow the pattern: checks, effects (including event emission), interactions. This ensures that events accurately reflect the state changes and appear in the correct chronological order in the event log.	[]	["https://github.com/crytic/caracal", "https://book.cairo-lang.org/ch99-02-02-contract-events.html"]	\N	0	{cairo}	\N	\N	2025-11-01 16:25:08.767942+00	2025-11-01 16:25:08.767942+00	t
BVD-CAIRO-QUA-001	Unused Events	Events defined in a contract but never emitted represent dead code and missing observability. Events are critical for off-chain monitoring, user interfaces, and indexers to track contract activity. Defined but unused events indicate incomplete implementation, potential bugs where events should be emitted, or unnecessary code bloat that increases deployment costs and complexity.	code-quality	medium	\N	CWE-1164	A04:2021	Remove unused event definitions or implement proper event emission where appropriate. Ensure all significant state changes emit corresponding events for transparency and off-chain tracking. Follow the pattern of emitting events after state updates but before external calls.	[]	["https://github.com/crytic/caracal", "https://book.cairo-lang.org/ch99-02-02-contract-events.html"]	\N	0	{cairo}	\N	\N	2025-11-01 16:25:08.767942+00	2025-11-01 16:25:08.767942+00	t
BVD-CAIRO-QUA-002	Unchecked Return Values	Ignoring return values from function calls, especially external calls, can lead to silent failures and incorrect assumptions about operation success. Many Cairo functions return Result types or option values that indicate success or failure. Not checking these values means errors go unnoticed, potentially leading to state inconsistencies, fund loss, or security vulnerabilities.	code-quality	medium	\N	CWE-252	A04:2021	Always check return values from function calls, especially external calls and system calls. Use proper error handling with Result types. Propagate errors appropriately using the ? operator or explicit matching. For functions that can fail, always verify success before proceeding.	[{"language": "cairo", "fixed_code": ": Check return value\\n#[external(v0)]\\nfn execute_transfer(ref self: ContractState, token: ContractAddress, to: ContractAddress, amount: u256) {\\n    let success = IERC20Dispatcher { contract_address: token }.transfer(to, amount);\\n    assert(success, 'Transfer failed');\\n    self.transfer_count.write(self.transfer_count.read() + 1);\\n}", "vulnerable_code": "Ignoring return value\\n#[external(v0)]\\nfn execute_transfer(ref self: ContractState, token: ContractAddress, to: ContractAddress, amount: u256) {\\n    // Return value ignored - transfer might fail silently\\n    IERC20Dispatcher { contract_address: token }.transfer(to, amount);\\n    self.transfer_count.write(self.transfer_count.read() + 1);\\n}"}]	["https://github.com/crytic/caracal", "https://book.cairo-lang.org/ch09-02-result.html"]	\N	0	{cairo}	\N	\N	2025-11-01 16:25:08.767942+00	2025-11-01 16:25:08.767942+00	t
BVD-CAIRO-QUA-003	Unused Function Arguments	Function parameters that are never used in the function body indicate incomplete implementation, copy-paste errors, or unnecessary complexity. Unused arguments increase gas costs, confuse developers about the function's intent, and may hide bugs where the argument should have been used but wasn't. This is especially problematic in external functions where users pay gas for passing unused data.	code-quality	low	\N	CWE-1164	A04:2021	Remove unused parameters from function signatures. If a parameter might be needed for future compatibility, document why it's currently unused. Consider using _ prefix for intentionally unused parameters. For interface implementations where arguments are required but unused, document the reason clearly.	[]	["https://github.com/crytic/caracal"]	\N	0	{cairo}	\N	\N	2025-11-01 16:25:08.767942+00	2025-11-01 16:25:08.767942+00	t
BVD-CAIRO-QUA-004	Dead Code Detection	Private functions that are never called represent dead code that increases contract size, deployment costs, and maintenance burden. Dead code can also hide security vulnerabilities that might be triggered if the code is accidentally invoked in the future. Identifying and removing unused private functions helps keep contracts lean, secure, and maintainable.	code-quality	low	\N	CWE-561	A04:2021	Remove unused private functions to reduce contract size and complexity. If functions are kept for future use, document this decision clearly. Use code coverage tools to identify dead code. Regularly audit contracts to remove deprecated or unused functionality.	[]	["https://github.com/crytic/caracal"]	\N	0	{cairo}	\N	\N	2025-11-01 16:25:08.767942+00	2025-11-01 16:25:08.767942+00	t
\.


--
-- Data for Name: vulnerability_trends; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.vulnerability_trends (id, pattern_id, contract_id, user_id, period_start, period_end, period_type, total_occurrences, unique_contracts, new_occurrences, reintroduced_occurrences, critical_count, high_count, medium_count, low_count, open_count, fixed_count, false_positive_count, acknowledged_count, scanner_distribution, avg_time_to_fix, fix_rate, reintroduction_rate, avg_false_positive_score, avg_confidence, duplicate_rate, created_at, updated_at) FROM stdin;
\.


--
-- Name: scanner_release_tracking_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.scanner_release_tracking_id_seq', 1, false);


--
-- Name: scanner_version_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.scanner_version_history_id_seq', 3, true);


--
-- Name: scanner_versions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.scanner_versions_id_seq', 16, true);


--
-- Name: alembic_version alembic_version_pkc; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.alembic_version
    ADD CONSTRAINT alembic_version_pkc PRIMARY KEY (version_num);


--
-- Name: code_quality_findings code_quality_findings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.code_quality_findings
    ADD CONSTRAINT code_quality_findings_pkey PRIMARY KEY (id);


--
-- Name: contract_files contract_files_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contract_files
    ADD CONSTRAINT contract_files_pkey PRIMARY KEY (id);


--
-- Name: contracts contracts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contracts
    ADD CONSTRAINT contracts_pkey PRIMARY KEY (id);


--
-- Name: deduplication_group_members deduplication_group_members_group_id_finding_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deduplication_group_members
    ADD CONSTRAINT deduplication_group_members_group_id_finding_id_key UNIQUE (group_id, finding_id);


--
-- Name: deduplication_group_members deduplication_group_members_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deduplication_group_members
    ADD CONSTRAINT deduplication_group_members_pkey PRIMARY KEY (id);


--
-- Name: deduplication_groups deduplication_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deduplication_groups
    ADD CONSTRAINT deduplication_groups_pkey PRIMARY KEY (id);


--
-- Name: formal_verification_results formal_verification_results_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.formal_verification_results
    ADD CONSTRAINT formal_verification_results_pkey PRIMARY KEY (id);


--
-- Name: fuzzing_results fuzzing_results_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fuzzing_results
    ADD CONSTRAINT fuzzing_results_pkey PRIMARY KEY (id);


--
-- Name: gas_analysis_findings gas_analysis_findings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.gas_analysis_findings
    ADD CONSTRAINT gas_analysis_findings_pkey PRIMARY KEY (id);


--
-- Name: pattern_tool_mappings pattern_tool_mappings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pattern_tool_mappings
    ADD CONSTRAINT pattern_tool_mappings_pkey PRIMARY KEY (id);


--
-- Name: project_contracts project_contracts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.project_contracts
    ADD CONSTRAINT project_contracts_pkey PRIMARY KEY (project_id, contract_id);


--
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


--
-- Name: saved_searches saved_searches_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.saved_searches
    ADD CONSTRAINT saved_searches_pkey PRIMARY KEY (id);


--
-- Name: scanner_release_tracking scanner_release_tracking_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.scanner_release_tracking
    ADD CONSTRAINT scanner_release_tracking_pkey PRIMARY KEY (id);


--
-- Name: scanner_release_tracking scanner_release_tracking_scanner_name_release_version_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.scanner_release_tracking
    ADD CONSTRAINT scanner_release_tracking_scanner_name_release_version_key UNIQUE (scanner_name, release_version);


--
-- Name: scanner_version_history scanner_version_history_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.scanner_version_history
    ADD CONSTRAINT scanner_version_history_pkey PRIMARY KEY (id);


--
-- Name: scanner_versions scanner_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.scanner_versions
    ADD CONSTRAINT scanner_versions_pkey PRIMARY KEY (id);


--
-- Name: scanner_versions scanner_versions_scanner_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.scanner_versions
    ADD CONSTRAINT scanner_versions_scanner_name_key UNIQUE (scanner_name);


--
-- Name: scans scans_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.scans
    ADD CONSTRAINT scans_pkey PRIMARY KEY (id);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: pattern_tool_mappings uq_pattern_tool_scanner_detector; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pattern_tool_mappings
    ADD CONSTRAINT uq_pattern_tool_scanner_detector UNIQUE (scanner_id, detector_id);


--
-- Name: vulnerability_trends uq_vuln_trends_pattern_contract_period; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vulnerability_trends
    ADD CONSTRAINT uq_vuln_trends_pattern_contract_period UNIQUE (pattern_id, contract_id, period_type, period_start);


--
-- Name: user_preferences user_preferences_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_preferences
    ADD CONSTRAINT user_preferences_pkey PRIMARY KEY (user_id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: vulnerabilities vulnerabilities_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vulnerabilities
    ADD CONSTRAINT vulnerabilities_pkey PRIMARY KEY (id);


--
-- Name: vulnerability_classifications vulnerability_classifications_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vulnerability_classifications
    ADD CONSTRAINT vulnerability_classifications_pkey PRIMARY KEY (id);


--
-- Name: vulnerability_patterns vulnerability_patterns_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vulnerability_patterns
    ADD CONSTRAINT vulnerability_patterns_pkey PRIMARY KEY (id);


--
-- Name: vulnerability_trends vulnerability_trends_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vulnerability_trends
    ADD CONSTRAINT vulnerability_trends_pkey PRIMARY KEY (id);


--
-- Name: idx_dedup_members_canonical; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_dedup_members_canonical ON public.deduplication_group_members USING btree (is_canonical) WHERE (is_canonical = true);


--
-- Name: idx_dedup_members_finding; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_dedup_members_finding ON public.deduplication_group_members USING btree (finding_id);


--
-- Name: idx_dedup_members_group; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_dedup_members_group ON public.deduplication_group_members USING btree (group_id);


--
-- Name: idx_release_tracking_applied; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_release_tracking_applied ON public.scanner_release_tracking USING btree (applied_to_platform);


--
-- Name: idx_release_tracking_scanner; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_release_tracking_scanner ON public.scanner_release_tracking USING btree (scanner_name);


--
-- Name: idx_scanner_versions_ecosystem; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_scanner_versions_ecosystem ON public.scanner_versions USING btree (ecosystem);


--
-- Name: idx_scanner_versions_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_scanner_versions_status ON public.scanner_versions USING btree (version_status);


--
-- Name: idx_scanner_versions_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_scanner_versions_type ON public.scanner_versions USING btree (scanner_type);


--
-- Name: idx_version_history_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_version_history_date ON public.scanner_version_history USING btree (updated_at DESC);


--
-- Name: idx_version_history_scanner; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_version_history_scanner ON public.scanner_version_history USING btree (scanner_name);


--
-- Name: ix_code_quality_findings_category; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_code_quality_findings_category ON public.code_quality_findings USING btree (category);


--
-- Name: ix_code_quality_findings_scan_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_code_quality_findings_scan_id ON public.code_quality_findings USING btree (scan_id);


--
-- Name: ix_code_quality_findings_scanner_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_code_quality_findings_scanner_id ON public.code_quality_findings USING btree (scanner_id);


--
-- Name: ix_code_quality_findings_severity; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_code_quality_findings_severity ON public.code_quality_findings USING btree (severity);


--
-- Name: ix_contract_files_contract_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_contract_files_contract_id ON public.contract_files USING btree (contract_id);


--
-- Name: ix_contracts_address; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_contracts_address ON public.contracts USING btree (address);


--
-- Name: ix_contracts_language; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_contracts_language ON public.contracts USING btree (language);


--
-- Name: ix_contracts_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_contracts_user_id ON public.contracts USING btree (user_id);


--
-- Name: ix_contracts_user_language_created; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_contracts_user_language_created ON public.contracts USING btree (user_id, language);


--
-- Name: ix_dedup_groups_contract_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_dedup_groups_contract_id ON public.deduplication_groups USING btree (contract_id);


--
-- Name: ix_dedup_groups_fingerprint_code; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_dedup_groups_fingerprint_code ON public.deduplication_groups USING btree (fingerprint_code);


--
-- Name: ix_dedup_groups_fingerprint_lookup; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_dedup_groups_fingerprint_lookup ON public.deduplication_groups USING btree (fingerprint_code, fingerprint_ast, contract_id);


--
-- Name: ix_dedup_groups_first_detected; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_dedup_groups_first_detected ON public.deduplication_groups USING btree (first_detected);


--
-- Name: ix_dedup_groups_pattern_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_dedup_groups_pattern_id ON public.deduplication_groups USING btree (pattern_id);


--
-- Name: ix_dedup_groups_primary_vuln_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_dedup_groups_primary_vuln_id ON public.deduplication_groups USING btree (primary_vulnerability_id);


--
-- Name: ix_dedup_groups_strategy; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_dedup_groups_strategy ON public.deduplication_groups USING btree (strategy);


--
-- Name: ix_dedup_groups_verified; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_dedup_groups_verified ON public.deduplication_groups USING btree (verified);


--
-- Name: ix_formal_verification_results_proof_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_formal_verification_results_proof_type ON public.formal_verification_results USING btree (proof_type);


--
-- Name: ix_formal_verification_results_scan_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_formal_verification_results_scan_id ON public.formal_verification_results USING btree (scan_id);


--
-- Name: ix_formal_verification_results_scanner_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_formal_verification_results_scanner_id ON public.formal_verification_results USING btree (scanner_id);


--
-- Name: ix_formal_verification_results_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_formal_verification_results_status ON public.formal_verification_results USING btree (status);


--
-- Name: ix_fuzzing_results_scan_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_fuzzing_results_scan_id ON public.fuzzing_results USING btree (scan_id);


--
-- Name: ix_fuzzing_results_scanner_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_fuzzing_results_scanner_id ON public.fuzzing_results USING btree (scanner_id);


--
-- Name: ix_fuzzing_results_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_fuzzing_results_status ON public.fuzzing_results USING btree (status);


--
-- Name: ix_fuzzing_results_test_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_fuzzing_results_test_name ON public.fuzzing_results USING btree (test_name);


--
-- Name: ix_gas_analysis_contract_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_gas_analysis_contract_id ON public.gas_analysis_findings USING btree (contract_id);


--
-- Name: ix_gas_analysis_contract_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_gas_analysis_contract_name ON public.gas_analysis_findings USING btree (contract_name);


--
-- Name: ix_gas_analysis_detector_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_gas_analysis_detector_id ON public.gas_analysis_findings USING btree (detector_id);


--
-- Name: ix_gas_analysis_file_path; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_gas_analysis_file_path ON public.gas_analysis_findings USING btree (file_path);


--
-- Name: ix_gas_analysis_findings_function_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_gas_analysis_findings_function_name ON public.gas_analysis_findings USING btree (function_name);


--
-- Name: ix_gas_analysis_findings_optimization_level; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_gas_analysis_findings_optimization_level ON public.gas_analysis_findings USING btree (optimization_level);


--
-- Name: ix_gas_analysis_findings_scan_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_gas_analysis_findings_scan_id ON public.gas_analysis_findings USING btree (scan_id);


--
-- Name: ix_gas_analysis_findings_scanner_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_gas_analysis_findings_scanner_id ON public.gas_analysis_findings USING btree (scanner_id);


--
-- Name: ix_pattern_tool_mappings_detector_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_pattern_tool_mappings_detector_id ON public.pattern_tool_mappings USING btree (detector_id);


--
-- Name: ix_pattern_tool_mappings_is_active; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_pattern_tool_mappings_is_active ON public.pattern_tool_mappings USING btree (is_active);


--
-- Name: ix_pattern_tool_mappings_pattern_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_pattern_tool_mappings_pattern_id ON public.pattern_tool_mappings USING btree (pattern_id);


--
-- Name: ix_pattern_tool_mappings_scanner_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_pattern_tool_mappings_scanner_id ON public.pattern_tool_mappings USING btree (scanner_id);


--
-- Name: ix_project_contracts_added; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_project_contracts_added ON public.project_contracts USING btree (project_id);


--
-- Name: ix_projects_created_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_projects_created_at ON public.projects USING btree (created_at);


--
-- Name: ix_projects_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_projects_name ON public.projects USING btree (name);


--
-- Name: ix_projects_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_projects_user_id ON public.projects USING btree (user_id);


--
-- Name: ix_saved_searches_created_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_saved_searches_created_at ON public.saved_searches USING btree (created_at DESC);


--
-- Name: ix_saved_searches_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_saved_searches_user_id ON public.saved_searches USING btree (user_id);


--
-- Name: ix_scans_contract_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_scans_contract_id ON public.scans USING btree (contract_id);


--
-- Name: ix_scans_failed; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_scans_failed ON public.scans USING btree (user_id, created_at DESC) WHERE (status = 'failed'::public.scan_status);


--
-- Name: ix_scans_scanners_used; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_scans_scanners_used ON public.scans USING gin (scanners_used);


--
-- Name: ix_scans_user_completed; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_scans_user_completed ON public.scans USING btree (user_id, completed_at DESC) WHERE (status = 'completed'::public.scan_status);


--
-- Name: ix_scans_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_scans_user_id ON public.scans USING btree (user_id);


--
-- Name: ix_scans_user_status_created; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_scans_user_status_created ON public.scans USING btree (user_id, status);


--
-- Name: ix_sessions_refresh_token; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX ix_sessions_refresh_token ON public.sessions USING btree (refresh_token);


--
-- Name: ix_sessions_token; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX ix_sessions_token ON public.sessions USING btree (token);


--
-- Name: ix_sessions_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_sessions_user_id ON public.sessions USING btree (user_id);


--
-- Name: ix_users_email; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX ix_users_email ON public.users USING btree (email);


--
-- Name: ix_vuln_classifications_classification; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vuln_classifications_classification ON public.vulnerability_classifications USING btree (classification);


--
-- Name: ix_vuln_classifications_created_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vuln_classifications_created_at ON public.vulnerability_classifications USING btree (created_at);


--
-- Name: ix_vuln_classifications_fix_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vuln_classifications_fix_status ON public.vulnerability_classifications USING btree (fix_status);


--
-- Name: ix_vuln_classifications_is_latest; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vuln_classifications_is_latest ON public.vulnerability_classifications USING btree (is_latest);


--
-- Name: ix_vuln_classifications_latest_lookup; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vuln_classifications_latest_lookup ON public.vulnerability_classifications USING btree (vulnerability_id, is_latest, created_at);


--
-- Name: ix_vuln_classifications_tags; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vuln_classifications_tags ON public.vulnerability_classifications USING gin (tags);


--
-- Name: ix_vuln_classifications_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vuln_classifications_user_id ON public.vulnerability_classifications USING btree (user_id);


--
-- Name: ix_vuln_classifications_vuln_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vuln_classifications_vuln_id ON public.vulnerability_classifications USING btree (vulnerability_id);


--
-- Name: ix_vuln_patterns_category; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vuln_patterns_category ON public.vulnerability_patterns USING btree (category);


--
-- Name: ix_vuln_patterns_cwe_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vuln_patterns_cwe_id ON public.vulnerability_patterns USING btree (cwe_id);


--
-- Name: ix_vuln_patterns_is_active; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vuln_patterns_is_active ON public.vulnerability_patterns USING btree (is_active);


--
-- Name: ix_vuln_patterns_keywords; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vuln_patterns_keywords ON public.vulnerability_patterns USING gin (keywords);


--
-- Name: ix_vuln_patterns_languages; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vuln_patterns_languages ON public.vulnerability_patterns USING gin (affected_languages);


--
-- Name: ix_vuln_patterns_severity; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vuln_patterns_severity ON public.vulnerability_patterns USING btree (severity);


--
-- Name: ix_vuln_patterns_swc_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vuln_patterns_swc_id ON public.vulnerability_patterns USING btree (swc_id);


--
-- Name: ix_vuln_trends_contract_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vuln_trends_contract_id ON public.vulnerability_trends USING btree (contract_id);


--
-- Name: ix_vuln_trends_contract_time_series; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vuln_trends_contract_time_series ON public.vulnerability_trends USING btree (contract_id, period_type, period_start);


--
-- Name: ix_vuln_trends_pattern_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vuln_trends_pattern_id ON public.vulnerability_trends USING btree (pattern_id);


--
-- Name: ix_vuln_trends_pattern_time_series; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vuln_trends_pattern_time_series ON public.vulnerability_trends USING btree (pattern_id, period_type, period_start);


--
-- Name: ix_vuln_trends_period_end; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vuln_trends_period_end ON public.vulnerability_trends USING btree (period_end);


--
-- Name: ix_vuln_trends_period_start; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vuln_trends_period_start ON public.vulnerability_trends USING btree (period_start);


--
-- Name: ix_vuln_trends_period_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vuln_trends_period_type ON public.vulnerability_trends USING btree (period_type);


--
-- Name: ix_vuln_trends_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vuln_trends_user_id ON public.vulnerability_trends USING btree (user_id);


--
-- Name: ix_vuln_trends_user_time_series; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vuln_trends_user_time_series ON public.vulnerability_trends USING btree (user_id, period_type, period_start);


--
-- Name: ix_vulnerabilities_category; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vulnerabilities_category ON public.vulnerabilities USING btree (category);


--
-- Name: ix_vulnerabilities_contract_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vulnerabilities_contract_id ON public.vulnerabilities USING btree (contract_id);


--
-- Name: ix_vulnerabilities_contract_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vulnerabilities_contract_name ON public.vulnerabilities USING btree (contract_name);


--
-- Name: ix_vulnerabilities_dedup_group_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vulnerabilities_dedup_group_id ON public.vulnerabilities USING btree (deduplication_group_id);


--
-- Name: ix_vulnerabilities_dedup_lookup; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vulnerabilities_dedup_lookup ON public.vulnerabilities USING btree (fingerprint_code, fingerprint_ast, contract_id);


--
-- Name: ix_vulnerabilities_detector_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vulnerabilities_detector_id ON public.vulnerabilities USING btree (detector_id);


--
-- Name: ix_vulnerabilities_false_positive_score; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vulnerabilities_false_positive_score ON public.vulnerabilities USING btree (false_positive_score);


--
-- Name: ix_vulnerabilities_file_path; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vulnerabilities_file_path ON public.vulnerabilities USING btree (file_path);


--
-- Name: ix_vulnerabilities_fingerprint_code; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vulnerabilities_fingerprint_code ON public.vulnerabilities USING btree (fingerprint_code);


--
-- Name: ix_vulnerabilities_fingerprint_composite; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vulnerabilities_fingerprint_composite ON public.vulnerabilities USING btree (fingerprint_composite);


--
-- Name: ix_vulnerabilities_fingerprint_location_fuzzy; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vulnerabilities_fingerprint_location_fuzzy ON public.vulnerabilities USING btree (fingerprint_location_fuzzy);


--
-- Name: ix_vulnerabilities_first_seen; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vulnerabilities_first_seen ON public.vulnerabilities USING btree (first_seen);


--
-- Name: ix_vulnerabilities_function_name; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vulnerabilities_function_name ON public.vulnerabilities USING btree (function_name);


--
-- Name: ix_vulnerabilities_fuzzy_dedup_lookup; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vulnerabilities_fuzzy_dedup_lookup ON public.vulnerabilities USING btree (fingerprint_location_fuzzy, fingerprint_code, contract_id);


--
-- Name: ix_vulnerabilities_historical_lookup; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vulnerabilities_historical_lookup ON public.vulnerabilities USING btree (pattern_id, contract_id, first_seen);


--
-- Name: ix_vulnerabilities_is_primary; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vulnerabilities_is_primary ON public.vulnerabilities USING btree (is_primary);


--
-- Name: ix_vulnerabilities_last_seen; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vulnerabilities_last_seen ON public.vulnerabilities USING btree (last_seen);


--
-- Name: ix_vulnerabilities_location_lookup; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vulnerabilities_location_lookup ON public.vulnerabilities USING btree (contract_name, file_path, function_name);


--
-- Name: ix_vulnerabilities_open; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vulnerabilities_open ON public.vulnerabilities USING btree (contract_id, severity) WHERE (status = 'open'::public.vulnerability_status);


--
-- Name: ix_vulnerabilities_pattern_code; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vulnerabilities_pattern_code ON public.vulnerabilities USING btree (pattern_code);


--
-- Name: ix_vulnerabilities_pattern_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vulnerabilities_pattern_id ON public.vulnerabilities USING btree (pattern_id);


--
-- Name: ix_vulnerabilities_scan_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vulnerabilities_scan_id ON public.vulnerabilities USING btree (scan_id);


--
-- Name: ix_vulnerabilities_scan_severity; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vulnerabilities_scan_severity ON public.vulnerabilities USING btree (scan_id, severity);


--
-- Name: ix_vulnerabilities_scanner_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vulnerabilities_scanner_id ON public.vulnerabilities USING btree (scanner_id);


--
-- Name: ix_vulnerabilities_severity; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vulnerabilities_severity ON public.vulnerabilities USING btree (severity);


--
-- Name: ix_vulnerabilities_user_classification; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vulnerabilities_user_classification ON public.vulnerabilities USING btree (user_classification);


--
-- Name: ix_vulns_contract_severity_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vulns_contract_severity_status ON public.vulnerabilities USING btree (contract_id, severity, status);


--
-- Name: deduplication_group_members trigger_update_dedup_group_stats; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_update_dedup_group_stats AFTER INSERT OR DELETE OR UPDATE ON public.deduplication_group_members FOR EACH ROW EXECUTE FUNCTION public.update_deduplication_group_stats();


--
-- Name: deduplication_groups trigger_update_dedup_group_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_update_dedup_group_updated_at BEFORE UPDATE ON public.deduplication_groups FOR EACH ROW EXECUTE FUNCTION public.update_deduplication_group_updated_at();


--
-- Name: code_quality_findings code_quality_findings_scan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.code_quality_findings
    ADD CONSTRAINT code_quality_findings_scan_id_fkey FOREIGN KEY (scan_id) REFERENCES public.scans(id) ON DELETE CASCADE;


--
-- Name: contract_files contract_files_contract_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contract_files
    ADD CONSTRAINT contract_files_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES public.contracts(id) ON DELETE CASCADE;


--
-- Name: contracts contracts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contracts
    ADD CONSTRAINT contracts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: deduplication_group_members deduplication_group_members_finding_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deduplication_group_members
    ADD CONSTRAINT deduplication_group_members_finding_id_fkey FOREIGN KEY (finding_id) REFERENCES public.vulnerabilities(id) ON DELETE CASCADE;


--
-- Name: deduplication_group_members deduplication_group_members_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deduplication_group_members
    ADD CONSTRAINT deduplication_group_members_group_id_fkey FOREIGN KEY (group_id) REFERENCES public.deduplication_groups(id) ON DELETE CASCADE;


--
-- Name: deduplication_groups deduplication_groups_contract_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deduplication_groups
    ADD CONSTRAINT deduplication_groups_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES public.contracts(id) ON DELETE CASCADE;


--
-- Name: deduplication_groups deduplication_groups_pattern_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deduplication_groups
    ADD CONSTRAINT deduplication_groups_pattern_id_fkey FOREIGN KEY (pattern_id) REFERENCES public.vulnerability_patterns(id) ON DELETE SET NULL;


--
-- Name: deduplication_groups deduplication_groups_primary_vulnerability_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deduplication_groups
    ADD CONSTRAINT deduplication_groups_primary_vulnerability_id_fkey FOREIGN KEY (primary_vulnerability_id) REFERENCES public.vulnerabilities(id) ON DELETE CASCADE;


--
-- Name: deduplication_groups deduplication_groups_verified_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deduplication_groups
    ADD CONSTRAINT deduplication_groups_verified_by_fkey FOREIGN KEY (verified_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: vulnerabilities fk_vulnerabilities_dedup_group_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vulnerabilities
    ADD CONSTRAINT fk_vulnerabilities_dedup_group_id FOREIGN KEY (deduplication_group_id) REFERENCES public.deduplication_groups(id) ON DELETE SET NULL;


--
-- Name: vulnerabilities fk_vulnerabilities_pattern_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vulnerabilities
    ADD CONSTRAINT fk_vulnerabilities_pattern_id FOREIGN KEY (pattern_id) REFERENCES public.vulnerability_patterns(id) ON DELETE SET NULL;


--
-- Name: formal_verification_results formal_verification_results_scan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.formal_verification_results
    ADD CONSTRAINT formal_verification_results_scan_id_fkey FOREIGN KEY (scan_id) REFERENCES public.scans(id) ON DELETE CASCADE;


--
-- Name: fuzzing_results fuzzing_results_scan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fuzzing_results
    ADD CONSTRAINT fuzzing_results_scan_id_fkey FOREIGN KEY (scan_id) REFERENCES public.scans(id) ON DELETE CASCADE;


--
-- Name: gas_analysis_findings gas_analysis_findings_scan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.gas_analysis_findings
    ADD CONSTRAINT gas_analysis_findings_scan_id_fkey FOREIGN KEY (scan_id) REFERENCES public.scans(id) ON DELETE CASCADE;


--
-- Name: pattern_tool_mappings pattern_tool_mappings_pattern_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pattern_tool_mappings
    ADD CONSTRAINT pattern_tool_mappings_pattern_id_fkey FOREIGN KEY (pattern_id) REFERENCES public.vulnerability_patterns(id) ON DELETE CASCADE;


--
-- Name: project_contracts project_contracts_contract_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.project_contracts
    ADD CONSTRAINT project_contracts_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES public.contracts(id) ON DELETE CASCADE;


--
-- Name: project_contracts project_contracts_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.project_contracts
    ADD CONSTRAINT project_contracts_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: projects projects_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: saved_searches saved_searches_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.saved_searches
    ADD CONSTRAINT saved_searches_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: scanner_release_tracking scanner_release_tracking_scanner_name_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.scanner_release_tracking
    ADD CONSTRAINT scanner_release_tracking_scanner_name_fkey FOREIGN KEY (scanner_name) REFERENCES public.scanner_versions(scanner_name) ON DELETE CASCADE;


--
-- Name: scanner_version_history scanner_version_history_scanner_name_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.scanner_version_history
    ADD CONSTRAINT scanner_version_history_scanner_name_fkey FOREIGN KEY (scanner_name) REFERENCES public.scanner_versions(scanner_name) ON DELETE CASCADE;


--
-- Name: scans scans_contract_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.scans
    ADD CONSTRAINT scans_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES public.contracts(id);


--
-- Name: scans scans_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.scans
    ADD CONSTRAINT scans_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: user_preferences user_preferences_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.user_preferences
    ADD CONSTRAINT user_preferences_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: vulnerabilities vulnerabilities_contract_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vulnerabilities
    ADD CONSTRAINT vulnerabilities_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES public.contracts(id);


--
-- Name: vulnerabilities vulnerabilities_scan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vulnerabilities
    ADD CONSTRAINT vulnerabilities_scan_id_fkey FOREIGN KEY (scan_id) REFERENCES public.scans(id);


--
-- Name: vulnerability_classifications vulnerability_classifications_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vulnerability_classifications
    ADD CONSTRAINT vulnerability_classifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: vulnerability_classifications vulnerability_classifications_vulnerability_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vulnerability_classifications
    ADD CONSTRAINT vulnerability_classifications_vulnerability_id_fkey FOREIGN KEY (vulnerability_id) REFERENCES public.vulnerabilities(id) ON DELETE CASCADE;


--
-- Name: vulnerability_trends vulnerability_trends_contract_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vulnerability_trends
    ADD CONSTRAINT vulnerability_trends_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES public.contracts(id) ON DELETE CASCADE;


--
-- Name: vulnerability_trends vulnerability_trends_pattern_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vulnerability_trends
    ADD CONSTRAINT vulnerability_trends_pattern_id_fkey FOREIGN KEY (pattern_id) REFERENCES public.vulnerability_patterns(id) ON DELETE CASCADE;


--
-- Name: vulnerability_trends vulnerability_trends_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vulnerability_trends
    ADD CONSTRAINT vulnerability_trends_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;


--
-- PostgreSQL database dump complete
--

