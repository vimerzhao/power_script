# cd到目标文件所在目录
# sh ./upload_image_to_tencent_cloud.sh ${1:要处理的文件}
origin_file=${1}
echo "Read COS_URL: ${COS_URL}"

target_file="${origin_file}.handle"
temp_file="temp.md"
cp ${origin_file} ${target_file}
# 检查变量是否不存在
if [ -z "${COS_URL+x}" ]; then
  echo "config COS_URL first"
  exit
fi
if [ -z "${COS_CONF_FILE+x}" ]; then
  echo "config COS_CONF_FILE first"
  exit
fi
exit

result_list=$(grep -rIE '!\[\]\([^)]+\)' ${target_file})
for ret in ${result_list}; do
  img_file=$(echo $ret | cut -d "(" -f 2 | cut  -d ")" -f 1)
  img_name=$(basename $img_file)
  target_file_path=$(dirname ${target_file})
  cloud_file="2023/${img_name}"
  # COS_URL是存储桶地址，如https://vimerzhao-blog-1252560110.cos.ap-guangzhou.myqcloud.com"
  file_url="${COS_URL}/${cloud_file}"
  echo "upload to ${img_name} -> ${file_url}"
  local_file=${target_file_path}/${img_file}
  #COS_CONF_FILE是配置文件，参见 https://cloud.tencent.com/document/product/436/10976
  coscmd -c ${COS_CONF_FILE} upload ${local_file} ${cloud_file}
  echo ${file_url}
  # 不能直接覆盖
  awk "{gsub(\"${img_file}\", \"${file_url}\"); print}" ${target_file} > ${temp_file}
  cp ${temp_file} ${target_file}
done
rm -rf ${temp_file}

diff ${origin_file} ${target_file}
echo "do: cp ${target_file} ${origin_file} && rm -rf ${target_file}"
