#!/usr/bin/env bash
# tokens.sh - total tokens the desktop workers have used so far (all run logs, incl. running sessions), deduped per API call
cat ~/felt-work/runs/*.jsonl ~/felt-work/runs/old/*.jsonl 2>/dev/null | jq -r 'select(.type=="assistant" and .message.usage) | [.message.id, (.message.usage.input_tokens//0), (.message.usage.cache_read_input_tokens//0), (.message.usage.cache_creation_input_tokens//0), (.message.usage.output_tokens//0)] | @tsv' 2>/dev/null \
 | awk -F'\t' '!seen[$1]++ {i+=$2; c+=$3; w+=$4; o+=$5; n++} END {printf "%s calls=%d input=%d cache_read=%d cache_write=%d output=%d total=%d\n", strftime("%T"), n, i, c, w, o, i+c+w+o}'
