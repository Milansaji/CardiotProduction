// ============================================================
// PM2 Ecosystem Config — WhatsApp CRM
// ============================================================
// Dev:        pm2 start ecosystem.config.cjs
// Production: pm2 start ecosystem.config.cjs --env production
//
// pm2 list               → process status
// pm2 logs               → tail all logs
// pm2 logs backend       → tail one process
// pm2 restart all        → restart
// pm2 reload all         → zero-downtime reload
// pm2 save               → persist across reboots
// pm2 startup            → print startup hook command
// pm2 delete all         → remove all processes
// ============================================================

const path = require('path');
const root = __dirname; // repo root

module.exports = {
    apps: [

        // ──────────────────────────────────────────────────────
        // 1. Express API + Webhook backend  (port 3001)
        //    Has its own package.json + .env inside backend/
        // ──────────────────────────────────────────────────────
        {
            name: 'backend',
            script: 'server.js',             // relative to cwd (backend/)
            cwd: path.join(root, 'backend'), // run FROM the backend folder
            instances: 1,
            exec_mode: 'fork',
            watch: false,
            autorestart: true,
            max_restarts: 10,
            restart_delay: 3000,
            env: {
                NODE_ENV: 'development',
                PORT: 3001,
            },
            env_production: {
                NODE_ENV: 'production',
                PORT: 3001,
            },
            log_date_format: 'YYYY-MM-DD HH:mm:ss',
            error_file: path.join(root, 'logs/backend-error.log'),
            out_file: path.join(root, 'logs/backend-out.log'),
            merge_logs: true,
        },

        // ──────────────────────────────────────────────────────
        // 2. Cardiot Bot  (port 3002)
        //    Has its own package.json + .env inside cardiot-bot-main/
        //    Uses ts-node so no build step needed in dev or prod.
        // ──────────────────────────────────────────────────────
        {
            name: 'cardiot-bot',
            script: path.join(root, 'cardiot-bot-main/node_modules/.bin/ts-node'),
            args: 'src/index.ts',
            cwd: path.join(root, 'cardiot-bot-main'),
            instances: 1,
            exec_mode: 'fork',
            watch: false,
            autorestart: true,
            max_restarts: 10,
            restart_delay: 3000,
            env: {
                NODE_ENV: 'development',
                PORT: 3002,
            },
            env_production: {
                NODE_ENV: 'production',
                PORT: 3002,
            },
            log_date_format: 'YYYY-MM-DD HH:mm:ss',
            error_file: path.join(root, 'logs/cardiot-bot-error.log'),
            out_file: path.join(root, 'logs/cardiot-bot-out.log'),
            merge_logs: true,
        },

        // ──────────────────────────────────────────────────────
        // 3. React Frontend — Vite preview server  (port 8080)
        //    Run `npm run build --prefix Frontend` before starting.
        //    Serves the built SPA and proxies /api → localhost:3001
        // ──────────────────────────────────────────────────────
        {
            name: 'frontend',
            script: path.join(root, 'Frontend/node_modules/.bin/vite'),
            args: 'preview',
            cwd: path.join(root, 'Frontend'),
            instances: 1,
            exec_mode: 'fork',
            watch: false,
            autorestart: true,
            max_restarts: 10,
            restart_delay: 3000,
            env: {
                NODE_ENV: 'development',
                PORT: 8080,
            },
            env_production: {
                NODE_ENV: 'production',
                PORT: 8080,
            },
            log_date_format: 'YYYY-MM-DD HH:mm:ss',
            error_file: path.join(root, 'logs/frontend-error.log'),
            out_file: path.join(root, 'logs/frontend-out.log'),
            merge_logs: true,
        },
    ],
};
