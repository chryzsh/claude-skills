---
name: oc2-bof-script-generator
description: Generate Python scripts for OC2 (Operator Console 2) that expose BOF (Beacon Object File) functionality to the C2 agent. This skill should be used when converting Cobalt Strike .cna Aggressor scripts to OC2 .s1.py Python format, creating BOF interface scripts for OC2, or adapting existing BOF projects for OC2 compatibility. Handles both single-BOF and multi-BOF projects.
---

# OC2 BOF Script Generator

## Overview

Generate Python scripts (`.s1.py` files) for OC2 that expose BOF functionality. These scripts are the OC2 equivalent of Aggressor scripts (`.cna` files) in Cobalt Strike, providing the interface between the C2 operator and the compiled BOF.

**Key capabilities:**
- Convert .cna Aggressor scripts to OC2 Python format
- Generate properly formatted argument encoding for BOF execution
- Handle single-BOF and multi-BOF projects
- Preserve all validation logic and command options

## Workflow

Follow this workflow when generating OC2 BOF scripts:

### Step 1: Gather Project Information

**Required information:**
- BOF project name (e.g., "cookie-monster", "SQL-BOF")
- Location of BOF project files (GitHub URL or local path)

**If project is on GitHub and not local:**
- Ask the user for the repository URL
- Offer to clone it to a temporary location for analysis

**Expected project structure:**
```
project-name/
├── *.c (BOF source code)
├── *.h (headers)
├── *.cna (Aggressor script - REQUIRED)
├── dist/ or bin/ (compiled BOFs)
└── README.md
```

### Step 2: Analyze Reference Scripts

Before generating new scripts, read 2-3 existing OC2 scripts from the reference directory to understand current patterns:

```bash
~/share/scripts/oc2-scripts/python-scripts-bof/
```

**Look for:**
- Similar BOFs with comparable argument structures
- Multi-BOF vs single-BOF patterns (check SQL-BOF for multi-BOF example)
- Recent validation patterns and conventions

### Step 3: Parse the .cna File

**Locate the .cna file** in the BOF project directory.

**Extract key information:**

1. **Command name(s):** From `beacon_command_register()` and `alias` definitions
2. **Description:** From `beacon_command_register()` second parameter
3. **Usage examples:** From `beacon_command_register()` third parameter
4. **Argument packing:** Find the `bof_pack()` call - this is critical
5. **Validation logic:** Identify all `berror()` checks and conditionals

**Critical line to find:**
```javascript
$args = bof_pack($bid, "format_string", $arg1, $arg2, ...);
```

The format string defines argument types and order. Document it as a comment in the Python script:
```python
# BOF expects: iiziZZ
```

**Format string mapping:**
- `i` → `BOFArgumentEncoding.INT`
- `z` → `BOFArgumentEncoding.STR` (narrow string)
- `Z` → `BOFArgumentEncoding.WSTR` (wide string)
- `b` → `BOFArgumentEncoding.BUFFER` (binary data)

### Step 4: Analyze BOF Source Code

**Read the BOF's main .c file** to understand:

1. **The `go()` function signature:** Verify expected arguments
2. **Argument parsing:** How the BOF uses `BeaconDataParse()` and related functions
3. **Functionality:** What the BOF actually does (for accurate descriptions)
4. **OPSEC considerations:** Note any warnings or important behavior

**Cross-reference** the source code's argument parsing with the .cna file's `bof_pack()` call to ensure accuracy.

### Step 5: Generate Python Script Structure

**Determine project type:**

- **Single-BOF:** One command → One class
- **Multi-BOF:** Multiple commands → Multiple classes in one file

**Class naming:**
- Single: `<ProjectName>BOF` (e.g., `CookieMonsterBOF`)
- Multi: `<Command><Project>BOF` (e.g., `SqlWhoamiBOF`, `SqlInfoBOF`)

**File naming convention:**
```
~/share/scripts/oc2-scripts/python-scripts-bof/<project-name>/<project-name>_bof.s1.py
```

**IMPORTANT:** The file MUST be named with `_bof` suffix (e.g., `cookie-monster_bof.s1.py`, `SQL_bof.s1.py`). Without the `_bof` suffix, OC2 will not recognize the script.

