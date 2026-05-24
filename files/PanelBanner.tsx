import React, { useEffect, useState } from 'react';
import http from '@/api/http';

type BannerType = 'info' | 'warning' | 'promo';

interface BannerData {
    enabled: boolean;
    type: BannerType;
    title?: string | null;
    message?: string | null;
}

const typeStyles: Record<BannerType, { border: string; label: string }> = {
    info: {
        border: 'border-blue-500',
        label: 'Informasi',
    },
    warning: {
        border: 'border-yellow-500',
        label: 'Warning',
    },
    promo: {
        border: 'border-green-500',
        label: 'Promosi',
    },
};

export default function PanelBanner() {
    const [banner, setBanner] = useState<BannerData | null>(null);
    const [hidden, setHidden] = useState(false);

    useEffect(() => {
        http.get('/api/client/panel-banner')
            .then(({ data }) => setBanner(data))
            .catch(() => setBanner(null));
    }, []);

    if (!banner || !banner.enabled || hidden || !banner.message) {
        return null;
    }

    const style = typeStyles[banner.type] || typeStyles.info;

    return (
        <div className={`relative mb-4 rounded bg-white p-4 pl-5 shadow border-l-4 ${style.border}`}>
            <button
                type={'button'}
                onClick={() => setHidden(true)}
                className={'absolute right-3 top-3 text-gray-400 hover:text-gray-700 focus:outline-none'}
                aria-label={'Tutup banner'}
            >
                ✕
            </button>

            <div className={'pr-8'}>
                <div className={'mb-1 text-sm font-semibold text-gray-800'}>
                    {banner.title || style.label}
                </div>

                <div className={'text-sm leading-relaxed text-gray-600'}>
                    {banner.message}
                </div>
            </div>
        </div>
    );
}
