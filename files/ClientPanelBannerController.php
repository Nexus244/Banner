<?php

namespace Pterodactyl\Http\Controllers\Api\Client;

use Illuminate\Http\JsonResponse;
use Pterodactyl\Models\PanelBannerSetting;
use Pterodactyl\Http\Controllers\Api\Client\ClientApiController;

class PanelBannerController extends ClientApiController
{
    public function show(): JsonResponse
    {
        $banner = PanelBannerSetting::query()->first();

        return response()->json([
            'enabled' => (bool) optional($banner)->enabled,
            'type' => optional($banner)->type ?: 'info',
            'title' => optional($banner)->title,
            'message' => optional($banner)->message,
        ]);
    }
}