### Step 6: Implement Core Components

#### 6.1 Class Initialization

```python
class CommandNameBOF(BaseBOFTask):
    def __init__(self):
        super().__init__(
            "command-name",                    # OC2 command name
            base_binary_name="bof-filename"   # BOF file without .o extension
        )

        self.parser.description = "..."
```

**For multi-BOF projects**, add `base_binary_path`:
```python
super().__init__(
    "sql-whoami",
    base_binary_name="whoami",
    base_binary_path="whoami"  # subdirectory containing the BOF
)
```

#### 6.2 Argument Parser Configuration

Add all arguments from the .cna file:

```python
# Positional arguments
self.parser.add_argument("server", help="SQL Server hostname or IP")
self.parser.add_argument("query", help="SQL query to execute")

# Optional arguments
self.parser.add_argument("--database", "-d", default="", help="Database name")

# Flags
self.parser.add_argument("--verbose", action="store_true", help="Enable verbose output")

# Mutually exclusive groups
mode_group = self.parser.add_mutually_exclusive_group(required=True)
mode_group.add_argument("--chrome", action="store_true", help="Target Chrome")
mode_group.add_argument("--edge", action="store_true", help="Target Edge")
```

#### 6.3 Epilog with Examples

Copy and adapt examples from the .cna file:

```python
self.parser.epilog = (
    "Example usage:\n"
    "  command-name arg1 arg2\n"
    "  command-name arg1 --optional value\n\n"
    "Notes:\n"
    "  - Important consideration 1\n"
    "  - Important consideration 2\n"
)
```

**For OC2-specific notes**, add warnings about file downloads:
```python
"OC2 Users:\n"
"  OC2 does not support automatic file downloads like Cobalt Strike.\n"
"  Use --copy-file <path> to save files to disk on the target system.\n"
```

#### 6.4 Argument Encoding (MOST CRITICAL)

Implement `_encode_arguments_bof()` to match the .cna file's `bof_pack()` call exactly:

```python
def _encode_arguments_bof(self, arguments: List[str]) -> List[Tuple[BOFArgumentEncoding, str]]:
    parser_arguments = self.parser.parse_args(arguments)

    # BOF expects: <format string from .cna>
    # Example: iiiiiiiiiziiiz
    return [
        (BOFArgumentEncoding.INT, 1 if parser_arguments.flag1 else 0),
        (BOFArgumentEncoding.INT, parser_arguments.numeric_value),
        (BOFArgumentEncoding.STR, parser_arguments.string_value),
        (BOFArgumentEncoding.WSTR, parser_arguments.wide_string),
        # ... in exact order from bof_pack()
    ]
```

**Critical rules:**
1. Arguments must be in the exact order from `bof_pack()`
2. Boolean flags → convert to integers (0 or 1)
3. Optional strings → use empty string `""` as default
4. Include the format string as a comment for reference

#### 6.5 Validation Logic (Optional but Recommended)

Port all validation from the .cna file:

```python
def validate_arguments(self, arguments: List[str]):
    super().validate_arguments(arguments)

    parser_arguments = self.parser.parse_args(arguments)

    # Port validation from .cna berror() checks
    if parser_arguments.keyOnly and parser_arguments.cookieOnly:
        raise TaskInvalidArgumentsException(
            "--key-only cannot be used with --cookie-only"
        )

    if parser_arguments.pid and parser_arguments.pid <= 0:
        raise TaskInvalidArgumentsException(
            f"Invalid PID: {parser_arguments.pid}"
        )
```

#### 6.6 Custom Run Logic (Optional)

Add warnings or pre-execution messages:

```python
def run(self, arguments: List[str]):
    parser_arguments = self.parser.parse_args(arguments)

    if not parser_arguments.copy_file:
        self.append_response(
            "[!] WARNING: Files will not be saved automatically in OC2.\n"
            "[!] Use --copy-file <path> to save to disk.\n\n"
        )

    super().run(arguments)
```

### Step 7: Handle Special Cases

#### File Upload Support

For BOFs that need file uploads (like enumshares with hostnames file):

