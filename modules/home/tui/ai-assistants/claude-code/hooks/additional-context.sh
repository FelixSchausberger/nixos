#!/usr/bin/env bash
set -euo pipefail

# Claude Code hook to inject additional context for all user prompts
# Provides default development principles and communication guidelines

# Define the additional context to inject
context="Unless otherwise specified: DRY, YAGNI, KISS, Pragmatic. Ask questions for clarifications. When doing a plan or research-like request, present your findings and halt for confirmation. Use raggy first to find documentation. Speak the facts, don't sugar coat statements. Your opinion matters. End all responses with an emoji of an animal"

# Output the hook response in correct JSON format
# When called by orchestrator, output JSON that it can parse
jq -n \
	--arg ctx "$context" \
	'{
    additionalContext: $ctx
  }'

exit 0
