import 'dotenv/config';

// export const env = {
//     baseURL: process.env.BASE_URL!,
//     companyCode: process.env.COMPANY_CODE!,
//     username: process.env.AOA_USERNAME!,
//     password: process.env.AOA_PASSWORD!,
//     lat: Number(process.env.AOA_LAT || 25.0330),
//     lon: Number(process.env.AOA_LON || 121.5654),
//     timezoneId: process.env.TZ || 'Asia/Taipei',
//     locale: process.env.LOCALE || 'zh-TW',
// };
export const env = {
    baseURL: 'https://erpline.aoacloud.com.tw/',
    companyCode: 'CYBERBIZ',
    username: 'jeffery.liu',
    password: 'A130608720',
    lat: Number(process.env.AOA_LAT || 25.0330),
    lon: Number(process.env.AOA_LON || 121.5654),
    timezoneId: process.env.TZ || 'Asia/Taipei',
    locale: process.env.LOCALE || 'zh-TW',
};

