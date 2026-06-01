# syntax=docker/dockerfile:1

FROM node:24-bookworm AS build

WORKDIR /app

COPY package.json package-lock.json .npmrc ./

ENV PUPPETEER_SKIP_DOWNLOAD=true

RUN npm ci --ignore-scripts

COPY . .

ENV NODE_OPTIONS=--max_old_space_size=4096

RUN node scripts/prepare.ts

RUN npm run bundle

FROM node:24-bookworm AS runtime

WORKDIR /app

ENV NODE_ENV=production \
    CI=true \
    CHROME_DEVTOOLS_MCP_NO_UPDATE_CHECKS=1 \
    PUPPETEER_SKIP_DOWNLOAD=true

COPY package.json package-lock.json .npmrc ./

RUN npm ci --ignore-scripts \
    && npm cache clean --force

COPY --from=build /app/build ./build
COPY --from=build /app/LICENSE ./LICENSE

# Install "Chrome for Testing" into the Puppeteer cache and expose it at a
# fixed path. The server otherwise resolves Chrome by channel and looks for a
# branded install at /opt/google/chrome/chrome, which does not exist here.
RUN apt-get update \
    && npx puppeteer browsers install chrome --install-deps \
    && ln -sf "$(find /root/.cache/puppeteer/chrome -type f -name chrome | head -n 1)" /usr/local/bin/chrome \
    && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["node", "build/src/bin/chrome-devtools-mcp.js"]

# Headless + isolated profile, with Chrome flags required inside containers.
CMD ["--headless", "--isolated", "--executablePath=/usr/local/bin/chrome", "--chrome-arg=--no-sandbox", "--chrome-arg=--disable-setuid-sandbox", "--chrome-arg=--disable-dev-shm-usage"]
