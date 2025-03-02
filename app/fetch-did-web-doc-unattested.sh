#!/bin/bash
# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

set -x

# This script invokes curl, and, if successful,
# POSTs the response back to the CCF app at /did/{did}/doc.
# It is only used for testing in non-SGX environments.

# TODO remove this again once CCF logs output from subprocesses
exec >  >(tee -i /tmp/scitt-fetch-did-web-doc-unattested.log)
exec 2>&1

AFETCH_DIR="/tmp/scitt"
did=$1
url=$2
nonce=$3
CCF_SERVICE_HOST=${CCF_SERVICE_HOST:-"127.0.0.1"}
CCF_SERVICE_PORT=${CCF_SERVICE_PORT:-"8000"}
callback_url="https://${CCF_SERVICE_HOST}:${CCF_SERVICE_PORT}/app/did/${did}/doc"
out_path=$(mktemp "${AFETCH_DIR}/out.XXXXXX")
trap "rm -f ${out_path}" 0 2 3 15

curl -k -f -o "${out_path}" "${url}"

exit_code=$?
if [ $exit_code -ne 0 ]; then
  echo "curl failed"
  exit 1
fi

cat "${out_path}"

body_b64=$(base64 --wrap=0 "${out_path}")

{
    echo "{"
    echo " \"url\": \"${url}\", "
    echo " \"nonce\": \"${nonce}\", "
    echo " \"body\": \"${body_b64}\""
    echo "}"
} > "$out_path"

cat "${out_path}"

retries_left=3
while [ $retries_left -gt 0 ]; do
    curl -k -f --data-binary "@${out_path}" -H "Content-Type: application/json" "${callback_url}"
    exit_code=$?
    if [ $exit_code -eq 0 ]; then
        break
    fi
    echo "curl failed, retrying..."
    ((retries_left--))
    sleep 1
done

if [ $exit_code -ne 0 ]; then
    # Send again without -f to get server output for debugging.
    curl -k --data-binary "@${out_path}" -H "Content-Type: application/json" "${callback_url}"
    echo "curl failed: ${callback_url}"
    exit 2
fi
