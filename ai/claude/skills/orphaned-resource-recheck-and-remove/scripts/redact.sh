#!/usr/bin/env bash
# Masks credential-shaped values so recheck/removal output stays safe to
# paste into chat, tickets, or a stakeholder message. Source this file
# and pipe any command output through `redact`.

redact() {
  sed -E \
    -e 's/AKIA[0-9A-Z]{16}/AKIA****************/g' \
    -e 's/(aws_secret_access_key *= *)[A-Za-z0-9\/+=]{40}/\1****REDACTED****/g' \
    -e 's/arn:aws:iam::[0-9]{12}:/arn:aws:iam::************:/g' \
    -e 's/[0-9]{12}/************/g'
}
