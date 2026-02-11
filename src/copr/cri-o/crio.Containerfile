FROM quay.io/fedora/fedora:42

RUN dnf install -y \
        --setopt=install_weak_deps=False \
        copr-cli && \
    dnf clean all

WORKDIR /

COPY build.sh .

ENTRYPOINT [ "/build.sh" ]
