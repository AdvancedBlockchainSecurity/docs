# File Upload Tests

**Priority**: P0 - Critical
**Last Tested**: _Not yet tested_
**Endpoint**: `POST /api/v1/upload`

---

## 1. Single File Upload

### 1.1 Solidity (.sol)
- [ ] Upload .sol file succeeds
- [ ] Language detected as "solidity"
- [ ] Compiler version detected from pragma
- [ ] Lines of code counted correctly
- [ ] Contract record created in database

### 1.2 Vyper (.vy)
- [ ] Upload .vy file succeeds
- [ ] Language detected as "vyper"
- [ ] Compiler version detected

### 1.3 Rust/Solana (.rs)
- [ ] Upload .rs file succeeds
- [ ] Language detected as "rust"
- [ ] Solana-specific detection works

### 1.4 Cairo (.cairo)
- [ ] Upload .cairo file succeeds
- [ ] Language detected as "cairo"

### 1.5 Invalid Files
- [ ] .js file rejected with 400 error
- [ ] .py file rejected with 400 error
- [ ] .txt file rejected with 400 error
- [ ] Error message lists supported extensions

---

## 2. Archive Upload

### 2.1 ZIP Archives
- [ ] Upload .zip archive succeeds
- [ ] All .sol files extracted
- [ ] Config files extracted (foundry.toml, package.json)
- [ ] Hidden files (.git, .env) excluded
- [ ] Build directories excluded (out/, artifacts/)

### 2.2 TAR Archives
- [ ] Upload .tar archive succeeds
- [ ] Upload .tar.gz archive succeeds
- [ ] Upload .tgz archive succeeds
- [ ] Files extracted correctly

### 2.3 Archive Validation
- [ ] Empty archive rejected
- [ ] Corrupted archive shows error
- [ ] Archive with no .sol files (only config) handled
- [ ] Nested directories extracted correctly

### 2.4 Main File Detection
- [ ] Main file detected in contracts/ directory
- [ ] Main file detected by name (Token.sol, Main.sol)
- [ ] Main file path stored in contract record

---

## 3. Multi-File Contracts

- [ ] is_multi_file = true for archives
- [ ] file_count matches extracted files
- [ ] total_lines_of_code calculated across all files
- [ ] Each file stored in contract_files table
- [ ] is_main_file flag set correctly

---

## 4. Upload Response Validation

### 4.1 Required Fields
- [ ] contract_id (UUID) returned
- [ ] filename matches uploaded file
- [ ] status = "success"
- [ ] message contains file count and LOC

### 4.2 Multi-File Fields
- [ ] is_multi_file = true for archives
- [ ] file_count > 1 for archives
- [ ] files[] array populated with FileInfo
- [ ] main_file_path set

### 4.3 Framework Fields (Phase 3.2)
- [ ] framework field populated ("foundry", "hardhat", "plain")
- [ ] framework_config contains parsed config
- [ ] Message includes framework type for non-plain

---

## 5. Contract Name Handling

- [ ] Custom contract_name used when provided
- [ ] Filename stem used when name not provided
- [ ] Special characters handled in name

---

## 6. Network Parameter

- [ ] Default network is "ethereum"
- [ ] Custom network value accepted
- [ ] Network stored in contract record

---

## 7. File Content Handling

- [ ] UTF-8 encoded files read correctly
- [ ] Non-UTF-8 files show appropriate error
- [ ] Large files handled without timeout
- [ ] Binary files rejected

---

## Test Files

Create these test files for upload testing:

```solidity
// simple.sol
pragma solidity ^0.8.20;
contract Simple {
    uint256 public value;
}
```

```
// test.zip structure
contracts/
  Token.sol
  Vault.sol
package.json
README.md
```

---

## Test Notes

_Record upload test results here:_

```
[Date] | [File Type] | [Result] | [Notes]
```
