#!/bin/bash

# Local constants
DEFAULT_CONTAINER_RECORDINGS_DIRECTORY="/freeswitch-recordings"
FREESWITCH_CONTAINER_CONFIG_DIRECTORY="/etc/freeswitch/"
FREESWITCH_CONTAINER_STORAGE_DIRECTORY="/var/lib/freeswitch/storage"
FREESWITCH_CONTAINER_BINARY="/usr/bin/freeswitch"
FREESWITCH_USER="freeswitch"
FREESWITCH_GROUP="daemon"
ENV_VARS_FILE="$FREESWITCH_CONTAINER_CONFIG_DIRECTORY/env.xml"

export FS_MOD_RAYO_RECORD_FILE_PREFIX="${FS_MOD_RAYO_RECORD_FILE_PREFIX:-$DEFAULT_CONTAINER_RECORDINGS_DIRECTORY}"

set -e

export_env_vars ()
{
  local preprocessor_vars=()
  preprocessor_vars+=("<!-- This file is generated automatically by docker-entrypoint.sh. Do not modify. -->")

  while IFS='=' read -r -d '' n v; do
    if  [[ $n == FS_* ]] ;
    then
      local export_name=${n#"FS_"} # remove prefix
      export_name="${export_name,,}" # convert to lowercase
      preprocessor_vars+=("<X-PRE-PROCESS cmd=\"set\" data=\"$export_name=$v\"/>")
    fi
  done < <(env -0)

  printf "%s\n" "${preprocessor_vars[@]}" > $ENV_VARS_FILE
}

if [ "$1" = 'freeswitch' ]; then
  export_env_vars

  # Setup recordings directory
  mkdir -p ${FS_MOD_RAYO_RECORD_FILE_PREFIX}
  chown -R "${FREESWITCH_USER}:${FREESWITCH_GROUP}" ${FS_MOD_RAYO_RECORD_FILE_PREFIX}

  # Setup config directory
  chown -R "${FREESWITCH_USER}:${FREESWITCH_GROUP}" ${FREESWITCH_CONTAINER_CONFIG_DIRECTORY}

  # Setup storage directory
  chown -R "${FREESWITCH_USER}:${FREESWITCH_USER}" ${FREESWITCH_CONTAINER_STORAGE_DIRECTORY}

  # execute FreeSWITCH
  exec ${FREESWITCH_CONTAINER_BINARY} -u ${FREESWITCH_USER} -g ${FREESWITCH_GROUP}
fi

exec "$@"
