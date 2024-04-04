FROM quay.io/toolbx/ubuntu-toolbox:23.10 AS builder

# Install packages needed for building packages.
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y install \
    g++ openjdk-11-jdk-headless golang && \
    rm -rd /var/lib/apt/lists/*

ARG TARGETARCH
ARG BAZELISK_URL=https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-
ARG BUILDIFIER_URL=https://github.com/bazelbuild/buildtools/releases/latest/download/buildifier-linux-
ARG BUILDOZER_URL=https://github.com/bazelbuild/buildtools/releases/latest/download/buildozer-linux-

# Install bazel
RUN curl --proto '=https' --tlsv1.3 -sSfL ${BAZELISK_URL}${TARGETARCH} > bazel
RUN chmod +x bazel
RUN curl --proto '=https' --tlsv1.3 -sSfL ${BUILDIFIER_URL}${TARGETARCH} > buildifier
RUN curl --proto '=https' --tlsv1.3 -sSfL ${BUILDOZER_URL}${TARGETARCH} > buildozer

# Install copybara
RUN git clone https://github.com/google/copybara.git --depth=1
WORKDIR /copybara
RUN /bazel build //java/com/google/copybara:copybara_deploy.jar -c opt

# Install pprof
WORKDIR /
RUN git clone https://github.com/google/pprof.git --depth=1
WORKDIR /pprof
RUN go build

FROM quay.io/toolbx/ubuntu-toolbox:23.10
LABEL name="ubuntu-debpack" version="23.10"

# Install packages
COPY extra-packages /
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y install \
    $(grep -v '^#' extra-packages | xargs) && \
    rm -rd /var/lib/apt/lists/*
RUN rm /extra-packages

COPY --from=builder --chmod=755 bazel buildifier buildozer /pprof/pprof /usr/local/bin/
COPY --from=builder \
    /copybara/bazel-bin/java/com/google/copybara/copybara_deploy.jar \
    /opt/copybara/
COPY --chmod=755 <<"EOF" /usr/local/bin/copybara
#!/usr/bin/env bash
exec java -jar /opt/copybara/copybara_deploy.jar "$@"
EOF

# Setup locale and timezone
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
RUN ln -fs /usr/share/zoneinfo/America/Los_Angeles /etc/localtime && \
    dpkg-reconfigure --frontend noninteractive tzdata

# Add user
ARG USER
ARG UID
RUN useradd --password "" --groups sudo --no-create-home --uid ${UID} ${USER}
