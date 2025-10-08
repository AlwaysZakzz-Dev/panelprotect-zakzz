#!/bin/bash
# ==========================================================
# 🧩 PANELPROTECT — AlwaysZakzz
# ==========================================================
# Fitur:
# ✅ Anti Intip Server
# ✅ Anti Delete User/Admin/Server
# ✅ Anti Colong Script / File Theft
# ✅ Anti Akses Lokasi Panel
# ✅ Manual Input Admin Utama
# ✅ Auto Deteksi Namespace Middleware (App/Pterodactyl)
# ✅ Fix Permission & Clear Cache Aman
# ✅ Backup controllers & routes
# ==========================================================

set -euo pipefail

PANEL_DIR="/var/www/pterodactyl"
DB_NAME="panel"
DB_USER="root"
DB_PASS=""    # isi jika MySQL root pakai password

green='\e[32m'; yellow='\e[33m'; red='\e[31m'; nc='\e[0m'

# ----------------- helper -----------------
err_exit() {
  echo -e "${red}✖ $1${nc}"
  exit 1
}

info() { echo -e "${green}✔ $1${nc}"; }
warn() { echo -e "${yellow}⚠ $1${nc}"; }

clear
echo -e "${green}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo -e "┃     ⚙️ PANELPROTECT v3.1 — AlwaysZakzz         ┃"
echo -e "┃        Secure • Build • Full Protection        ┃"
echo -e "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${nc}"
sleep 1

# 0. Validasi path
if [ ! -d "$PANEL_DIR" ]; then
  err_exit "Folder panel tidak ditemukan: $PANEL_DIR. Pastikan path benar."
fi
cd "$PANEL_DIR" || err_exit "Gagal masuk ke $PANEL_DIR"

# 1. Install Node & rebuild frontend (safe)
echo -e "${yellow}🚀 [1/9] Install Node.js & rebuild panel (safe) ...${nc}"
apt update -y >/dev/null 2>&1 || warn "apt update gagal (lanjut)"
curl -fsSL https://deb.nodesource.com/setup_20.x | bash - >/dev/null 2>&1 || warn "setup nodesource gagal (lanjut)"
apt install -y nodejs yarn >/dev/null 2>&1 || warn "install nodejs/yarn gagal (lanjut)"

echo -e "${yellow}🔎 Versi node & yarn:${nc}"
node -v || warn "node tidak terdeteksi"
yarn -v || warn "yarn tidak terdeteksi"

rm -rf node_modules || true
yarn install >/dev/null 2>&1 || warn "yarn install gagal (lanjut)"
export NODE_OPTIONS=--openssl-legacy-provider
yarn build >/dev/null 2>&1 || warn "yarn build warning (lanjut)"
info "Build panel selesai (jika ada warning, periksa manual)."

# 2. Input Admin Utama
echo -e "${yellow}👑 [2/9] Masukkan ID Admin Utama (contoh: 1):${nc}"
read -r -p "🆔 ID Admin Utama: " ADMIN_ID
if [[ -z "${ADMIN_ID// }" ]]; then
  err_exit "ID Admin Utama tidak boleh kosong."
fi

# set user jadi root_admin (mysql)
if [[ -z "$DB_PASS" ]]; then
  mysql -u "$DB_USER" "$DB_NAME" -e "UPDATE users SET root_admin = 1 WHERE id = $ADMIN_ID;" >/dev/null 2>&1 || warn "Query MySQL gagal/diabaikan."
else
  mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "UPDATE users SET root_admin = 1 WHERE id = $ADMIN_ID;" >/dev/null 2>&1 || warn "Query MySQL gagal/diabaikan."
fi
info "User ID $ADMIN_ID diset sebagai Admin Utama (root_admin=1) — jika query gagal, periksa kredensial DB."

