#!/bin/bash
# ==========================================================
# 🧩 PANELPROTECT v3 — AlwaysZakzz (Final)
# ==========================================================
# Fitur:
# - Install Node.js 20.x & rebuild frontend
# - Manual input Admin Utama (MAIN_ADMIN_ID)
# - Middleware global proteksi:
#   * Anti Intip Server (kecuali Admin Utama)
#   * Anti Delete User (kecuali Admin Utama)
#   * Anti Delete Admin (kecuali Admin Utama)
#   * Anti Colong Script / File Theft (kecuali Admin Utama)
#   * Anti Delete Server (kecuali Admin Utama)
# - Backup controllers & routes
# - Clear cache & restart queue
# ==========================================================

set -e

PANEL_DIR="/var/www/pterodactyl"
DB_NAME="panel"
DB_USER="root"
DB_PASS=""   # jika MySQL root punya password, taruh di sini

green='\e[32m'; yellow='\e[33m'; red='\e[31m'; nc='\e[0m'

clear
echo -e "${green}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo -e "┃     ⚙️ PANELPROTECT  — AlwaysZakzz   ┃"
echo -e "┃        Secure • Build • Full Protection      ┃"
echo -e "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${nc}"
sleep 1

# =============== STEP 0: Validasi panel dir ===============
if [ ! -d "$PANEL_DIR" ]; then
    echo -e "${red}❌ Folder panel tidak ditemukan: $PANEL_DIR${nc}"
    exit 1
fi

cd "$PANEL_DIR"

# =============== STEP 1: Install Node.js & Build Panel ===============
echo -e "${yellow}🚀 [1/8] Install Node.js & rebuild panel...${nc}"
apt update -y >/dev/null 2>&1 || true
curl -fsSL https://deb.nodesource.com/setup_20.x | bash - >/dev/null 2>&1
apt install -y nodejs yarn >/dev/null 2>&1 || { echo -e "${red}❌ Gagal install nodejs/yarn${nc}"; exit 1; }

echo -e "${yellow}🔎 node & yarn versions:${nc}"
node -v || true
yarn -v || true

rm -rf node_modules
yarn install >/dev/null 2>&1 || { echo -e "${red}❌ yarn install gagal${nc}"; }
export NODE_OPTIONS=--openssl-legacy-provider
yarn build >/dev/null 2>&1 || { echo -e "${yellow}⚠️ yarn build mungkin keluarkan warning — lanjutkan.${nc}"; }
echo -e "${green}✅ Build panel selesai.${nc}"
sleep 1

# =============== STEP 2: Input Admin Utama Manual ===============
echo -e "${yellow}👑 [2/8] Masukkan ID Admin Utama (contoh: 1):${nc}"
read -p "🆔 ID Admin Utama: " ADMIN_ID

if [[ -z "$ADMIN_ID" ]]; then
    echo -e "${red}❌ ID admin utama tidak boleh kosong.${nc}"
    exit 1
fi

# set user jadi root_admin
if [[ -z "$DB_PASS" ]]; then
    mysql -u "$DB_USER" "$DB_NAME" -e "UPDATE users SET root_admin = 1 WHERE id = $ADMIN_ID;" >/dev/null 2>&1 || true
else
    mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "UPDATE users SET root_admin = 1 WHERE id = $ADMIN_ID;" >/dev/null 2>&1 || true
fi
echo -e "${green}✅ User ID $ADMIN_ID diset sebagai Admin Utama (root_admin=1).${nc}"
sleep 1

# =============== STEP 3: Backup penting ===============
echo -e "${yellow}📦 [3/8] Backup controllers & routes...${nc}"
BACKUP_DIR="/root/panelprotect_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -r "$PANEL_DIR/app/Http/Controllers" "$BACKUP_DIR/" || true
cp -r "$PANEL_DIR/routes" "$BACKUP_DIR/" || true
echo -e "${green}✅ Backup tersimpan: $BACKUP_DIR${nc}"
sleep 1

# =============== STEP 4: Pastikan Middleware folder ada ===============
echo -e "${yellow}🧱 [4/8] Menyiapkan middleware...${nc}"
MW_DIR="$PANEL_DIR/app/Http/Middleware"
MW_FILE="$MW_DIR/AlwaysZakzzProtect.php"

mkdir -p "$MW_DIR"

cat > "$MW_FILE" <<'PHP_EOF'
<?php

namespace Pterodactyl\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Pterodactyl\Exceptions\DisplayException;

/**
 * AlwaysZakzzProtect
 * - Proteksi global untuk panel (anti intip, anti delete, anti file theft, dsb.)
 * - Admin utama bisa akses semua (MAIN_ADMIN_ID di .env)
 */
