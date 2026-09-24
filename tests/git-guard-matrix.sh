#!/bin/bash
# git-guard regression matrix. Payloads are JSON-escaped by awk, not by printf
# or sed, so no shell escape layer can mangle a case (CLAUDE.md Known Pitfalls:
# printf eats a backslash level) and multi-line commands can be built.
#
# Exit codes are checked exactly: 0 is PASS, 2 is BLOCK, anything else FAILS.
# Claude Code treats any exit other than 2 as a non-blocking error, so a hook
# that crashes lets the command through. Counting a crash as PASS would hide
# exactly the failure that matters.
H="${1:-templates/.claude/hooks/git-guard.sh}"
[ -f "$H" ] || { echo "not found: $H (run from the repo root, or pass the hook path)"; exit 1; }
Q='"'; B='`'; SQ="'"; NL=$'\n'; TB=$'\t'
PASS=0; FAIL=0

jesc() {  # JSON-escape stdin: backslash, double quote, newline, tab, CR
    awk '{ s = (NR == 1) ? $0 : s "\n" $0 }
         END { n = length(s); o = ""
               for (i = 1; i <= n; i++) {
                   c = substr(s, i, 1)
                   if (c == "\\") o = o "\\\\"; else if (c == "\"") o = o "\\\""
                   else if (c == "\n") o = o "\\n"; else if (c == "\t") o = o "\\t"
                   else if (c == "\r") o = o "\\r"; else o = o c
               }
               printf "%s", o }'
}

check() { # check <expect: BLOCK|PASS> <label> <raw JSON payload>
    exp="$1"; label="$2"
    printf '%s' "$3" | PATH="${HOOKPATH:-$PATH}" bash "$H" >/dev/null 2>&1
    rc=$?
    case $rc in 0) got=PASS ;; 2) got=BLOCK ;; *) got="ERROR rc=$rc" ;; esac
    if [ "$got" = "$exp" ]; then PASS=$((PASS+1)); printf "  ok   %-8s %s\n" "$got" "$label"
    else FAIL=$((FAIL+1)); printf "  FAIL want=%-6s got=%-12s %s\n" "$exp" "$got" "$label"; fi
}

run() { # run <expect: BLOCK|PASS> <label> <command-string>
    check "$1" "$2" "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$(printf '%s' "$3" | jesc)\"}}"
}

echo "── 必须仍然拦截（漏拦 = 丢失未提交工作）──"
run BLOCK "裸 reset --hard"            "git reset --hard HEAD~1"
run BLOCK "裸 clean -fd"               "git clean -fd"
run BLOCK "裸 checkout ."              "git checkout ."
run BLOCK "restore 单文件"             "git restore src/a.py"
run BLOCK "branch -D"                  "git branch -D feat "
run BLOCK "push --force main"          "git push --force origin main"
run BLOCK "push --force master"        "git push --force origin master"
run BLOCK "push -f 短标志"             "git push -f origin main"
run BLOCK "push -fu 组合短标志"        "git push -fu origin main"
run BLOCK "push -uf 组合短标志"        "git push -uf origin main"
run BLOCK "push -f refs/heads/main"    "git push -f origin refs/heads/main"
run BLOCK "复合: commit 后接毁灭命令"  "git commit -m ${Q}safe msg${Q} && git reset --hard"
run BLOCK "复合: 分号分隔"             "git add -A; git clean -fd"
run BLOCK "bash -c 包裹"               "bash -c ${Q}git reset --hard${Q}"
run BLOCK "eval 包裹"                  "eval ${Q}git clean -fd${Q}"
run BLOCK "sudo 前缀"                  "sudo git reset --hard"
run BLOCK "-m 之后另起危险命令"        "git commit -m ${Q}msg${Q} ; git checkout ."
run BLOCK "message 参数在前但命令在后" "git commit --message ${Q}x${Q} && git branch -D old "

echo "── 必须放行（本次修的就是这些）──"
run PASS  "提交信息描述 reset --hard"  "git commit -m ${Q}revert the git reset --hard change${Q}"
run PASS  "提交信息描述 clean -fd"     "git commit -m ${Q}document why git clean -fd is blocked${Q}"
run PASS  "单引号提交信息"             "git commit -m 'explain git checkout . danger'"
run PASS  "--message 长形式"           "git commit --message ${Q}about git reset --hard${Q}"
run PASS  "-F 从文件读取信息"          "git commit -F /tmp/msg-about-git-clean-fd.txt"
run PASS  "grep -F 搜索该字符串"       "grep -F ${Q}git reset --hard${Q} docs/"

