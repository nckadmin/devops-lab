#!/bin/bash

# Values are read from capacity-hunter.env (see capacity-hunter.env.example).
# That file is gitignored and never committed.
ENV_FILE="${ENV_FILE:-$(dirname "$0")/capacity-hunter.env}"
[ -f "$ENV_FILE" ] && . "$ENV_FILE"

: "${COMPARTMENT_ID:?set COMPARTMENT_ID}"
: "${AD:?set AD}"
: "${SUBNET_ID:?set SUBNET_ID}"
: "${IMAGE_ID:?set IMAGE_ID}"
SSH_KEY_FILE="${SSH_KEY_FILE:?set SSH_KEY_FILE}"
DISPLAY_NAME="${DISPLAY_NAME:-arm-instance}"
LOG_FILE="$HOME/capacity-hunter.log"
WAIT_SECONDS=300

echo "$(date): Starting capacity hunt (interval: ${WAIT_SECONDS}s)..." >> "$LOG_FILE"

attempt=0
while true; do
  attempt=$((attempt+1))
  echo "$(date): Attempt #$attempt" >> "$LOG_FILE"

  result=$(oci compute instance launch \
    --compartment-id "$COMPARTMENT_ID" \
    --availability-domain "$AD" \
    --shape "VM.Standard.A1.Flex" \
    --shape-config '{"ocpus":2,"memoryInGBs":12}' \
    --image-id "$IMAGE_ID" \
    --subnet-id "$SUBNET_ID" \
    --assign-public-ip true \
    --ssh-authorized-keys-file "$SSH_KEY_FILE" \
    --display-name "$DISPLAY_NAME" 2>&1)

  if echo "$result" | grep -q '"lifecycle-state"'; then
    echo "$(date): SUCCESS! Instance created!" >> "$LOG_FILE"
    echo "$result" >> "$LOG_FILE"
    break
  elif echo "$result" | grep -qi "out of capacity\|out of host capacity"; then
    echo "$(date): Out of capacity, retrying in ${WAIT_SECONDS}s..." >> "$LOG_FILE"
  elif echo "$result" | grep -qi "toomanyrequests\|too many requests"; then
    echo "$(date): Rate limited, waiting ${WAIT_SECONDS}s..." >> "$LOG_FILE"
  elif echo "$result" | grep -qi "timed out\|timeout\|connection\|RequestException\|could not connect"; then
    echo "$(date): Network/timeout error, retrying in ${WAIT_SECONDS}s..." >> "$LOG_FILE"
  else
    echo "$(date): Unexpected error, retrying anyway in ${WAIT_SECONDS}s..." >> "$LOG_FILE"
    echo "$result" >> "$LOG_FILE"
  fi

  sleep "$WAIT_SECONDS"
done