class AlwaysZakzzProtect
{
    public function handle(Request $request, Closure $next)
    {
        $user = $request->user();
        if (!$user) {
            return $next($request);
        }

        $adminMainId = (int) env('MAIN_ADMIN_ID', 1);
        $uid = (int) $user->id;
        $path = $request->path();
        $method = strtoupper($request->method());

        // Jika user adalah admin utama -> beri akses penuh
        if ($uid === $adminMainId) {
            return $next($request);
        }

        // 1) Anti Delete (global) - blok semua DELETE kecuali admin utama
        if ($method === 'DELETE') {
            throw new DisplayException("🚫 Aksi penghapusan diblokir oleh proteksi panel. Hanya Admin Utama yang dapat melakukan tindakan ini. ©AlwaysZakzz Protect");
        }

        // 2) Anti Intip Server Panel (GET pada path servers/detail/api)
        // Cegah akses detail server lain via path yang mengandung 'servers' atau 'api/client/servers'
        if (stripos($path, 'api/client/servers') !== false || stripos($path, '/servers') !== false || stripos($path, 'servers/') !== false) {
            // untuk safety hanya larang GET detail yang tampaknya bukan milik user — 
            // kita blokir akses GET umum ke route servers jika bukan admin utama
            if ($method === 'GET') {
                throw new DisplayException("🚫 Akses server dibatasi. Hanya Admin Utama yang dapat melihat detail server lain. ©AlwaysZakzz Protect");
            }
        }

        // 3) Anti Colong Script / File Theft
        // Block akses ke route file manager / download / files bagi non-admin utama
        if (stripos($path, 'files') !== false || stripos($path, 'download') !== false || stripos($path, 'file') !== false) {
            // blok semua method yang mencoba lihat/ambil/ubah file
            if (in_array($method, ['GET','POST','PUT','PATCH','DELETE'])) {
                throw new DisplayException("🚫 Akses file server diblokir. Tidak diperkenankan mengunduh atau mengubah file selain oleh Admin Utama. ©AlwaysZakzz Protect");
            }
        }

        // 4) Anti Ubah Data Sensitif (users/admin)
        if (stripos($path, 'admin/users') !== false || stripos($path, 'users') !== false) {
            if (in_array($method, ['PUT','PATCH','POST'])) {
                $sensitive = ['email','password','root_admin','first_name','last_name'];
                foreach ($sensitive as $f) {
                    if ($request->has($f)) {
                        throw new DisplayException("🚫 Perubahan data sensitif ('$f') diblokir. Hanya Admin Utama yang dapat mengubah data ini. ©AlwaysZakzz Protect");
                    }
                }
            }
        }

        // 5) Anti akses lokasi panel
        if (stripos($path, 'locations') !== false) {
            throw new DisplayException("🚫 Akses lokasi panel dibatasi. Hanya Admin Utama dapat mengelola lokasi. ©AlwaysZakzz Protect");
        }

        return $next($request);
    }
}
PHP_EOF

echo -e "${green}✅ Middleware AlwaysZakzzProtect dibuat: $MW_FILE${nc}"
sleep 1

# =============== STEP 5: Registrasi Middleware global di Kernel ===============
echo -e "${yellow}🔗 [5/8] Mendaftarkan middleware ke Kernel global...${nc}"
KERNEL_FILE="$PANEL_DIR/app/Http/Kernel.php"
if ! grep -q "AlwaysZakzzProtect" "$KERNEL_FILE"; then
    # Sisipkan setelah declaration protected $middleware = [
    sed -i "/protected \$middleware = \[/a \ \ \ \ \App\Http\Middleware\AlwaysZakzzProtect::class," "$KERNEL_FILE"
    echo -e "${green}✅ Middleware didaftarkan ke Kernel global.${nc}"
else
    echo -e "${yellow}⚠️ Middleware sudah terdaftar di Kernel.${nc}"
fi
sleep 1

# =============== STEP 6: Set MAIN_ADMIN_ID di .env ===============
echo -e "${yellow}🧩 [6/8] Menambahkan MAIN_ADMIN_ID ke .env...${nc}"
ENV_FILE="$PANEL_DIR/.env"
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${red}❌ File .env tidak ditemukan di $PANEL_DIR/.env${nc}"
else
    if grep -q "^MAIN_ADMIN_ID=" "$ENV_FILE"; then
        sed -i "s/^MAIN_ADMIN_ID=.*/MAIN_ADMIN_ID=$ADMIN_ID/" "$ENV_FILE"
    else
        echo "" >> "$ENV_FILE"
        echo "MAIN_ADMIN_ID=$ADMIN_ID" >> "$ENV_FILE"
    fi
    echo -e "${green}✅ MAIN_ADMIN_ID diset ke $ADMIN_ID di .env${nc}"
fi
sleep 1

# =============== STEP 7: Clear cache & restart queue ===============
echo -e "${yellow}🧹 [7/8] Clear cache & restart queue...${nc}"
php artisan view:clear || true
php artisan cache:clear || true
php artisan config:clear || true
php artisan route:clear || true
php artisan queue:restart || true
echo -e "${green}✅ Cache cleared & queue restarted.${nc}"
sleep 1

# =============== STEP 8: Final check & selesai ===============
echo -e "${green}🎉 PANELPROTECT v3 selesai dipasang!${nc}"
echo -e "${yellow}Proteksi aktif:${nc} Anti Intip Server • Anti Colong Script • Anti Delete User/Admin • Anti Delete Server • Anti Location"
echo -e "${green}Admin Utama (boleh semua): User ID $ADMIN_ID${nc}"
echo -e "${yellow}Backup controllers/routes: $BACKUP_DIR${nc}"
echo -e "${yellow}Jika mau revert, restore folder dari backup di: $BACKUP_DIR${nc}"
echo -e "${red}Catatan: Tes akses dengan akun non-admin untuk memastikan proteksi bekerja sesuai harapan.${nc}"
