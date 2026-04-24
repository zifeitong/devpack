FROM ghcr.io/zifeitong/ubuntu-devpack:latest

ARG TARGETARCH
RUN [ "${TARGETARCH}" = "amd64" ]

ARG CUDNN_URL=https://developer.download.nvidia.com/compute/cudnn/redist/cudnn/linux-x86_64/

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y cuda-tooklit

RUN <<EOF
  CUDNN_ARCHIVE=`curl ${CUDNN_URL} | grep -o "cudnn-linux-x86_64-[^']*-archive" | tail -1`
  wget -nv --show-progress --progress=dot:mega ${CUDNN_URL}${CUDNN_ARCHIVE}.tar.xz
  tar -xf ${CUDNN_ARCHIVE}.tar.xz
  mv ${CUDNN_ARCHIVE}/include/* /usr/local/cuda/include
  mv ${CUDNN_ARCHIVE}/lib/* /usr/local/cuda/lib64
  mv ${CUDNN_ARCHIVE}/LICENSE /usr/local/cuda/LICENSE.cudnn
  rm -r ${CUDNN_ARCHIVE}
  rm ${CUDNN_ARCHIVE}.tar.xz
  ldconfig
EOF
