# Neovim -> IntelliJ (IdeaVim) keymap translation

This file is the audit trail for the generated IdeaVim config at `intellij/.ideavimrc`.

Implementation note:
- Toggle-like Neovim keys (`<leader>e`, `<leader>tt`, `<leader>gs`, `<leader>st`, `<leader>xx`, etc.) are implemented with a small Vimscript toggle helper that calls `Activate...ToolWindow` and `HideActiveWindow`.
- This gives close/open toggle behavior on repeated key use, matching Neovim intent.
- If you manually open/close tool windows with mouse/IDE shortcuts, the internal toggle state can drift; pressing the same toggle key once will re-sync.

Legend:
- `Exact`: same intent/flow in IntelliJ
- `Approx`: closest practical IntelliJ equivalent
- `N/A`: no meaningful IntelliJ/IdeaVim equivalent (or Neovim-plugin-only behavior)

## 1) Core editor / window

| Key | Source | Neovim intent | IntelliJ action / mapping | Status |
|---|---|---|---|---|
| `<C-s>` | `init.lua:115` | Save buffer | `SaveAll` | Approx |
| `<leader>qa` | `init.lua:116` | Save all and quit | `SaveAll` + `Exit` | Approx |
| `<leader>qf` | `init.lua:117` | Open diagnostic quickfix list | `ActivateProblemsViewToolWindow` | Approx |
| `<C-h>` / `<C-j>` / `<C-k>` / `<C-l>` | `init.lua:122-125` | Move between split windows | `<C-w>h/j/k/l` | Exact |
| `dq` | `init.lua:139` | Close current buffer | `CloseContent` | Approx |
| `<Down>` / `<Up>` | `init.lua:128-129` | Cursor+scroll behavior | left as IdeaVim defaults | N/A |
| `<Esc><Esc>` (terminal) | `init.lua:118` | Exit terminal mode | no terminal-mode equivalent | N/A |
| `<C-w>q` (terminal) | `init.lua:119` | Close terminal pane | no terminal-mode equivalent | N/A |

## 2) Line movement

| Key | Source | Neovim intent | IntelliJ action / mapping | Status |
|---|---|---|---|---|
| `<A-Up>` / `<A-k>` | `lua/ba/autocommands/moveindent.lua:144,146,149,151` | Move line/selection up | `MoveLineUp` (n/x/i) | Approx |
| `<A-Down>` / `<A-j>` | `lua/ba/autocommands/moveindent.lua:145,147,150,152` | Move line/selection down | `MoveLineDown` (n/x/i) | Approx |

## 3) Search / picker / explorer (snacks)

