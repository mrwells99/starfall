# syntax=docker/dockerfile:1.7
#
# Starfall dedicated server.
#
# Strategy: this repo has no export_presets.cfg and no external assets — all
# geometry is generated at runtime — so a Godot *export* would need ~1 GB of
# export templates to produce a .pck that is essentially the source we already
# have. Instead the image bundles the pinned Godot binary, the project source,
# and a **pre-built import cache**. That gets the properties that actually
# matter in production (immutable artifact, no writes to the project at run
# time, no import race between the six server processes, fast start) without
# the template download. See DEPLOYMENT.md for when to revisit this.

ARG ROCKY_VERSION=9
ARG GODOT_VERSION=4.5.1-stable

# ---------------------------------------------------------------- builder ---
FROM rockylinux/rockylinux:${ROCKY_VERSION} AS builder

ARG GODOT_VERSION
# Official checksum from the Godot release's SHA512-SUMS.txt. Bump both this and
# GODOT_VERSION together; the build fails closed if they disagree.
ARG GODOT_SHA512=5bccbed65a94b82c7c319fdb15719ee8113a6e503976cc54e16f1c61fe95f3d74e5e40b8449b5bb89ff7f424574c20af01a4f5ef08b389e4dc338b245185b0b9

RUN dnf install -y --setopt=install_weak_deps=False unzip wget ca-certificates \
    && dnf clean all && rm -rf /var/cache/dnf

WORKDIR /build

RUN wget -q -O godot.zip \
        "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip" \
    && echo "${GODOT_SHA512}  godot.zip" | sha512sum -c - \
    && unzip -q godot.zip \
    && install -m 0755 "Godot_v${GODOT_VERSION}_linux.x86_64" /usr/local/bin/godot \
    && rm -rf godot.zip "Godot_v${GODOT_VERSION}_linux.x86_64" \
    && godot --version

COPY . /opt/starfall

# Build the import cache now so the runtime filesystem can stay read-only.
RUN cd /opt/starfall \
    && HOME=/tmp godot --headless --path /opt/starfall --import \
    && test -d /opt/starfall/.godot

# ---------------------------------------------------------------- runtime ---
FROM rockylinux/rockylinux:${ROCKY_VERSION}-minimal AS runtime

# fontconfig: Godot initialises its text server even headless.
# iproute:    `ss`, used by the container healthcheck to prove the UDP socket is bound.
RUN microdnf install -y --setopt=install_weak_deps=0 fontconfig iproute \
    && microdnf clean all && rm -rf /var/cache/yum /var/cache/dnf

# Fixed high UID so bind-mounted files (if ever added) have a predictable owner.
RUN groupadd --system --gid 10001 starfall \
    && useradd --system --uid 10001 --gid 10001 --home-dir /opt/starfall \
       --shell /sbin/nologin starfall

COPY --from=builder /usr/local/bin/godot /usr/local/bin/godot
COPY --from=builder --chown=root:root /opt/starfall /opt/starfall

# The project tree is read-only to the service account: the server only reads it.
RUN chmod -R a-w /opt/starfall

# Godot writes its user:// data and shader cache under HOME. Point it at a
# tmpfs mount so the rest of the filesystem can stay read-only.
ENV HOME=/tmp \
    XDG_DATA_HOME=/tmp/.local/share \
    XDG_CONFIG_HOME=/tmp/.config \
    XDG_CACHE_HOME=/tmp/.cache

USER 10001:10001
WORKDIR /opt/starfall

# Which UDP port this instance binds. Compose sets it per service; the
# healthcheck needs it, and it must agree with the --port= in the command.
ENV STARFALL_PORT=27840

# Liveness: the process is up AND the ENet socket is bound. A Godot server that
# crashed after start would keep the container alive without this.
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD ss -uln 2>/dev/null | grep -q ":${STARFALL_PORT}\b" || exit 1

# Everything after `--` reaches OS.get_cmdline_user_args() in scripts/arena.gd.
ENTRYPOINT ["/usr/local/bin/godot", "--headless", "--path", "/opt/starfall", "--"]
CMD ["--dedicated", "--mode=duel", "--port=27840", "--min-players=2", "--rematch-delay=8"]
