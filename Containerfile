FROM quay.io/toolbx/ubuntu-toolbox:23.10 AS base

# Install packages needed for all stages
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y install \
        gcc openjdk-11-jdk && \
    rm -rd /var/lib/apt/lists/*

FROM base AS builder

ARG TARGETARCH
ARG BAZELISK_URL=https://github.com/bazelbuild/bazelisk/releases/download/v1.19.0/bazelisk-linux-
ARG BUILDIFIER_URL=https://github.com/bazelbuild/buildtools/releases/download/v7.1.0/buildifier-linux-
ARG BUILDOZER_URL=https://github.com/bazelbuild/buildtools/releases/download/v7.1.0/buildozer-linux-

# Install bazel
RUN curl --proto '=https' --tlsv1.3 -sSfL ${BAZELISK_URL}${TARGETARCH} > bazel
RUN chmod +x bazel
RUN curl --proto '=https' --tlsv1.3 -sSfL ${BUILDIFIER_URL}${TARGETARCH} > buildifier
RUN curl --proto '=https' --tlsv1.3 -sSfL ${BUILDOZER_URL}${TARGETARCH} > buildozer

# Install copybara
RUN git clone https://github.com/google/copybara.git --depth=1
WORKDIR /copybara
RUN /bazel build //java/com/google/copybara:copybara_deploy.jar -c opt

FROM base
LABEL com.github.containers.toolbox="true" \
      name="ubuntu-toolbox" \
      version="23.10" \
      usage="This image is meant to be used with the toolbox command" \
      summary="Base image for creating Ubuntu Toolbx containers" \
      maintainer="Ievgen Popovych <jmennius@gmail.com>"

# Install packages
COPY extra-packages /
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y install \
        $(grep -v '^#' extra-packages | xargs) && \
    rm -rd /var/lib/apt/lists/*
RUN rm /extra-packages

COPY --from=builder --chmod=755 bazel buildifier buildozer /usr/local/bin
COPY --from=builder \
     /copybara/bazel-bin/java/com/google/copybara/copybara_deploy.jar \
     /opt/copybara/
COPY --chmod=755 <<"EOF" /usr/local/bin/copybara
#!/usr/bin/env bash
exec java -jar /opt/copybara/copybara_deploy.jar "$@"
EOF
