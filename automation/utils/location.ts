// automation/utils/location.ts

/**
 * 根據經緯度返回人類可讀的位置描述
 * 這是一個簡化的版本，使用預定義的台灣地區座標範圍
 */
export function getLocationName(lat: number, lon: number): string {
    // 台灣主要城市的大致座標範圍
    const locations = [
        { name: '台北市', minLat: 25.0, maxLat: 25.2, minLon: 121.4, maxLon: 121.7 },
        { name: '新北市', minLat: 24.8, maxLat: 25.3, minLon: 121.3, maxLon: 122.0 },
        { name: '桃園市', minLat: 24.8, maxLat: 25.1, minLon: 121.0, maxLon: 121.4 },
        { name: '台中市', minLat: 24.0, maxLat: 24.4, minLon: 120.5, maxLon: 121.0 },
        { name: '台南市', minLat: 22.9, maxLat: 23.1, minLon: 120.1, maxLon: 120.4 },
        { name: '高雄市', minLat: 22.5, maxLat: 22.9, minLon: 120.2, maxLon: 120.6 },
        { name: '新竹市', minLat: 24.7, maxLat: 24.9, minLon: 120.9, maxLon: 121.1 },
        { name: '基隆市', minLat: 25.1, maxLat: 25.2, minLon: 121.7, maxLon: 121.8 },
        { name: '嘉義市', minLat: 23.4, maxLat: 23.5, minLon: 120.4, maxLon: 120.5 },
        { name: '宜蘭縣', minLat: 24.4, maxLat: 24.9, minLon: 121.4, maxLon: 122.0 },
        { name: '花蓮縣', minLat: 23.5, maxLat: 24.4, minLon: 121.3, maxLon: 121.7 },
        { name: '台東縣', minLat: 22.5, maxLat: 23.5, minLon: 120.9, maxLon: 121.6 },
    ];

    // 查找匹配的位置
    for (const loc of locations) {
        if (lat >= loc.minLat && lat <= loc.maxLat && 
            lon >= loc.minLon && lon <= loc.maxLon) {
            return loc.name;
        }
    }

    // 如果沒有匹配，返回更一般的描述
    if (lat >= 21.5 && lat <= 25.5 && lon >= 119.5 && lon <= 122.5) {
        return '台灣';
    }

    // 預設返回經緯度
    return `${lat.toFixed(4)}, ${lon.toFixed(4)}`;
}

/**
 * 從環境變數取得位置名稱
 */
export function getEnvLocationName(env: { lat: number; lon: number }): string {
    return getLocationName(env.lat, env.lon);
}