# Copyright 2018 Correct Context Sp. z o. o.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


xc::utils::wait-for-command(){
  local CMD
  CMD=${2}
  local NAME
  NAME=${1}
  local TIMEOUT
  TIMEOUT=${3:-60}
  for x in `seq $TIMEOUT`
  do
    if $CMD;then
      echo "[ OK ] $NAME"
      return 0
    else
      echo "[WAIT] $NAME..."
      sleep 1
    fi
  done
  echo "[FAIL] $NAME"
  echo "ERROR: $NAME - command '$CMD' failed."
  return 1
}

xc::utils::ssh-private-to-public(){
  ssh-keygen -yef "$1" | ssh-keygen -if /dev/stdin
}
# Utility functions that are not core of CLI library

xc::utils::calculate-number-change(){
  local existing_nodes_count
  existing_nodes_count=$1
  local change
  change=${2:-KEEP}
  case "$change" in
    KEEP)
      echo $existing_nodes_count
      return 0
      ;;
    +[0-9])
      echo $(( existing_nodes_count $change ))
      ;;
    -[0-9])
      local out=$(( existing_nodes_count $change ))
      if [ $out -lt 0 ];then
        return 1
      fi
      ;;
    [0-9])
      echo "$change"
      ;;
    *)
      error "Change must be +N, -N or N, not '$change'."
      return 1
      ;;
  esac
}

xc::utils::has-file-content-changed(){
  local file_path=$1
  if [ "${file_path:0:1}" != "/" ];then
    local file_path=$(readlink -f "$file_path")
  fi
  local cache_path="${XDG_CACHE_PATH:-${XDG_RUNTIME_PATH:-$HOME/.cache}}/cksum-$(cksum "$file_path" | cut -f1 -d' ')"
  local current_ck=$(stat -c %y "$file_path")
  if [ ! -f "$cache_path" ] || [ "$current_ck" != "$(cat "$cache_path")" ];then
    echo "$current_ck" > "$cache_path"
    return 0
  fi
  return 1
}
