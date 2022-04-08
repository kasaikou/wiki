FROM golang:1.18-bullseye
ARG NODEJS_VERSION=14.x \
    HUGO_VERSION=0.92.0

RUN \
    # Install apt packages
    apt-get install -y libc6 && \
    #
    # Install nodejs
    curl -sL https://deb.nodesource.com/setup_${NODEJS_VERSION} | bash - && \
    apt-get install -y nodejs && \
    #
    # Install hugo
    go install --tags extended github.com/gohugoio/hugo@v${HUGO_VERSION}

