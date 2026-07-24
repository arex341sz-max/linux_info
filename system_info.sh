#!/bin/bash

# ============================================================
# نام: system_info.sh
# کاربرد: نمایش اطلاعات سیستم در ۴ سطح امنیتی-سیستمی
# نسخه: 1.0
# ============================================================

# ---------- تنظیمات آپدیت (این بخش را ویرایش کنید) ----------
CURRENT_VERSION="1.0"   # نسخه فعلی اسکریپت
REPO_OWNER="arex341sz-max"   # نام کاربری گیت‌هاب خود را وارد کنید
REPO_NAME="linuxinfoupdate"          # نام مخزن گیت‌هاب خود را وارد کنید
REPO_BRANCH="main"                  # برنچ مخزن (معمولاً main یا master)
# آدرس کامل فایل‌ها در گیت‌هاب (RAW)
REPO_RAW_URL="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${REPO_BRANCH}"

# ---------- پایان تنظیمات آپدیت ----------

# ---------- رنگ‌ها برای خروجی زیبا ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # بدون رنگ

# ---------- تابع بررسی و انجام آپدیت ----------
check_for_updates() {
    # دریافت مسیر مطلق اسکریپت فعلی (قبل از هر گونه cd)
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
    
    # دریافت فایل version.txt از سرور
    echo -e "${BLUE}➜ در حال بررسی آپدیت...${NC}"
    VERSION_FILE=$(curl -s --max-time 5 "${REPO_RAW_URL}/version.txt" 2>/dev/null)
    
    # اگر نتوانست فایل را بگیرد (مثلاً قطعی اینترنت)، بدون خطا ادامه بده
    if [ -z "$VERSION_FILE" ]; then
        echo -e "${YELLOW}⚠ عدم دسترسی به سرور برای بررسی آپدیت.${NC}"
        return 0
    fi

    # استخراج شماره نسخه از خطی که با v= شروع می‌شود
    REMOTE_VERSION=$(echo "$VERSION_FILE" | grep -E "^v=" | head -1 | cut -d'=' -f2 | tr -d ' \t\n\r')
    
    # استخراج لیست فایل‌ها از بین دو علامت " 
    FILE_LIST=$(echo "$VERSION_FILE" | grep -A100 "^listf=" | sed -n '/^listf="/,/^"/p' | grep -v "^listf=" | grep -v '^"$' | sed 's/^[ \t]*//' | sed '/^[[:space:]]*$/d')

    # اگر نسخه به درستی استخراج نشد، خطا بده و ادامه بده
    if [ -z "$REMOTE_VERSION" ]; then
        echo -e "${YELLOW}⚠ فایل version.txt معتبر نیست (نسخه پیدا نشد).${NC}"
        return 0
    fi

    # مقایسه نسخه‌ها (اگر متفاوت بود)
    if [ "$REMOTE_VERSION" != "$CURRENT_VERSION" ]; then
        # ✅ نمایش تیک سبز و نسخه‌ی جدید
        echo -e "${GREEN}✓ اپدیت ${REMOTE_VERSION}${NC}"
        echo -e "${YELLOW}⚠ در حال دریافت آپدیت...${NC}"
        
        # اگر لیست فایل‌ها خالی بود، از لیست پیش‌فرض استفاده کن (فقط خود اسکریپت)
        if [ -z "$FILE_LIST" ]; then
            echo -e "${YELLOW}⚠ لیست فایل‌ها در version.txt خالی است. فقط فایل اصلی آپدیت می‌شود.${NC}"
            FILE_LIST="$SCRIPT_NAME"
        fi
        
        # ایجاد یک پوشه موقت برای دانلود
        TEMP_DIR=$(mktemp -d)
        cd "$TEMP_DIR" || exit 1
        
        UPDATE_SUCCESS=true
        
        # دانلود تمام فایل‌های موجود در لیست
        for FILE in $FILE_LIST; do
            # حذف فاصله‌های اضافی
            FILE=$(echo "$FILE" | xargs)
            if [ -z "$FILE" ]; then
                continue
            fi
            
            echo -e "${BLUE}➜ دانلود ${FILE} ...${NC}"
            # دانلود فایل با حفظ ساختار پوشه‌ها
            curl -s -f --create-dirs -O "${REPO_RAW_URL}/${FILE}"
            if [ $? -ne 0 ] || [ ! -f "$FILE" ]; then
                echo -e "${RED}✗ خطا در دانلود فایل ${FILE}!${NC}"
                UPDATE_SUCCESS=false
                break
            fi
        done
        
        # اگر همه فایل‌ها با موفقیت دانلود شدند
        if [ "$UPDATE_SUCCESS" = true ]; then
            # جایگزینی فایل‌های قدیمی با فایل‌های جدید
            for FILE in $FILE_LIST; do
                FILE=$(echo "$FILE" | xargs)
                if [ -z "$FILE" ]; then
                    continue
                fi
                
                # ساخت مسیر کامل فایل مقصد با استفاده از SCRIPT_DIR ذخیره‌شده
                TARGET_FILE="${SCRIPT_DIR}/${FILE}"
                
                # ایجاد پوشه‌های مورد نیاز در مسیر مقصد
                TARGET_DIR=$(dirname "$TARGET_FILE")
                mkdir -p "$TARGET_DIR"
                
                # اگر فایل مقصد با فایل مبدا یکی نباشد، کپی کن
                if [ "$(realpath "$FILE" 2>/dev/null)" != "$(realpath "$TARGET_FILE" 2>/dev/null)" ]; then
                    cp -f "$FILE" "$TARGET_FILE"
                    # مجوز اجرا بده (فقط برای فایل‌هایی که پسوند .sh یا .py دارند)
                    if [[ "$FILE" == *.sh ]] || [[ "$FILE" == *.py ]]; then
                        chmod +x "$TARGET_FILE" 2>/dev/null
                    fi
                    echo -e "${GREEN}✓ فایل ${FILE} با موفقیت آپدیت شد.${NC}"
                else
                    echo -e "${YELLOW}⚠ فایل ${FILE} یکسان است، نیازی به کپی نیست.${NC}"
                fi
            done
            
            # پاک کردن پوشه موقت
            cd /tmp && rm -rf "$TEMP_DIR"
            
            echo -e "${GREEN}✓ آپدیت کامل شد. در حال راه‌اندازی مجدد اسکریپت جدید...${NC}"
            echo -e "═══════════════════════════════════════════════════════\n"
            
            # اجرای اسکریپت جدید با مسیر کامل و خروج از اسکریپت فعلی
            exec "${SCRIPT_DIR}/${SCRIPT_NAME}" "$@"
            # (بعد از exec، کدهای پایین دیگر اجرا نمی‌شوند)
        else
            # اگر دانلود ناموفق بود، به پوشه قبلی برگرد و ادامه بده
            cd - > /dev/null
            rm -rf "$TEMP_DIR"
            echo -e "${RED}✗ آپدیت ناموفق بود. ادامه با نسخه فعلی...${NC}"
        fi
    else
        # ✅ نمایش تیک سبز و پیام به‌روز بودن
        echo -e "${GREEN}✓ اسکریپت شما به‌روز است. (نسخه ${CURRENT_VERSION})${NC}"
    fi
}

