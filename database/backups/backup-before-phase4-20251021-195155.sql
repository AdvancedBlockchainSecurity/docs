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
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    is_project boolean DEFAULT false NOT NULL
);


ALTER TABLE public.contracts OWNER TO postgres;

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
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.gas_analysis_findings OWNER TO postgres;

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
    scanner_id character varying(50),
    category character varying(100),
    confidence numeric(3,2)
);


ALTER TABLE public.vulnerabilities OWNER TO postgres;

--
-- Name: COLUMN vulnerabilities.scanner_id; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.vulnerabilities.scanner_id IS 'Scanner tool that detected this vulnerability (e.g., slither, mythril, aderyn)';


--
-- Name: COLUMN vulnerabilities.category; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.vulnerabilities.category IS 'Vulnerability type category (e.g., reentrancy, access_control, arithmetic)';


--
-- Name: COLUMN vulnerabilities.confidence; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.vulnerabilities.confidence IS 'Scanner confidence score (0.0 to 1.0, where 1.0 is highest confidence)';


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
-- Name: ix_vulnerabilities_category; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vulnerabilities_category ON public.vulnerabilities USING btree (category);


--
-- Name: ix_vulnerabilities_contract_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vulnerabilities_contract_id ON public.vulnerabilities USING btree (contract_id);


--
-- Name: ix_vulnerabilities_open; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vulnerabilities_open ON public.vulnerabilities USING btree (contract_id, severity) WHERE (status = 'open'::public.vulnerability_status);


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
-- Name: ix_vulns_contract_severity_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_vulns_contract_severity_status ON public.vulnerabilities USING btree (contract_id, severity, status);


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
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: pg_database_owner
--

GRANT ALL ON SCHEMA public TO blocksecops;


--
-- Name: TABLE alembic_version; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.alembic_version TO blocksecops;


--
-- Name: TABLE code_quality_findings; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.code_quality_findings TO blocksecops;


--
-- Name: TABLE contract_files; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.contract_files TO blocksecops;


--
-- Name: TABLE contracts; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.contracts TO blocksecops;


--
-- Name: TABLE formal_verification_results; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.formal_verification_results TO blocksecops;


--
-- Name: TABLE fuzzing_results; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.fuzzing_results TO blocksecops;


--
-- Name: TABLE gas_analysis_findings; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.gas_analysis_findings TO blocksecops;


--
-- Name: TABLE project_contracts; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.project_contracts TO blocksecops;


--
-- Name: TABLE projects; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.projects TO blocksecops;


--
-- Name: TABLE saved_searches; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.saved_searches TO blocksecops;


--
-- Name: TABLE scans; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.scans TO blocksecops;


--
-- Name: TABLE sessions; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.sessions TO blocksecops;


--
-- Name: TABLE user_preferences; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.user_preferences TO blocksecops;


--
-- Name: TABLE users; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.users TO blocksecops;


--
-- Name: TABLE vulnerabilities; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vulnerabilities TO blocksecops;


--
-- PostgreSQL database dump complete
--

