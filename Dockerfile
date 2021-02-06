FROM bitwalker/alpine-elixir:latest as build

COPY . .
RUN apk update && apk add --update musl musl-dev musl-utils nodejs-npm build-base imagemagick
RUN npm install
RUN npm install -g --silent @angular/cli
RUN ng build
RUN mix deps.get

FROM bitwalker/alpine-elixir:latest
COPY --from=build . .

CMD ["mix", "phx.server"]