# ---------- توابع کمکی ----------
print_header() {
    echo -e "\n${CYAN}${BOLD}═══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}  $1${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════${NC}"
}

print_ok() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warn() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_danger() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}➜ $1${NC}"
}

# بررسی دسترسی ریشه برای سطوح ۳ و ۴
check_root() {
    if [[ $LEVEL -ge 3 && $EUID -ne 0 ]]; then
        echo -e "${YELLOW}توجه: برای بررسی کامل نقض‌ها نیاز به دسترسی ریشه دارید.${NC}"
        echo -e "${YELLOW}لطفاً اسکریپت را با sudo اجرا کنید: sudo $0 $LEVEL${NC}"
        echo -e "${YELLOW}در غیر این صورت، برخی از بخش‌ها ناقص نمایش داده می‌شوند.${NC}"
        echo ""
    fi
}

# ---------- سطح ۱: اطلاعات عادی و پایه ----------
show_level1() {
    print_header "سطح ۱ - اطلاعات پایه سیستم"

    # نام هاست
    print_info "نام میزبان (Hostname):"
    echo -e "  ${BOLD}$(hostname)${NC}"

    # توزیع و نسخه
    print_info "توزیع و نسخه سیستم‌عامل:"
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo -e "  ${BOLD}$PRETTY_NAME${NC}"
    else
        echo -e "  $(lsb_release -d 2>/dev/null || cat /etc/issue | head -1)"
    fi

    # هسته
    print_info "نسخه هسته (Kernel):"
    echo -e "  ${BOLD}$(uname -r)${NC}"

    # معماری
    print_info "معماری سیستم:"
    echo -e "  ${BOLD}$(uname -m)${NC}"

    # زمان آپتایم
    print_info "زمان فعالیت (Uptime):"
    echo -e "  ${BOLD}$(uptime -p | sed 's/up //')${NC}"

    # پردازنده
    print_info "مدل پردازنده (CPU):"
    CPU_MODEL=$(lscpu | grep "Model name" | awk -F: '{print $2}' | xargs)
    CPU_CORES=$(nproc)
    echo -e "  ${BOLD}$CPU_MODEL${NC} (${CPU_CORES} هسته)"

    # حافظه RAM
    print_info "حافظه فیزیکی (RAM):"
    TOTAL_MEM=$(free -h | grep Mem | awk '{print $2}')
    USED_MEM=$(free -h | grep Mem | awk '{print $3}')
    FREE_MEM=$(free -h | grep Mem | awk '{print $4}')
    echo -e "  کل: ${BOLD}$TOTAL_MEM${NC}  |  استفاده شده: ${BOLD}$USED_MEM${NC}  |  آزاد: ${BOLD}$FREE_MEM${NC}"

    # فضای دیسک (ریشه)
    print_info "فضای دیسک (مجلد ریشه /):"
    df -h / | grep -v "Filesystem" | awk '{print "  کل: " $2 "  |  استفاده: " $3 "  |  باقیمانده: " $4 "  |  درصد: " $5}'

    # کاربران لاگین کرده
    print_info "کاربران متصل در حال حاضر:"
    who | awk '{print "  " $1 " (از " $5 " - " $3 " " $4 ")"}' || echo "  هیچ کاربری متصل نیست."
}

