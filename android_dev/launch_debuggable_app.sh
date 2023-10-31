#!/bin/sh
# build & install & launch，比较定制化且相对低频，就不纳入脚本了
if [ "$#" -ne 2 ]; then
    echo "./launch_debuggable_app.sh \$PKG_NAME \$PORT_NUM"
    exit 1
fi
PKG_NAME="$1"
PORT_NUM="$2"
TARGET_PID=$(adb shell pidof ${PKG_NAME})
echo "--->TARGET_PID: $TARGET_PID"
if [ "${TARGET_PID}" = "" ]; then
    echo "Package: ${PKG_NAME} is not running!!!"
    exit 1
fi

function run_in_android() {
 adb shell "run-as ${PKG_NAME} sh -c '${1}'" # 解决权限问题
}

# Step 1 清理之前可能残留的lldb进程
# enable for debug
echo "--->before clear:"
run_in_android ps
echo "--->start clear lldb-server if needed"
# 可能有 lldb-server 和 [lldb-server] ，只需要命中前者并kill即可
CLIENT_LLDB_ID=$(run_in_android ps| grep 'lldb-server$' | awk '{print $2}')
if [ "${CLIENT_LLDB_ID}" != "" ]; then
    echo "--->Kill LLDB: ${CLIENT_LLDB_ID} <---"
    run_in_android "kill -9 ${CLIENT_LLDB_ID}"
fi
echo "--->current process info(after clear):"
run_in_android ps
# Step 2 准备Server
LLDB_DIR="/data/data/${PKG_NAME}/lldb"
SERVER_DIR="${LLDB_DIR}/bin/"
run_in_android "mkdir -p ${SERVER_DIR}"
SERVER_PATH=${SERVER_DIR}/lldb-server
TMP_SERVER="/data/local/tmp/lldb-server"
run_in_android "cp -F ${TMP_SERVER} ${SERVER_PATH} && chmod 700 ${SERVER_PATH}"
# Step 3(如果是还命令行调用，则有必要设置环境变量，VSCode有专门的配置入口: Lldb->Adapter Env)
export ANDROID_PLATFORM_LOCAL_PORT=50012
export ANDROID_PLATFORM_LOCAL_GDB_PORT=50013
#echo "ANDROID_PLATFORM_LOCAL_PORT=${ANDROID_PLATFORM_LOCAL_PORT}"
#echo "ANDROID_PLATFORM_LOCAL_GDB_PORT=${ANDROID_PLATFORM_LOCAL_GDB_PORT}"

# Step 4 开始监听
echo "--->start listen to ${PORT_NUM}"
run_in_android "${SERVER_PATH} platform --listen \"*:${PORT_NUM}\" --server" &
echo "--->current process info(after launch listening):"
run_in_android ps # verbose info
gen=".generated"
if [ ! -d "$gen" ]; then
  mkdir ${gen}
else
  echo "Directory exists: $directory"
fi
CLIENT_LLDB_ID=$(run_in_android ps| grep lldb | awk '{print $2}')
if [ "${CLIENT_LLDB_ID}" != "" ]; then
    # launch.json的exitCommand中调用，每次使用完及时清理lldb server进程
    echo "--->new client lldb id: ${CLIENT_LLDB_ID}"
    echo "#Generated at $(date)" > ${gen}/before_lldb_quit.sh
    echo "adb shell \"run-as ${PKG_NAME} sh -c 'kill -9 ${CLIENT_LLDB_ID}'\"" >> ${gen}/before_lldb_quit.sh
    chmod +x ${gen}/before_lldb_quit.sh
fi

# Step 5 生成lldb命令，让VSCode加载，因为DeviceId / 端口 / 进程id 都在脚本生成，在`launch.json`直接运行lldb其实不方便，
#        这里利用 temp 文件传递了这些信息
launch_file=${gen}/launch.sh
device_id=$(adb devices | head -2 |tail -1 | cut -f 1)
echo "--->device id: ${device_id}"
echo "version" > ${launch_file}
echo "platform select remote-android" >> ${launch_file}
echo "platform connect connect://${device_id}:${PORT_NUM}" >> ${launch_file}
echo "process attach -p ${TARGET_PID}" >> ${launch_file}
current_path=$(pwd)
# 这一句衔接在attach后面不会生效，需要研究下......
echo "add-dsym ${current_path}/src/out/android_debug_unopt_arm64/libflutter.so" >> ${launch_file}
# from terminal
#/data/research/llvm-project/.build/bin/lldb -s ${launch_file}
#/root/.install/android-sdk-linux/ndk/26.1.10909125/toolchains/llvm/prebuilt/linux-x86_64/bin/lldb  -s ${launch_file}
echo "--->Try Kill in this place"
