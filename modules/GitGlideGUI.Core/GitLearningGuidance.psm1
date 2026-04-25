<#
GitLearningGuidance.psm1
Plain-language Git operation and workflow guidance for Git Glide GUI.
#>

Set-StrictMode -Version 2.0

function Get-GglOperationGuidanceNames {
    return @(
        'Open existing repo',
        'Init new repo',
        'Stage selected',
        'Unstage selected',
        'Commit',
        'Push current branch',
        'Pull current branch',
        'Create feature branch',
        'Switch branch',
        'Stash changes',
        'Apply/pop stash',
        'Merge',
        'Cherry-pick',
        'Resolve conflicts',
        'Create tag/release',
        'History / Graph',
        'Soft undo last commit'
    )
}

function Get-GglOperationGuidance {
    param([AllowNull()][string]$Name)

    $key = if ([string]::IsNullOrWhiteSpace($Name)) { 'Stage selected' } else { $Name.Trim() }
    switch -Regex ($key) {
        '^Open existing repo$' { return "Open existing repo`r`n`r`nUse this when the folder already contains a .git directory. Git Glide will run commands inside that repository instead of inside the extracted tool folder.`r`n`r`nUseful when: you are continuing work on an existing project." }
        '^Init new repo$' { return "Init new repo`r`n`r`nCreates a new .git directory in a normal folder. This starts version control for a project that is not tracked yet.`r`n`r`nUseful when: you created a new project and want Git to track changes from now on." }
        '^Stage selected$' { return "Stage selected`r`n`r`nAdds only selected files to the next commit. Staging is Git's preparation area: it lets you decide exactly what belongs in the next snapshot.`r`n`r`nUseful when: you changed many files but want a small, focused commit." }
        '^Unstage selected$' { return "Unstage selected`r`n`r`nRemoves selected files from the next commit while keeping the file edits on disk.`r`n`r`nUseful when: you accidentally staged too much." }
        '^Commit$' { return "Commit`r`n`r`nRecords staged changes as a new local snapshot with a message. A commit should usually represent one logical change.`r`n`r`nUseful when: a focused change builds, tests, or at least makes sense as one reviewable step." }
        '^Push current branch$' { return "Push current branch`r`n`r`nUploads local commits to the remote repository so others, CI, or another machine can see them.`r`n`r`nUseful when: you want to share work, back it up remotely, or create a pull/merge request." }
        '^Pull current branch$' { return "Pull current branch`r`n`r`nDownloads remote changes and fast-forwards your current branch when possible. Git Glide prefers --ff-only to avoid surprise merge commits.`r`n`r`nUseful when: you want to update your branch before continuing work." }
        '^Create feature branch$' { return "Create feature branch`r`n`r`nCreates a separate branch for one focused task. This protects main/develop from unfinished changes.`r`n`r`nUseful when: starting a bug fix, improvement, experiment, or AI-assisted coding iteration." }
        '^Switch branch$' { return "Switch branch`r`n`r`nMoves your working directory to another branch. Git may block switching if local changes would be overwritten.`r`n`r`nUseful when: changing task context after committing or stashing current work." }
        '^Stash changes$' { return "Stash changes`r`n`r`nTemporarily saves unfinished local changes and cleans the working tree. Stashes are not a substitute for commits, but are useful for short interruptions.`r`n`r`nUseful when: you need to pull, switch, or merge before your current work is ready to commit." }
        '^Apply/pop stash$' { return "Apply/pop stash`r`n`r`nApply replays a stash and keeps it. Pop replays a stash and drops it if successful. Conflicts can happen if files changed meanwhile.`r`n`r`nUseful when: returning to interrupted work." }
        '^Merge$' { return "Merge`r`n`r`nCombines changes from one branch into another. If both sides edited the same lines, Git asks you to resolve conflicts.`r`n`r`nUseful when: finishing a feature branch or bringing develop/main updates together." }
        '^Cherry-pick$' { return "Cherry-pick`r`n`r`nCopies one selected commit onto the current branch. It is precise, but can create duplicate history when overused.`r`n`r`nUseful when: you need one bug fix from another branch without merging the whole branch." }
        '^Resolve conflicts$' { return "Resolve conflicts`r`n`r`nA conflict means Git could not safely combine changes automatically. Open each conflicted file, choose the correct content, remove conflict markers, stage the file, then continue or abort the operation.`r`n`r`nUseful when: merge, pull, stash pop/apply, rebase, or cherry-pick stops for manual review." }
        '^Create tag/release$' { return "Create tag/release`r`n`r`nA tag names a specific commit, often as a release version such as v1.2.0. Annotated tags include a message and metadata; lightweight tags are simple pointers.`r`n`r`nUseful when: marking releases, milestones, or known-good states." }
        '^History / Graph$' { return "History / Graph`r`n`r`nShows commits, branch tips, tags, and merges. It is read-only and helps you understand where changes came from before doing risky operations.`r`n`r`nUseful when: deciding whether to pull, merge, cherry-pick, delete a branch/tag, or recover history." }
        '^Soft undo last commit$' { return "Soft undo last commit`r`n`r`nRuns git reset --soft HEAD~1. It removes the last commit but keeps its changes staged, so you can adjust and recommit.`r`n`r`nUseful when: the last local commit message or contents need correction before pushing." }
        default { return "Select an operation to see what it means, what it does, and when it is useful." }
    }
}

function Get-GglTypicalWorkflowGuide {
    $lines = @()
    $lines += 'Typical Git workflows during software development'
    $lines += ''
    $lines += '1. Start or open work'
    $lines += '- Open an existing repository, or initialize a new repository for a new project.'
    $lines += '- If it is a new project, add a .gitignore and make the first commit.'
    $lines += ''
    $lines += '2. Work on a focused branch'
    $lines += '- Pull the base branch when clean.'
    $lines += '- Create a feature branch for one focused task.'
    $lines += '- Make edits, build/test locally, then review the diff.'
    $lines += ''
    $lines += '3. Create clean commits'
    $lines += '- Stage only files that belong together.'
    $lines += '- Commit with a clear message that explains the intent.'
    $lines += '- Prefer several small logical commits over one large unclear commit.'
    $lines += ''
    $lines += '4. Synchronize safely'
    $lines += '- Pull only with a clean working tree.'
    $lines += '- Stash unfinished work if you must switch or pull before committing.'
    $lines += '- Inspect History / Graph before merge, cherry-pick, or force-with-lease.'
    $lines += ''
    $lines += '5. Integrate and recover'
    $lines += '- Merge when you want the whole branch history.'
    $lines += '- Cherry-pick when you only need one specific commit.'
    $lines += '- If conflicts occur, use Recovery to list conflicted files, open them, resolve markers, stage resolved files, and continue or abort.'
    $lines += ''
    $lines += '6. Release'
    $lines += '- Create an annotated tag for a release commit.'
    $lines += '- Push the tag when the release is ready to share.'
    return ($lines -join "`r`n")
}

Export-ModuleMember -Function Get-GglOperationGuidanceNames, Get-GglOperationGuidance, Get-GglTypicalWorkflowGuide
