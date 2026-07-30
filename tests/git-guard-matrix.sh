#!/bin/bash
# git-guard regression matrix. Cases are built with awk so no bash escape layer
# can mangle them (see docs/progress.md Gotchas: printf eats a backslash level).
H="${1:-/e/Code/cc-discipline/templates/.claude/hooks/git-guard.sh}"
Q='"'
PASS=0; FAIL=0

run() { # run <expect: BLOCK|PASS> <label> <command-string>
    exp="$1"; label="$2"; cmd="$3"
    esc=$(printf '%s' "$cmd" | sed 's/\\/\\\\/g; s/"/\\"/g')
    out=$(printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$esc" | bash "$H" 2>&1)
    rc=$?
    got=$([ $rc -eq 2 ] && echo BLOCK || echo PASS)
    if [ "$got" = "$exp" ]; then PASS=$((PASS+1)); printf "  ok   %-8s %s\n" "$got" "$label"
    else FAIL=$((FAIL+1)); printf "  FAIL want=%-6s got=%-6s %s\n" "$exp" "$got" "$label"; fi
}

echo "── 必须仍然拦截（漏拦 = 丢失未提交工作）──"
run BLOCK "裸 reset --hard"            "git reset --hard HEAD~1"
run BLOCK "裸 clean -fd"               "git clean -fd"
run BLOCK "裸 checkout ."              "git checkout ."
run BLOCK "restore 单文件"             "git restore src/a.py"
run BLOCK "branch -D"                  "git branch -D feat "
run BLOCK "push --force main"          "git push --force origin main"
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
run PASS  "hook 自测豁免"              "echo x | bash .claude/hooks/git-guard.sh"

echo
echo "通过 $PASS / 失败 $FAIL"
[ "$FAIL" -eq 0 ]
