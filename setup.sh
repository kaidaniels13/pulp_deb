#!/usr/bin/env bash
set -e

# export PULP_URL=${PULP_URL:-http://localhost:5001}

# Poll a Pulp task until it is finished and output the content HREF.
wait_until_task_finished() {
    local task_url=${1}
    while true
    do
        local response=$(http ${task_url})
        local state=$(echo ${response} | jq -r .state)
        case ${state} in
            failed|canceled)
                echo "Task in final state: ${state}" >&2
                exit 1
                ;;
            completed)
                local result_href=$(echo ${response} | jq -r .created_resources[0])
                echo "${result_href}"
                break
                ;;
            *)
                echo "Still waiting..."
                sleep 1
                ;;
        esac
    done
}

