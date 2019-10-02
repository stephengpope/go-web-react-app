# Build the Go API
FROM golang:latest AS builder
ADD . /app
WORKDIR /app/server
#RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags "-w" -a -o /main .

# Build the React application
FROM node:alpine AS node_builder
COPY --from=builder /app/client ./
RUN npm install
RUN npm run build

# Final stage build, this will be the container
# that we will deploy to production
FROM alpine:latest
RUN apk --no-cache add ca-certificates
COPY --from=builder /main ./
COPY --from=node_builder /build ./web
RUN chmod +x ./main
EXPOSE 8080
CMD ./main

-----

FROM heroku/heroku:18-build as build

COPY . /app
WORKDIR /app/server

# Setup buildpack
RUN mkdir -p /tmp/buildpack/heroku/go /tmp/build_cache /tmp/env
RUN curl https://codon-buildpacks.s3.amazonaws.com/buildpacks/heroku/go.tgz | tar xz -C /tmp/buildpack/heroku/go

#Execute Buildpack
RUN STACK=heroku-18 /tmp/buildpack/heroku/go/bin/compile /app/server /tmp/build_cache /tmp/env

# Build the React application
FROM FROM heroku/heroku:18 AS node_builder
COPY --from=builder /app/client ./
RUN npm install
RUN npm run build

# Prepare final, minimal image
FROM heroku/heroku:18

COPY --from=build /app/server /app
COPY --from=node_builder /build /app/web
ENV HOME /app
WORKDIR /app
RUN useradd -m heroku
USER heroku
