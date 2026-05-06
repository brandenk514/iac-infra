FROM ghcr.io/haveagitgat/tdarr_node:latest

# Upstream image bundles intel-media 25.4.0, which is too old for kernel 6.17's
# i915 uAPI on this host (libva fails vaInitialize against the A310). Pull the
# kobuk-team PPA build to match the host's working stack (26.x).
RUN apt-get update && \
    apt-get install -y --no-install-recommends software-properties-common gpg-agent ca-certificates && \
    add-apt-repository -y ppa:kobuk-team/intel-graphics && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        intel-media-va-driver-non-free \
        libmfx-gen1 \
        libvpl-tools \
        libva2 \
        libva-drm2 \
        vainfo && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
