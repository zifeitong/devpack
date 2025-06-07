#===== Build Image =====
FROM docker.io/library/ubuntu:24.04 AS builder

# Install packages needed for building packages.
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y install \
    build-essential golang curl git libelf-dev libcap-dev libarchive-tools && \
    rm -rd /var/lib/apt/lists/*

ARG TARGETARCH
ARG BAZELISK_URL=https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-
ARG BUILDIFIER_URL=https://github.com/bazelbuild/buildtools/releases/latest/download/buildifier-linux-
ARG BUILDOZER_URL=https://github.com/bazelbuild/buildtools/releases/latest/download/buildozer-linux-
ARG MAGIC_TRACE_URL=https://github.com/janestreet/magic-trace/releases/latest/download/magic-trace
ARG UV_URL=https://github.com/astral-sh/uv/releases/latest/download/uv
ARG DUCKDB_URL=https://github.com/duckdb/duckdb/releases/latest/download/duckdb_cli-linux
ARG COPYBARA_URL=https://github.com/google/copybara/releases/latest/download/copybara_deploy.jar
ARG JJ_URL=https://github.com/jj-vcs/jj/releases/latest/download

ENV GOPATH=/go

# Install bazel
RUN curl --proto '=https' --tlsv1.3 -sSfL ${BAZELISK_URL}${TARGETARCH} > bazel
RUN chmod +x bazel
RUN curl --proto '=https' --tlsv1.3 -sSfL ${BUILDIFIER_URL}${TARGETARCH} > buildifier
RUN curl --proto '=https' --tlsv1.3 -sSfL ${BUILDOZER_URL}${TARGETARCH} > buildozer

# Install duckdb \
curl --proto '=https' --tlsv1.3 -sSfL ${DUCKDB_URL}-${TARGETARCH}.zip | bsdtar -xvf- ; \

RUN if [ "$TARGETARCH" = "amd64" ] ; then \
  # Install uv \
  curl --proto '=https' --tlsv1.3 -sSfL ${UV_URL}-x86_64-unknown-linux-gnu.tar.gz | tar xvz --strip-components=1 ; \
  # Install magic-trace \
  curl --proto '=https' --tlsv1.3 -sSfL ${MAGIC_TRACE_URL} > magic-trace ; \
  # Install jj \
  curl --proto '=https' --tlsv1.3 -sSfL ${JJ_URL}/jj-$(curl -w "%{url_effective}" -I -L -s $JJ_URL -o /dev/null | sed 's:.*/::')-x86_64-unknown-linux-musl.tar.gz  | tar xvz ; \
elif [ "$TARGETARCH" = "arm64" ] ; then \
  # Install uv \
  curl --proto '=https' --tlsv1.3 -sSfL ${UV_URL}-aarch64-unknown-linux-gnu.tar.gz | tar xvz --strip-components=1 ; \
  # Install jj \
  curl --proto '=https' --tlsv1.3 -sSfL ${JJ_URL}/jj-$(curl -w "%{url_effective}" -I -L -s $JJ_URL -o /dev/null | sed 's:.*/::')-aarch64-unknown-linux-musl.tar.gz  | tar xvz ; \
fi

# Install copybara
RUN curl --proto '=https' --tlsv1.3 -sSfL ${COPYBARA_URL} > copybara_deploy.jar

# Install perf_data_converter
WORKDIR /
RUN git clone https://github.com/google/perf_data_converter.git --depth=1
WORKDIR /perf_data_converter
RUN /bazel build //src:perf_to_profile -c opt

# Install grpc_cli
WORKDIR /
RUN git clone https://github.com/grpc/grpc.git --depth=1
WORKDIR /grpc
RUN CC=gcc /bazel build //test/cpp/util:grpc_cli -c opt

# Install pprof
RUN go install github.com/google/pprof@latest

# Install doggo
RUN go install github.com/mr-karan/doggo/cmd/doggo@v1.0.5

# ===== Main Image =====
FROM docker.io/library/ubuntu:24.04 AS ubuntu-devpack
LABEL name="ubuntu-debpack" version="24.04"

# Remove apt configuration optimized for containers
RUN rm /etc/apt/apt.conf.d/docker-gzip-indexes /etc/apt/apt.conf.d/docker-no-languages

# Delete the default 'ubuntu' user
RUN userdel --remove ubuntu

# Install packages
ARG DEBIAN_FRONTEND=noninteractive

COPY extra-packages /
RUN apt-get update && \
    apt-get install -y unminimize && \
    yes | unminimize && \
    apt-get -y install ubuntu-minimal ubuntu-standard $(grep -v '^#' extra-packages | xargs)
RUN if [ "$TARGETARCH" = "amd64" ] ; then \
    apt-get -y install $(grep -v '^#' extra-packages.amd64 | xargs) ; \
fi
RUN rm /extra-packages

RUN ln -s "$(find /usr/lib/linux-tools/*/perf | head -1)" /usr/local/bin/perf

COPY --from=builder --chmod=755 bazel buildifier buildozer magic-trac[e] uv uvx duckdb \
     /go/bin/pprof \
     /grpc/bazel-bin/test/cpp/util/grpc_cli \
     /perf_data_converter/bazel-bin/src/perf_to_profile \
     /go/bin/doggo \
     /usr/local/bin/
COPY --from=builder /copybara_deploy.jar /opt/copybara/
COPY --chmod=755 <<"EOF" /usr/local/bin/copybara
#!/usr/bin/env bash
exec java -jar /opt/copybara/copybara_deploy.jar "$@"
EOF

# Disable APT ESM hook.
RUN rm /etc/apt/apt.conf.d/20apt-esm-hook.conf

# Update command-not-found database
RUN apt-get update