echo "── 原有安全命令仍放行 ──"
run PASS  "git status"                 "git status"
run PASS  "checkout -b 新分支"         "git checkout -b feature/x"
run PASS  "restore --staged"           "git restore --staged a.py"
run PASS  "branch -d 安全删除"         "git branch -d merged "
run PASS  "push 普通"                  "git push origin main"
# v2.13.6 回归：这四条以前全部误报
run PASS  "push 同行带 --format"       "git push origin main && git log -1 --format=%h"
run PASS  "--force-with-lease"         "git push --force-with-lease origin main"
run PASS  "push --follow-tags"         "git push --follow-tags origin main"
run PASS  "force 到非主干分支"         "git push -f origin feature-x"
run PASS  "hook 自测豁免"              "echo x | bash .claude/hooks/git-guard.sh"

echo "── Codex 2026-09-23：14 条漏拦（必须拦）──"
run BLOCK "#1 hook 路径不豁免整条命令"      "echo x | bash .claude/hooks/git-guard.sh && git reset --hard"
run BLOCK "#2 -m 里的 \$(...)"              "git commit -m ${Q}\$(git reset --hard)${Q}"
run BLOCK "#3 -m 里的反引号"                "git commit -m ${Q}${B}git reset --hard${B}${Q}"
run BLOCK "#4 checkout -f"                  "git checkout -f main"
run BLOCK "#5 restore --staged --worktree"  "git restore --staged --worktree src/a.py"
run BLOCK "#6 --staged 不跨 &&"             "git restore --staged a && git restore b"
run BLOCK "#7 clean -d -f"                  "git clean -d -f"
run BLOCK "#8 clean --force -d"             "git clean --force -d"
run BLOCK "#9 branch --delete --force"      "git branch --delete --force old"
run BLOCK "#10 git -C"                      "git -C repo reset --hard"
run BLOCK "#11 --git-dir / --work-tree"     "git --git-dir=.git --work-tree=. reset --hard"
run BLOCK "#12 push -f 隐式上游"            "git push -f"
run BLOCK "#13 push +main"                  "git push origin +main"
run BLOCK "#14 强推后再接一次 push"         "git push -f origin main && git push origin dev"

echo "── 解析器细节（必须拦）──"
run BLOCK "引号里带空格的 -C 路径"          "git -C ${Q}my repo${Q} reset --hard"
run BLOCK "--attr-source 分开写"            "git --attr-source HEAD reset --hard"
run BLOCK "不认识的长参数：两种读法都查"    "git --future-opt val reset --hard"
run BLOCK "子 shell"                        "(cd sub && git reset --hard)"
run BLOCK "全局参数里的 \$(...)"            "git -C ${Q}\$(pwd)${Q} reset --hard"
run BLOCK "绝对路径的 git"                  "/usr/bin/git clean -fd"
run BLOCK "clean -xdf 簇"                   "git clean -xdf"
run BLOCK "branch -df 簇"                   "git branch -df old"
run BLOCK "checkout ./路径（旧行为）"       "git checkout ./src/a.py"
run BLOCK "sh -c 单引号"                    "sh -c ${SQ}git clean -fd${SQ}"
run BLOCK "管道头是 git，不算 hook 自测"    "git reset --hard | bash .claude/hooks/git-guard.sh"
run BLOCK "换行分隔"                        "git status${NL}git reset --hard"
run BLOCK "反斜杠续行"                      "git reset \\${NL}--hard"
run PASS  "写进文件的 heredoc 正文是数据"   "cat > notes.md <<${SQ}EOF${SQ}${NL}run git reset --hard to undo${NL}EOF"
run BLOCK "heredoc 里的撇号不吞后面的命令"  "cat > f.txt <<${SQ}EOF${SQ}${NL}don${SQ}t${NL}EOF${NL}git reset --hard"
run BLOCK "提交 heredoc 后面还有命令"       "git commit -m ${Q}\$(cat <<${SQ}EOF${SQ}${NL}msg${NL}EOF${NL}git reset --hard${NL})${Q}"
run BLOCK "定界符没加引号，正文会展开"      "git commit -m ${Q}\$(cat <<EOF${NL}\$(git reset --hard)${NL}EOF${NL})${Q}"
run BLOCK "重定向后的隐式强推"              "git push -f 2>&1"
run BLOCK "push --force HEAD:main"          "git push --force origin HEAD:main"

