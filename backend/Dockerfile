# Élan backend. Build:  docker build -t elan-backend .
# Run:  docker run -p 3000:3000 -v elan-data:/data --env-file .env elan-backend
# Serve it behind HTTPS (your host's TLS, or a reverse proxy): patient locations must be encrypted in transit.
FROM node:22-alpine
WORKDIR /app
ENV NODE_ENV=production \
    ELAN_DB_PATH=/data/elan.db
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY . .
# The SQLite database lives on a volume so it survives restarts and redeploys
RUN mkdir -p /data && chown node:node /data
VOLUME /data
USER node
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s CMD wget -qO- http://127.0.0.1:${PORT:-3000}/health || exit 1
CMD ["node", "server.js"]
