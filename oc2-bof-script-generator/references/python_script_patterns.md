# OC2 BOF Python Script Patterns

This reference documents the standard structure and patterns for OC2 BOF Python scripts (`.s1.py` files).

## Standard Structure

### 1. Imports

```python
from typing import List, Tuple, Optional, Dict

from outflank_stage1.task.base_bof_task import BaseBOFTask
from outflank_stage1.task.enums import BOFArgumentEncoding
from outflank_stage1.task.exceptions import TaskInvalidArgumentsException
```

### 2. Class Definition

```python
class <CommandName>BOF(BaseBOFTask):
    def __init__(self):
        super().__init__("command-name", base_binary_name="bof-filename")
```

**Parameters for `super().__init__()`:**
- First argument: command name as it appears in OC2 (kebab-case)
- `base_binary_name`: BOF filename without extension (optional, defaults to command name)
- `base_binary_path`: subdirectory path for multi-BOF projects (optional)

### 3. Parser Configuration

```python
self.parser.description = "Brief command description"

# Add arguments
self.parser.add_argument("positional_arg", help="Argument description")
self.parser.add_argument("--optional", "-o", default="", help="Optional argument")
self.parser.add_argument("--flag", action="store_true", help="Boolean flag")

# Add epilog with examples
self.parser.epilog = (
    "Example usage:\n"
    "  command-name arg1 arg2\n"
    "  command-name arg1 --optional value\n"
)
```

### 4. Argument Encoding Method (Required)

```python
def _encode_arguments_bof(self, arguments: List[str]) -> List[Tuple[BOFArgumentEncoding, str]]:
    parser_arguments = self.parser.parse_args(arguments)

    # BOF expects: <format string from .cna file>
    return [
        (BOFArgumentEncoding.INT, int_value),
        (BOFArgumentEncoding.STR, string_value),
        (BOFArgumentEncoding.WSTR, wide_string_value),
        # ...
    ]
```

**CRITICAL:** Arguments must be returned in the exact order the BOF expects them.

### 5. Optional: Custom Validation

```python
def validate_arguments(self, arguments: List[str]):
    super().validate_arguments(arguments)

    parser_arguments = self.parser.parse_args(arguments)

    # Custom validation logic
    if parser_arguments.value <= 0:
        raise TaskInvalidArgumentsException("Value must be positive")
```

### 6. Optional: File Upload Support

```python
def validate_files(self, arguments: List[str]):
    file = self.get_file_by_name("file_name")
    if file is None:
        raise TaskInvalidArgumentsException("No file uploaded")

def get_gui_elements(self) -> Optional[Dict]:
    return {
        "title": "Command Title",
        "desc": "Command description",
        "elements": [
            {
                "name": "file_name",
                "type": "file",
                "description": "File description",
                "placeholder": "Select file",
            },
        ],
    }
```

### 7. Optional: Custom Run Logic

```python
def run(self, arguments: List[str]):
    parser_arguments = self.parser.parse_args(arguments)

    # Display warnings or information
    self.append_response("Custom message\n")

    # Execute the BOF
    super().run(arguments)
```

## BOF Argument Encoding Types

Map .cna `bof_pack()` format characters to Python enums:

| .cna Format | Python Enum | Description |
|-------------|-------------|-------------|
| `i` | `BOFArgumentEncoding.INT` | 32-bit integer |
| `z` | `BOFArgumentEncoding.STR` | Narrow (ASCII) string |
| `Z` | `BOFArgumentEncoding.WSTR` | Wide (Unicode) string |
| `b` | `BOFArgumentEncoding.BUFFER` | Binary buffer |
| `b` | `BOFArgumentEncoding.BIN` | Binary data (alternative) |

### Format String Examples

From .cna file:
```javascript
$args = bof_pack($1, "iiiiiiiiiziiiz", $chrome, $edge, $system, ...);
```

Translates to Python comment:
```python
# BOF expects: iiiiiiiiiziiiz
```

And encoding:
```python
return [
    (BOFArgumentEncoding.INT, chrome),      # i
    (BOFArgumentEncoding.INT, edge),        # i
    (BOFArgumentEncoding.INT, system),      # i
    # ...
    (BOFArgumentEncoding.STR, path),        # z
    (BOFArgumentEncoding.INT, keyOnly),     # i
    # ...
]
```

## Multi-BOF Projects (SQL-BOF Pattern)

For projects with multiple BOFs in one repository:

```python
# sql-whoami
class SqlWhoamiBOF(BaseBOFTask):
    def __init__(self):
        super().__init__("sql-whoami", base_binary_name="whoami", base_binary_path="whoami")
    # ...

# sql-info
class SqlInfoBOF(BaseBOFTask):
    def __init__(self):
        super().__init__("sql-info", base_binary_name="info", base_binary_path="info")
    # ...
```

**Key points:**
- Multiple classes in one `.s1.py` file
- Each has unique command name
- `base_binary_name` matches individual BOF filename
- `base_binary_path` points to subdirectory containing the BOF

## Common Patterns

### Boolean Flags to Integers

```python
flag_value = 1 if parser_arguments.flag else 0
```

### Optional Arguments with Defaults

```python
self.parser.add_argument("--optional", default="", help="...")
# Later:
value = parser_arguments.optional if parser_arguments.optional else ""
```

### PID Validation

```python
if parser_arguments.pid and parser_arguments.pid <= 0:
    raise TaskInvalidArgumentsException(f"Invalid PID: {parser_arguments.pid}")
```

### File Reading for Binary Arguments

```python
import os

if not os.path.exists(parser_arguments.file_path):
    raise FileNotFoundError(f"File not found: {parser_arguments.file_path}")

with open(parser_arguments.file_path, 'rb') as f:
    file_bytes = f.read()

return [
    # ...
    (BOFArgumentEncoding.BIN, file_bytes)
]
```

## Naming Conventions

- Class names: `<CommandName>BOF` (PascalCase)
- Command names: `kebab-case` (as used in OC2)
- File names: `<project-name>_bof.s1.py` (lowercase with hyphens, **MUST include `_bof` suffix**)

**CRITICAL:** The file naming convention requires the `_bof` suffix before `.s1.py`. Examples:
- `cookie-monster_bof.s1.py` ✓
- `SQL_bof.s1.py` ✓
- `enumshares_bof.s1.py` ✓
- `cookie-monster.s1.py` ✗ (will not work)

Without the `_bof` suffix, OC2 will not recognize or load the script.
