ARG BASE
FROM ${BASE}:latest

# Add user
ARG USER
ARG UID
RUN useradd --password "" --groups sudo --no-create-home --uid ${UID} ${USER}

# Copy config files
COPY --chown=${USER}:${USER} config /config/

COPY <<"EOF" /etc/bash.bashrc
. "${XDG_CONFIG_HOME}/bash/bashrc"
EOF

ARG GIT_AUTHOR_NAME
ARG GIT_AUTHOR_EMAIL

RUN cat << EOF >> /config/git/config
[user]
    name = ${GIT_AUTHOR_NAME}
    email = ${GIT_AUTHOR_EMAIL}
EOF

RUN cat << EOF >> /config/jj/config.toml
[user]
    name = "${GIT_AUTHOR_NAME}"
    email = "${GIT_AUTHOR_EMAIL}"
EOF

# Setup locale and timezone
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
RUN ln -fs /usr/share/zoneinfo/America/Los_Angeles /etc/localtime && \
    dpkg-reconfigure --frontend noninteractive tzdata