echo "── 必须放行（新解析器不许误拦）──"
run PASS  "提交 heredoc 提到 reset --hard"  "git commit -m ${Q}\$(cat <<${SQ}EOF${SQ}${NL}revert the git reset --hard change${NL}${NL}Co-Authored-By: x${NL}EOF${NL})${Q}"
run PASS  "提交 heredoc 正文有 1)"          "git commit -m ${Q}\$(cat <<${SQ}EOF${SQ}${NL}fix: 1) drop the git reset --hard path${NL}EOF${NL})${Q}"
run PASS  "提交 heredoc 正文有双引号"       "git commit -m ${Q}\$(cat <<${SQ}EOF${SQ}${NL}say ${Q}hi${Q} before git reset --hard${NL}EOF${NL})${Q}"
run PASS  "git -C 后面是安全命令"           "git -C repo status"
run PASS  "--no-pager 后面是 log"           "git --no-pager log --oneline -3"
run PASS  "--staged 只管自己那条"           "git restore --staged a && git status"
run PASS  "强推功能分支，另一条普通推 main" "git push -f origin feature-x && git push origin main"
run PASS  "CLAUDE.md 里的 hook 自测写法"    "echo ${SQ}{${Q}tool_name${Q}:${Q}Bash${Q},${Q}tool_input${Q}:{${Q}command${Q}:${Q}git checkout .${Q}}}${SQ} | bash templates/.claude/hooks/git-guard.sh 2>&1"
run PASS  "git grep 搜 restore"             "git grep -n restore -- src/"
run PASS  "推 +功能分支"                    "git push origin +feature-x"

echo "── 负载解析 ──"
check PASS  "description 提到危险命令"      '{"tool_name":"Bash","tool_input":{"command":"git status","description":"explain why git reset --hard is blocked"}}'
check PASS  "非 Bash 工具"                  '{"session_id":"t","tool_name":"Edit","tool_input":{"file_path":"x.sh"}}'
check BLOCK "更早的同名键不能冒充命令"      '{"session_id":"s","meta":{"command":"ls"},"tool_name":"Bash","tool_input":{"command":"git reset --hard"}}'
check BLOCK "tool_input 在 tool_name 前面"  '{"tool_input":{"command":"git reset --hard"},"tool_name":"Bash"}'
check BLOCK "字符串里的 command 不算键"     '{"tool_name":"Bash","tool_input":{"description":"the \"command\": field","command":"git reset --hard"}}'
check BLOCK "找不到 command 就查整个负载"   '{"tool_name":"Bash","tool_input":{"cmd":"git reset --hard"}}'

echo "── Codex 代码评审 2026-09-24（必须拦）──"
run BLOCK "\$(...) 里引号中的 ) 不能提前收尾"     "git commit -m ${Q}\$(printf ${SQ}1) update${SQ}; git reset --hard)${Q}"
run BLOCK "同上，落在 hook 自测豁免段里"         "echo ${Q}\$(printf ${SQ})${SQ}; git reset --hard)${Q} | bash .claude/hooks/git-guard.sh"
run BLOCK "push -o 吃掉一个值"                   "git push -f -o ci.skip origin"
run BLOCK "push --push-option 吃掉一个值"        "git push -f --push-option ci.skip origin"
run BLOCK "push -f4 带数字的簇"                  "git push -f4 origin main"
run BLOCK "push -f6 带数字的簇"                  "git push -f6 origin master"
run BLOCK "|| 分隔"                              "git status || git reset --hard"
run BLOCK "& 后台"                               "git reset --hard &"
run BLOCK "|& 管道"                              "git clean -fd |& tee clean.log"
run BLOCK "-c 吃掉一个值"                        "git -c core.pager=cat reset --hard"
run BLOCK "--namespace 分开写"                   "git --namespace ns reset --hard"
run BLOCK "--config-env 分开写"                  "git --config-env core.x=HOME reset --hard"
run BLOCK "--git-dir / --work-tree 分开写"       "git --git-dir .git --work-tree . reset --hard"
run BLOCK "git.exe"                              "git.exe reset --hard"
run BLOCK "Windows 路径的 git.exe"               "${Q}C:\\Program Files\\Git\\cmd\\git.exe${Q} reset --hard"
run BLOCK "大小写混写的 Git"                     "Git reset --hard"
run BLOCK "注释只到行尾"                         "# note${NL}git reset --hard"
run BLOCK "行尾注释之后的下一行照查"             "git status # ok${NL}git clean -fd"