| Key | Source | Neovim intent | IntelliJ action / mapping | Status |
|---|---|---|---|---|
| `<leader><space>` | `lua/plugins/editor/snacks-picker.lua:84` | Smart file finder | `SearchEverywhere` | Approx |
| `<leader><leader>` | requested + legacy telescope comment | Smart buffer finder | `RecentFiles` | Approx |
| `<leader>,` | `lua/plugins/editor/snacks-picker.lua:85` | Buffers picker | `RecentFiles` | Approx |
| `<leader>/` | `lua/plugins/editor/snacks-picker.lua:86` | Grep | `FindInPath` | Exact |
| `<leader>:` | `lua/plugins/editor/snacks-picker.lua:87` | Command history | `GotoAction` | Approx |
| `<leader>n` | `lua/plugins/editor/snacks-picker.lua:88` | Notification history | `Notifications` | Approx |
| `<leader>e` / `\` | `lua/plugins/editor/snacks-picker.lua:89-90` | Toggle explorer | stateful toggle wrapper on `ActivateProjectToolWindow` + `HideActiveWindow` | Approx |
| `<leader>fb` | `lua/plugins/editor/snacks-picker.lua:93` | Buffers | `RecentFiles` | Approx |
| `<leader>fc` | `lua/plugins/editor/snacks-picker.lua:94` | Find config file | `GotoFile` | Approx |
| `<leader>ff` | `lua/plugins/editor/snacks-picker.lua:95` | Find files | `GotoFile` | Exact |
| `<leader>fg` | `lua/plugins/editor/snacks-picker.lua:96` | Find git files | `RecentChangedFiles` | Approx |
| `<leader>fp` | `lua/plugins/editor/snacks-picker.lua:97` | Projects | `ManageRecentProjects` | Approx |
| `<leader>fr` | `lua/plugins/editor/snacks-picker.lua:98` | Recent files | `RecentFiles` | Exact |
| `<leader>sb` | `lua/plugins/editor/snacks-picker.lua:110` | Buffer lines | `Find` | Approx |
| `<leader>sB` | `lua/plugins/editor/snacks-picker.lua:111` | Grep open buffers | `FindInPath` | Approx |
| `<leader>sw` (n/x) | `lua/plugins/editor/snacks-picker.lua:112` | Grep word/selection | `FindWordAtCaret` / `FindInPath` | Approx |
| `<leader>s` (operator) | `lua/plugins/editor/snacks-picker.lua:114` | Grep by motion | no operator equivalent | N/A |
| `<leader>s"` | `lua/plugins/editor/snacks-picker.lua:117` | Registers picker | no IntelliJ register model | N/A |
| `<leader>s/` | `lua/plugins/editor/snacks-picker.lua:118` | Search history | `Find` | Approx |
| `<leader>sA` | `lua/plugins/editor/snacks-picker.lua:119` | Autocmds list | `GotoAction` | Approx |
| `<leader>sc` | `lua/plugins/editor/snacks-picker.lua:120` | Command history | `GotoAction` | Approx |
| `<leader>sC` | `lua/plugins/editor/snacks-picker.lua:121` | Commands list | `GotoAction` | Approx |
| `<leader>sd` | `lua/plugins/editor/snacks-picker.lua:122` | Diagnostics | stateful toggle wrapper on `ActivateProblemsViewToolWindow` + `HideActiveWindow` | Approx |
| `<leader>sD` | `lua/plugins/editor/snacks-picker.lua:123` | Buffer diagnostics | `ShowErrorDescription` | Approx |
| `<leader>sh` | `lua/plugins/editor/snacks-picker.lua:124` | Help pages | `HelpTopics` | Approx |
| `<leader>sH` | `lua/plugins/editor/snacks-picker.lua:125` | Highlights | no direct equivalent | N/A |
| `<leader>sI` | `lua/plugins/editor/snacks-picker.lua:126` | Icons picker | no direct equivalent | N/A |
| `<leader>sj` | `lua/plugins/editor/snacks-picker.lua:127` | Jumps | `RecentLocations` | Approx |
| `<leader>sk` | `lua/plugins/editor/snacks-picker.lua:128` | Keymaps list | `Keymap` | Approx |
| `<leader>sl` | `lua/plugins/editor/snacks-picker.lua:129` | Location list | `ActivateProblemsViewToolWindow` | Approx |
| `<leader>sm` | `lua/plugins/editor/snacks-picker.lua:130` | Marks | `ShowBookmarks` | Approx |
| `<leader>sM` | `lua/plugins/editor/snacks-picker.lua:131` | Man pages | no practical equivalent | N/A |
| `<leader>sp` | `lua/plugins/editor/snacks-picker.lua:132` | Pickers list | `SearchEverywhere` | Approx |
| `<leader>sP` | `lua/plugins/editor/snacks-picker.lua:133` | Plugin spec search | `GotoAction` | Approx |
| `<leader>sq` | `lua/plugins/editor/snacks-picker.lua:134` | Quickfix list | `ActivateProblemsViewToolWindow` | Approx |
| `<leader>s.` | `lua/plugins/editor/snacks-picker.lua:135` | Resume picker | `RecentFiles` | Approx |
| `<leader>su` | `lua/plugins/editor/snacks-picker.lua:136` | Undo history | `LocalHistory.ShowHistory` | Approx |
| `<leader>uc` | `lua/plugins/editor/snacks-picker.lua:137` | Colorschemes picker | `QuickChangeColorScheme` | Approx |
| `<leader>ss` | `lua/plugins/editor/snacks-picker.lua:147` | LSP symbols | `FileStructurePopup` | Approx |
| `<leader>sS` | `lua/plugins/editor/snacks-picker.lua:148` | Workspace symbols | `GotoSymbol` | Exact |
| `<leader>st` / `<leader>sT` | `lua/plugins/editor/snacks-picker.lua:157-158` | TODO search | stateful toggle wrapper on `ActivateTODOToolWindow` + `HideActiveWindow` | Approx |

