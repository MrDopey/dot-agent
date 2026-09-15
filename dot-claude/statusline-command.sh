#!/bin/sh
# Claude Code status line — mirrors nuts oh-my-zsh theme (dir git status time)
input=$(cat)

dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
[ -z "$dir" ] && dir=$(pwd)
short_dir=$(echo "$dir" | sed "s|^$HOME|~|")

model=$(echo "$input" | jq -r '.model.display_name // empty')

# Git branch
branch=""
dirty=""
if git_branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$dir" symbolic-ref --short HEAD 2>/dev/null); then
  branch="$git_branch"
elif git_branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$dir" rev-parse --short HEAD 2>/dev/null); then
  branch="$git_branch"
fi
if [ -n "$branch" ]; then
  if ! GIT_OPTIONAL_LOCKS=0 git -C "$dir" diff --quiet 2>/dev/null || ! GIT_OPTIONAL_LOCKS=0 git -C "$dir" diff --cached --quiet 2>/dev/null; then
    dirty="1"
  fi
fi

# Context usage
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')

fmt_tokens() {
  n=$1
  if [ "$n" -ge 1000000 ] 2>/dev/null; then
    awk -v n="$n" 'BEGIN{v=n/1000000; printf (v==int(v)) ? "%dm" : "%.1fm", v}'
  elif [ "$n" -ge 1000 ] 2>/dev/null; then
    awk -v n="$n" 'BEGIN{printf "%dk", int(n/1000+0.5)}'
  else
    printf "%s" "$n"
  fi
}

# Left segment — nuts style: bold cyan dir, blue branch, red/green status dot, then Claude info
left_plain="$short_dir"
left_colored=$(printf "\033[1;36m%s\033[0m" "$short_dir")
if [ -n "$branch" ]; then
  left_plain="$left_plain ($branch) ●"
  left_colored="$left_colored$(printf " \033[34m(%s)\033[0m" "$branch")"
  if [ -n "$dirty" ]; then
    left_colored="$left_colored$(printf " \033[31m●\033[0m")"
  else
    left_colored="$left_colored$(printf " \033[32m●\033[0m")"
  fi
fi
if [ -n "$model" ]; then
  left_plain="$left_plain [$model]"
  left_colored="$left_colored$(printf " \033[36m[%s]\033[0m" "$model")"
fi

# Right segment — token usage + cost
right_plain=""
right_colored=""
if [ -n "$used" ]; then
  if [ -n "$tokens" ]; then
    right_plain=$(printf "usage:%s/%.0f%%" "$(fmt_tokens "$tokens")" "$used")
  else
    right_plain=$(printf "usage:%.0f%%" "$used")
  fi
  right_colored=$(printf "\033[33m%s\033[0m" "$right_plain")
fi
if [ -n "$cost" ]; then
  cost_plain=$(printf "\$%.2f" "$cost")
  cost_colored=$(printf "\033[32m%s\033[0m" "$cost_plain")
  if [ -n "$right_plain" ]; then
    right_plain="$right_plain $cost_plain"
    right_colored="$right_colored $cost_colored"
  else
    right_plain="$cost_plain"
    right_colored="$cost_colored"
  fi
fi

# Assemble — left-align dir/branch/model, right-align usage/cost to terminal width
# Margin accounts for Claude Code rendering the statusline in a slightly narrower
# area than the reported terminal width (COLUMNS is often unset/unreliable here too).
cols="${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}"
margin=4
avail=$((cols - margin))
pad=$((avail - ${#left_plain} - ${#right_plain} - 1))
printf "%s" "$left_colored"
if [ -n "$right_plain" ]; then
  [ "$pad" -lt 1 ] && pad=1
  printf "%*s%s" "$pad" "" "$right_colored"
fi
printf "\n"
