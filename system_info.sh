#!/bin/bash

# ============================================================
# نام: system_info.sh
# کاربرد: نمایش اطلاعات سیستم در ۴ سطح امنیتی-سیستمی
# نسخه: 1.0
# ============================================================

# ---------- تنظیمات آپدیت (این بخش را ویرایش کنید) ----------
CURRENT_VERSION="1.0"   # نسخه فعلی اسکریپت
REPO_OWNER="sazidehm"   # نام کاربری گیت‌هاب خود را وارد کنید
REPO_NAME="linuxsupd"          # نام مخزن گیت‌هاب خود را وارد کنید
REPO_BRANCH="main"                  # برنچ مخزن (معمولاً main یا master)
# آدرس کامل فایل‌ها در گیت‌هاب (RAW)
REPO_RAW_URL="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${REPO_BRANCH}"

# ---------- پایان تنظیمات آپدیت ----------

# ---------- رنگ‌ها ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ---------- تابع بررسی و انجام آپدیت با پاکسازی کامل ----------
check_for_updates() {
    # دریافت مسیر مطلق اسکریپت فعلی
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
    
    # دریافت فایل version.txt از سرور
    echo -e "${BLUE}➜ در حال بررسی آپدیت...${NC}"
    VERSION_FILE=$(curl -s --max-time 5 "${REPO_RAW_URL}/version.txt" 2>/dev/null)
    
    if [ -z "$VERSION_FILE" ]; then
        echo -e "${YELLOW}⚠ عدم دسترسی به سرور برای بررسی آپدیت.${NC}"
        return 0
    fi

    # استخراج نسخه
    REMOTE_VERSION=$(echo "$VERSION_FILE" | grep -E "^v=" | head -1 | cut -d'=' -f2 | tr -d ' \t\n\r')
    
    # استخراج لیست فایل‌ها
    FILE_LIST=$(echo "$VERSION_FILE" | grep -A100 "^listf=" | sed -n '/^listf="/,/^"/p' | grep -v "^listf=" | grep -v '^"$' | sed 's/^[ \t]*//' | sed '/^[[:space:]]*$/d')

    if [ -z "$REMOTE_VERSION" ]; then
        echo -e "${YELLOW}⚠ فایل version.txt معتبر نیست (نسخه پیدا نشد).${NC}"
        return 0
    fi

    # مقایسه نسخه‌ها
    if [ "$REMOTE_VERSION" != "$CURRENT_VERSION" ]; then
        echo -e "${GREEN}✓ اپدیت ${REMOTE_VERSION}${NC}"
        echo -e "${YELLOW}⚠ در حال دریافت آپدیت...${NC}"
        
        if [ -z "$FILE_LIST" ]; then
            echo -e "${YELLOW}⚠ لیست فایل‌ها خالی است. فقط فایل اصلی آپدیت می‌شود.${NC}"
            FILE_LIST="$SCRIPT_NAME"
        fi
        
        # پوشه موقت برای دانلود
        TEMP_DIR=$(mktemp -d)
        cd "$TEMP_DIR" || exit 1
        
        UPDATE_SUCCESS=true
        
        # دانلود فایل‌ها
        for FILE in $FILE_LIST; do
            FILE=$(echo "$FILE" | xargs)
            [ -z "$FILE" ] && continue
            
            echo -e "${BLUE}➜ دانلود ${FILE} ...${NC}"
            curl -s -f --create-dirs -O "${REPO_RAW_URL}/${FILE}"
            if [ $? -ne 0 ] || [ ! -f "$FILE" ]; then
                echo -e "${RED}✗ خطا در دانلود فایل ${FILE}!${NC}"
                UPDATE_SUCCESS=false
                break
            fi
        done
        
        if [ "$UPDATE_SUCCESS" = true ]; then
            # ====================================================
            # ساخت اسکریپت به‌روزرسانی (Updater) برای پاکسازی کامل
            # ====================================================
            cat > "${TEMP_DIR}/updater.sh" << 'EOF'
#!/bin/bash
# این اسکریپت توسط system_info.sh ساخته شده است
# وظیفه: پاکسازی کامل دایرکتوری و نصب فایل‌های جدید

TARGET_DIR="$1"
SOURCE_DIR="$2"
SCRIPT_NAME="$3"
shift 3
ARGS="$@"

# حذف همه فایل‌ها و پوشه‌های قدیمی (به جز خود پوشه)
echo "🧹 در حال پاکسازی کامل دایرکتوری: $TARGET_DIR"
cd "$TARGET_DIR" || exit 1

# حذف همه چیز به جز پوشه‌های مخفی (مثل .git) اگر وجود دارند
# اما برای امنیت، همه چیز را حذف می‌کنیم
rm -rf ./* 2>/dev/null
rm -rf .[!.]* 2>/dev/null   # حذف فایل‌های مخفی (به جز . و ..)

# کپی فایل‌های جدید از پوشه موقت
echo "📦 در حال کپی فایل‌های جدید..."
cp -rf "$SOURCE_DIR"/* "$TARGET_DIR/" 2>/dev/null
cp -rf "$SOURCE_DIR"/.[!.]* "$TARGET_DIR/" 2>/dev/null   # کپی فایل‌های مخفی

# مجوز اجرا به اسکریپت اصلی بده
chmod +x "$TARGET_DIR/$SCRIPT_NAME" 2>/dev/null

# پاک کردن پوشه موقت
rm -rf "$SOURCE_DIR"

# اجرای اسکریپت جدید
echo "🚀 در حال اجرای نسخه جدید..."
exec "$TARGET_DIR/$SCRIPT_NAME" $ARGS
EOF
            
            chmod +x "${TEMP_DIR}/updater.sh"
            
            echo -e "${GREEN}✓ آپدیت کامل شد. در حال پاکسازی و راه‌اندازی مجدد...${NC}"
            echo -e "═══════════════════════════════════════════════════════\n"
            
            # اجرای اسکریپت به‌روزرسانی و خروج از اسکریپت فعلی
            exec "${TEMP_DIR}/updater.sh" "$SCRIPT_DIR" "$TEMP_DIR" "$SCRIPT_NAME" "$@"
            # بعد از exec، کدهای پایین اجرا نمی‌شوند
        else
            cd - > /dev/null
            rm -rf "$TEMP_DIR"
            echo -e "${RED}✗ آپدیت ناموفق بود. ادامه با نسخه فعلی...${NC}"
        fi
    else
        echo -e "${GREEN}✓ اسکریپت شما به‌روز است. (نسخه ${CURRENT_VERSION})${NC}"
    fi
}

# ---------- توابع کمکی (همان‌طور که قبلاً داشتید) ----------
print_header() {
    echo -e "\n${CYAN}${BOLD}═══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}  $1${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════${NC}"
}

print_ok() { echo -e "${GREEN}✓ $1${NC}"; }
print_warn() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_danger() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${BLUE}➜ $1${NC}"; }

# بررسی دسترسی ریشه برای سطوح ۳ و ۴
check_root() {
    if [[ $LEVEL -ge 3 && $EUID -ne 0 ]]; then
        echo -e "${YELLOW}توجه: برای بررسی کامل نقض‌ها نیاز به دسترسی ریشه دارید.${NC}"
        echo -e "${YELLOW}لطفاً اسکریپت را با sudo اجرا کنید: sudo $0 $LEVEL${NC}"
        echo ""
    fi
}

# ---------- سطح ۱ ----------
show_level1() {
    print_header "سطح ۱ - اطلاعات پایه سیستم"
    print_info "نام میزبان (Hostname):"
    echo -e "  ${BOLD}$(hostname)${NC}"
    print_info "توزیع و نسخه سیستم‌عامل:"
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo -e "  ${BOLD}$PRETTY_NAME${NC}"
    else
        echo -e "  $(lsb_release -d 2>/dev/null || cat /etc/issue | head -1)"
    fi
    print_info "نسخه هسته (Kernel):"
    echo -e "  ${BOLD}$(uname -r)${NC}"
    print_info "معماری سیستم:"
    echo -e "  ${BOLD}$(uname -m)${NC}"
    print_info "زمان فعالیت (Uptime):"
    echo -e "  ${BOLD}$(uptime -p | sed 's/up //')${NC}"
    print_info "مدل پردازنده (CPU):"
    CPU_MODEL=$(lscpu | grep "Model name" | awk -F: '{print $2}' | xargs)
    CPU_CORES=$(nproc)
    echo -e "  ${BOLD}$CPU_MODEL${NC} (${CPU_CORES} هسته)"
    print_info "حافظه فیزیکی (RAM):"
    TOTAL_MEM=$(free -h | grep Mem | awk '{print $2}')
    USED_MEM=$(free -h | grep Mem | awk '{print $3}')
    FREE_MEM=$(free -h | grep Mem | awk '{print $4}')
    echo -e "  کل: ${BOLD}$TOTAL_MEM${NC}  |  استفاده شده: ${BOLD}$USED_MEM${NC}  |  آزاد: ${BOLD}$FREE_MEM${NC}"
    print_info "فضای دیسک (مجلد ریشه /):"
    df -h / | grep -v "Filesystem" | awk '{print "  کل: " $2 "  |  استفاده: " $3 "  |  باقیمانده: " $4 "  |  درصد: " $5}'
    print_info "کاربران متصل در حال حاضر:"
    who | awk '{print "  " $1 " (از " $5 " - " $3 " " $4 ")"}' || echo "  هیچ کاربری متصل نیست."
}

# ---------- سطح ۲ ----------
show_level2() {
    print_header "سطح ۲ - اطلاعات شبکه"
    print_info "آدرس‌های IP داخلی (به جز loopback):"
    ip -4 addr show | grep -v "127.0.0.1" | grep "inet " | awk '{print "  " $2 " روی " $NF}'
    print_info "آدرس IP عمومی (خارجی):"
    EXT_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "نامشخص (عدم دسترسی به اینترنت)")
    echo -e "  ${BOLD}$EXT_IP${NC}"
    print_info "دروازه پیش‌فرض (Default Gateway):"
    GW=$(ip route show default | awk '{print $3}')
    echo -e "  ${BOLD}$GW${NC}"
    print_info "پورت‌های باز (در حال گوش دادن - TCP/UDP):"
    ss -tuln | grep LISTEN | awk '{print "  " $5 " (" $1 ")"}' | head -15
    print_info "تعداد اتصالات فعال برقرار شده (Established):"
    EST_COUNT=$(ss -tun | grep ESTAB | wc -l)
    echo -e "  ${BOLD}$EST_COUNT${NC} اتصال"
    print_info "کارت‌های شبکه و مک آدرس:"
    ip link show | grep -E "^[0-9]+:" | awk -F': ' '{print $2}' | while read iface; do
        MAC=$(cat /sys/class/net/$iface/address 2>/dev/null)
        [ -n "$MAC" ] && echo -e "  $iface : ${BOLD}$MAC${NC}"
    done
}

# ---------- سطح ۳ ----------
show_level3() {
    print_header "سطح ۳ - بررسی نقض‌ها و رویدادهای امنیتی (متوسط)"
    print_info "آخرین ۵ بار تلاش ناموفق برای ورود (SSH/Login):"
    if command -v lastb &> /dev/null; then
        lastb -a 2>/dev/null | head -5 | while read line; do echo -e "  ${YELLOW}$line${NC}"; done || print_ok "هیچ تلاش ناموفقی یافت نشد."
    else
        sudo journalctl -q _COMM=sshd 2>/dev/null | grep "Failed password" | tail -5 | while read line; do echo -e "  ${YELLOW}$line${NC}"; done || echo "  دسترسی به لاگ‌ها ممکن نیست."
    fi
    print_info "آخرین ۳ خطای sudo (تلاش برای دسترسی غیرمجاز):"
    sudo journalctl -q SYSLOG_IDENTIFIER=sudo 2>/dev/null | grep -i "fail\|denied" | tail -3 | while read line; do echo -e "  ${YELLOW}$line${NC}"; done || echo "  خطایی یافت نشد."
    print_info "سرویس‌های دارای خطا در بوت اخیر (systemd):"
    FAILED=$(systemctl --failed --no-legend 2>/dev/null | awk '{print $1}')
    if [ -n "$FAILED" ]; then
        echo "$FAILED" | while read svc; do echo -e "  ${RED}✗ $svc${NC}"; done
    else
        print_ok "همه سرویس‌ها به درستی اجرا شده‌اند."
    fi
    print_info "پردازه‌های در حال اجرا از مسیرهای موقت (/tmp, /dev/shm):"
    ps aux | grep -E "/tmp/|/dev/shm/" | grep -v grep | awk '{print "  " $2 " - " $11 " (" $1 ")"}' | while read line; do echo -e "  ${YELLOW}$line${NC}"; done || print_ok "هیچ پردازه‌ای از مسیرهای موقت اجرا نشده است."
    LOAD=$(uptime | awk -F'load average:' '{print $2}' | xargs)
    print_info "میانگین بار سیستم (Load Average) - ۱، ۵، ۱۵ دقیقه:"
    echo -e "  ${BOLD}$LOAD${NC}"
}

# ---------- سطح ۴ ----------
show_level4() {
    print_header "سطح ۴ - بررسی نقض‌های بزرگ و بحرانی ⚠️"
    print_info "بررسی فایل‌های SUID/SGID (۱۵ مورد اول):"
    SUID_FILES=$(find / -xdev -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null | head -15)
    if [ -n "$SUID_FILES" ]; then
        echo "$SUID_FILES" | while read file; do
            PERMS=$(ls -la "$file" 2>/dev/null | awk '{print $1}')
            echo -e "  ${RED}${PERMS}${NC} ${YELLOW}$file${NC}"
        done
        TOTAL=$(find / -xdev -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null | wc -l)
        echo -e "  ${YELLOW}تعداد کل: $TOTAL فایل${NC}"
    else
        print_ok "فایل خاصی یافت نشد."
    fi
    print_info "بررسی کرون‌جاب‌های ریشه (root):"
    sudo crontab -l -u root 2>/dev/null | grep -v "^#" | grep -v "^$" | while read line; do echo -e "    ${YELLOW}$line${NC}"; done || echo "    (هیچ کرونی برای ریشه تعریف نشده)"
    print_info "بررسی تنظیمات خطرناک SSH:"
    if [ -f /etc/ssh/sshd_config ]; then
        grep -qi "^PermitRootLogin yes" /etc/ssh/sshd_config && print_danger "ورود ریشه (Root) با SSH مجاز است!"
        grep -qi "^PasswordAuthentication yes" /etc/ssh/sshd_config && print_danger "احراز هویت با رمز عبور در SSH فعال است!"
    fi
    print_info "بررسی کاربران دارای UID=0 (ریشه) غیر از root:"
    UID0=$(awk -F: '($3==0){print $1}' /etc/passwd | grep -v "^root$")
    if [ -n "$UID0" ]; then
        echo "$UID0" | while read user; do print_danger "کاربر ${user} نیز دارای UID صفر است!"; done
    else
        print_ok "فقط کاربر root دارای UID صفر است."
    fi
    print_info "بررسی کاربران با رمز عبور خالی:"
    EMPTY=$(sudo awk -F: '($2==""){print $1}' /etc/shadow 2>/dev/null)
    if [ -n "$EMPTY" ]; then
        echo "$EMPTY" | while read user; do print_danger "کاربر ${user} رمز عبور خالی دارد!"; done
    else
        print_ok "هیچ کاربری با رمز خالی یافت نشد."
    fi
    echo -e "\n${RED}${BOLD}■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■${NC}"
    echo -e "${RED}${BOLD}نتیجه‌گیری سطح ۴: اگر مورد قرمزی دیدید، سیستم در معرض خطر است.${NC}"
    echo -e "${RED}${BOLD}■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■${NC}"
}

# ---------- منوی تعاملی ----------
show_menu() {
    clear
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}        سیستم نمایش اطلاعات و امنیت لینوکس${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BOLD}لطفاً یکی از گزینه‌های زیر را انتخاب کنید:${NC}"
    echo ""
    echo -e "  ${GREEN}1${NC}) اطلاعات عادی لینوکس (سیستم، پردازنده، حافظه، دیسک)"
    echo -e "  ${GREEN}2${NC}) اطلاعات عادی + اطلاعات شبکه (IP، پورت، دروازه)"
    echo -e "  ${GREEN}3${NC}) بررسی نقض‌های سیستمی (ورود ناموفق، خطاهای sudo، سرویس‌های خراب)"
    echo -e "  ${GREEN}4${NC}) بررسی نقض‌های بزرگ (فایل‌های SUID، کرون خطرناک، تنظیمات SSH، کاربران ریشه)"
    echo -e "  ${RED}0${NC}) خروج"
    echo ""
    echo -n "انتخاب شما [0-4]: "
    read -r choice
    echo ""

    case $choice in
        1|2|3|4) LEVEL=$choice ;;
        0) echo -e "${GREEN}خروج.${NC}"; exit 0 ;;
        *) echo -e "${RED}گزینه نامعتبر!${NC}"; sleep 1; show_menu ;;
    esac
}

# ============================================================
# ---------- بخش اصلی ----------
# ============================================================

if [ -z "$1" ]; then
    show_menu
else
    LEVEL=$1
    if [[ ! "$LEVEL" =~ ^[1-4]$ ]]; then
        echo -e "${RED}خطا: سطح نامعتبر!${NC}"
        echo "استفاده: $0 [1|2|3|4]"
        exit 1
    fi
fi

# چک آپدیت
check_for_updates "$@"

# بررسی دسترسی ریشه
check_root

# اجرای سطح انتخاب‌شده
case $LEVEL in
    1) show_level1 ;;
    2) show_level1; show_level2 ;;
    3) show_level1; show_level2; show_level3 ;;
    4) show_level1; show_level2; show_level3; show_level4 ;;
esac

echo -e "\n${GREEN}${BOLD}✓ پایان بررسی.${NC}"
exit 0
