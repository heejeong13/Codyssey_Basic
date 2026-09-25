FROM ubuntu:24.04

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
       ca-certificates iproute2 procps \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --shell /bin/bash agent-admin

WORKDIR /home/agent-admin/agent-app
COPY --chown=agent-admin:agent-admin agent-leak-app-arm64 ./agent-leak-app-arm64
COPY --chown=agent-admin:agent-admin monitor.sh ./monitor.sh

RUN chmod 0755 agent-leak-app-arm64 monitor.sh \
    && mkdir -p upload_files api_keys logs evidence \
    && printf '%s\n' 'agent_api_key_test' > api_keys/secret.key \
    && chown -R agent-admin:agent-admin /home/agent-admin/agent-app

USER agent-admin

ENV AGENT_HOME=/home/agent-admin/agent-app \
    AGENT_PORT=15034 \
    AGENT_UPLOAD_DIR=/home/agent-admin/agent-app/upload_files \
    AGENT_KEY_PATH=/home/agent-admin/agent-app/api_keys \
    AGENT_LOG_DIR=/home/agent-admin/agent-app/logs

EXPOSE 15034
CMD ["./agent-leak-app-arm64"]
