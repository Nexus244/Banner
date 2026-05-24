<?php

namespace Pterodactyl\Http\Controllers\Admin;

use Illuminate\Http\Request;
use Illuminate\View\View;
use Illuminate\Http\RedirectResponse;
use Pterodactyl\Models\PanelBannerSetting;
use Pterodactyl\Http\Controllers\Controller;

class PanelBannerController extends Controller
{
    public function index(Request $request): View
    {
        abort_unless($request->user() && $request->user()->root_admin, 403);

        $banner = $this->getBanner();

        return view('admin.banner.index', [
            'banner' => $banner,
        ]);
    }

    public function update(Request $request): RedirectResponse
    {
        abort_unless($request->user() && $request->user()->root_admin, 403);

        $data = $request->validate([
            'enabled' => ['nullable', 'boolean'],
            'type' => ['required', 'in:info,warning,promo'],
            'title' => ['nullable', 'string', 'max:120'],
            'message' => ['nullable', 'string', 'max:1000'],
        ]);

        $banner = $this->getBanner();
        $banner->update([
            'enabled' => $request->boolean('enabled'),
            'type' => $data['type'],
            'title' => $data['title'] ?? null,
            'message' => $data['message'] ?? null,
        ]);

        return redirect('/admin/banner')->with('success', 'Pengaturan banner berhasil disimpan.');
    }

    private function getBanner(): PanelBannerSetting
    {
        $banner = PanelBannerSetting::query()->first();

        if (!$banner) {
            $banner = PanelBannerSetting::query()->create([
                'enabled' => false,
                'type' => 'info',
                'title' => 'Informasi',
                'message' => 'Selamat datang di panel.',
            ]);
        }

        return $banner;
    }
}
