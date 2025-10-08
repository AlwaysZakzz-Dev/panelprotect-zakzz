#!/bin/bash
# ==========================================================
# 🧩 FULL PANEL PROTECT & REBUILD — AlwaysZakzz Edition
# ==========================================================
# Fitur:
# 1. Install Node.js + rebuild frontend panel
# 2. Jadikan user ID 1 sebagai admin penuh
# 3. Tambahkan proteksi anti intip, anti maling, anti ubah data, anti location
# 4. Finalisasi & bersihkan cache panel
# ==========================================================

PANEL_DIR="/var/www/pterodactyl"
DB_NAME="panel"
DB_USER="root"

green='\e[32m'; yellow='\e[33m'; red='\e[31m'; nc='\e[0m'

clear
echo -e "${green}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo -e "┃     ⚙️ FULL PANEL PROTECT — AlwaysZakzz       ┃"
echo -e "┃     Build + Secure + Finalize Automatically   ┃"
echo -e "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${nc}"
sleep 1

# =============== STEP 1: Install Node.js & Build Panel ===============
echo -e "${yellow}🚀 [1/5] Instalasi Node.js & Build Panel...${nc}"
curl -fsSL https://deb.nodesource.com/setup_20.x | bash - >/dev/null 2>&1
apt install -y nodejs >/dev/null 2>&1
node -v

cd $PANEL_DIR || { echo "${red}❌ Folder panel tidak ditemukan!"; exit 1; }

rm -rf node_modules
yarn install
yarn add cross-env
export NODE_OPTIONS=--openssl-legacy-provider
yarn build
echo -e "${green}✅ Build Panel selesai.${nc}"
sleep 1

# =============== STEP 2: Jadikan Admin Utama ===============
echo -e "${yellow}👑 [2/5] Menjadikan User ID 1 sebagai admin penuh...${nc}"
mysql -u $DB_USER -p $DB_NAME -e "UPDATE users SET root_admin = 1 WHERE id = 1;"
echo -e "${green}✅ User ID 1 sekarang admin utama.${nc}"
sleep 1

# =============== STEP 3: Tambah Proteksi Otomatis ===============
echo -e "${yellow}🧱 [3/5] Menambahkan Anti Intip / Anti Ubah Data / Anti Location...${nc}"

# Anti Intip Server
SERVER_CTRL="$PANEL_DIR/app/Http/Controllers/Api/Client/Server/ServerController.php"
if grep -q "AlwaysZakzz" "$SERVER_CTRL"; then
    echo "✔️ Anti Intip Server sudah terpasang."
else
    sed -i '/function index()/a \
$authUser  = Auth()->user();\
if ($authUser->id !== 1 && (int)$server->owner_id !== (int)$authUser->id) {\
    abort(403, "AlwaysZakzz Anti Intip Wkwkwk Kalo Mau Intip Server Minimal Server Punya Lu Bukan Punya Orang");\
}' "$SERVER_CTRL"
    echo "✅ Anti Intip Server ditambahkan."
fi

# Anti Maling SC
FILE_CTRL="$PANEL_DIR/app/Http/Controllers/Api/Client/Server/FileController.php"
if grep -q "AlwaysZakzz" "$FILE_CTRL"; then
    echo "✔️ Anti Maling SC sudah terpasang."
else
    sed -i '78i \
$authUser  = Auth()->user();\
if ($authUser->id !== 1 && (int)$server->owner_id !== (int)$authUser->id) {\
    abort(403, "AlwaysZakzz Anti Intip Wkwkwk Kalo Mau Intip Server Minimal Server Punya Lu Bukan Punya Orang");\
}' "$FILE_CTRL"
    echo "✅ Anti Maling SC ditambahkan."
fi

# Anti Ubah Data User
USER_CTRL="$PANEL_DIR/app/Http/Controllers/Admin/UserController.php"
if grep -q "Anti Ubah Data User" "$USER_CTRL"; then
    echo "✔️ Anti Ubah Data User sudah terpasang."
else
    cat > "$USER_CTRL" <<'EOF'
<?php

namespace Pterodactyl\Http\Controllers\Admin;

use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Collection;
use Spatie\QueryBuilder\QueryBuilder;
use Pterodactyl\Exceptions\DisplayException;
use Pterodactyl\Http\Controllers\Controller;
use Pterodactyl\Http\Requests\Admin\UserFormRequest;
use Pterodactyl\Models\User;