# ---------- سطح ۲: اطلاعات عادی + شبکه ----------
show_level2() {
    print_header "سطح ۲ - اطلاعات شبکه"

    # آی‌پی داخلی
    print_info "آدرس‌های IP داخلی (به جز loopback):"
    ip -4 addr show | grep -v "127.0.0.1" | grep "inet " | awk '{print "  " $2 " روی " $NF}' | while read line; do
        echo -e "  ${BOLD}${line}${NC}"
    done

    # آی‌پی عمومی (خارجی)
    print_info "آدرس IP عمومی (خارجی):"
    EXT_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "نامشخص (عدم دسترسی به اینترنت)")
    echo -e "  ${BOLD}$EXT_IP${NC}"

    # دروازه پیش‌فرض
    print_info "دروازه پیش‌فرض (Default Gateway):"
    GW=$(ip route show default | awk '{print $3}')
    echo -e "  ${BOLD}$GW${NC}"

    # پورت‌های باز و در حال گوش دادن (Listening)
    print_info "پورت‌های باز (در حال گوش دادن - TCP/UDP):"
    ss -tuln | grep LISTEN | awk '{print "  " $5 " (" $1 ")"}' | head -15

    # اتصالات فعال برقرار شده
    print_info "تعداد اتصالات فعال برقرار شده (Established):"
    EST_COUNT=$(ss -tun | grep ESTAB | wc -l)
    echo -e "  ${BOLD}$EST_COUNT${NC} اتصال"

    # کارت شبکه و مک آدرس
    print_info "کارت‌های شبکه و مک آدرس:"
    ip link show | grep -E "^[0-9]+:" | awk -F': ' '{print $2}' | while read iface; do
        MAC=$(cat /sys/class/net/$iface/address 2>/dev/null)
        if [ -n "$MAC" ]; then
            echo -e "  $iface : ${BOLD}$MAC${NC}"
        fi
    done
}

