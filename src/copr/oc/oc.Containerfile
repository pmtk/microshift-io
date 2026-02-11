FROM quay.io/fedora/fedora:42

RUN dnf install -y \
        --setopt=install_weak_deps=False \
        git rpm-build make golang copr-cli jq && \
    dnf clean all

RUN LATEST_OKD_TAG=$(curl -L \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        https://api.github.com/repos/okd-project/okd/releases/latest | jq -r '.tag_name') ; \
    [ "$(uname -m)" = "aarch64" ] && ARCH="-arm64" || ARCH="" ; \
        OKD_CLIENT_URL="https://github.com/okd-project/okd/releases/download/${LATEST_OKD_TAG}/openshift-client-linux${ARCH}-${LATEST_OKD_TAG}.tar.gz" && \
        echo "OKD_CLIENT_URL: ${OKD_CLIENT_URL}" && \
        curl -L --retry 5 -o /tmp/okd-client.tar.gz "${OKD_CLIENT_URL}" && \
        tar -xzf /tmp/okd-client.tar.gz -C /usr/local/bin/ && \
        rm -rf /tmp/okd-client.tar.gz

WORKDIR /

COPY . .

ENTRYPOINT [ "/build.sh" ]
