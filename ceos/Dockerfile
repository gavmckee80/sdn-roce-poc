FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive

# Install the tools you need
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        iproute2 net-tools lldpd iputils-ping \
        wpasupplicant vim openssh-server && \
    rm -rf /var/lib/apt/lists/*

# --- SSH hardening for a *lab* image ----------------------------
RUN echo 'root:password' | chpasswd && \
    sed -ri 's/^#?PermitRootLogin .*/PermitRootLogin yes/'  /etc/ssh/sshd_config && \
    sed -ri 's/^#?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Make sure the runtime directory exists every time the container starts
RUN mkdir -p /run/sshd && \
    ssh-keygen -A   # generate host keys inside the image layer

EXPOSE 22

# Keep container alive: recreate /run/sshd (in case tmpfs was cleared)
ENTRYPOINT ["/bin/bash", "-c", "mkdir -p /run/sshd && exec /usr/sbin/sshd -D -e"]