echo "── Codex 代码评审 2026-09-24（必须放行）──"
run PASS  "行尾注释提到危险命令"                 "git status # do not run git reset --hard"
run PASS  "-m 与 heredoc 之间有续行"             "git commit -m \\${NL}${Q}\$(cat <<${SQ}EOF${SQ}${NL}explain git reset --hard${NL}EOF${NL})${Q}"
run PASS  "push -o 普通推送"                     "git push -o ci.skip origin feature-x"
run PASS  "push -f -o 推功能分支"                "git push -f -o ci.skip origin feature-x"
run PASS  "heredoc 定界符用双引号"               "git commit -m ${Q}\$(cat <<${Q}EOF${Q}${NL}revert the git reset --hard change${NL}EOF${NL})${Q}"
run PASS  "heredoc 定界符用反斜杠"               "git commit -m ${Q}\$(cat <<\\EOF${NL}revert the git reset --hard change${NL}EOF${NL})${Q}"
run PASS  "heredoc <<- 与缩进的结束行"           "git commit -m ${Q}\$(cat <<-${SQ}EOF${SQ}${NL}${TB}revert the git reset --hard change${NL}${TB}EOF${NL})${Q}"
run PASS  "-m 紧贴信息"                          "git commit -m${Q}revert the git reset --hard change${Q}"
run PASS  "--message= 形式"                      "git commit --message=${Q}about git reset --hard${Q}"
run PASS  "-F 紧贴文件名"                        "git commit -F${Q}notes on git reset --hard.txt${Q}"
run PASS  "--file= 形式"                         "git commit --file=${Q}notes on git clean -fd.txt${Q}"
run PASS  "hook 自测前面带 VAR=值"               "echo ${SQ}{${Q}command${Q}:${Q}git clean -fd${Q}}${SQ} | PATH=/x bash .claude/hooks/git-guard.sh"

echo "── 2.14.0 试用反馈：heredoc 正文（必须放行：只是数据）──"
run PASS  "cat >> 追加说明文字"                   "cat >> docs/progress.md <<${SQ}EOF${SQ}${NL}- 坑: 不要 git reset --hard${NL}EOF"
run PASS  "git commit -F - 读 heredoc"            "git commit -F - <<${SQ}EOF${SQ}${NL}fix: 上次误用了 git reset --hard${NL}EOF"
run PASS  "tee -a 追加"                           "tee -a notes.md <<${SQ}EOF${SQ}${NL}never git clean -fd here${NL}EOF"
run PASS  "markdown 反引号片段"                   "cat >> notes.md <<${SQ}EOF${SQ}${NL}- avoid ${B}git reset --hard${B} and ${B}git push -f${B}${NL}EOF"
run PASS  "管道只接 tee"                          "cat <<${SQ}EOF${SQ} | tee notes.md${NL}git checkout -- x is dangerous${NL}EOF"
run PASS  "管道接 git commit -F -"                "cat <<${SQ}EOF${SQ} | git commit -F -${NL}undo git reset --hard${NL}EOF"
LONG=""; i=0; while [ $i -lt 110 ]; do LONG="${LONG}- ${B}git log${B} then ${B}git push${B} (case $i)${NL}"; i=$((i+1)); done
run PASS  "ziiqii 复现：长笔记里 220 个 git 片段" "cat >> docs/progress.md <<${SQ}EOF${SQ}${NL}${LONG}EOF"

