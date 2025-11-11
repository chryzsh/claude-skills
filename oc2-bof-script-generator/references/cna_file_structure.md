# Aggressor Script (.cna) File Structure

This reference documents how to parse and extract information from Cobalt Strike Aggressor scripts (.cna files).

## Key Components

### 1. Command Registration

```javascript
beacon_command_register(
    "command-name",
    "Brief description",
    "Detailed usage information..."
);
```

**Contains:**
- Command name (first parameter)
- Short description (second parameter)
- Extended help text with usage examples and options (third parameter)

### 2. Alias Definition

```javascript
alias command-name {
    // Command implementation
}
```

The alias block contains:
- Argument parsing logic
- Variable declarations
- BOF file loading
- **Argument packing (most important)**
- BOF execution

### 3. BOF Argument Packing

The critical line to find:

```javascript
$args = bof_pack($1, "format_string", $arg1, $arg2, ...);
```

**Format string characters:**
- `i` = 32-bit integer
- `z` = narrow (ASCII) string
- `Z` = wide (Unicode) string
- `b` = binary buffer
- `s` = short (16-bit integer, rare)

**Example:**
```javascript
$args = bof_pack($1, "iiiiiiiiiziiiz",
    $chrome, $edge, $system, $firefox,
    $chromeCookiePID, $chromeLoginDataPID,
    $edgeCookiePID, $edgeLoginDataPID,
    $pid, $path, $keyOnly, $cookieOnly,
    $loginDataOnly, $copyFile);
```

This tells us:
- 8 integer arguments (i i i i i i i i)
- 1 narrow string (z)
- 3 integer arguments (i i i)
- 1 narrow string (z)

### 4. Variable Initialization

Variables are often initialized at the start:

```javascript
$chrome = 0;
$edge = 0;
$firefox = 0;
$path = "";
$copyFile = "";
```

This shows:
- Which arguments are integers (initialized to 0)
- Which are strings (initialized to "")
- Default values

### 5. Argument Parsing

Look for loops and conditionals:

```javascript
for ($i = 1; $i < size(@_); $i++) {
    if (@_[$i] eq "--chrome") {
        $chrome = 1;
    }
    else if (@_[$i] eq "--system") {
        $system = 1;
        $i++;
        $path = @_[$i];
        $i++;
        $pid = @_[$i];
    }
    // ...
}
```

This reveals:
- Flag arguments (set to 1 when present)
- Arguments that take values (read next array element)
- Argument names and purposes

### 6. Validation Logic

```javascript
if ($keyOnly == 1 && ($cookieOnly == 1 || $loginDataOnly == 1)) {
    berror($1, "--key-only cannot be used with --cookie-only or --login-data-only");
    return;
}
```

Shows:
- Mutually exclusive options
- Required argument combinations
- Validation constraints to implement in Python

## Parsing Workflow

### Step 1: Identify Command Name
```javascript
beacon_command_register("command-name", ...)
alias command-name { ... }
```

### Step 2: Extract Description and Usage
From `beacon_command_register()` third parameter

### Step 3: Find bof_pack() Call
Search for `bof_pack` in the alias block:
```javascript
$args = bof_pack($bid, "ZZZ", %opts["command"], %opts["url"], %opts["--ua"]);
```

### Step 4: Map Arguments
1. Note the format string: `"ZZZ"`
2. Note the argument order: `command`, `url`, `--ua`
3. Map each format character to its corresponding variable

### Step 5: Identify Argument Types
From variable initialization and parsing:
- Boolean flags → map to integers (0 or 1)
- String options → map to strings
- Numeric options → map to integers

### Step 6: Extract Validation Rules
Look for `berror()` calls and conditionals that check argument validity

## Common Patterns

### Simple Command (No Arguments)

```javascript
alias listpipes {
    $bof = _read_bof_resource($1);
    beacon_inline_execute($1, $bof, "go", $null);   # no args
}
```

Python equivalent:
```python
def _encode_arguments_bof(self, arguments: List[str]) -> List[Tuple[BOFArgumentEncoding, str]]:
    return []  # No arguments
```

### Command with Positional Arguments

```javascript
$args = bof_pack($1, "ZZZ", $command, $url, $user_agent);
```

Python:
```python
return [
    (BOFArgumentEncoding.WSTR, parser_arguments.command),
    (BOFArgumentEncoding.WSTR, parser_arguments.url),
    (BOFArgumentEncoding.WSTR, parser_arguments.user_agent),
]
```

### Command with Optional Flags

```javascript
$chrome = 0;
if (@_[$i] eq "--chrome") {
    $chrome = 1;
}
$args = bof_pack($1, "i...", $chrome, ...);
```

Python:
```python
chrome = 1 if parser_arguments.chrome else 0
return [
    (BOFArgumentEncoding.INT, chrome),
    # ...
]
```

### Command with Multiple Argument Types

```javascript
$args = bof_pack($1, "ZZi", $server, $command, $timeout);
```

Python:
```python
return [
    (BOFArgumentEncoding.WSTR, parser_arguments.server),
    (BOFArgumentEncoding.WSTR, parser_arguments.command),
    (BOFArgumentEncoding.INT, parser_arguments.timeout),
]
```

## Tips for Accurate Conversion

1. **Count carefully:** Ensure format string length matches argument count
2. **Preserve order:** Arguments must be in exact order from bof_pack()
3. **Check types:** Verify integers vs strings vs wide strings
4. **Note defaults:** Use same default values as .cna file
5. **Include validation:** Port all validation logic to Python
6. **Copy examples:** Use .cna epilog examples in Python epilog

## Multi-BOF Projects

Some .cna files define multiple aliases:

```javascript
alias sql-whoami { ... }
alias sql-info { ... }
alias sql-query { ... }
```

Each alias becomes a separate Python class in the same `.s1.py` file.
