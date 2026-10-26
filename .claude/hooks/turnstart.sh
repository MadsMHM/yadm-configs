#!/bin/bash
# UserPromptSubmit: record turn start time so notify.sh only pings on long turns.
sid=$(jq -r '.session_id // empty')
[ -n "$sid" ] && date +%s > "/tmp/claude-turnstart-${sid}"
exit 0
