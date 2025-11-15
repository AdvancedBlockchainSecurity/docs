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

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

-- *not* creating schema, since initdb creates it


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS '';


--
-- Name: contract_language; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.contract_language AS ENUM (
    'solidity',
    'vyper',
    'rust',
    'move',
    'cairo'
);


--
-- Name: contract_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.contract_status AS ENUM (
    'uploaded',
    'pending',
    'scanning',
    'scanned',
    'failed'
);


--
-- Name: scan_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.scan_status AS ENUM (
    'queued',
    'running',
    'completed',
    'failed'
);


--
-- Name: vulnerability_severity; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.vulnerability_severity AS ENUM (
    'critical',
    'high',
    'medium',
    'low'
);


--
-- Name: vulnerability_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.vulnerability_status AS ENUM (
    'open',
    'acknowledged',
    'fixed',
    'false_positive'
);


--
-- Name: check_scanner_version_update(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: FUNCTION check_scanner_version_update(p_scanner_name character varying, p_new_version character varying, p_new_image_tag character varying); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.check_scanner_version_update(p_scanner_name character varying, p_new_version character varying, p_new_image_tag character varying) IS 'Check if a scanner version update is available';


--
-- Name: record_scanner_update(character varying, character varying, character varying, character varying, boolean, text, text); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: FUNCTION record_scanner_update(p_scanner_name character varying, p_new_version character varying, p_new_image_tag character varying, p_change_type character varying, p_breaking boolean, p_detector_changes text, p_release_notes text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.record_scanner_update(p_scanner_name character varying, p_new_version character varying, p_new_image_tag character varying, p_change_type character varying, p_breaking boolean, p_detector_changes text, p_release_notes text) IS 'Record a scanner version update with history tracking';


--
-- Name: update_deduplication_group_stats(); Type: FUNCTION; Schema: public; Owner: -
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


--
-- Name: update_deduplication_group_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_deduplication_group_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: alembic_version; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.alembic_version (
    version_num character varying(32) NOT NULL
);


--
-- Name: code_quality_findings; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: contract_files; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: contracts; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: deduplication_group_members; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: TABLE deduplication_group_members; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.deduplication_group_members IS 'Phase 4E: Many-to-many relationship between deduplication groups and vulnerabilities';


--
-- Name: COLUMN deduplication_group_members.match_confidence; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.deduplication_group_members.match_confidence IS 'Confidence level of this specific finding match (exact, high, medium, low)';


--
-- Name: COLUMN deduplication_group_members.matched_fingerprints; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.deduplication_group_members.matched_fingerprints IS 'JSON array of fingerprint fields that matched for this specific finding';


--
-- Name: COLUMN deduplication_group_members.is_canonical; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.deduplication_group_members.is_canonical IS 'Whether this is the canonical (primary) finding for the group';


--
-- Name: deduplication_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.deduplication_groups (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    canonical_finding_id uuid NOT NULL,
    contract_id uuid NOT NULL,
    pattern_code character varying(50),
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


--
-- Name: TABLE deduplication_groups; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.deduplication_groups IS 'Phase 4E: Groups of duplicate vulnerability findings across different scanners';


--
-- Name: formal_verification_results; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: fuzzing_results; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: gas_analysis_findings; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: COLUMN gas_analysis_findings.contract_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.gas_analysis_findings.contract_id IS 'Contract ID for this gas optimization finding';


--
-- Name: COLUMN gas_analysis_findings.detector_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.gas_analysis_findings.detector_id IS 'Detector ID that found this optimization (extracted by parser)';


--
-- Name: COLUMN gas_analysis_findings.file_path; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.gas_analysis_findings.file_path IS 'Source file path where optimization applies (extracted by parser)';


--
-- Name: COLUMN gas_analysis_findings.contract_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.gas_analysis_findings.contract_name IS 'Contract name where optimization applies (for enrichment context)';


--
-- Name: scanner_versions; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: TABLE scanner_versions; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.scanner_versions IS 'Tracks current scanner versions and integration status for BlockSecOps platform';


--
-- Name: COLUMN scanner_versions.version_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.scanner_versions.version_status IS 'Current version status: up-to-date, outdated, unknown, deprecated';


--
-- Name: COLUMN scanner_versions.integration_percentage; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.scanner_versions.integration_percentage IS 'Automatically calculated percentage of integrated detectors';


--
-- Name: outdated_scanners; Type: VIEW; Schema: public; Owner: -
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


--
-- Name: VIEW outdated_scanners; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.outdated_scanners IS 'Quick view of scanners needing updates';


--
-- Name: pattern_tool_mappings; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: project_contracts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_contracts (
    project_id uuid NOT NULL,
    contract_id uuid NOT NULL,
    added_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: projects; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: saved_searches; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: TABLE saved_searches; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.saved_searches IS 'User-saved search queries for quick re-execution';


--
-- Name: COLUMN saved_searches.search_params; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.saved_searches.search_params IS 'JSON object containing SearchRequest parameters';


--
-- Name: scanner_release_tracking; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: TABLE scanner_release_tracking; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.scanner_release_tracking IS 'Tracks upstream releases for version monitoring';


--
-- Name: scanner_release_tracking_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.scanner_release_tracking_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: scanner_release_tracking_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.scanner_release_tracking_id_seq OWNED BY public.scanner_release_tracking.id;


--
-- Name: scanner_version_history; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: TABLE scanner_version_history; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.scanner_version_history IS 'Audit trail of all scanner version updates';


--
-- Name: COLUMN scanner_version_history.change_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.scanner_version_history.change_type IS 'Type of version change: major, minor, patch, image-only';


--
-- Name: scanner_version_history_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.scanner_version_history_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: scanner_version_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.scanner_version_history_id_seq OWNED BY public.scanner_version_history.id;


--
-- Name: scanner_version_status; Type: VIEW; Schema: public; Owner: -
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


--
-- Name: VIEW scanner_version_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.scanner_version_status IS 'Overview of scanner version status with pending releases';


--
-- Name: scanner_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.scanner_versions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: scanner_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.scanner_versions_id_seq OWNED BY public.scanner_versions.id;


--
-- Name: scans; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: COLUMN scans.scanners_used; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.scans.scanners_used IS 'Array of scanner IDs used in this scan (e.g., {slither, mythril})';


--
-- Name: COLUMN scans.scan_config; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.scans.scan_config IS 'Scanner configuration and parameters used for this scan';


--
-- Name: COLUMN scans.duration_seconds; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.scans.duration_seconds IS 'Scan duration in seconds (completed_at - started_at)';


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: user_preferences; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: TABLE user_preferences; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.user_preferences IS 'User-specific settings and preferences';


--
-- Name: COLUMN user_preferences.preferences; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.user_preferences.preferences IS 'Additional user preferences as JSON';


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: vulnerabilities; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: COLUMN vulnerabilities.category; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.vulnerabilities.category IS 'Vulnerability type category (e.g., reentrancy, access_control, arithmetic)';


--
-- Name: COLUMN vulnerabilities.confidence; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.vulnerabilities.confidence IS 'Scanner confidence score (0.0 to 1.0, where 1.0 is highest confidence)';


--
-- Name: COLUMN vulnerabilities.file_path; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.vulnerabilities.file_path IS 'Source file path where vulnerability was detected (extracted by parser)';


--
-- Name: COLUMN vulnerabilities.function_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.vulnerabilities.function_name IS 'Function name where vulnerability exists (for enrichment context)';


--
-- Name: COLUMN vulnerabilities.contract_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.vulnerabilities.contract_name IS 'Contract name where vulnerability exists (for enrichment context)';


--
-- Name: vulnerability_classifications; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: vulnerability_patterns; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: vulnerability_trends; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: scanner_release_tracking id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scanner_release_tracking ALTER COLUMN id SET DEFAULT nextval('public.scanner_release_tracking_id_seq'::regclass);


--
-- Name: scanner_version_history id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scanner_version_history ALTER COLUMN id SET DEFAULT nextval('public.scanner_version_history_id_seq'::regclass);


--
-- Name: scanner_versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scanner_versions ALTER COLUMN id SET DEFAULT nextval('public.scanner_versions_id_seq'::regclass);


--
-- Name: alembic_version alembic_version_pkc; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.alembic_version
    ADD CONSTRAINT alembic_version_pkc PRIMARY KEY (version_num);


--
-- Name: code_quality_findings code_quality_findings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.code_quality_findings
    ADD CONSTRAINT code_quality_findings_pkey PRIMARY KEY (id);


--
-- Name: contract_files contract_files_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_files
    ADD CONSTRAINT contract_files_pkey PRIMARY KEY (id);


--
-- Name: contracts contracts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contracts
    ADD CONSTRAINT contracts_pkey PRIMARY KEY (id);


--
-- Name: deduplication_group_members deduplication_group_members_group_id_finding_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deduplication_group_members
    ADD CONSTRAINT deduplication_group_members_group_id_finding_id_key UNIQUE (group_id, finding_id);


--
-- Name: deduplication_group_members deduplication_group_members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deduplication_group_members
    ADD CONSTRAINT deduplication_group_members_pkey PRIMARY KEY (id);


--
-- Name: deduplication_groups deduplication_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deduplication_groups
    ADD CONSTRAINT deduplication_groups_pkey PRIMARY KEY (id);


--
-- Name: formal_verification_results formal_verification_results_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.formal_verification_results
    ADD CONSTRAINT formal_verification_results_pkey PRIMARY KEY (id);


--
-- Name: fuzzing_results fuzzing_results_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fuzzing_results
    ADD CONSTRAINT fuzzing_results_pkey PRIMARY KEY (id);


--
-- Name: gas_analysis_findings gas_analysis_findings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gas_analysis_findings
    ADD CONSTRAINT gas_analysis_findings_pkey PRIMARY KEY (id);


--
-- Name: pattern_tool_mappings pattern_tool_mappings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pattern_tool_mappings
    ADD CONSTRAINT pattern_tool_mappings_pkey PRIMARY KEY (id);


--
-- Name: project_contracts project_contracts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_contracts
    ADD CONSTRAINT project_contracts_pkey PRIMARY KEY (project_id, contract_id);


--
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


--
-- Name: saved_searches saved_searches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_searches
    ADD CONSTRAINT saved_searches_pkey PRIMARY KEY (id);


--
-- Name: scanner_release_tracking scanner_release_tracking_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scanner_release_tracking
    ADD CONSTRAINT scanner_release_tracking_pkey PRIMARY KEY (id);


--
-- Name: scanner_release_tracking scanner_release_tracking_scanner_name_release_version_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scanner_release_tracking
    ADD CONSTRAINT scanner_release_tracking_scanner_name_release_version_key UNIQUE (scanner_name, release_version);


--
-- Name: scanner_version_history scanner_version_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scanner_version_history
    ADD CONSTRAINT scanner_version_history_pkey PRIMARY KEY (id);


--
-- Name: scanner_versions scanner_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scanner_versions
    ADD CONSTRAINT scanner_versions_pkey PRIMARY KEY (id);


--
-- Name: scanner_versions scanner_versions_scanner_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scanner_versions
    ADD CONSTRAINT scanner_versions_scanner_name_key UNIQUE (scanner_name);


--
-- Name: scans scans_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scans
    ADD CONSTRAINT scans_pkey PRIMARY KEY (id);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: pattern_tool_mappings uq_pattern_tool_scanner_detector; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pattern_tool_mappings
    ADD CONSTRAINT uq_pattern_tool_scanner_detector UNIQUE (scanner_id, detector_id);


--
-- Name: vulnerability_trends uq_vuln_trends_pattern_contract_period; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vulnerability_trends
    ADD CONSTRAINT uq_vuln_trends_pattern_contract_period UNIQUE (pattern_id, contract_id, period_type, period_start);


--
-- Name: user_preferences user_preferences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_preferences
    ADD CONSTRAINT user_preferences_pkey PRIMARY KEY (user_id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: vulnerabilities vulnerabilities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vulnerabilities
    ADD CONSTRAINT vulnerabilities_pkey PRIMARY KEY (id);


--
-- Name: vulnerability_classifications vulnerability_classifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vulnerability_classifications
    ADD CONSTRAINT vulnerability_classifications_pkey PRIMARY KEY (id);


--
-- Name: vulnerability_patterns vulnerability_patterns_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vulnerability_patterns
    ADD CONSTRAINT vulnerability_patterns_pkey PRIMARY KEY (id);


--
-- Name: vulnerability_trends vulnerability_trends_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vulnerability_trends
    ADD CONSTRAINT vulnerability_trends_pkey PRIMARY KEY (id);


--
-- Name: idx_dedup_members_canonical; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dedup_members_canonical ON public.deduplication_group_members USING btree (is_canonical) WHERE (is_canonical = true);


--
-- Name: idx_dedup_members_finding; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dedup_members_finding ON public.deduplication_group_members USING btree (finding_id);


--
-- Name: idx_dedup_members_group; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dedup_members_group ON public.deduplication_group_members USING btree (group_id);


--
-- Name: idx_release_tracking_applied; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_release_tracking_applied ON public.scanner_release_tracking USING btree (applied_to_platform);


--
-- Name: idx_release_tracking_scanner; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_release_tracking_scanner ON public.scanner_release_tracking USING btree (scanner_name);


--
-- Name: idx_scanner_versions_ecosystem; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_scanner_versions_ecosystem ON public.scanner_versions USING btree (ecosystem);


--
-- Name: idx_scanner_versions_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_scanner_versions_status ON public.scanner_versions USING btree (version_status);


--
-- Name: idx_scanner_versions_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_scanner_versions_type ON public.scanner_versions USING btree (scanner_type);


--
-- Name: idx_version_history_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_version_history_date ON public.scanner_version_history USING btree (updated_at DESC);


--
-- Name: idx_version_history_scanner; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_version_history_scanner ON public.scanner_version_history USING btree (scanner_name);


--
-- Name: ix_code_quality_findings_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_code_quality_findings_category ON public.code_quality_findings USING btree (category);


--
-- Name: ix_code_quality_findings_scan_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_code_quality_findings_scan_id ON public.code_quality_findings USING btree (scan_id);


--
-- Name: ix_code_quality_findings_scanner_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_code_quality_findings_scanner_id ON public.code_quality_findings USING btree (scanner_id);


--
-- Name: ix_code_quality_findings_severity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_code_quality_findings_severity ON public.code_quality_findings USING btree (severity);


--
-- Name: ix_contract_files_contract_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_contract_files_contract_id ON public.contract_files USING btree (contract_id);


--
-- Name: ix_contracts_address; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_contracts_address ON public.contracts USING btree (address);


--
-- Name: ix_contracts_language; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_contracts_language ON public.contracts USING btree (language);


--
-- Name: ix_contracts_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_contracts_user_id ON public.contracts USING btree (user_id);


--
-- Name: ix_contracts_user_language_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_contracts_user_language_created ON public.contracts USING btree (user_id, language);


--
-- Name: ix_dedup_groups_contract_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_dedup_groups_contract_id ON public.deduplication_groups USING btree (contract_id);


--
-- Name: ix_dedup_groups_fingerprint_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_dedup_groups_fingerprint_code ON public.deduplication_groups USING btree (fingerprint_code);


--
-- Name: ix_dedup_groups_fingerprint_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_dedup_groups_fingerprint_lookup ON public.deduplication_groups USING btree (fingerprint_code, fingerprint_ast, contract_id);


--
-- Name: ix_dedup_groups_first_detected; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_dedup_groups_first_detected ON public.deduplication_groups USING btree (first_detected);


--
-- Name: ix_dedup_groups_pattern_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_dedup_groups_pattern_id ON public.deduplication_groups USING btree (pattern_code);


--
-- Name: ix_dedup_groups_primary_vuln_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_dedup_groups_primary_vuln_id ON public.deduplication_groups USING btree (canonical_finding_id);


--
-- Name: ix_dedup_groups_strategy; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_dedup_groups_strategy ON public.deduplication_groups USING btree (strategy);


--
-- Name: ix_dedup_groups_verified; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_dedup_groups_verified ON public.deduplication_groups USING btree (verified);


--
-- Name: ix_formal_verification_results_proof_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_formal_verification_results_proof_type ON public.formal_verification_results USING btree (proof_type);


--
-- Name: ix_formal_verification_results_scan_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_formal_verification_results_scan_id ON public.formal_verification_results USING btree (scan_id);


--
-- Name: ix_formal_verification_results_scanner_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_formal_verification_results_scanner_id ON public.formal_verification_results USING btree (scanner_id);


--
-- Name: ix_formal_verification_results_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_formal_verification_results_status ON public.formal_verification_results USING btree (status);


--
-- Name: ix_fuzzing_results_scan_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_fuzzing_results_scan_id ON public.fuzzing_results USING btree (scan_id);


--
-- Name: ix_fuzzing_results_scanner_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_fuzzing_results_scanner_id ON public.fuzzing_results USING btree (scanner_id);


--
-- Name: ix_fuzzing_results_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_fuzzing_results_status ON public.fuzzing_results USING btree (status);


--
-- Name: ix_fuzzing_results_test_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_fuzzing_results_test_name ON public.fuzzing_results USING btree (test_name);


--
-- Name: ix_gas_analysis_contract_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_gas_analysis_contract_id ON public.gas_analysis_findings USING btree (contract_id);


--
-- Name: ix_gas_analysis_contract_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_gas_analysis_contract_name ON public.gas_analysis_findings USING btree (contract_name);


--
-- Name: ix_gas_analysis_detector_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_gas_analysis_detector_id ON public.gas_analysis_findings USING btree (detector_id);


--
-- Name: ix_gas_analysis_file_path; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_gas_analysis_file_path ON public.gas_analysis_findings USING btree (file_path);


--
-- Name: ix_gas_analysis_findings_function_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_gas_analysis_findings_function_name ON public.gas_analysis_findings USING btree (function_name);


--
-- Name: ix_gas_analysis_findings_optimization_level; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_gas_analysis_findings_optimization_level ON public.gas_analysis_findings USING btree (optimization_level);


--
-- Name: ix_gas_analysis_findings_scan_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_gas_analysis_findings_scan_id ON public.gas_analysis_findings USING btree (scan_id);


--
-- Name: ix_gas_analysis_findings_scanner_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_gas_analysis_findings_scanner_id ON public.gas_analysis_findings USING btree (scanner_id);


--
-- Name: ix_pattern_tool_mappings_detector_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_pattern_tool_mappings_detector_id ON public.pattern_tool_mappings USING btree (detector_id);


--
-- Name: ix_pattern_tool_mappings_is_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_pattern_tool_mappings_is_active ON public.pattern_tool_mappings USING btree (is_active);


--
-- Name: ix_pattern_tool_mappings_pattern_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_pattern_tool_mappings_pattern_id ON public.pattern_tool_mappings USING btree (pattern_id);


--
-- Name: ix_pattern_tool_mappings_scanner_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_pattern_tool_mappings_scanner_id ON public.pattern_tool_mappings USING btree (scanner_id);


--
-- Name: ix_project_contracts_added; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_project_contracts_added ON public.project_contracts USING btree (project_id);


--
-- Name: ix_projects_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_projects_created_at ON public.projects USING btree (created_at);


--
-- Name: ix_projects_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_projects_name ON public.projects USING btree (name);


--
-- Name: ix_projects_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_projects_user_id ON public.projects USING btree (user_id);


--
-- Name: ix_saved_searches_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_saved_searches_created_at ON public.saved_searches USING btree (created_at DESC);


--
-- Name: ix_saved_searches_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_saved_searches_user_id ON public.saved_searches USING btree (user_id);


--
-- Name: ix_scans_contract_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_scans_contract_id ON public.scans USING btree (contract_id);


--
-- Name: ix_scans_failed; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_scans_failed ON public.scans USING btree (user_id, created_at DESC) WHERE (status = 'failed'::public.scan_status);


--
-- Name: ix_scans_scanners_used; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_scans_scanners_used ON public.scans USING gin (scanners_used);


--
-- Name: ix_scans_user_completed; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_scans_user_completed ON public.scans USING btree (user_id, completed_at DESC) WHERE (status = 'completed'::public.scan_status);


--
-- Name: ix_scans_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_scans_user_id ON public.scans USING btree (user_id);


--
-- Name: ix_scans_user_status_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_scans_user_status_created ON public.scans USING btree (user_id, status);


--
-- Name: ix_sessions_refresh_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ix_sessions_refresh_token ON public.sessions USING btree (refresh_token);


--
-- Name: ix_sessions_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ix_sessions_token ON public.sessions USING btree (token);


--
-- Name: ix_sessions_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_sessions_user_id ON public.sessions USING btree (user_id);


--
-- Name: ix_users_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ix_users_email ON public.users USING btree (email);


--
-- Name: ix_vuln_classifications_classification; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vuln_classifications_classification ON public.vulnerability_classifications USING btree (classification);


--
-- Name: ix_vuln_classifications_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vuln_classifications_created_at ON public.vulnerability_classifications USING btree (created_at);


--
-- Name: ix_vuln_classifications_fix_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vuln_classifications_fix_status ON public.vulnerability_classifications USING btree (fix_status);


--
-- Name: ix_vuln_classifications_is_latest; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vuln_classifications_is_latest ON public.vulnerability_classifications USING btree (is_latest);


--
-- Name: ix_vuln_classifications_latest_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vuln_classifications_latest_lookup ON public.vulnerability_classifications USING btree (vulnerability_id, is_latest, created_at);


--
-- Name: ix_vuln_classifications_tags; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vuln_classifications_tags ON public.vulnerability_classifications USING gin (tags);


--
-- Name: ix_vuln_classifications_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vuln_classifications_user_id ON public.vulnerability_classifications USING btree (user_id);


--
-- Name: ix_vuln_classifications_vuln_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vuln_classifications_vuln_id ON public.vulnerability_classifications USING btree (vulnerability_id);


--
-- Name: ix_vuln_patterns_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vuln_patterns_category ON public.vulnerability_patterns USING btree (category);


--
-- Name: ix_vuln_patterns_cwe_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vuln_patterns_cwe_id ON public.vulnerability_patterns USING btree (cwe_id);


--
-- Name: ix_vuln_patterns_is_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vuln_patterns_is_active ON public.vulnerability_patterns USING btree (is_active);


--
-- Name: ix_vuln_patterns_keywords; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vuln_patterns_keywords ON public.vulnerability_patterns USING gin (keywords);


--
-- Name: ix_vuln_patterns_languages; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vuln_patterns_languages ON public.vulnerability_patterns USING gin (affected_languages);


--
-- Name: ix_vuln_patterns_severity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vuln_patterns_severity ON public.vulnerability_patterns USING btree (severity);


--
-- Name: ix_vuln_patterns_swc_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vuln_patterns_swc_id ON public.vulnerability_patterns USING btree (swc_id);


--
-- Name: ix_vuln_trends_contract_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vuln_trends_contract_id ON public.vulnerability_trends USING btree (contract_id);


--
-- Name: ix_vuln_trends_contract_time_series; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vuln_trends_contract_time_series ON public.vulnerability_trends USING btree (contract_id, period_type, period_start);


--
-- Name: ix_vuln_trends_pattern_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vuln_trends_pattern_id ON public.vulnerability_trends USING btree (pattern_id);


--
-- Name: ix_vuln_trends_pattern_time_series; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vuln_trends_pattern_time_series ON public.vulnerability_trends USING btree (pattern_id, period_type, period_start);


--
-- Name: ix_vuln_trends_period_end; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vuln_trends_period_end ON public.vulnerability_trends USING btree (period_end);


--
-- Name: ix_vuln_trends_period_start; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vuln_trends_period_start ON public.vulnerability_trends USING btree (period_start);


--
-- Name: ix_vuln_trends_period_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vuln_trends_period_type ON public.vulnerability_trends USING btree (period_type);


--
-- Name: ix_vuln_trends_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vuln_trends_user_id ON public.vulnerability_trends USING btree (user_id);


--
-- Name: ix_vuln_trends_user_time_series; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vuln_trends_user_time_series ON public.vulnerability_trends USING btree (user_id, period_type, period_start);


--
-- Name: ix_vulnerabilities_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vulnerabilities_category ON public.vulnerabilities USING btree (category);


--
-- Name: ix_vulnerabilities_contract_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vulnerabilities_contract_id ON public.vulnerabilities USING btree (contract_id);


--
-- Name: ix_vulnerabilities_contract_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vulnerabilities_contract_name ON public.vulnerabilities USING btree (contract_name);


--
-- Name: ix_vulnerabilities_dedup_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vulnerabilities_dedup_group_id ON public.vulnerabilities USING btree (deduplication_group_id);


--
-- Name: ix_vulnerabilities_dedup_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vulnerabilities_dedup_lookup ON public.vulnerabilities USING btree (fingerprint_code, fingerprint_ast, contract_id);


--
-- Name: ix_vulnerabilities_detector_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vulnerabilities_detector_id ON public.vulnerabilities USING btree (detector_id);


--
-- Name: ix_vulnerabilities_false_positive_score; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vulnerabilities_false_positive_score ON public.vulnerabilities USING btree (false_positive_score);


--
-- Name: ix_vulnerabilities_file_path; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vulnerabilities_file_path ON public.vulnerabilities USING btree (file_path);


--
-- Name: ix_vulnerabilities_fingerprint_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vulnerabilities_fingerprint_code ON public.vulnerabilities USING btree (fingerprint_code);


--
-- Name: ix_vulnerabilities_fingerprint_composite; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vulnerabilities_fingerprint_composite ON public.vulnerabilities USING btree (fingerprint_composite);


--
-- Name: ix_vulnerabilities_fingerprint_location_fuzzy; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vulnerabilities_fingerprint_location_fuzzy ON public.vulnerabilities USING btree (fingerprint_location_fuzzy);


--
-- Name: ix_vulnerabilities_first_seen; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vulnerabilities_first_seen ON public.vulnerabilities USING btree (first_seen);


--
-- Name: ix_vulnerabilities_function_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vulnerabilities_function_name ON public.vulnerabilities USING btree (function_name);


--
-- Name: ix_vulnerabilities_fuzzy_dedup_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vulnerabilities_fuzzy_dedup_lookup ON public.vulnerabilities USING btree (fingerprint_location_fuzzy, fingerprint_code, contract_id);


--
-- Name: ix_vulnerabilities_historical_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vulnerabilities_historical_lookup ON public.vulnerabilities USING btree (pattern_id, contract_id, first_seen);


--
-- Name: ix_vulnerabilities_is_primary; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vulnerabilities_is_primary ON public.vulnerabilities USING btree (is_primary);


--
-- Name: ix_vulnerabilities_last_seen; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vulnerabilities_last_seen ON public.vulnerabilities USING btree (last_seen);


--
-- Name: ix_vulnerabilities_location_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vulnerabilities_location_lookup ON public.vulnerabilities USING btree (contract_name, file_path, function_name);


--
-- Name: ix_vulnerabilities_open; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vulnerabilities_open ON public.vulnerabilities USING btree (contract_id, severity) WHERE (status = 'open'::public.vulnerability_status);


--
-- Name: ix_vulnerabilities_pattern_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vulnerabilities_pattern_code ON public.vulnerabilities USING btree (pattern_code);


--
-- Name: ix_vulnerabilities_pattern_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vulnerabilities_pattern_id ON public.vulnerabilities USING btree (pattern_id);


--
-- Name: ix_vulnerabilities_scan_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vulnerabilities_scan_id ON public.vulnerabilities USING btree (scan_id);


--
-- Name: ix_vulnerabilities_scan_severity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vulnerabilities_scan_severity ON public.vulnerabilities USING btree (scan_id, severity);


--
-- Name: ix_vulnerabilities_scanner_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vulnerabilities_scanner_id ON public.vulnerabilities USING btree (scanner_id);


--
-- Name: ix_vulnerabilities_severity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vulnerabilities_severity ON public.vulnerabilities USING btree (severity);


--
-- Name: ix_vulnerabilities_user_classification; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vulnerabilities_user_classification ON public.vulnerabilities USING btree (user_classification);


--
-- Name: ix_vulns_contract_severity_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_vulns_contract_severity_status ON public.vulnerabilities USING btree (contract_id, severity, status);


--
-- Name: deduplication_group_members trigger_update_dedup_group_stats; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_dedup_group_stats AFTER INSERT OR DELETE OR UPDATE ON public.deduplication_group_members FOR EACH ROW EXECUTE FUNCTION public.update_deduplication_group_stats();


--
-- Name: deduplication_groups trigger_update_dedup_group_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trigger_update_dedup_group_updated_at BEFORE UPDATE ON public.deduplication_groups FOR EACH ROW EXECUTE FUNCTION public.update_deduplication_group_updated_at();


--
-- Name: code_quality_findings code_quality_findings_scan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.code_quality_findings
    ADD CONSTRAINT code_quality_findings_scan_id_fkey FOREIGN KEY (scan_id) REFERENCES public.scans(id) ON DELETE CASCADE;


--
-- Name: contract_files contract_files_contract_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_files
    ADD CONSTRAINT contract_files_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES public.contracts(id) ON DELETE CASCADE;


--
-- Name: contracts contracts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contracts
    ADD CONSTRAINT contracts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: deduplication_group_members deduplication_group_members_finding_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deduplication_group_members
    ADD CONSTRAINT deduplication_group_members_finding_id_fkey FOREIGN KEY (finding_id) REFERENCES public.vulnerabilities(id) ON DELETE CASCADE;


--
-- Name: deduplication_group_members deduplication_group_members_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deduplication_group_members
    ADD CONSTRAINT deduplication_group_members_group_id_fkey FOREIGN KEY (group_id) REFERENCES public.deduplication_groups(id) ON DELETE CASCADE;


--
-- Name: deduplication_groups deduplication_groups_contract_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deduplication_groups
    ADD CONSTRAINT deduplication_groups_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES public.contracts(id) ON DELETE CASCADE;


--
-- Name: deduplication_groups deduplication_groups_pattern_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deduplication_groups
    ADD CONSTRAINT deduplication_groups_pattern_id_fkey FOREIGN KEY (pattern_code) REFERENCES public.vulnerability_patterns(id) ON DELETE SET NULL;


--
-- Name: deduplication_groups deduplication_groups_primary_vulnerability_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deduplication_groups
    ADD CONSTRAINT deduplication_groups_primary_vulnerability_id_fkey FOREIGN KEY (canonical_finding_id) REFERENCES public.vulnerabilities(id) ON DELETE CASCADE;


--
-- Name: deduplication_groups deduplication_groups_verified_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deduplication_groups
    ADD CONSTRAINT deduplication_groups_verified_by_fkey FOREIGN KEY (verified_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: vulnerabilities fk_vulnerabilities_dedup_group_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vulnerabilities
    ADD CONSTRAINT fk_vulnerabilities_dedup_group_id FOREIGN KEY (deduplication_group_id) REFERENCES public.deduplication_groups(id) ON DELETE SET NULL;


--
-- Name: vulnerabilities fk_vulnerabilities_pattern_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vulnerabilities
    ADD CONSTRAINT fk_vulnerabilities_pattern_id FOREIGN KEY (pattern_id) REFERENCES public.vulnerability_patterns(id) ON DELETE SET NULL;


--
-- Name: formal_verification_results formal_verification_results_scan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.formal_verification_results
    ADD CONSTRAINT formal_verification_results_scan_id_fkey FOREIGN KEY (scan_id) REFERENCES public.scans(id) ON DELETE CASCADE;


--
-- Name: fuzzing_results fuzzing_results_scan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fuzzing_results
    ADD CONSTRAINT fuzzing_results_scan_id_fkey FOREIGN KEY (scan_id) REFERENCES public.scans(id) ON DELETE CASCADE;


--
-- Name: gas_analysis_findings gas_analysis_findings_scan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gas_analysis_findings
    ADD CONSTRAINT gas_analysis_findings_scan_id_fkey FOREIGN KEY (scan_id) REFERENCES public.scans(id) ON DELETE CASCADE;


--
-- Name: pattern_tool_mappings pattern_tool_mappings_pattern_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pattern_tool_mappings
    ADD CONSTRAINT pattern_tool_mappings_pattern_id_fkey FOREIGN KEY (pattern_id) REFERENCES public.vulnerability_patterns(id) ON DELETE CASCADE;


--
-- Name: project_contracts project_contracts_contract_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_contracts
    ADD CONSTRAINT project_contracts_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES public.contracts(id) ON DELETE CASCADE;


--
-- Name: project_contracts project_contracts_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_contracts
    ADD CONSTRAINT project_contracts_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: projects projects_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: saved_searches saved_searches_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_searches
    ADD CONSTRAINT saved_searches_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: scanner_release_tracking scanner_release_tracking_scanner_name_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scanner_release_tracking
    ADD CONSTRAINT scanner_release_tracking_scanner_name_fkey FOREIGN KEY (scanner_name) REFERENCES public.scanner_versions(scanner_name) ON DELETE CASCADE;


--
-- Name: scanner_version_history scanner_version_history_scanner_name_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scanner_version_history
    ADD CONSTRAINT scanner_version_history_scanner_name_fkey FOREIGN KEY (scanner_name) REFERENCES public.scanner_versions(scanner_name) ON DELETE CASCADE;


--
-- Name: scans scans_contract_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scans
    ADD CONSTRAINT scans_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES public.contracts(id);


--
-- Name: scans scans_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scans
    ADD CONSTRAINT scans_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: user_preferences user_preferences_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_preferences
    ADD CONSTRAINT user_preferences_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: vulnerabilities vulnerabilities_contract_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vulnerabilities
    ADD CONSTRAINT vulnerabilities_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES public.contracts(id);


--
-- Name: vulnerabilities vulnerabilities_scan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vulnerabilities
    ADD CONSTRAINT vulnerabilities_scan_id_fkey FOREIGN KEY (scan_id) REFERENCES public.scans(id);


--
-- Name: vulnerability_classifications vulnerability_classifications_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vulnerability_classifications
    ADD CONSTRAINT vulnerability_classifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: vulnerability_classifications vulnerability_classifications_vulnerability_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vulnerability_classifications
    ADD CONSTRAINT vulnerability_classifications_vulnerability_id_fkey FOREIGN KEY (vulnerability_id) REFERENCES public.vulnerabilities(id) ON DELETE CASCADE;


--
-- Name: vulnerability_trends vulnerability_trends_contract_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vulnerability_trends
    ADD CONSTRAINT vulnerability_trends_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES public.contracts(id) ON DELETE CASCADE;


--
-- Name: vulnerability_trends vulnerability_trends_pattern_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vulnerability_trends
    ADD CONSTRAINT vulnerability_trends_pattern_id_fkey FOREIGN KEY (pattern_id) REFERENCES public.vulnerability_patterns(id) ON DELETE CASCADE;


--
-- Name: vulnerability_trends vulnerability_trends_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vulnerability_trends
    ADD CONSTRAINT vulnerability_trends_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

