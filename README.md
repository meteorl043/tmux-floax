FloaX - Floating panes in Tmux!
============

![image](./img/floaxv3.png)

> ### 🔧 This is a maintained fork
>
> Upstream [`omerxx/tmux-floax`](https://github.com/omerxx/tmux-floax) has slowed down
> considerably — a single maintainer, **25 open issues and 12 open pull requests**, several of
> which have been sitting for well over a year. Some of those issues (a floating pane that hangs
> tmux, an embed that silently does nothing) made the plugin unusable for us, so this fork exists
> to carry the fixes.
>
> **Everything here is on `main` and is drop-in compatible with upstream** — same options, same
> keybindings, no migration needed. See [What's fixed](#whats-fixed-) for the details.
>
> 中文说明见 [下方](#floax--tmux-浮动窗格)。

## Install 💻

Tmux version 3.3 or newer is required to use this plugin.

Add this to your `.tmux.conf` and run `<prefix>+I` for TPM to install the plugin.
```conf
set -g @plugin 'meteorl043/tmux-floax'
```

Already using upstream? Change the line above, then remove the old checkout so TPM re-clones it:

```bash
rm -rf ~/.tmux/plugins/tmux-floax   # or ~/.config/tmux/plugins/tmux-floax
```

## What's fixed 🩹

Eight defects found and fixed here, plus three pull requests upstream never merged, relative to
upstream `133f526`.

### Found and fixed in this fork

| # | Defect | Symptom |
|---|--------|---------|
| 1 | `embed.sh` defined its own `pop()`, shadowing the `pop()` in `utils.sh` that actually opens the popup. Bash resolves function names at call time, so the later definition won: `tmux_popup() → pop()` re-entered `tmux_popup()`. | **Infinite recursion.** One keypress dragged window after window into the floating session until tmux wedged, and the popup never actually opened. Likely the root cause of [#8](https://github.com/omerxx/tmux-floax/issues/8), [#20](https://github.com/omerxx/tmux-floax/issues/20) and [#44](https://github.com/omerxx/tmux-floax/issues/44). |
| 2 | `-t "$SESSION"` is parsed as a **window index** before it is tried as a session name. | With tmux's default numeric session names (`0`, `1`, …), `movew -t 0` moved the window *inside* the floating session instead of back. Embed appeared to do nothing. All session targets now use the `=name:` form. |
| 3 | The pop path never recorded `ORIGIN_SESSION`. | Embed had no idea where to send the window back to. |
| 4 | Bare `tmux detach-client` (6 call sites). | tmux picks "the current client", frequently the **outer** one — detaching your whole terminal instead of closing the popup. |
| 5 | The pop path never called `set_bindings`, while `embed()` calls `unset_bindings`. | The advertised `C-M-*` keys (including `C-M-e` to embed) were gone for good after the first embed. |
| 6 | `movew` with no `-s` in both directions. | tmux resolves "current window" from whichever client it deems most recent — often the wrong one, and the move degenerates into a silent no-op. |
| 7 | `neww -d` had no target. | The placeholder window that keeps the floating session alive could land in an arbitrary session. |
| 8 | `tmux bind -n c-M-b` (lowercase `c`). | Zoom-out was never bound. |

### Cherry-picked from unmerged upstream PRs

| PR | Fix |
|----|-----|
| [#72](https://github.com/omerxx/tmux-floax/pull/72) | Don't `send-keys "cd …"` into the floating pane when a TUI (nvim, lazygit, htop…) is in the foreground — the keys went to the TUI and broke it. Adds [`@floax-shell-commands`](#additional-configuration-options). |
| [#66](https://github.com/omerxx/tmux-floax/pull/66) | Restore the original popup title after unlocking bindings, instead of leaving it stuck on `Bindings locked. Unlock with [Ctrl-Alt-u]`. |
| [#70](https://github.com/omerxx/tmux-floax/pull/70) (adapted) | Two bugs: (a) every zoom/title action closes and reopens the popup, but after `detach-client` there is no "current client" for tmux to hang it on, so the re-pop landed on the wrong client or failed; (b) `popup -b rounded` spends one row/column per side on the border, so `#{window_width}` read from *inside* the popup is 2 less than the `-w` that produced it — feeding that straight back made every resize step drift, with zoom-in shrinking by 3 instead of 5 and zoom-out growing by 7. |

Adapted, not merged verbatim: the upstream PR duplicated `pop()` into a `pop_with_client()` twin
(replaced here by a `FLOAX_TARGET_CLIENT` variable that `pop()` forwards as `popup -c`), and its
`unlock_bindings` reset the title to the hardcoded default, discarding any custom `@floax-title`.

### Deliberately not taken

- [#54](https://github.com/omerxx/tmux-floax/pull/54) — `kill-session` when the popup closes destroys whatever was running in the scratch session, which is the entire point of a scratch session.
- [#42](https://github.com/omerxx/tmux-floax/pull/42) — already superseded by `sed 's/[^0-9.]//g'` on upstream `main`.
- [#61](https://github.com/omerxx/tmux-floax/pull/61), [#69](https://github.com/omerxx/tmux-floax/pull/69) — same bugs as #2 and #8 above; the fixes here are supersets.
- [#43](https://github.com/omerxx/tmux-floax/pull/43), [#51](https://github.com/omerxx/tmux-floax/pull/51), [#68](https://github.com/omerxx/tmux-floax/pull/68), [#71](https://github.com/omerxx/tmux-floax/pull/71) — feature work and refactors, out of scope for a bugfix fork.

### How this was verified

In an isolated tmux server driven by a real pty client, with a numerically named session (`0`) to
exercise the target-resolution bugs: pop → resize → lock/unlock → embed, then two further round
trips, both with and without a pre-existing floating session, plus a check that the `C-M-*`
bindings are live exactly while the pane is popped and released afterwards.

## Using the internal menu 📃
The menu (set with `@floax-bind-menu` and defaults to `<prefix>+P`) will appear when running a floating pane.
When triggered from a non floating window, the only option currently is to pop the window out to the floating pane.
Unless disabled, the same keys are also bound to the root table (can be used without Tmux prefix) only when using the floating pane.
The options are also listed in the title (unless it was configured differently).
Standard menu options (followed by their hotkey):
- Size down (-): Decrease overall size
- Size up (+): Increase overall size
- Fullscreen: Toggles the pane to 100% of the screen's space
- Reset: Sets the pane's size back to the default settings
- Embed: sends the floating panes window to the working space under it

## Configure ⚙️

The default binding for this plugin is `<prefix>+p` (and `<prefix>+P` for the internal menu)
You can change it by adding this line with your desired key:

```bash
set -g @floax-bind '<mykey>'
```

### Root Binding

If you want to toggle floax without `<prefix>` (e.g. `Alt+p`), you can do so by prepending `-n`:

```bash
# M- means "hold Meta/Alt"
set -g @floax-bind '-n M-p'
```

### Additional configuration options:

```bash
# Setting the main key to toggle the floating pane on and off
set -g @floax-bind '<my-key>'

# When the pane is toggled, using this bind pops a menu with additional options
# such as resize, fullscreen, resetting to defaults and more.
set -g @floax-bind-menu 'P'

# The default width and height of the floating pane
set -g @floax-width '80%'
set -g @floax-height '80%'

# The border color can be changed, these are the colors supported by Tmux:
# black, red, green, yellow, blue, magenta, cyan, white for the standard
# terminal colors; brightred, brightyellow and so on for the bright variants;
# colour0/color0 to colour255/color255 for the colors from the 256-color
# palette; default for the default color; or a hexadecimal RGB color such as #882244.
set -g @floax-border-color 'magenta'

# The text color can also be changed, by default it's blue 
# to distinguish from the main window
# Optional colors are as shown above in @floax-border-color
set -g @floax-text-color 'blue'

# By default when floax sees a change in session path 
# it'll change the floating pane's path
# You can disable this by setting it to false
# You could also "cd -" when the pane is toggled to go back
set -g @floax-change-path 'true'

# When @floax-change-path is true, floax sends a `cd <path>` to the floating
# pane's shell. If a TUI (nvim, lazygit, htop, ...) is in the foreground of
# that pane, those keys would be interpreted by the TUI instead — usually
# breaking it. Floax therefore only sends `cd` when the pane's foreground
# process matches one of the known shell commands below. Override the list
# to add other shells (e.g. nushell, xonsh):
set -g @floax-shell-commands 'zsh bash fish sh dash ksh'

# The default session name of the floating pane is 'scratch'
# You can modify the session name with this option:
set -g @floax-session-name 'some-other-session-name'

# Change the title of the floating window
set -g @floax-title 'floax'
```

## Staying in sync with upstream 🔄

```bash
cd ~/.tmux/plugins/tmux-floax
git remote add upstream https://github.com/omerxx/tmux-floax   # once
git fetch upstream && git rebase upstream/main
```

## Contributors 🙌

All original credit goes to [@omerxx](https://github.com/omerxx) and the upstream contributors:

<a href="https://github.com/omerxx/tmux-floax/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=omerxx/tmux-floax" />
</a>

Made with [contrib.rocks](https://contrib.rocks).

---

FloaX — Tmux 浮动窗格
============

> ### 🔧 这是一个维护中的 fork
>
> 上游 [`omerxx/tmux-floax`](https://github.com/omerxx/tmux-floax) 基本停滞了 —— 单人维护，
> **25 个 issue 和 12 个 PR 悬而未决**，其中不少已经挂了一年多。有几个问题（浮动窗格把 tmux
> 卡死、嵌入回去毫无反应）直接让插件不可用，所以有了这个 fork。
>
> **所有修复都在 `main` 上，与上游完全兼容** —— 配置项、快捷键都一样，不需要迁移。详见
> [修了什么](#修了什么-)。

## 安装 💻

需要 tmux 3.3 或更新版本。

在 `.tmux.conf` 中加入下面这行，然后按 `<prefix>+I` 让 TPM 安装：
```conf
set -g @plugin 'meteorl043/tmux-floax'
```

原本用的是上游？改完上面这行后删掉旧目录，让 TPM 重新克隆：

```bash
rm -rf ~/.tmux/plugins/tmux-floax   # 或 ~/.config/tmux/plugins/tmux-floax
```

## 修了什么 🩹

相对上游 `133f526`：本 fork 自己发现并修复了 8 个缺陷，另外挑了 3 个上游一直没合的 PR。

### 本 fork 发现并修复

| # | 缺陷 | 症状 |
|---|------|------|
| 1 | `embed.sh` 自己定义了一个 `pop()`，覆盖了 `utils.sh` 里那个真正打开浮动窗口的 `pop()`。bash 在**调用时**才解析函数名，所以后定义的胜出：`tmux_popup() → pop()` 又回到了 `tmux_popup()`。 | **无限递归。** 一次按键就把一个又一个窗口拖进浮动会话，直到 tmux 卡死，而浮动窗口自始至终没真正弹出过。多半就是 [#8](https://github.com/omerxx/tmux-floax/issues/8)、[#20](https://github.com/omerxx/tmux-floax/issues/20)、[#44](https://github.com/omerxx/tmux-floax/issues/44) 的根因。 |
| 2 | `-t "$SESSION"` 会先按**窗口索引**解析，解析不了才当会话名。 | 用 tmux 默认的数字会话名（`0`、`1`……）时，`movew -t 0` 把窗口移到了浮动会话*内部*，而不是移回去 —— 表现为嵌入没反应。现在所有会话目标一律写成 `=name:` 形式。 |
| 3 | pop 路径从不记录 `ORIGIN_SESSION`。 | 嵌入时根本不知道该把窗口送回哪里。 |
| 4 | 裸 `tmux detach-client`（6 处）。 | tmux 会挑"当前客户端"，而这经常是**外层**那个 —— 于是断开的是你整个终端，而不是关掉弹窗。 |
| 5 | pop 路径从不调用 `set_bindings`，而 `embed()` 会调用 `unset_bindings`。 | 第一次嵌入之后，标题里宣传的那些 `C-M-*` 键（包括用于嵌入的 `C-M-e`）就永久失效了。 |
| 6 | 两个方向的 `movew` 都不带 `-s`。 | tmux 从"它认为最近的那个客户端"推断当前窗口 —— 经常推错，于是整个移动退化成静默空转。 |
| 7 | `neww -d` 没有指定目标。 | 那个用来保活浮动会话的占位窗口可能落到任意会话里。 |
| 8 | `tmux bind -n c-M-b`（小写 `c`）。 | 缩小从来就没绑上过。 |

### 挑自上游未合并的 PR

| PR | 修复内容 |
|----|---------|
| [#72](https://github.com/omerxx/tmux-floax/pull/72) | 浮动窗格前台跑着 TUI（nvim、lazygit、htop……）时，不再往里 `send-keys "cd …"` —— 这些按键会被 TUI 吃掉并搞乱它。新增 [`@floax-shell-commands`](#其他配置项)。 |
| [#66](https://github.com/omerxx/tmux-floax/pull/66) | 解锁按键绑定后恢复原标题，而不是一直卡在 `Bindings locked. Unlock with [Ctrl-Alt-u]`。 |
| [#70](https://github.com/omerxx/tmux-floax/pull/70)（改编） | 两个 bug：(a) 每次缩放/改标题都要关掉弹窗再开一个，但 `detach-client` 之后已经没有"当前客户端"可以挂载，于是重开落到了错的客户端上，或者干脆失败；(b) `popup -b rounded` 每边占掉一行/一列边框，所以在弹窗*内部*读到的 `#{window_width}` 比生成它的 `-w` 小 2 —— 直接回填就导致每次缩放都漂移，放大名义 5 实际只有 3，缩小名义 5 实际掉了 7。 |

之所以说"改编"：上游那个 PR 把 `pop()` 复制成了一个 `pop_with_client()` 孪生函数（这里改成一个
`FLOAX_TARGET_CLIENT` 变量，由 `pop()` 转成 `popup -c`）；而且它的 `unlock_bindings` 把标题重置
成硬编码的默认值，会丢掉用户自定义的 `@floax-title`。

### 有意没挑的

- [#54](https://github.com/omerxx/tmux-floax/pull/54) —— 弹窗一关就 `kill-session`，scratch 会话里跑的东西全没了，而这恰恰是 scratch 会话存在的意义。
- [#42](https://github.com/omerxx/tmux-floax/pull/42) —— 上游 `main` 里的 `sed 's/[^0-9.]//g'` 已经覆盖了。
- [#61](https://github.com/omerxx/tmux-floax/pull/61)、[#69](https://github.com/omerxx/tmux-floax/pull/69) —— 就是上面的 #2 和 #8，这里的修复是超集。
- [#43](https://github.com/omerxx/tmux-floax/pull/43)、[#51](https://github.com/omerxx/tmux-floax/pull/51)、[#68](https://github.com/omerxx/tmux-floax/pull/68)、[#71](https://github.com/omerxx/tmux-floax/pull/71) —— 新功能和重构，超出一个 bugfix fork 的范围。

### 怎么验证的

在隔离的 tmux server 上、用真实 pty 客户端驱动，并特意使用数字会话名（`0`）来触发目标解析类
缺陷：pop → 缩放 → 锁定/解锁 → 嵌入，再跑两轮往返，浮动会话预先存在和不存在两种情况都测；
另外验证 `C-M-*` 绑定恰好在弹出期间生效、嵌入后释放。

## 使用内置菜单 📃

菜单（由 `@floax-bind-menu` 设置，默认 `<prefix>+P`）在浮动窗格运行时弹出。
从非浮动窗口触发时，目前唯一的选项是把当前窗口弹出到浮动窗格。
除非禁用，同样这些键也会绑到 root 表（不需要 tmux prefix），但仅在使用浮动窗格时有效。
这些选项也会列在标题里（除非另行配置）。
标准菜单项（后面是热键）：
- Size down (-)：缩小整体尺寸
- Size up (+)：放大整体尺寸
- Fullscreen：切换到占满屏幕
- Reset：尺寸恢复默认
- Embed：把浮动窗格的窗口送回下面的工作区

## 配置 ⚙️

插件默认绑定是 `<prefix>+p`（内置菜单是 `<prefix>+P`）。改成你想要的键：

```bash
set -g @floax-bind '<mykey>'
```

### Root 绑定

想不带 `<prefix>` 直接切换（例如 `Alt+p`），加个 `-n` 前缀：

```bash
# M- 表示按住 Meta/Alt
set -g @floax-bind '-n M-p'
```

### 其他配置项

```bash
# 切换浮动窗格的主键
set -g @floax-bind '<my-key>'

# 浮动窗格开启时，这个键弹出菜单，提供缩放、全屏、恢复默认等选项
set -g @floax-bind-menu 'P'

# 浮动窗格的默认宽高
set -g @floax-width '80%'
set -g @floax-height '80%'

# 边框颜色，支持 tmux 的颜色写法：
# black、red、green、yellow、blue、magenta、cyan、white 是标准终端色；
# brightred、brightyellow 等是亮色变体；colour0/color0 到 colour255/color255
# 取自 256 色板；default 表示默认色；也可以写十六进制 RGB，如 #882244。
set -g @floax-border-color 'magenta'

# 文字颜色，默认 blue，用于和主窗口区分
# 可选颜色同上
set -g @floax-text-color 'blue'

# 默认情况下，floax 发现会话路径变化时会同步切换浮动窗格的路径
# 设为 false 可以关掉
# 也可以在切换时用 "cd -" 退回去
set -g @floax-change-path 'true'

# @floax-change-path 为 true 时，floax 会往浮动窗格的 shell 里发送 `cd <path>`。
# 如果那个窗格前台正跑着 TUI（nvim、lazygit、htop……），这些按键会被 TUI 接走 ——
# 通常就把它搞乱了。所以 floax 只在窗格前台进程匹配下面这份已知 shell 列表时才发送 `cd`。
# 想支持别的 shell（例如 nushell、xonsh）就改这个列表：
set -g @floax-shell-commands 'zsh bash fish sh dash ksh'

# 浮动窗格的默认会话名是 'scratch'，可以这样改：
set -g @floax-session-name 'some-other-session-name'

# 修改浮动窗口的标题
set -g @floax-title 'floax'
```

## 跟进上游 🔄

```bash
cd ~/.tmux/plugins/tmux-floax
git remote add upstream https://github.com/omerxx/tmux-floax   # 只需一次
git fetch upstream && git rebase upstream/main
```

## 贡献者 🙌

原始功劳全部归 [@omerxx](https://github.com/omerxx) 和上游贡献者：

<a href="https://github.com/omerxx/tmux-floax/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=omerxx/tmux-floax" />
</a>

Made with [contrib.rocks](https://contrib.rocks).
