FROM ghcr.io/zifeitong/ubuntu-devpack:latest

# Add user
ARG USER
ARG UID
RUN useradd --password "" --groups sudo --no-create-home --uid ${UID} ${USER}

# Setup locale and timezone
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
RUN ln -fs /usr/share/zoneinfo/America/Los_Angeles /etc/localtime && \
    dpkg-reconfigure --frontend noninteractive tzdata