# ---------- سطح ۳: نقض‌های سیستمی (متوسط) ----------
show_level3() {
    print_header "سطح ۳ - بررسی نقض‌ها و رویدادهای امنیتی (متوسط)"

    # ۱. ورودهای ناموفق (SSH و ترمینال)
    print_info "آخرین ۵ بار تلاش ناموفق برای ورود (SSH/Login):"
    if command -v lastb &> /dev/null; then
        LASTB_OUT=$(lastb -a 2>/dev/null | head -5)
        if [ -n "$LASTB_OUT" ]; then
            echo "$LASTB_OUT" | while read line; do
                echo -e "  ${YELLOW}$line${NC}"
            done
        else
            print_ok "هیچ تلاش ناموفقی یافت نشد."
        fi
    else
        # fallback به لاگ‌ها
        sudo journalctl -q _COMM=sshd 2>/dev/null | grep "Failed password" | tail -5 | while read line; do
            echo -e "  ${YELLOW}$line${NC}"
        done || echo "  دسترسی به لاگ‌ها ممکن نیست."
    fi

    # ۲. تلاش‌های ناموفق سودو (sudo)
    print_info "آخرین ۵ خطای sudo (تلاش برای دسترسی غیرمجاز):"
    if [ -f /var/log/auth.log ]; then
        grep "sudo.*FAILED" /var/log/auth.log 2>/dev/null | tail -3 | while read line; do
            echo -e "  ${YELLOW}$line${NC}"
        done || echo "  خطایی یافت نشد."
    else
        sudo journalctl -q SYSLOG_IDENTIFIER=sudo 2>/dev/null | grep -i "fail\|denied" | tail -3 | while read line; do
            echo -e "  ${YELLOW}$line${NC}"
        done || echo "  خطایی یافت نشد."
    fi

    # ۳. سرویس‌هایی که در بوت اخیر خراب شده‌اند
    print_info "سرویس‌های دارای خطا در بوت اخیر (systemd):"
    FAILED_SERVICES=$(systemctl --failed --no-legend 2>/dev/null | awk '{print $1}')
    if [ -n "$FAILED_SERVICES" ]; then
        echo "$FAILED_SERVICES" | while read svc; do
            echo -e "  ${RED}✗ $svc${NC}"
        done
    else
        print_ok "همه سرویس‌ها به درستی اجرا شده‌اند."
    fi

    # ۴. پردازه‌های مشکوک (اجرا از /tmp یا /dev/shm)
    print_info "پردازه‌های در حال اجرا از مسیرهای موقت (/tmp, /dev/shm):"
    PS_LIST=$(ps aux | grep -E "/tmp/|/dev/shm/" | grep -v grep)
    if [ -n "$PS_LIST" ]; then
        echo "$PS_LIST" | awk '{print "  " $2 " - " $11 " (" $1 ")"}' | while read line; do
            echo -e "  ${YELLOW}$line${NC}"
        done
    else
        print_ok "هیچ پردازه‌ای از مسیرهای موقت اجرا نشده است."
    fi

    # ۵. بار بالای سیستم (Load Average)
    LOAD=$(uptime | awk -F'load average:' '{print $2}' | xargs)
    print_info "میانگین بار سیستم (Load Average) - ۱، ۵، ۱۵ دقیقه:"
    echo -e "  ${BOLD}$LOAD${NC}"
    # بررسی تقریبی
    LOAD_1=$(echo $LOAD | cut -d, -f1)
    if (( $(echo "$LOAD_1 > $CPU_CORES" | bc -l) )); then
        print_warn "بار سیستم بیشتر از تعداد هسته‌هاست! ممکن است سیستم تحت فشار باشد."
    fi
}