echo "── 2.14.0 试用反馈：heredoc 正文（必须拦：会被执行）──"
run BLOCK "喂给 bash"                             "bash <<${SQ}EOF${SQ}${NL}git reset --hard${NL}EOF"
run BLOCK "sudo bash"                             "sudo bash <<${SQ}EOF${SQ}${NL}git reset --hard${NL}EOF"
run BLOCK "cat 经管道进 bash"                     "cat <<${SQ}EOF${SQ} | bash${NL}git reset --hard${NL}EOF"
run BLOCK "先写脚本再用 bash 执行"                "cat > x.sh <<${SQ}EOF${SQ}${NL}git reset --hard${NL}EOF${NL}bash x.sh"
run BLOCK "先写脚本再 ./ 执行"                    "cat > x.sh <<${SQ}EOF${SQ}${NL}git clean -fd${NL}EOF${NL}chmod +x x.sh && ./x.sh"
run BLOCK "先写 py 再用 python 执行"              "cat > x.py <<${SQ}EOF${SQ}${NL}import os; os.system(${Q}git reset --hard${Q})${NL}EOF${NL}python3 x.py"
run BLOCK "喂给 python3 -"                        "python3 - <<${SQ}EOF${SQ}${NL}import os; os.system(${Q}git reset --hard${Q})${NL}EOF"
run BLOCK "喂给 ssh"                              "ssh host <<${SQ}EOF${SQ}${NL}cd repo && git reset --hard${NL}EOF"
run BLOCK "命令替换里的 heredoc 交给 bash -c"     "bash -c ${Q}\$(cat <<${SQ}EOF${SQ}${NL}git reset --hard${NL}EOF${NL})${Q}"
run BLOCK "进程替换里的 heredoc"                  "bash <(cat <<${SQ}EOF${SQ}${NL}git reset --hard${NL}EOF${NL})"
run BLOCK "未加引号的定界符：正文里的 \$(...)"   "cat > notes.md <<EOF${NL}\$(git reset --hard)${NL}EOF"
run BLOCK "未加引号的定界符：正文里的反引号"      "cat > notes.md <<EOF${NL}${B}git reset --hard${B}${NL}EOF"
run BLOCK "写脚本文件（没执行）也是代码"          "cat > x.sh <<${SQ}EOF${SQ}${NL}git reset --hard${NL}EOF"
run BLOCK "写 git hook 也是代码"                  "cat > .git/hooks/pre-commit <<${SQ}EOF${SQ}${NL}git reset --hard${NL}EOF"
run BLOCK "tee 写脚本也是代码"                    "tee deploy.sh <<${SQ}EOF${SQ}${NL}git clean -fd${NL}EOF"
run BLOCK "写到 bin/ 下也是代码"                  "cat > bin/cleanup <<${SQ}EOF${SQ}${NL}git clean -fd${NL}EOF"

echo "── 2.14.0 试用反馈：stash ──"
run BLOCK "stash drop"                            "git stash drop"
run BLOCK "stash drop 指定条目"                   "git stash drop stash@{1}"
run BLOCK "stash clear"                           "git stash clear"
run PASS  "stash list"                            "git stash list"
run PASS  "stash pop"                             "git stash pop"
run PASS  "stash push -m"                         "git stash push -m ${Q}wip${Q}"

# The fallback path: when awk gives no verdict the wrapper runs a coarse text
# check. Force that path with a stand-in awk that prints nothing and exits 1.
echo "── awk 出错或溢出时的兜底 ──"
SHIM=$(mktemp -d)
printf '#!/bin/sh\ncat >/dev/null\nexit 1\n' > "$SHIM/awk"; chmod +x "$SHIM/awk"
shim() { # shim <expect> <label> <command-string> — the hook runs with the broken awk
    p="{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$(printf '%s' "$3" | jesc)\"}}"
    HOOKPATH="$SHIM:$PATH"; check "$1" "$2" "$p"; HOOKPATH=""
}
shim BLOCK "awk 坏了：危险命令仍拦"              "git reset --hard"
shim PASS  "awk 坏了：非 git 命令放行"           "ls -la"
shim PASS  "awk 坏了：git 但不是受保护子命令"    "git status"
rm -rf "$SHIM"
# Distinct strings: identical ones are judged once (the queue dedupes), so only
# more than QMAX (1000) different pieces can overflow it.
OV=""; i=0; while [ $i -lt 1001 ]; do OV="${OV}echo ${Q}git log $i${Q}; "; i=$((i+1)); done
run BLOCK "工作队列溢出：粗检查兜底拦"          "${OV}git push origin feature-x"
run PASS  "工作队列溢出：没有受保护子命令就放行" "${OV}ls"
BIG=""; i=0; while [ $i -lt 1200 ]; do BIG="${BIG}some text for a large file, nothing special here 0123456789${NL}"; i=$((i+1)); done
run PASS  "超过 64KB：不提受保护子命令就放行"   "cat > big.txt <<${SQ}EOF${SQ}${NL}${BIG}EOF"
run BLOCK "超过 64KB：粗检查兜底拦"             "cat > big.txt <<${SQ}EOF${SQ}${NL}${BIG}EOF${NL}git push -f"

echo
echo "通过 $PASS / 失败 $FAIL"
[ "$FAIL" -eq 0 ]
