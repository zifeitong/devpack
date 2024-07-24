FROM ghcr.io/zifeitong/ubuntu-devpack:latest

ARG CUDA_VERSION=12.5

ARG TARGETARCH
RUN [ "${TARGETARCH}" = "amd64" ]

ARG CUDA_KEYRING=cuda-keyring_1.1-1_all.deb
ARG CUDA_KEYRING_URL=https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/

ARG CUDNN_ARCHIVE=cudnn-linux-x86_64-9.2.1.18_cuda12-archive
ARG CUDNN_URL=https://developer.download.nvidia.com/compute/cudnn/redist/cudnn/linux-x86_64/

RUN <<EOF
  wget ${CUDA_KEYRING_URL}${CUDA_KEYRING}
  dpkg -i ./${CUDA_KEYRING}
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get -y install cuda-toolkit
  rm ${CUDA_KEYRING}
EOF

RUN <<EOF
  wget -nv --show-progress --progress=dot:mega ${CUDNN_URL}${CUDNN_ARCHIVE}.tar.xz
  tar -xf ${CUDNN_ARCHIVE}.tar.xz
  cp -r ${CUDNN_ARCHIVE}/include/* /usr/local/cuda/include
  cp -r ${CUDNN_ARCHIVE}/lib/* /usr/local/cuda/lib64
  cp -r ${CUDNN_ARCHIVE}/LICENSE /usr/local/cuda/LICENSE.cudnn
  rm ${CUDNN_ARCHIVE}.tar.xz
EOF

ENV PATH="$PATH:/usr/local/cuda-$CUDA_VERSION/bin"
