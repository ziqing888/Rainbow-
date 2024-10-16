# Rainbow-

[ -f "Rainbow.sh" ] && rm Rainbow.sh
wget -q https://raw.githubusercontent.com/ziqing888/Rainbow-/refs/heads/main/Rainbow.sh -O Rainbow.sh || { echo "下载失败！"; exit 1; }
chmod +x Rainbow.sh && ./Rainbow.sh