```python
def validate_files(self, arguments: List[str]):
    file = self.get_file_by_name("file_name")
    if file is None:
        raise TaskInvalidArgumentsException("No file uploaded")

def get_gui_elements(self) -> Optional[Dict]:
    return {
        "title": "Command Title",
        "desc": "Description",
        "elements": [
            {
                "name": "file_name",
                "type": "file",
                "description": "File with data",
                "placeholder": "Select file",
            },
        ],
    }

def _encode_arguments_bof(self, arguments: List[str]) -> List[Tuple[BOFArgumentEncoding, str]]:
    file = self.get_file_by_name("file_name")
    file_content = file.content

    # Ensure newline at end if required
    if not file_content.endswith(b'\n'):
        file_content += b'\n'

    return [(BOFArgumentEncoding.BUFFER, file_content)]
```

#### Binary File Arguments

For BOFs that take DLL/binary files:

```python
import os
import hashlib

def _encode_arguments_bof(self, arguments: List[str]) -> List[Tuple[BOFArgumentEncoding, str]]:
    parser_arguments = self.parser.parse_args(arguments)

    if not os.path.exists(parser_arguments.dll_path):
        raise FileNotFoundError(f"File not found: {parser_arguments.dll_path}")

    with open(parser_arguments.dll_path, 'rb') as f:
        dll_bytes = f.read()

    # Calculate hash if needed
    sha512_hash = hashlib.sha512(dll_bytes).hexdigest().upper()

    return [
        # ... other arguments
        (BOFArgumentEncoding.STR, sha512_hash),
        (BOFArgumentEncoding.BIN, dll_bytes)
    ]
```

### Step 8: Review and Test

**Review checklist:**

- [ ] All commands from .cna file have corresponding Python classes
- [ ] `bof_pack()` format string matches Python encoding exactly
- [ ] Argument order is identical to .cna file
- [ ] All validation logic ported
- [ ] Examples in epilog are accurate
- [ ] OC2-specific warnings added where relevant
- [ ] File paths and binary names are correct

**Testing approach:**

1. **Syntax check:** Ensure Python file has no syntax errors
2. **Import test:** Verify the class can be imported in OC2
3. **Argument parsing:** Test with various argument combinations
4. **Integration test:** Load in OC2 and execute against a test target (if possible)

### Step 9: Update Documentation

After generating the script, inform the user about the README file:

**README location:**
```
~/share/scripts/oc2-scripts/python-scripts-bof/README.md
```

The README contains tables documenting all implemented BOF scripts. Suggest adding an entry for the newly created script.

### Step 10: Output Location

**Save the generated script to:**
```
~/share/scripts/oc2-scripts/python-scripts-bof/<project-name>/<project-name>_bof.s1.py
```

**CRITICAL:** The file MUST include the `_bof` suffix before `.s1.py` or OC2 will not load it.

**Do NOT save to the BOF project directory.**

## Reference Materials

This skill includes reference documentation:

### `references/python_script_patterns.md`

Complete reference for OC2 Python script structure:
- Standard imports and class structure
- Parser configuration patterns
- Argument encoding examples
- Multi-BOF project patterns
- Common validation patterns
- Naming conventions

**When to read:** Before generating any script, and when encountering unusual argument patterns.

### `references/cna_file_structure.md`

Guide to parsing Aggressor scripts:
- Command registration and alias structure
- How to find and interpret `bof_pack()` calls
- Format string character meanings
- Argument parsing patterns
- Validation logic extraction

**When to read:** When analyzing a .cna file to extract BOF interface details.

## Common Pitfalls

1. **Argument order mismatch:** Always match the exact order from `bof_pack()`
2. **Type mismatches:** `i` vs `z` vs `Z` - get the format string right
3. **Missing validation:** Port all `berror()` checks from .cna
4. **Incorrect binary name:** Verify `base_binary_name` matches actual BOF filename
5. **Forgetting default values:** Use same defaults as .cna (often `""` or `0`)
6. **Multi-BOF path errors:** Set `base_binary_path` for projects with subdirectories

## Example Commands That Should Trigger This Skill

- "Generate an OC2 script for the cookie-monster BOF"
- "Convert this .cna file to OC2 Python format"
- "Create a .s1.py file for this BOF project"
- "I need an OC2 interface for the TappingAtTheWindow BOF"
- "Help me port this Aggressor script to OC2"
