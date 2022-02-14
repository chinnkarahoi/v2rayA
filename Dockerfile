FROM mzz2017/git:alpine AS version
WORKDIR /build
ADD .git ./.git
RUN git describe --abbrev=0 --tags | tee ./version


FROM node:lts-alpine AS builder-web
ADD gui /build/gui
WORKDIR /build/gui
RUN echo "network-timeout 600000" >> .yarnrc
#RUN yarn config set registry https://registry.npm.taobao.org
#RUN yarn config set sass_binary_site https://cdn.npm.taobao.org/dist/node-sass -g
RUN yarn cache clean && yarn && yarn build

FROM golang:alpine AS builder
ADD service /build/service
WORKDIR /build/service
COPY --from=version /build/version ./
COPY --from=builder-web /build/web server/router/web
RUN export VERSION=$(cat ./version) && CGO_ENABLED=0 go build -ldflags="-X github.com/v2rayA/v2rayA/conf.Version=${VERSION:1} -s -w" -o v2raya .

FROM karahoi/xray:latest
COPY --from=builder /build/service/v2raya /usr/bin/
RUN apk add --no-cache iptables ip6tables
RUN ln -sf /usr/bin/xray /usr/bin/v2ray
RUN mkdir -p /usr/local/share/xray /root/.local/share/xray && \
    wget -O /root/.local/share/xray/geosite.dat https://raw.githubusercontent.com/mzz2017/dist-v2ray-rules-dat/master/geosite.dat && \
    wget -O /root/.local/share/xray/geoip.dat https://raw.githubusercontent.com/mzz2017/dist-v2ray-rules-dat/master/geoip.dat
EXPOSE 2017
VOLUME /etc/v2raya
ENTRYPOINT ["v2raya"]
