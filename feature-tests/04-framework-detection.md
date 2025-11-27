# Framework Detection Tests

**Priority**: P1 - High
**Last Tested**: _Not yet tested_
**Related**: Phase 3.2 Project Structure Support

---

## 1. Framework Detection

### 1.1 Foundry Detection
- [ ] Project with foundry.toml detected as "foundry"
- [ ] foundry.toml parsed correctly
- [ ] Solidity version extracted from config
- [ ] src_dir detected (default: "src")
- [ ] libs detected (default: ["lib"])

### 1.2 Hardhat Detection
- [ ] Project with hardhat.config.js detected as "hardhat"
- [ ] Project with hardhat.config.ts detected as "hardhat"
- [ ] Solidity version extracted from config
- [ ] sources_path detected (default: "./contracts")
- [ ] package.json dependencies parsed

### 1.3 Plain Detection
- [ ] Project without framework files detected as "plain"
- [ ] No framework_config stored for plain projects
- [ ] Plain projects still upload successfully

### 1.4 Mixed Detection
- [ ] Project with both foundry.toml and hardhat.config.js → Foundry wins
- [ ] Detection priority: Foundry > Hardhat > Plain

---

## 2. Foundry Config Parsing

### 2.1 foundry.toml Fields
- [ ] solc_version parsed (solc = "0.8.20")
- [ ] src parsed (src = "src")
- [ ] test parsed (test = "test")
- [ ] out parsed (out = "out")
- [ ] libs parsed (libs = ["lib"])
- [ ] optimizer parsed (optimizer = true)
- [ ] optimizer_runs parsed (optimizer_runs = 200)
- [ ] via_ir parsed
- [ ] evm_version parsed

### 2.2 remappings.txt Parsing
- [ ] Remappings loaded from remappings.txt
- [ ] Remappings from foundry.toml [profile.default.remappings]
- [ ] Multiple remappings parsed correctly

### 2.3 Framework Config Storage
- [ ] Config stored as JSONB in database
- [ ] Config retrievable via API
- [ ] Config includes all parsed fields

---

## 3. Hardhat Config Parsing

### 3.1 hardhat.config.js Fields
- [ ] Solidity version parsed
- [ ] Sources path parsed
- [ ] Tests path parsed
- [ ] Optimizer settings parsed

### 3.2 package.json Parsing
- [ ] Dependencies extracted
- [ ] @openzeppelin/contracts version detected
- [ ] Other dependencies listed

---

## 4. Import Remapping

### 4.1 OpenZeppelin Imports
- [ ] `@openzeppelin/contracts/token/ERC20/ERC20.sol` resolves
- [ ] `@openzeppelin/contracts/access/Ownable.sol` resolves
- [ ] `@openzeppelin/contracts/utils/Context.sol` resolves
- [ ] Resolved path: `lib/openzeppelin-contracts/contracts/...`

### 4.2 forge-std Imports
- [ ] `forge-std/Test.sol` resolves
- [ ] `forge-std/console.sol` resolves
- [ ] Resolved path: `lib/forge-std/src/...`

### 4.3 Custom Remappings
- [ ] Custom remapping `ds-test/=lib/ds-test/src/` works
- [ ] Custom remapping `solmate/=lib/solmate/src/` works

### 4.4 Longest Prefix Matching
- [ ] `@openzeppelin/contracts/` matches before `@openzeppelin/`
- [ ] More specific remapping takes precedence

### 4.5 Relative Imports
- [ ] `./Token.sol` unchanged (not remapped)
- [ ] `../interfaces/IERC20.sol` unchanged
- [ ] Relative imports resolved from importing file's directory

---

## 5. Smart Dependency Extraction

### 5.1 Transitive Dependencies
- [ ] Direct imports extracted
- [ ] Imports of imports extracted (transitive)
- [ ] Deep dependency chains resolved
- [ ] All required files included

### 5.2 Circular Import Handling
- [ ] Circular imports detected
- [ ] No infinite loop occurs
- [ ] Both files in cycle included once

### 5.3 File Limit Enforcement
- [ ] Free tier stops at 25 files
- [ ] Pro tier stops at 100 files
- [ ] Enterprise has no limit
- [ ] Truncation logged when limit hit

### 5.4 Smart Filtering Results
- [ ] OpenZeppelin (200+ files) → ~10-15 files extracted
- [ ] Only imported files included
- [ ] lib/ files not blindly included
- [ ] User source files always included

---

## 6. OpenZeppelin Project Testing

### 6.1 ERC20 with OpenZeppelin
```solidity
// Test file: Token.sol
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract Token is ERC20 {
    constructor() ERC20("Test", "TST") {}
}
```
- [ ] Upload succeeds
- [ ] ERC20.sol extracted
- [ ] IERC20.sol extracted (dependency)
- [ ] IERC20Metadata.sol extracted
- [ ] Context.sol extracted
- [ ] Total files < 25 (free tier compatible)

### 6.2 ERC721 with OpenZeppelin
- [ ] ERC721 imports resolve
- [ ] All NFT dependencies extracted
- [ ] Free tier can upload

### 6.3 Access Control with OpenZeppelin
- [ ] Ownable.sol imports resolve
- [ ] AccessControl.sol imports resolve
- [ ] All dependencies extracted

---

## 7. Hardhat Project Testing

### 7.1 Basic Hardhat Project
- [ ] contracts/ directory recognized
- [ ] node_modules/ dependencies resolved
- [ ] package.json kept in extraction
- [ ] Framework detected correctly

### 7.2 Hardhat + OpenZeppelin
- [ ] node_modules/@openzeppelin/contracts/ resolved
- [ ] Imports from node_modules work
- [ ] Smart filtering applies to node_modules

---

## 8. Foundry Project Testing

### 8.1 Basic Foundry Project
- [ ] src/ directory recognized
- [ ] lib/ dependencies resolved
- [ ] foundry.toml parsed
- [ ] remappings.txt applied

### 8.2 Foundry with forge-std
- [ ] forge-std/Test.sol resolves
- [ ] forge-std/console.sol resolves
- [ ] Test files can import forge-std

---

## 9. Test Project Upload

### 9.1 Foundry Sample Project
- [ ] Upload foundry-sample.zip from test-projects directory
- [ ] Framework detected as "foundry"
- [ ] foundry.toml parsed correctly
- [ ] remappings.txt applied
- [ ] Token.sol identified as main file

### 9.2 Hardhat Sample Project
- [ ] Upload hardhat-sample.zip from test-projects directory
- [ ] Framework detected as "hardhat"
- [ ] hardhat.config.js parsed correctly
- [ ] package.json dependencies extracted
- [ ] Token.sol identified as main file

### 9.3 Contract URL Import
- [ ] Import from raw GitHub URL succeeds
- [ ] Import from Etherscan verified contract URL succeeds
- [ ] Invalid URL returns appropriate error
- [ ] Non-Solidity URL rejected

---

## Test Notes

_Record framework detection test results here:_

```
[Date] | [Framework] | [Test] | [Result] | [Notes]
```
