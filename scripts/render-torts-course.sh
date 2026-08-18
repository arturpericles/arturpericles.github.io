#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f _quarto.yml || ! -d teaching/torts ]]; then
  printf 'Run this script from the arturpericles.art repository root.\n' >&2
  exit 2
fi

course_pages=(
  teaching/torts/syllabus-render.md
  teaching/torts/index.md
  teaching/torts/schedule.md
  teaching/torts/policies.md
)

for course_page in "${course_pages[@]}"; do
  quarto render "$course_page" --no-clean
done

for class_page in teaching/torts/classes/*.md; do
  quarto render "$class_page" --no-clean
done
