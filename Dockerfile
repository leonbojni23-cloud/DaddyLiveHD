ARG PORT=3000
ARG PROXY_CONTENT=TRUE
ARG SOCKS5
ARG API_URL

# Build on the Python version documented and tested by this project.
FROM python:3.12-slim AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app
RUN mkdir -p /app/.web && python -m venv /app/.venv
ENV PATH="/app/.venv/bin:$PATH"

COPY requirements.txt ./
RUN pip install --no-cache-dir --upgrade pip setuptools wheel \
    && pip install --no-cache-dir -r requirements.txt

COPY rxconfig.py ./
RUN reflex init

COPY . .

ARG PORT API_URL PROXY_CONTENT SOCKS5
RUN REFLEX_API_URL=${API_URL:-http://localhost:${PORT:-3000}} \
    reflex export --loglevel debug --frontend-only --no-zip \
    && mkdir -p /srv \
    && cp -a .web/build/client/. /srv/ \
    && rm -rf .web

FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends caddy redis-server \
    && rm -rf /var/lib/apt/lists/*

ARG PORT=3000
ARG API_URL
ARG PROXY_CONTENT=TRUE
ARG SOCKS5

ENV PATH="/app/.venv/bin:$PATH" \
    PORT=${PORT} \
    REFLEX_API_URL=${API_URL:-http://localhost:${PORT}} \
    REDIS_URL=redis://localhost \
    PROXY_CONTENT=${PROXY_CONTENT} \
    SOCKS5=${SOCKS5}

WORKDIR /app
COPY --from=builder /app /app
COPY --from=builder /srv /srv

EXPOSE ${PORT}
STOPSIGNAL SIGTERM

CMD ["sh", "-c", "caddy start && redis-server --daemonize yes && exec reflex run --env prod --backend-only"]
