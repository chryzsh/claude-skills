# Beacon API Reference

Complete reference for the Beacon API available in BOF-PE files.

## Data Parsing API

Parse packed arguments passed to the BOF-PE entry point.

```cpp
typedef struct {
    char* original;  // Original buffer pointer
    char* buffer;    // Current position in buffer
    int   length;    // Remaining bytes
    int   size;      // Total buffer size
} datap;

// Initialize parser with argument buffer
void BeaconDataParse(datap* parser, char* buffer, int size);

// Extract null-terminated string (returns pointer into buffer)
char* BeaconDataExtract(datap* parser, int* size);

// Extract raw pointer of specified size
char* BeaconDataPtr(datap* parser, int size);

// Extract 4-byte integer
int BeaconDataInt(datap* parser);

// Extract 2-byte short
short BeaconDataShort(datap* parser);

// Get remaining data length
int BeaconDataLength(datap* parser);
```

**Usage example:**
```cpp
void go(const char* data, int len) {
    BEACON_INIT;
    datap args = {0};
    BeaconDataParse(&args, (char*)data, len);

    const char* target = BeaconDataExtract(&args, nullptr);
    int port = BeaconDataInt(&args);
    short flags = BeaconDataShort(&args);
}
```

## Output API

Send output back to the C2 server or stdout (standalone).

```cpp
// Output type constants
#define CALLBACK_OUTPUT      0x0    // Standard output
#define CALLBACK_OUTPUT_OEM  0x1e   // OEM codepage output
#define CALLBACK_OUTPUT_UTF8 0x20   // UTF-8 output
#define CALLBACK_ERROR       0x0d   // Error output

// Printf-style formatted output
void BeaconPrintf(int type, const char* fmt, ...);

// Raw binary output
void BeaconOutput(int type, char* data, int len);
```

**Usage example:**
```cpp
BeaconPrintf(CALLBACK_OUTPUT, "Found %d users\n", count);
BeaconPrintf(CALLBACK_ERROR, "Failed to connect: %d\n", GetLastError());
BeaconOutput(CALLBACK_OUTPUT, binaryData, dataLen);
```

## Format API

Build formatted data buffers for complex output.

```cpp
typedef struct {
    char* original;
    char* buffer;
    int   length;
    int   size;
} formatp;

// Allocate format buffer
void BeaconFormatAlloc(formatp* format, int maxsz);

// Reset buffer for reuse
void BeaconFormatReset(formatp* format);

// Append raw data
void BeaconFormatAppend(formatp* format, const char* text, int len);

// Printf-style append
void BeaconFormatPrintf(formatp* format, const char* fmt, ...);

// Append 4-byte integer
void BeaconFormatInt(formatp* format, int value);

// Get buffer as string
char* BeaconFormatToString(formatp* format, int* size);

// Free format buffer
void BeaconFormatFree(formatp* format);
```

## Token API

Impersonation and token operations.

```cpp
// Apply token to current thread
BOOL BeaconUseToken(HANDLE token);

// Revert to original token
void BeaconRevertToken();

// Check if running as admin
BOOL BeaconIsAdmin();
```

## Process Injection API

Spawn and inject into processes.

```cpp
// Get configured spawn-to process path
void BeaconGetSpawnTo(BOOL x86, char* buffer, int length);

// Inject payload into existing process
void BeaconInjectProcess(
    HANDLE hProc,      // Process handle
    int pid,           // Process ID
    char* payload,     // Shellcode
    int p_len,         // Shellcode length
    int p_offset,      // Offset into shellcode
    char* arg,         // Arguments
    int a_len          // Argument length
);

// Inject into temporary process
void BeaconInjectTemporaryProcess(
    PROCESS_INFORMATION* pInfo,
    char* payload, int p_len, int p_offset,
    char* arg, int a_len
);

// Spawn temporary process
BOOL BeaconSpawnTemporaryProcess(
    BOOL x86,
    BOOL ignoreToken,
    STARTUPINFO* si,
    PROCESS_INFORMATION* pInfo
);

// Cleanup spawned process
void BeaconCleanupProcess(PROCESS_INFORMATION* pInfo);
```

## Key/Value Store API

Persist data between BOF executions.

```cpp
// Store value with key
BOOL BeaconAddValue(const char* key, void* ptr);

// Retrieve value by key (returns NULL if not found)
void* BeaconGetValue(const char* key);

// Remove value by key
BOOL BeaconRemoveValue(const char* key);
```

**Note:** Stored memory is not masked during sleep and not freed by Beacon.

## Data Store API

Access Beacon's data store for file storage.

```cpp
#define DATA_STORE_TYPE_EMPTY 0
#define DATA_STORE_TYPE_GENERAL_FILE 1

typedef struct {
    int type;
    DWORD64 hash;
    BOOL masked;
    char* buffer;
    size_t length;
} DATA_STORE_OBJECT;

// Get item from data store
DATA_STORE_OBJECT* BeaconDataStoreGetItem(size_t index);

// Protect/mask item
void BeaconDataStoreProtectItem(size_t index);

// Unprotect/unmask item for reading
void BeaconDataStoreUnprotectItem(size_t index);

// Get max entries
size_t BeaconDataStoreMaxEntries();
```

## Utility Functions

```cpp
// Convert ANSI to wide string
BOOL toWideChar(char* src, wchar_t* dst, int max);

// Get custom user data
char* BeaconGetCustomUserData();
```

## BOF-PE Specific API

```cpp
// Entry point function signature
typedef void (*BeaconEntryPtr)(const char* data, int len);

// Invoke BOF-PE in standalone mode (called by BEACON_MAIN macro)
int BeaconInvokeStandalone(
    int argc,
    const char* argv[],
    const char* bof_args_def,  // Argument format string
    BeaconEntryPtr entry       // Entry function pointer
);
```

## Beacon Information

Get information about the running Beacon.

```cpp
typedef struct {
    char* ptr;
    size_t size;
} HEAP_RECORD;

typedef struct {
    char*  sleep_mask_ptr;
    DWORD  sleep_mask_text_size;
    DWORD  sleep_mask_total_size;
    char*  beacon_ptr;
    DWORD* sections;
    HEAP_RECORD* heap_records;
    char   mask[13];
} BEACON_INFO;

void BeaconInformation(BEACON_INFO* info);
```
