# OC2 Runtime Module Reference

Use this reference when an OC2 BOF script depends on `outflank_stage1` behavior and you need the real implementation rather than a guessed stub.

## Bundled runtime snapshot

The skill now includes a self-contained snapshot of the BOF-script-relevant OC2 runtime modules under:

```bash
references/runtime_snapshot/
```

Primary package roots:

```bash
references/runtime_snapshot/outflank_stage1
```

This snapshot was copied from the recovered OC2 runtime extracted from `stage1-api-1`.

## First files to check

For BOF `.s1.py` generation, these are the most relevant files:

```text
outflank_stage1/__init__.py
outflank_stage1/task/__init__.py
outflank_stage1/task/base_task.py
outflank_stage1/task/base_bof_task.py
outflank_stage1/task/task_file.py
outflank_stage1/task/enums/__init__.py
outflank_stage1/task/enums/bof_argument_encoding.py
outflank_stage1/task/exceptions/__init__.py
outflank_stage1/task/exceptions/task_exception.py
outflank_stage1/task/exceptions/task_invalid_arguments_exception.py
outflank_stage1/implant/__init__.py
outflank_stage1/implant/enums/__init__.py
```

## What each file answers

- `outflank_stage1/task/base_task.py`
  Confirms parser behavior, `add_task_after()`, file helpers, and `base_path` handling.
- `outflank_stage1/task/base_bof_task.py`
  Confirms BOF filename resolution, `base_binary_name`, `base_binary_path`, arch suffixes, argument packing, and runtime validation.
- `outflank_stage1/task/enums/bof_argument_encoding.py`
  Confirms valid `BOFArgumentEncoding` and `BOFType` members.
- `outflank_stage1/task/exceptions/*`
  Confirms the exception classes OC2 BOF scripts typically raise.
- `outflank_stage1/implant/enums/__init__.py`
  Confirms `ImplantArch`, `ImplantOSType`, and `ImplantPrivilege` values used by task code.
- `outflank_stage1/__init__.py`
  Confirms OC2 shared-path defaults such as `/shared`, `/shared/bofs`, and `/shared/tasks`.

## Known runtime facts from the recovered package

- `BaseTask` initializes `_base_path` to `None`.
- `BaseTask.add_task_after()` does not copy `base_path` into child tasks.
- `BaseBOFTask` resolves BOFs with:

```python
os.path.join(
    self.get_base_path(),
    self._get_base_binary_path(arguments),
    self._get_bof_binary_filename(implant, arguments),
)
```

- `BaseBOFTask` chooses suffixes `.x64.o`, `.x86.o`, or `.arm64.o` from implant architecture.
- `BOFArgumentEncoding` supports `WSTR`, `STR`, `BUFFER`, `INT`, and `SHORT`.
- `BOFType` supports `DEFAULT`, `DEFAULT_NON_THREADED`, and `ASYNC`.

## Scope guidance

- For standard BOF wrappers, `outflank_stage1` is the package to reference.
- `outflank_stage1_private` was intentionally not bundled because BOF wrapper generation usually does not need it directly.
- If a future OC2 script needs service-side helpers or private task-cache behavior, recover and snapshot the relevant `outflank_stage1_private` files separately instead of guessing.
