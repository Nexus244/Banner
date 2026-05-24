<?php

namespace Pterodactyl\Models;

use Illuminate\Database\Eloquent\Model;

class PanelBannerSetting extends Model
{
    protected $table = 'panel_banner_settings';

    protected $fillable = [
        'enabled',
        'type',
        'title',
        'message',
    ];

    protected $casts = [
        'enabled' => 'boolean',
    ];
}