## 4) LSP / code actions / diagnostics

| Key | Source | Neovim intent | IntelliJ action / mapping | Status |
|---|---|---|---|---|
| `ga` (n/x) | `lua/plugins/editor/actions-preview.lua:64` | Code actions | `ShowIntentionActions` | Exact |
| `gd` | `lua/plugins/editor/snacks-picker.lua:140` | Go to definition | `GotoDeclaration` | Exact |
| `gD` | `lua/plugins/editor/snacks-picker.lua:141` | Go to declaration | `GotoTypeDeclaration` | Approx |
| `gr` | `lua/plugins/editor/snacks-picker.lua:142` | References | `ShowUsages` | Exact |
| `gI` | `lua/plugins/editor/snacks-picker.lua:143` | Implementation | `GotoImplementation` | Exact |
| `gy` | `lua/plugins/editor/snacks-picker.lua:144` | Type definition | `GotoTypeDeclaration` | Exact |
| `]d` / `[d` | `lua/plugins/coding/lsp.lua:140-141` | Next/prev diagnostics | `GotoNextError` / `GotoPreviousError` | Exact |
| `]h` / `[h` | `lua/plugins/coding/lsp.lua:143-144` | Next/prev hint/info | mapped to next/prev error | Approx |
| `<leader>k` | `lua/plugins/coding/lsp.lua:146` | Show diagnostics on line | `ShowErrorDescription` | Exact |
| `<C-w>d` | `lua/plugins/coding/lsp.lua:150` | Open diagnostics window | `ShowErrorDescription` | Approx |
| `<leader>th` | `lua/plugins/coding/lsp.lua:204` | Toggle inlay hints | `ToggleInlayHintsGloballyAction` | Approx |
| `<leader>rn` | `lua/plugins/coding/inc-rename.lua:11` | Rename symbol | `RenameElement` | Exact |
| `<leader>bF` | `lua/plugins/editor/formatting.lua:8` | Format buffer | `ReformatCode` | Exact |
| `<leader>rw` | `lua/ba/autocommands/replace-text.lua:2` | Replace word (confirm) | `Replace` | Approx |
| `<leader>r` | `lua/ba/autocommands/replace-text.lua:80` | Motion-based replace | `Replace` | Approx |
| `<leader>sr` (n/x) | `lua/plugins/coding/replace.lua:44` | project/range replace | `ReplaceInPath` | Approx |

## 5) Trouble / TODO / noice equivalents