# 3. Backup controllers & routes
echo -e "${yellow}📦 [3/9] Backup controllers & routes ...${nc}"
BACKUP_DIR="/root/panelprotect_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -r "$PANEL_DIR/app/Http/Controllers" "$BACKUP_DIR/" 2>/dev/null || warn "Backup controllers gagal/diabaikan"
cp -r "$PANEL_DIR/routes" "$BACKUP_DIR/" 2>/dev/null || warn "Backup routes gagal/diabaikan"
info "Backup dibuat: $BACKUP_DIR (jika ada masalah, cek permission)."

# 4. Deteksi namespace (App atau Pterodactyl)
echo -e "${yellow}🔍 [4/9] Deteksi namespace middleware ...${nc}"
NS_DETECT_FILE="app/Http/Middleware/Authenticate.php"
if [ -f "$NS_DETECT_FILE" ]; then
  NS_LINE=$(head -n 5 "$NS_DETECT_FILE" | grep -i "namespace" || true)
  if [[ -n "$NS_LINE" ]]; then
    # extract namespace token (2nd word)
    NS=$(echo "$NS_LINE" | awk '{print $2}' | tr -d ';')
  else
    NS="App\\Http\\Middleware"
  fi
else
  NS="App\\Http\\Middleware"
fi
info "Namespace dideteksi: $NS"

# 5. Buat middleware proteksi
echo -e "${yellow}🧱 [5/9] Menulis middleware AlwaysZakzzProtect ...${nc}"
MW_DIR="$PANEL_DIR/app/Http/Middleware"
MW_FILE="$MW_DIR/AlwaysZakzzProtect.php"
mkdir -p "$MW_DIR"

cat > "$MW_FILE" <<PHP_EOF
<?php
namespace $NS;

use Closure;
use Illuminate\Http\Request;

/**
 * AlwaysZakzzProtect
 * Proteksi global: anti intip, anti delete, anti file theft, anti ubah sensitif.
 * Admin Utama (MAIN_ADMIN_ID di .env) akan dibebaskan.
 */
