FROM node:20-slim

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

COPY package*.json ./

RUN npm ci --omit=dev \
    && npm cache clean --force

COPY --chown=node:node . .

RUN mkdir -p /app/logs \
    && chown -R node:node /app

USER node

EXPOSE 3000

CMD ["node", "server.js"]
