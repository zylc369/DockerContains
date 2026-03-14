#! /bin/bash

set -x -e

# 兼容性获取脚本所在目录
SOURCE="${BASH_SOURCE[0]}"

# 解析软链接
while [ -h "$SOURCE" ]; do
  SCRIPT_DIR="$(cd "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$SCRIPT_DIR/$SOURCE"
done

SCRIPT_DIR="$(cd "$(dirname "$SOURCE")" && pwd)"

LOG_PATH=$SCRIPT_DIR/home_cloud_dot_clean.log

echo "清理开始 $SCRIPT_DIR..."

dot_clean -v $SCRIPT_DIR > $LOG_PATH

echo "清理结束 ${SCRIPT_DIR}，日志路径：${LOG_PATH}"