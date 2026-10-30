# losslesscut-docker

Docker container to run [LosslessCut](https://losslesscut.app) (v3.70.2) via a web browser (noVNC) or a VNC client.

This image is a derivative of [outlyer-net/docker-losslesscut](https://github.com/outlyer-net/docker-losslesscut) (GPL-2.0), based on [jlesage/docker-baseimage-gui](https://github.com/jlesage/docker-baseimage-gui).

## Quick start

Build locally:

```
make build          # from Git Bash / Linux; builds for the current platform
```

or, without make:

```
docker build --build-arg TARGETPLATFORM=linux/amd64 -t losslesscut-docker:3.70.2 .
```

Run:

```
docker run --rm -d --name losslesscut -p 5800:5800 losslesscut-docker:3.70.2
```

Then browse to `http://localhost:5800`. A compose example is provided in `docker-compose.yaml`.

Multi-arch (linux/amd64, linux/arm64, linux/arm/v7):

```
make multiarch-builder
make buildx
```

## Tags

Built images are tagged with the LosslessCut version scheme, e.g. `3.70.2`, `3.70.2-v1`, `3.70`, `3`.

## Environment variables

Inherited from the jlesage baseimage (see [documentation](https://github.com/jlesage/docker-baseimage-gui#environment-variables)):

| Variable | Default | Description |
|---|---|---|
| `USER_ID` / `GROUP_ID` | auto | User/group ID used for the files written by the container |
| `TZ` | `Etc/UTC` | Timezone |
| `KEEP_APP_RUNNING` | `0` | Restart the app automatically if it crashes |
| `APP_NICENESS` | `0` | Nice level of the app process |
| `CLEAN_TMP_DIR` | `1` | Clean `/tmp` at startup |
| `SECURE_CONNECTION` | `0` | Set to `1` to serve the web UI over HTTPS |
| `WEB_AUDIO` | `0` | Set to `1` to stream application audio through the web browser |
| `DARK_MODE` | `0` | Set to `1` to activate dark mode |

## Ports

| Port | Description |
|---|---|
| 5800 | Web interface (noVNC) |
| 5900 | VNC |

## Volumes

| Path | Description |
|---|---|
| `/config` | Configuration (persists container settings) |
| `/storage` | Data storage (video files); `HOME` is set here so the file chooser starts in it |

## FFmpeg note

LosslessCut 3.70.x bundles FFmpeg 8.1 in its x64 and arm64 builds. The **armv7l** build does not bundle FFmpeg; this image falls back to installing Debian's `ffmpeg` package (an older version) inside the container in that case. This is acceptable for lossless cutting operations, but may behave differently for FFmpeg-dependent features. When invoking the bundled ffmpeg/ffprobe manually (`docker exec`), set `LD_LIBRARY_PATH=/LosslessCut/resources`; the application itself handles this automatically.

## Security

Access to the web UI and VNC ports is unauthenticated by default — protect the container (firewall, reverse proxy with auth, or `SECURE_CONNECTION=1` over a trusted network). Note that LosslessCut's own HTTP API rejects browser-origin requests (as of 3.70.0); this does not affect the noVNC web access provided by the base image.

## Credits

- Original Docker packaging: [outlyer-net/docker-losslesscut](https://github.com/outlyer-net/docker-losslesscut) by Toni Corvera (GPL-2.0)
- Base image: [jlesage/docker-baseimage-gui](https://github.com/jlesage/docker-baseimage-gui)
- Application: [LosslessCut](https://github.com/mifi/lossless-cut)

## License

GPL-2.0 — see [LICENSE](LICENSE).