| Key | Source | Neovim intent | IntelliJ action / mapping | Status |
|---|---|---|---|---|
| `[t` / `]t` | `lua/plugins/ui/code.lua:32-33` | Prev/next TODO comment | `FindPrevious` / `FindNext` | Approx |
| `<leader>xt` / `<leader>xT` | `lua/plugins/ui/code.lua:34-35` | TODO list views | stateful toggle wrapper on `ActivateTODOToolWindow` + `HideActiveWindow` | Approx |
| `<leader>cs` | `lua/plugins/ui/code.lua:47` | Symbols panel | `FileStructurePopup` | Approx |
| `<leader>xx` / `<leader>xX` | `lua/plugins/ui/code.lua:48-49` | Diagnostics panel | stateful toggle wrapper on `ActivateProblemsViewToolWindow` + `HideActiveWindow` | Approx |
| `<leader>xL` / `<leader>xQ` | `lua/plugins/ui/code.lua:50-51` | Loclist/quickfix | stateful toggle wrapper on `ActivateProblemsViewToolWindow` + `HideActiveWindow` | Approx |
| `<leader>cl` | `lua/plugins/ui/code.lua:52` | LSP references/defs panel | `ShowUsages` | Approx |
| `<leader>snl`/`<leader>snh`/`<leader>sna`/`<leader>snd`/`<leader>snt` | `lua/plugins/ui/noice.lua:18-22` | Message/notification history | `Notifications` | Approx |
| `<S-Enter>` (cmd mode) | `lua/plugins/ui/noice.lua:17` | Redirect cmdline | no IntelliJ command-line mode | N/A |
| `<C-f>` / `<C-b>` noice scroll | `lua/plugins/ui/noice.lua:23-24` | Scroll LSP markdown popup | keep IDE defaults | N/A |

## 6) Git workflow

| Key | Source | Neovim intent | IntelliJ action / mapping | Status |
|---|---|---|---|---|
| `<leader>gg` | `lua/plugins/editor/git.lua:11` | Git UI | `Vcs.QuickListPopupAction` | Approx |
| `<leader>gp` | `lua/plugins/editor/git.lua:12` | Open remote page | `OpenInBrowser` | Approx |
| `<leader>gb` | `lua/plugins/editor/snacks-picker.lua:101` | Git branches | `Git.Branches` | Exact |
| `<leader>gl` | `lua/plugins/editor/snacks-picker.lua:102` | Git log | `Vcs.ShowTabbedFileHistory` | Approx |
| `<leader>gL` | `lua/plugins/editor/snacks-picker.lua:103` | Git log line | `Annotate` | Approx |
| `<leader>gs` | `lua/plugins/editor/snacks-picker.lua:104` | Git status | stateful toggle wrapper on `ActivateVersionControlToolWindow` + `HideActiveWindow` | Approx |
| `<leader>gS` | `lua/plugins/editor/snacks-picker.lua:105` | Git stash | `Git.Unstash` | Approx |
| `<leader>gD` | `lua/plugins/editor/snacks-picker.lua:106` | Git diff hunks | `ShowDiff` | Approx |
| `<leader>gf` | `lua/plugins/editor/snacks-picker.lua:107` | File git log | `Vcs.ShowTabbedFileHistory` | Approx |
| `<leader>gc` / `<leader>gac` | `lua/plugins/editor/git.lua:34-35` | Commit / amend | `CheckinProject` | Approx |
| `[c` / `]c` | `lua/plugins/editor/git.lua:65-79` | Prev/next change hunk | `VcsShowPrevChangeMarker` / `VcsShowNextChangeMarker` | Exact |
| `<leader>bb` / `<leader>tb` | `lua/plugins/editor/git.lua:24,103` | Toggle blame | `Annotate` | Approx |
| `<leader>tw` | `lua/plugins/editor/git.lua:104` | Toggle word diff | `ShowDiff` | Approx |
| `<leader>hs` / `<leader>hS` | `lua/plugins/editor/git.lua:83,90,92` | Stage hunk/buffer | `CheckinProject` | Approx |
| `<leader>hr` / `<leader>hR` | `lua/plugins/editor/git.lua:86,91,94` | Reset hunk/buffer | `Rollback` | Approx |
| `<leader>hu` | `lua/plugins/editor/git.lua:93` | Undo stage hunk | `u` | Approx |
| `<leader>hh` / `<leader>hi` / `<leader>hd` / `<leader>gd` | `lua/plugins/editor/git.lua:95,96,99,101` | Diff/preview hunk | `ShowDiff` | Approx |
| `<leader>hb` | `lua/plugins/editor/git.lua:97` | Blame line | `Annotate` | Approx |
| `<leader>hB` | `lua/plugins/editor/git.lua:98` | Diff vs blamed commit | `Vcs.ShowTabbedFileHistory` | Approx |

