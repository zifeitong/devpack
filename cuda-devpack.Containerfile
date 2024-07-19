FROM ghcr.io/zifeitong/ubuntu-devpack:latest

ARG CUDA_VERSION=12.5

ARG TARGETARCH
RUN [ "${TARGETARCH}" = "amd64" ]

ARG CUDA_KEYRING=cuda-keyring_1.1-1_all.deb
ARG CUDA_KEYRING_URL=https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/

RUN <<EOF
wget ${CUDA_KEYRING_URL}${CUDA_KEYRING}
dpkg -i ./${CUDA_KEYRING}
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -y install cuda-toolkit
rm ${CUDA_KEYRING}
EOF

ENV PATH="$PATH:/usr/local/cuda-$CUDA_VERSION/bin"
