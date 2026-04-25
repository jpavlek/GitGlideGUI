# Git Glide GUI v3.5 - Pester Compatibility Hotfix

## Purpose

v3.5 fixes the quality-check failure reported on Windows systems with older Pester versions, especially Pester 3.4.0.

## Fixed

- `run-pester-tests.ps1` no longer calls `Invoke-Pester -Output Detailed` unless the installed Pester version exposes an exact `-Output` parameter.
- This avoids the Pester 3.x error:

```text
Parameter cannot be processed because the parameter name 'Output' is ambiguous.
Possible matches include: -OutputXml -OutputFile -OutputFormat.
```

## Preserved

- Environment sanitization for invalid `LIB`, `INCLUDE`, and `LIBPATH` entries remains in place.
- Root-level wrappers remain available:
  - `run-quality-checks.bat`
  - `run-pester-tests.bat`
- The Windows smoke-launch test remains part of quality checks.

## Notes

This is a compatibility hotfix, not a feature release. The next feature iteration remains v3.5: read-only History / Graph tab and a dedicated history service.
