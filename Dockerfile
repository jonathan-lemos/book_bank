FROM bitwalker/alpine-elixir:latest

COPY . .
RUN apk update && \
apk add --update musl musl-dev musl-utils nodejs-npm build-base imagemagick && \
npm install && \
npm install -g --silent @angular/cli && \
ng build && \
mix deps.get

CMD ["mix", "phx.server"]
