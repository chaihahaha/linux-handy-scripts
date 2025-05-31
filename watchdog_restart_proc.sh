#!/bin/bash

# 配置参数
TIMEOUT=8            # 无响应超时秒数
WATCHDOG_INTERVAL=1   # 监控检测间隔秒数
ACTIVE_FILE="./program_active"
cleanup() {
    # 终止所有相关进程
    kill -9 $PROCESS_PID $TAIL_PID 2>/dev/null
    wait $PROCESS_PID $TAIL_PID 2>/dev/null 2>&1
    rm -f $ACTIVE_FILE
}

trap cleanup EXIT

while true; do
    # 启动测试进程并重定向输出
    setsid python process.py > $ACTIVE_FILE  2>&1 &
    PROCESS_PID=$!

    # 启动监控进程
    (
        while kill -0 $PROCESS_PID 2>/dev/null; do
            sleep $WATCHDOG_INTERVAL
            # 计算文件最后修改时间
            LAST_ACTIVE=$(date +%s -r $ACTIVE_FILE 2>/dev/null || echo 0)
            CURRENT_TIME=$(date +%s)
            ELAPSED=$((CURRENT_TIME - LAST_ACTIVE))

            if [ $ELAPSED -ge $TIMEOUT ]; then
                echo "[看门狗] 检测到${TIMEOUT}秒无活动，触发重启"
                kill -9 $(pstree -p $PROCESS_PID | grep -o '([0-9]\+)' | grep -o '[0-9]\+')
                break
            fi
        done
    ) &
    TAIL_PID=$!

    # 等待进程结束
    wait $PROCESS_PID
    echo "进程退出，等待重启..."
    sleep 0.1

    # 清理残留进程
    kill -9 $TAIL_PID 2>/dev/null
    wait $TAIL_PID 2>/dev/null
done

