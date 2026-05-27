FROM python:3.12-alpine

RUN apk add --no-cache git && \
    pip install --no-cache-dir \
        git+https://github.com/Kozea/Radicale.git@master && \
    apk del git

COPY plugin /opt/radicale-oauth2-hybrid
RUN pip install --no-cache-dir /opt/radicale-oauth2-hybrid

# Auto-login web UI when session cookie is present (PROPFIND probe).
RUN sed -i "s/credentials: 'omit'/credentials: 'include'/" \
    /usr/local/lib/python3.12/site-packages/radicale/web/internal_data/js/scenes/LoginScene.js

RUN adduser -D -h /data radicale && \
    mkdir -p /data && chown radicale:radicale /data

EXPOSE 5232
USER radicale
CMD ["python", "-m", "radicale", "--config", "/etc/radicale/config"]
