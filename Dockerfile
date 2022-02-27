FROM alpine AS loader

RUN apk update
RUN apk add --no-cache bash curl

WORKDIR /root/

# download kubectl
# steps described on https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/
RUN curl -L "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" -o kubectl
RUN curl -L "https://dl.k8s.io/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256" -o kubectl.sha256
RUN echo "$(cat kubectl.sha256)  kubectl" | sha256sum -c

# download additional libs
RUN curl -L "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
RUN curl -L "https://getcli.jfrog.io" | bash

# extend Buildkite agent
FROM buildkite/agent:3

# install dependencies
RUN apk update
RUN apk add postgresql-client gettext

# install & setup python
RUN apk add python3
RUN ln -sf python3 /usr/bin/python
RUN python -m pip install --upgrade pip setuptools

# build & testing tools (tox, poetry)
RUN curl -sL https://raw.githubusercontent.com/python-poetry/poetry/master/install-poetry.py | python -
RUN poetry config virtualenvs.in-project true
RUN python -m pip install tox tox-poetry

WORKDIR /buildkite-agent/

COPY --from=loader /root/kubectl /tmp/
COPY --from=loader /root/kustomize /tmp/
COPY --from=loader /root/jfrog /tmp/

# install kubectl & others
RUN install -m 0755 /tmp/kubectl /usr/local/bin/kubectl
RUN install -m 0755 /tmp/jfrog /usr/local/bin/jfrog
RUN install -m 0755 /tmp/kustomize /usr/local/bin/kustomize
RUN rm /tmp/kubectl
RUN rm /tmp/kustomize
RUN rm /tmp/jfrog

# setup hooks
COPY src/hooks hooks/
COPY src/scripts scripts/
RUN chmod -R 0755 hooks/ scripts/

# entrypoint routines
COPY src/entrypoint/* /docker-entrypoint.d/
RUN chmod -R 0755 /docker-entrypoint.d/

ENV BUILDKITE_HOOKS_PATH /buildkite-agent/hooks