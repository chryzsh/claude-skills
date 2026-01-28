# BOF Makefile - Process Enumeration
#
# Compiles proc-enum BOF for x64 and x86 architectures

# BOF name - determines output filename (proc-enum.x64.o, proc-enum.x86.o)
BOFNAME := proc-enum

# Common include directory (not used for this BOF)
COMINCLUDE :=

# Library includes - no additional libraries needed for process enumeration
# CreateToolhelp32Snapshot is in kernel32 which is linked by default
LIBINCLUDE :=

# BOF Linter configuration
BOFLINT := boflint.py
LOADER := any

# Compiler definitions
CC_x64 := x86_64-w64-mingw32-gcc
CC_x86 := i686-w64-mingw32-gcc
CC := x86_64-w64-mingw32-clang

# Compilation flags
CFLAGS := -Os -c -DBOF
TEST_CFLAGS := -g

# Output directory
OUTPUT_DIR := .

# Default target: compile BOF object files for both architectures
all:
	$(CC_x64) -o $(BOFNAME).x64.o $(COMINCLUDE) $(CFLAGS) entry.c
	$(CC_x86) -o $(BOFNAME).x86.o $(COMINCLUDE) $(CFLAGS) entry.c
	@if [ "$(OUTPUT_DIR)" != "." ]; then \
		mkdir -p $(OUTPUT_DIR) && mv $(BOFNAME)*.o $(OUTPUT_DIR); \
	fi

# Test target: compile as executable for local testing
test:
	$(CC_x64) entry.c $(TEST_CFLAGS) $(COMINCLUDE) $(LIBINCLUDE) -o $(BOFNAME).x64.exe
	$(CC_x86) entry.c $(TEST_CFLAGS) $(COMINCLUDE) $(LIBINCLUDE) -o $(BOFNAME).x86.exe

# Scan-build target: static analysis with clang
scanbuild:
	$(CC) entry.c -o $(BOFNAME).scanbuild.exe $(COMINCLUDE) $(LIBINCLUDE)

# Check target: run cppcheck for additional static analysis
check:
	cppcheck --enable=all $(COMINCLUDE) --platform=win64 entry.c

# Lint target: validate compiled BOF with boflint
lint:
	@echo "Linting $(BOFNAME).x64.o..."
	@python3 $(BOFLINT) $(OUTPUT_DIR)/$(BOFNAME).x64.o --loader $(LOADER) || true
	@echo ""
	@echo "Linting $(BOFNAME).x86.o..."
	@python3 $(BOFLINT) $(OUTPUT_DIR)/$(BOFNAME).x86.o --loader $(LOADER) || true

# Lint with verbose output
lint-verbose:
	@echo "Linting $(BOFNAME).x64.o (verbose)..."
	@python3 $(BOFLINT) $(OUTPUT_DIR)/$(BOFNAME).x64.o --loader $(LOADER) -v || true
	@echo ""
	@echo "Linting $(BOFNAME).x86.o (verbose)..."
	@python3 $(BOFLINT) $(OUTPUT_DIR)/$(BOFNAME).x86.o --loader $(LOADER) -v || true

# Clean target: remove compiled files
clean:
	rm -f $(BOFNAME).*.exe
	rm -f $(BOFNAME).*.o

.PHONY: all test scanbuild check lint lint-verbose clean
