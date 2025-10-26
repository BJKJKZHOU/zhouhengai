#!/usr/bin/env bash
#
# Run jekyll serve and then launch the site

prod=false
command="bundle exec jekyll serve --livereload --host 0.0.0.0 --port 4000 --force_polling --watch --incremental"
host="0.0.0.0"

help() {
  echo "Usage:"
  echo
  echo "   bash /path/to/run [options]"
  echo
  echo "Options:"
  echo "     -H, --host [HOST]    Host to bind to."
  echo "     -p, --production     Run Jekyll in 'production' mode."
  echo "     -h, --help           Print this help information."
}

while (($#)); do
  opt="$1"
  case $opt in
  -H | --host)
    host="$2"
    shift 2
    ;;
  -p | --production)
    prod=true
    shift
    ;;
  -h | --help)
    help
    exit 0
    ;;
  *)
    echo -e "> Unknown option: '$opt'\n"
    help
    exit 1
    ;;
  esac
done

# 清理旧的站点地图文件
echo "清理旧的站点地图文件..."
if [ -f "sitemap.xml" ]; then
  rm sitemap.xml
  echo "已删除旧的 sitemap.xml"
fi

# 清理构建目录，确保重新生成
if [ -d "_site" ]; then
  rm -rf _site
  echo "已清理 _site 目录"
fi

command="$command --force_polling"

command="$command -H $host"

if $prod; then
  command="JEKYLL_ENV=production $command"
fi

if [ -e /proc/1/cgroup ] && grep -q docker /proc/1/cgroup; then
  command="$command --force_polling"
fi

echo "启动Jekyll服务器并重新生成站点地图..."
echo -e "\n> $command\n"
eval "$command"
