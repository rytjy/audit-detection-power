#!/usr/bin/env bash
# sloc.sh — **唯一口径**的 SLOC 计数（2026-09-27 立；治 A6「口径不统一」）
#
# 背景：2026-09-27 同一个靶同一天出现过两个不同 SLOC（子线程先报 3,942、后自己更正 4,614）。
#      口径不统一 = 覆盖率不可比 = 收尾结论不可信。所以口径只留**这一处**。
#
# 唯一口径:
#   纳入: in-scope 的 *.sol
#   排除: **搜索根顶层** lib/ · */node_modules/* · */test/* · */tests/* · */script/* · */fixture/*
#         （只排顶层 lib/：contracts/lib/ 这类内层目录是一方代码，必须计数）
#   计数: 非空且非注释行   grep -vcE '^[[:space:]]*(//|/\*|\*|$)'
#
# 用法:
#   sloc.sh <dir|file> [<dir|file> ...]        # 逐文件 + 合计
#   sloc.sh --total <dir|file> ...             # 只输出合计数字
#   sloc.sh --list  <dir|file> ...             # 只输出参与计数的文件（供核对）
#   --include PAT  额外纳入（find -path 模式）
#   --exclude PAT  额外排除
set -uo pipefail

INCLUDE=""; EXCLUDE=""; MODE="table"; ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --total) MODE="total"; shift;;
    --list)  MODE="list";  shift;;
    --include) INCLUDE="$2"; shift 2;;
    --exclude) EXCLUDE="$2"; shift 2;;
    *) ARGS+=("$1"); shift;;
  esac
done
[ ${#ARGS[@]} -eq 0 ] && { echo "用法: sloc.sh [--total|--list] <dir|file> ..." >&2; exit 2; }

# 收集文件
collect() {
  local x
  for x in "${ARGS[@]}"; do
    if [ -f "$x" ] && [[ "$x" == *.sol ]]; then
      echo "$x"
    elif [ -d "$x" ]; then
      # 只排除**该搜索根顶层**的 lib/（contracts/lib/ 之类是一方代码，必须保留）
      find "$x" -name '*.sol' \
        -not -path "$x/lib/*" \
        -not -path '*/node_modules/*' -not -path '*/test/*' -not -path '*/tests/*' \
        -not -path '*/script/*' -not -path '*/fixture/*' 2>/dev/null
    fi
  done | sort -u
}

FILES=$(collect)
[ -z "${INCLUDE}" ] || FILES=$(printf '%s\n%s\n' "$FILES" "$(find ${ARGS[*]} -path "$INCLUDE" -name '*.sol' 2>/dev/null)" | sort -u)
[ -z "${EXCLUDE}" ] || FILES=$(printf '%s\n' "$FILES" | grep -vE "$EXCLUDE" || true)

case "$MODE" in
  list)  printf '%s\n' "$FILES" | grep . ;;
  total) printf '%s\n' "$FILES" | grep . | while IFS= read -r f; do
           grep -vcE '^[[:space:]]*(//|/\*|\*|$)' "$f" 2>/dev/null || echo 0
         done | paste -sd+ | bc ;;
  table)
    printf '%-64s %8s\n' "FILE" "SLOC"
    printf '%s\n' "$FILES" | grep . | while IFS= read -r f; do
      printf '%-64s %8s\n' "${f:0:64}" "$(grep -vcE '^[[:space:]]*(//|/\*|\*|$)' "$f" 2>/dev/null || echo 0)"
    done
    printf '%-64s %8s\n' "TOTAL" "$(printf '%s\n' "$FILES" | grep . | while IFS= read -r f; do grep -vcE '^[[:space:]]*(//|/\*|\*|$)' "$f" 2>/dev/null || echo 0; done | paste -sd+ | bc)"
    ;;
esac
