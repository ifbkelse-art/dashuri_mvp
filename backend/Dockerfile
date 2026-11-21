# Multi-stage build → distroless, non-root. One image, two entry points:
#   API (Cloud Run service): /app/api
#   Jobs (Cloud Run jobs):   /app/worker <job>
FROM golang:1.25 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/api ./cmd/api \
 && CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/worker ./cmd/worker

FROM gcr.io/distroless/static-debian12:nonroot
WORKDIR /app
COPY --from=build /out/api /out/worker /app/
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/app/api"]