# ---------- سطح ۴: نقض‌های بزرگ و بحرانی ----------
show_level4() {
    print_header "سطح ۴ - بررسی نقض‌های بزرگ و بحرانی سیستم ⚠️"

    # ۱. فایل‌های SUID/SGID مشکوک (به‌خصوص فایل‌های غیرمعمول)
    print_info "بررسی فایل‌های SUID/SGID (احتمالاً خطرناک):"
    echo "  (نمایش ۱۵ مورد اول - در صورت وجود)"
    SUID_FILES=$(find / -xdev -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null | head -15)
    if [ -n "$SUID_FILES" ]; then
        echo "$SUID_FILES" | while read file; do
            PERMS=$(ls -la "$file" 2>/dev/null | awk '{print $1}')
            echo -e "  ${RED}${PERMS}${NC} ${YELLOW}$file${NC}"
        done
        TOTAL_SUID=$(find / -xdev -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null | wc -l)
        echo -e "  ${YELLOW}تعداد کل: $TOTAL_SUID فایل${NC}"
        print_warn "وجود بیش از حد فایل‌های SUID غیرسیستمی می‌تواند خطرناک باشد!"
    else
        print_ok "فایل SUID/SGID خاصی یافت نشد (یا دسترسی محدود)."
    fi

    # ۲. بررسی کرون‌جاب‌های (Cron) کاربران
    print_info "بررسی کرون‌جاب‌های ناشناس یا غیرمعمول:"
    echo "  کرون جاب‌های ریشه (root):"
    CRON_ROOT=$(sudo crontab -l -u root 2>/dev/null | grep -v "^#" | grep -v "^$")
    if [ -n "$CRON_ROOT" ]; then
        echo "$CRON_ROOT" | while read line; do
            echo -e "    ${YELLOW}$line${NC}"
        done
    else
        echo "    (هیچ کرونی برای ریشه تعریف نشده)"
    fi

    echo "  کرون جاب‌های سیستم در /etc/cron.d:"
    ls -la /etc/cron.d/ 2>/dev/null | grep -v "^total" | while read line; do
        echo -e "    ${YELLOW}$line${NC}"
    done || echo "    پوشه موجود نیست."

    # ۳. تنظیمات خطرناک SSH
    print_info "بررسی تنظیمات خطرناک SSH در /etc/ssh/sshd_config:"
    if [ -f /etc/ssh/sshd_config ]; then
        # PermitRootLogin
        if grep -qi "^PermitRootLogin yes" /etc/ssh/sshd_config; then
            print_danger "ورود ریشه (Root) با SSH مجاز است! (PermitRootLogin yes)"
        elif grep -qi "^PermitRootLogin prohibit-password" /etc/ssh/sshd_config; then
            print_warn "ورود ریشه با کلید مجاز است (خطر متوسط)"
        else
            print_ok "ورود ریشه محدود شده است (امن)."
        fi

        # PasswordAuthentication
        if grep -qi "^PasswordAuthentication yes" /etc/ssh/sshd_config; then
            print_danger "احراز هویت با رمز عبور در SSH فعال است! (خطر حملات Brute-Force)"
        else
            print_ok "احراز هویت با رمز عبور غیرفعال است (امن‌تر)."
        fi
    else
        echo "  فایل sshd_config یافت نشد."
    fi

    # ۴. کاربران دارای UID صفر (ریشه) غیر از root
    print_info "بررسی کاربران دارای UID=0 (دسترسی ریشه):"
    UID0_USERS=$(awk -F: '($3==0){print $1}' /etc/passwd | grep -v "^root$")
    if [ -n "$UID0_USERS" ]; then
        echo "$UID0_USERS" | while read user; do
            print_danger "کاربر ${user} نیز دارای UID صفر است! (نقض امنیتی بزرگ)"
        done
    else
        print_ok "فقط کاربر root دارای UID صفر است."
    fi

    # ۵. رمزهای عبور خالی در /etc/shadow
    print_info "بررسی کاربران با رمز عبور خالی:"
    EMPTY_PASS=$(sudo awk -F: '($2==""){print $1}' /etc/shadow 2>/dev/null)
    if [ -n "$EMPTY_PASS" ]; then
        echo "$EMPTY_PASS" | while read user; do
            print_danger "کاربر ${user} رمز عبور خالی دارد! (بحرانی)"
        done
    else
        print_ok "هیچ کاربری با رمز خالی یافت نشد."
    fi

    # ۶. ماژول‌های کرنل بارگذاری شده (چک کردن ماژول‌های غیرعادی)
    print_info "بررسی ماژول‌های کرنل بارگذاری شده (به دنبال ماژول‌های مشکوک):"
    LOADED_MODS=$(lsmod | awk '{print $1}' | tail -n +2)
    SUSPICIOUS_MODS=$(echo "$LOADED_MODS" | grep -E "hidp|nfsd|vbox|vmw|wrapper|inject|hide" | head -5)
    if [ -n "$SUSPICIOUS_MODS" ]; then
        echo "$SUSPICIOUS_MODS" | while read mod; do
            print_warn "ماژول ${mod} بارگذاری شده است (ممکن است خطرناک باشد)."
        done
    else
        print_ok "ماژول خاصی یافت نشد."
    fi

    # ۷. خطاهای بحرانی در dmesg (اخیر)
    print_info "بررسی خطاهای بحرانی اخیر در هسته (dmesg):"
    DMESG_ERR=$(sudo dmesg | tail -20 | grep -iE "segfault|panic|oops|bug|corrupt|deadlock")
    if [ -n "$DMESG_ERR" ]; then
        echo "$DMESG_ERR" | while read line; do
            echo -e "  ${RED}$line${NC}"
        done
    else
        print_ok "خطای بحرانی خاصی در dmesg مشاهده نشد."
    fi

    # ۸. توصیه نهایی
    echo -e "\n${RED}${BOLD}■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■${NC}"
    echo -e "${RED}${BOLD}نتیجه‌گیری سطح ۴: اگر مورد قرمزی (خطا/نقض) در بالا دیدید،${NC}"
    echo -e "${RED}${BOLD}سیستم شما در معرض خطر است. حتماً اقدامات امنیتی را سریعاً انجام دهید.${NC}"
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
        1|2|3|4)
            LEVEL=$choice
            # بعد از انتخاب، ادامه اجرا
            ;;
        0)
            echo -e "${GREEN}خروج از برنامه.${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}گزینه نامعتبر! لطفاً دوباره تلاش کنید.${NC}"
            sleep 1
            show_menu
            return
            ;;
    esac
}

