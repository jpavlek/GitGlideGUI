# Install and Run — Git Glide GUI v3.7.0

## Fresh extraction

1. Extract `GitGlideGUI_v3_7_0_functional.zip`.
2. Open Command Prompt in the extracted folder.
3. Run:

```bat
run-quality-checks.bat
```

4. Start the GUI:

```bat
git-glide-gui.bat
```

## Overlay into existing repository

1. Extract this package into your repository root.
2. Allow replacing `VERSION`, `git-glide-gui.bat`, and the v3.7 files.
3. Run:

```bat
run-quality-checks.bat
git-glide-gui.bat
```

## Expected file layout

```text
GitGlideGUI_v3_7_0_functional/
  VERSION
  README.md
  git-glide-gui.bat
  git-glide-gui-v3.7.0.bat
  run-quality-checks.bat
  docs/
    CHANGELOG_V3_7_0.md
    FILES_CHANGED_V3_7_0.md
    INSTALL_AND_RUN_V3_7_0.md
    MANIFEST_V3_7_0.txt
    RELEASE_CHECKLIST_V3_7_0.md
    ROADMAP_AFTER_V3_7.md
  scripts/
    windows/
      GitGlideGUI-v3.7.0.ps1
      run-git-glide-v3.7-quality-checks.ps1
      run-quality-checks.bat
```

## Local validation commands

```bat
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\windows\run-git-glide-v3.7-quality-checks.ps1
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; [scriptblock]::Create((Get-Content -Raw 'scripts/windows/GitGlideGUI-v3.7.0.ps1')) > $null; 'PowerShell parse OK'"
```
