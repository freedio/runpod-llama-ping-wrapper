FROM busybox:1.36.1 AS bb

FROM ghcr.io/ggml-org/llama.cpp:server-cuda

# Add busybox so we can run a tiny health server without installing packages
COPY --from=bb /bin/busybox /bin/busybox

COPY start.sh /start.sh
RUN chmod +x /start.sh

ENTRYPOINT ["/start.sh"]