# ============================================================
# ---------- بخش اصلی (Main) ----------
# ============================================================

# اگر آرگومان داده نشد، منو را نمایش بده
if [ -z "$1" ]; then
    show_menu
    # حالا LEVEL توسط منو تنظیم شده است
else
    LEVEL=$1
    # بررسی معتبر بودن سطح
    if [[ ! "$LEVEL" =~ ^[1-4]$ ]]; then
        echo -e "${RED}خطا: سطح نامعتبر است! لطفاً عدد ۱ تا ۴ را وارد کنید.${NC}"
        echo -e "${BOLD}استفاده از اسکریپت:${NC}"
        echo "  $0 [1|2|3|4]"
        echo ""
        echo "  1 - اطلاعات عادی لینوکس (سیستم، پردازنده، حافظه، دیسک)"
        echo "  2 - اطلاعات عادی + اطلاعات شبکه (IP، پورت، دروازه)"
        echo "  3 - بررسی نقض‌های سیستمی (ورود ناموفق، خطاهای sudo، سرویس‌های خراب)"
        echo "  4 - بررسی نقض‌های بزرگ (فایل‌های SUID، کرون خطرناک، تنظیمات SSH، کاربران ریشه)"
        exit 1
    fi
fi

# ---------- ✅ چک کردن آپدیت (قبل از هر کاری) ----------
check_for_updates "$@"

# ---------- ادامه اجرای اصلی ----------
# بررسی دسترسی ریشه
check_root

# اجرای سطوح به صورت پله‌ای
case $LEVEL in
    1)
        show_level1
        ;;
    2)
        show_level1
        show_level2
        ;;
    3)
        show_level1
        show_level2
        show_level3
        ;;
    4)
        show_level1
        show_level2
        show_level3
        show_level4
        ;;
    *)
        echo -e "${RED}خطا: سطح نامعتبر است! لطفاً عدد ۱ تا ۴ را وارد کنید.${NC}"
        exit 1
        ;;
esac

echo -e "\n${GREEN}${BOLD}✓ پایان بررسی.${NC}"
exit 0