class UserController extends Controller
{
    public function update(UserFormRequest $request, User $user): RedirectResponse
    {
        $restrictedFields = ['password', 'email', 'first_name', 'last_name'];

        foreach ($restrictedFields as $field) {
            if ($request->filled($field) && $request->user()->id !== 1) {
                throw new DisplayException("Anti Ubah Data User Aktif! '{$field}' hanya bisa diubah oleh user ID 1 ©Protect By AlwaysZakzz");
            }
        }

        $this->updateService
            ->setUserLevel(User::USER_LEVEL_ADMIN)
            ->handle($user, $request->normalize());

        $this->alert->success(trans('admin/user.notices.account_updated'))->flash();

        return redirect()->route('admin.users.view', $user->id);
    }

    public function json(Request $request): Model|Collection
    {
        $users = QueryBuilder::for(User::query())->allowedFilters(['email'])->paginate(25);

        if ($request->query('user_id')) {
            $user = User::query()->findOrFail($request->input('user_id'));
            $user->md5 = md5(strtolower($user->email));
            return $user;
        }

        return $users->map(function ($item) {
            $item->md5 = md5(strtolower($item->email));
            return $item;
        });
    }
}
EOF
    echo "✅ Anti Ubah Data User ditambahkan."
fi

# Anti Intip Location
LOCATION_CTRL="$PANEL_DIR/app/Http/Controllers/Admin/LocationController.php"
if grep -q "AlwaysZakzz Protect" "$LOCATION_CTRL"; then
    echo "✔️ Anti Intip Location sudah terpasang."
else
    cat > "$LOCATION_CTRL" <<'EOF'
<?php
namespace Pterodactyl\Http\Controllers\Admin;

use Illuminate\View\View;
use Illuminate\Http\RedirectResponse;
use Illuminate\Support\Facades\Auth;
use Pterodactyl\Models\Location;
use Prologue\Alerts\AlertsMessageBag;
use Illuminate\View\Factory as ViewFactory;
use Pterodactyl\Exceptions\DisplayException;
use Pterodactyl\Http\Controllers\Controller;
use Pterodactyl\Http\Requests\Admin\LocationFormRequest;
use Pterodactyl\Services\Locations\{
    LocationUpdateService,
    LocationCreationService,
    LocationDeletionService
};
use Pterodactyl\Contracts\Repository\LocationRepositoryInterface;

class LocationController extends Controller
{
    public function __construct(
        protected AlertsMessageBag $alert,
        protected LocationCreationService $creationService,
        protected LocationDeletionService $deletionService,
        protected LocationRepositoryInterface $repository,
        protected LocationUpdateService $updateService,
        protected ViewFactory $view
    ) {}

    private function guard()
    {
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            abort(403, "AlwaysZakzz Protect - Akses ditolak");
        }
    }

    public function index(): View
    {
        $this->guard();
        return $this->view->make('admin.locations.index', [
            'locations' => $this->repository->getAllWithDetails(),
        ]);
    }

    public function view(int $id): View
    {
        $this->guard();
        return $this->view->make('admin.locations.view', [
            'location' => $this->repository->getWithNodes($id),
        ]);
    }

    public function create(LocationFormRequest $request): RedirectResponse
    {
        $this->guard();
        $location = $this->creationService->handle($request->normalize());
        $this->alert->success('Location created successfully.')->flash();
        return redirect()->route('admin.locations.view', $location->id);
    }

    public function update(LocationFormRequest $request, Location $location): RedirectResponse
    {
        $this->guard();
        if ($request->input('action') === 'delete') return $this->delete($location);

        $this->updateService->handle($location->id, $request->normalize());
        $this->alert->success('Location updated successfully.')->flash();
        return redirect()->route('admin.locations.view', $location->id);
    }

    public function delete(Location $location): RedirectResponse
    {
        $this->guard();
        try {
            $this->deletionService->handle($location->id);
            return redirect()->route('admin.locations');
        } catch (DisplayException $ex) {
            $this->alert->danger($ex->getMessage())->flash();
            return redirect()->route('admin.locations.view', $location->id);
        }
    }
}
EOF
    echo "✅ Anti Intip Location ditambahkan."
fi

# =============== STEP 4: Finalisasi ===============
echo -e "${yellow}🧹 [4/5] Membersihkan cache panel...${nc}"
php artisan view:clear
php artisan cache:clear
php artisan config:clear
php artisan route:clear
php artisan queue:restart
echo -e "${green}✅ Finalisasi selesai.${nc}"

# =============== SELESAI ===============
echo -e "${green}🎉 Semua langkah selesai! Panel kamu kini: Anti Intip, Anti Maling, Anti Ubah Data, dan Anti Location.${nc}"
echo -e "${yellow}Login ulang ke panel dan nikmati keamanan penuh by AlwaysZakzz.${nc}"
