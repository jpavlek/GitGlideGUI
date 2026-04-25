# Git Glide GUI v3.6.7 - GitHub diagnostics and safer file removal

## Focus

v3.6.7 improves the GitHub publishing path after the first successful local releases. It adds diagnostics for common remote setup problems and separates destructive file removal from safe stop-tracking workflows.

## Added

- GitHub diagnostics dialog with current remotes, current branch, upstream tracking status, remote access testing, GitHub repository opening, new-repository opening, and push-with-upstream.
- Clear guidance when GitHub reports repository not found, missing upstream, HTTPS authentication failure, or SSH key failure.
- `git rm -- <file>` workflow for removing tracked files from Git and disk after confirmation.
- `git rm --cached -- <file>` workflow for stopping Git tracking while keeping the local file.
- Explicit changed-file badges such as `[index:M work:-]` and `[index:- work:M]` to make staging state changes visible.

## Validation

Run on Windows:

```bat
cd /d scripts\windows
run-quality-checks.bat
```
