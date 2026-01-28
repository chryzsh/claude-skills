/*
 * Beacon Object File (BOF) API Header
 *
 * Common declarations for BOF development with Cobalt Strike
 */

#ifndef BEACON_H
#define BEACON_H

#include <windows.h>
#include <tlhelp32.h>

/* Beacon callback types */
#define CALLBACK_OUTPUT      0x0
#define CALLBACK_OUTPUT_OEM  0x1
#define CALLBACK_ERROR       0x0d
#define CALLBACK_OUTPUT_UTF8 0x20

/* Data parser structure */
typedef struct {
    char* original;
    char* buffer;
    int length;
    int size;
} datap;

/* Beacon API function declarations */
DECLSPEC_IMPORT void __cdecl BeaconDataParse(datap* parser, char* buffer, int size);
DECLSPEC_IMPORT int __cdecl BeaconDataInt(datap* parser);
DECLSPEC_IMPORT short __cdecl BeaconDataShort(datap* parser);
DECLSPEC_IMPORT int __cdecl BeaconDataLength(datap* parser);
DECLSPEC_IMPORT char* __cdecl BeaconDataExtract(datap* parser, int* size);

DECLSPEC_IMPORT void __cdecl BeaconPrintf(int type, char* fmt, ...);
DECLSPEC_IMPORT void __cdecl BeaconOutput(int type, char* data, int len);

/* Commonly used Win32 APIs - extend as needed */
DECLSPEC_IMPORT FARPROC WINAPI KERNEL32$GetProcAddress(HMODULE, LPCSTR);
DECLSPEC_IMPORT HMODULE WINAPI KERNEL32$LoadLibraryA(LPCSTR);
DECLSPEC_IMPORT HMODULE WINAPI KERNEL32$GetModuleHandleA(LPCSTR);

DECLSPEC_IMPORT LPVOID WINAPI KERNEL32$HeapAlloc(HANDLE, DWORD, SIZE_T);
DECLSPEC_IMPORT BOOL WINAPI KERNEL32$HeapFree(HANDLE, DWORD, LPVOID);
DECLSPEC_IMPORT HANDLE WINAPI KERNEL32$GetProcessHeap(void);

DECLSPEC_IMPORT BOOL WINAPI KERNEL32$CloseHandle(HANDLE);
DECLSPEC_IMPORT DWORD WINAPI KERNEL32$GetLastError(void);

/* CreateToolhelp32Snapshot APIs for process enumeration */
DECLSPEC_IMPORT HANDLE WINAPI KERNEL32$CreateToolhelp32Snapshot(DWORD dwFlags, DWORD th32ProcessID);
DECLSPEC_IMPORT BOOL WINAPI KERNEL32$Process32FirstW(HANDLE hSnapshot, LPPROCESSENTRY32W lppe);
DECLSPEC_IMPORT BOOL WINAPI KERNEL32$Process32NextW(HANDLE hSnapshot, LPPROCESSENTRY32W lppe);

/* MSVCRT functions for string operations */
DECLSPEC_IMPORT void* __cdecl MSVCRT$memset(void*, int, size_t);
DECLSPEC_IMPORT void* __cdecl MSVCRT$memcpy(void*, const void*, size_t);
DECLSPEC_IMPORT size_t __cdecl MSVCRT$strlen(const char*);
DECLSPEC_IMPORT char* __cdecl MSVCRT$strcpy(char*, const char*);
DECLSPEC_IMPORT int __cdecl MSVCRT$strcmp(const char*, const char*);

/* Convenience macros for cleaner code */
#define GetProcAddress KERNEL32$GetProcAddress
#define LoadLibraryA KERNEL32$LoadLibraryA
#define GetModuleHandleA KERNEL32$GetModuleHandleA
#define HeapAlloc KERNEL32$HeapAlloc
#define HeapFree KERNEL32$HeapFree
#define GetProcessHeap KERNEL32$GetProcessHeap
#define CloseHandle KERNEL32$CloseHandle
#define GetLastError KERNEL32$GetLastError

#define CreateToolhelp32Snapshot KERNEL32$CreateToolhelp32Snapshot
#define Process32FirstW KERNEL32$Process32FirstW
#define Process32NextW KERNEL32$Process32NextW

#define memset MSVCRT$memset
#define memcpy MSVCRT$memcpy
#define strlen MSVCRT$strlen
#define strcpy MSVCRT$strcpy
#define strcmp MSVCRT$strcmp

#endif /* BEACON_H */