## 7) Buffers, undo tree, sessions

| Key | Source | Neovim intent | IntelliJ action / mapping | Status |
|---|---|---|---|---|
| `<leader>uu` | `lua/plugins/editor/undotree.lua:6` | Undo tree | `LocalHistory.ShowHistory` | Approx |
| `<leader>qs` / `<leader>qS` / `<leader>ql` / `<leader>qd` | `lua/plugins/editor/session.lua:37-40` | Session restore/select/disable | `ManageRecentProjects` | Approx |
| `<leader>lz` | `lua/plugins/lazy.lua:14` | Lazy plugin manager UI | `ShowSettings` | Approx |

## 8) Debug

| Key | Source | Neovim intent | IntelliJ action / mapping | Status |
|---|---|---|---|---|
| `<leader>dc` | `lua/plugins/editor/debug.lua:28` | Start/continue debug | `Debug` | Exact |
| `<leader>dj` | `lua/plugins/editor/debug.lua:35` | Step into | `StepInto` | Exact |
| `<leader>dl` | `lua/plugins/editor/debug.lua:42` | Step over | `StepOver` | Exact |
| `<leader>dk` | `lua/plugins/editor/debug.lua:49` | Step out | `StepOut` | Exact |
| `<leader>db` | `lua/plugins/editor/debug.lua:56` | Toggle breakpoint | `ToggleLineBreakpoint` | Exact |
| `<leader>dB` | `lua/plugins/editor/debug.lua:63` | Conditional breakpoint UI | `ViewBreakpoints` | Approx |
| `<leader>dr` | `lua/plugins/editor/debug.lua:71` | Toggle debug UI | stateful toggle wrapper on `ActivateDebugToolWindow` + `HideActiveWindow` | Approx |

## 9) Language-specific keys

| Key | Source | Neovim intent | IntelliJ action / mapping | Status |
|---|---|---|---|---|
| `<leader>cR` | `lua/plugins/lang/rust.lua:53` | Rust code action | `ShowIntentionActions` | Approx |
| `<leader>dr` (Rust local) | `lua/plugins/lang/rust.lua:54` | Rust debuggables picker | `ActivateDebugToolWindow` (global) | Approx |
| `<leader>gt` | `lua/plugins/lang/daml.lua:7` | Run Daml script | `Run` | Approx |
| `<localleader>e`/`h`/`r`/`R` | `lua/plugins/lang/haskell.lua:17,23,31,39` | Haskell eval/hoogle/repl | left unmapped (tooling-specific) | N/A |
| `<leader>cp` | `lua/plugins/lang/markdown.lua:74` | Markdown preview toggle | left unmapped (action id differs by IDE/plugin) | N/A |
| `<leader>um` | `lua/plugins/lang/markdown.lua:117` | Render markdown toggle | Neovim-plugin-specific | N/A |

## 10) Contextual mappings (considered, not ported)

These are scoped to custom Neovim plugin UIs and do not have a direct IntelliJ editor-mode analogue:

- `lua/plugins/editor/explorer.lua:103-134` (snacks explorer in-window keys)
- `lua/plugins/editor/neo-tree.lua:37-77` (neo-tree in-window keys)
- `lua/ba/util/git.lua:11,26,172` (`q` for temporary git buffers)
- `lua/plugins/editor/flash.lua:12-16` (`s/S/r/R` flash motions intentionally left as default Vim motions)

## 11) Collisions resolved

- `<leader>dr` has two Neovim meanings (global debug UI and Rust-local debuggables). IntelliJ mapping keeps global debug behavior.
- `<leader>st`/`<leader>sT` appears in multiple plugin files with same TODO-search intent; merged to `ActivateTODOToolWindow`.
- `<leader>e` and `\` both mapped to project explorer, mirroring Neovim.