class AlwaysZakzzProtect
{
    public function handle(Request \$request, Closure \$next)
    {
        \$user = \$request->user();
        if (!\$user) {
            return \$next(\$request);
        }

        \$adminMainId = (int) env('MAIN_ADMIN_ID', 1);
        \$uid = (int) \$user->id;
        \$path = \$request->path();
        \$method = strtoupper(\$request->method());

        // jika admin utama -> bebas
        if (\$uid === \$adminMainId) {
            return \$next(\$request);
        }

        // 1) Anti Delete global
        if (\$method === 'DELETE') {
            abort(403, '⚠️ Aksi penghapusan diblokir. Hanya Admin Utama yang dapat melakukan penghapusan. ©AlwaysZakzz Protect');
        }

        // 2) Anti Intip Server (blok GET umum ke route servers bagi non-admin)
        if (stripos(\$path, 'api/client/servers') !== false || stripos(\$path, 'servers') !== false) {
            if (\$method === 'GET') {
                abort(403, '⚠️ Akses server dibatasi. Hanya Admin Utama dapat melihat detail server lain. ©AlwaysZakzz Protect');
            }
        }

        // 3) Anti Colong Script / File Theft (blok file/download/files)
        if (stripos(\$path, 'files') !== false || stripos(\$path, 'download') !== false || stripos(\$path, 'file') !== false) {
            abort(403, '⚠️ Akses file server diblokir. Tidak diperkenankan mengunduh atau mengubah file selain oleh Admin Utama. ©AlwaysZakzz Protect');
        }

        // 4) Anti Ubah data sensitif (users/admin)
        if (stripos(\$path, 'admin/users') !== false || stripos(\$path, '/users') !== false) {
            if (in_array(\$method, ['POST','PUT','PATCH'])) {
                \$sensitive = ['email','password','root_admin','first_name','last_name'];
                foreach (\$sensitive as \$f) {
                    if (\$request->has(\$f)) {
                        abort(403, \"⚠️ Perubahan data sensitif ('\$f') diblokir. Hanya Admin Utama yang dapat mengubah data ini. ©AlwaysZakzz Protect\");
                    }
                }
            }
        }

        // 5) Anti akses lokasi panel
        if (stripos(\$path, 'locations') !== false) {
            abort(403, '⚠️ Akses lokasi panel dibatasi. Hanya Admin Utama dapat mengelola lokasi. ©AlwaysZakzz Protect');
        }

        return \$next(\$request);
    }
}
PHP_EOF

info "Middleware dibuat: $MW_FILE"

# 6. Daftarkan middleware di Kernel (global)
echo -e "${yellow}🔗 [6/9] Mendaftarkan middleware ke Kernel ...${nc}"
KERNEL_FILE="$PANEL_DIR/app/Http/Kernel.php"
if [ -f "$KERNEL_FILE" ]; then
  if ! grep -q "AlwaysZakzzProtect" "$KERNEL_FILE"; then
    # pasang namespace\AlwaysZakzzProtect::class setelah protected $middleware = [
    # melakukan escaping backslashes:
    NS_ESCAPED=$(echo "$NS" | sed 's/\\/\\\\/g')
    sed -i "/protected \$middleware = \[/a \ \ \ \ $NS_ESCAPED\\\\AlwaysZakzzProtect::class," "$KERNEL_FILE" \
      && info "Middleware didaftarkan ke Kernel (global)."
  else
    warn "Middleware sudah ada di Kernel (tidak didaftarkan ulang)."
  fi
else
  warn "Kernel.php tidak ditemukan; middleware dibuat tapi tidak terdaftar otomatis."
fi

# 7. Tulis MAIN_ADMIN_ID ke .env
echo -e "${yellow}🧩 [7/9] Menyimpan MAIN_ADMIN_ID ke .env ...${nc}"
ENV_FILE="$PANEL_DIR/.env"
if [ -f "$ENV_FILE" ]; then
  if grep -q "^MAIN_ADMIN_ID=" "$ENV_FILE"; then
    sed -i "s/^MAIN_ADMIN_ID=.*/MAIN_ADMIN_ID=$ADMIN_ID/" "$ENV_FILE" && info "MAIN_ADMIN_ID diupdate di .env"
  else
    echo "" >> "$ENV_FILE"
    echo "MAIN_ADMIN_ID=$ADMIN_ID" >> "$ENV_FILE"
    info "MAIN_ADMIN_ID ditambahkan ke .env"
  fi
else
  warn ".env tidak ditemukan — silakan buat MAIN_ADMIN_ID manual di file .env"
fi

# 8. Permission & cache cleanup
echo -e "${yellow}🧹 [8/9] Memperbaiki permission & clear cache ...${nc}"
mkdir -p storage/logs bootstrap/cache || true
chown -R www-data:www-data "$PANEL_DIR" || warn "gagal chown www-data (cek user webserver)"
chmod -R 775 "$PANEL_DIR/storage" "$PANEL_DIR/bootstrap/cache" || warn "gagal chmod (cek permission)"

php artisan optimize:clear >/dev/null 2>&1 || warn "artisan optimize:clear gagal (lanjut)"
php artisan view:clear >/dev/null 2>&1 || true
php artisan cache:clear >/dev/null 2>&1 || true
php artisan config:clear >/dev/null 2>&1 || true
php artisan route:clear >/dev/null 2>&1 || true
php artisan queue:restart >/dev/null 2>&1 || true
info "Cache dibersihkan & permission diatur."

# 9. Final & instructions
echo -e "${green}🎉 PANELPROTECT v3.1 terpasang!${nc}"
echo -e "${yellow}Proteksi aktif: Anti Intip Server • Anti Colong Script • Anti Delete User/Admin • Anti Delete Server • Anti Location${nc}"
echo -e "${green}Admin Utama (boleh semua): User ID $ADMIN_ID${nc}"
echo -e "${yellow}Backup controllers/routes: $BACKUP_DIR${nc}"
echo -e "${red}Catatan: Tes akses dengan akun non-admin untuk memastikan proteksi bekerja (akan muncul pesan proteksi berwarna pada panel).${nc}"
echo -e ""
echo -e "${yellow}Untuk revert: restore folder controller/routes dari backup lalu hapus middleware dan entry di Kernel + MAIN_ADMIN_ID di .env${nc}"
