FROM alpine AS loader

RUN apk update
RUN apk add --no-cache curl

WORKDIR /root/

# download kubectl
# steps described on https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/
RUN curl -L "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" -o kubectl
RUN curl -L "https://dl.k8s.io/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256" -o kubectl.sha256
RUN echo "$(cat kubectl.sha256)  kubectl" | sha256sum -c

# download additional libs
RUN curl -L "https://getcli.jfrog.io" | sh

# extend Buildkite agent
FROM buildkite/agent:3

# install dependencies
RUN apk update
RUN apk add postgresql-client gettext

WORKDIR /buildkite-agent/

COPY --from=loader /root/kubectl /tmp/
COPY --from=loader /root/jfrog /tmp/

# install kubectl & others
RUN install -m 0755 /tmp/kubectl /usr/local/bin/kubectl
RUN install -m 0755 /tmp/jfrog /usr/local/bin/jfrog
RUN rm /tmp/kubectl
RUN rm /tmp/jfrog

# setup hooks
COPY src/hooks hooks/
COPY src/scripts scripts/
RUN chmod -R 0755 hooks/ scripts/

# entrypoint routines
COPY src/entrypoint/* /docker-entrypoint.d/
RUN chmod -R 0755 /docker-entrypoint.d/

ENV BUILDKITE_HOOKS_PATH /buildkite-agent/hooks