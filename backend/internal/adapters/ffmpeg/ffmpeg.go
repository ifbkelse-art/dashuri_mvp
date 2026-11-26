// Package ffmpeg runs ffprobe/ffmpeg on local files for Reels media
// processing (validation, 720p H.264 transcode, poster and moderation
// stills). It replaces the processing Mux did for us.
//
// Untrusted input rules (every uploaded file is hostile until proven
// otherwise):
//   - only local files: -protocol_whitelist file, so a crafted file
//     cannot make ffmpeg fetch URLs (SSRF);
//   - only container demuxers: -format_whitelist, so HLS/concat/playlist
//     demuxers can never run (they could read other local files);
//   - the container must probe as one of AllowedFormats before decoding;
//   - every run has a timeout and output size/duration caps;
//   - metadata (GPS location, device, creation time) is stripped from
//     every output (-map_metadata -1).
//
// The API image (distroless) has no ffmpeg; the media worker image
// (backend/Dockerfile.media) does. Available() reports which.
package ffmpeg

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"os/exec"
	"slices"
	"strconv"
	"strings"
	"time"
)

// Output policy. 720p H.264 High, CRF 26 with a 2.5 Mb/s cap: a 60 s reel
// is ≈ 8–19 MB, plays on every Android phone with hardware decoding and
// starts fast (moov atom first).
const (
	TargetShortSide = 720
	MaxBitrateKbps  = 2500
	AudioKbps       = 96
	PosterMaxSide   = 720
	FrameMaxSide    = 512 // moderation stills
)

// AllowedFormats are ffprobe format_name entries we accept (phone camera
// and gallery files). ffprobe reports comma-joined demuxer aliases.
var AllowedFormats = []string{"mov", "mp4", "m4a", "3gp", "3g2", "mj2", "matroska", "webm"}

// demuxers is the input whitelist passed to ffmpeg/ffprobe.
var demuxers = strings.Join(AllowedFormats, ",")

// ErrTimeout means a run hit its time limit (transient, retried).
var ErrTimeout = errors.New("ffmpeg timed out")

// ErrNotInstalled means ffmpeg/ffprobe are not on this machine.
var ErrNotInstalled = errors.New("ffmpeg not installed")

// Tool wraps the two binaries.
type Tool struct {
	FFmpeg  string        // path or name on PATH
	FFprobe string        // path or name on PATH
	Timeout time.Duration // per invocation (default 3 min)
}

// New uses ffmpeg/ffprobe from PATH.
func New() *Tool { return &Tool{FFmpeg: "ffmpeg", FFprobe: "ffprobe", Timeout: 3 * time.Minute} }

// Available is true when both binaries can be found.
func (t *Tool) Available() bool {
	if t == nil {
		return false
	}
	_, e1 := exec.LookPath(t.FFmpeg)
	_, e2 := exec.LookPath(t.FFprobe)
	return e1 == nil && e2 == nil
}

// Info is what ffprobe found.
type Info struct {
	FormatName string
	DurationMs int
	Width      int // as displayed (rotation applied)
	Height     int
	VideoCodec string
	PixFmt     string
	Rotation   int
	BitRate    int64 // container bits/s (0 when unknown)
	HasVideo   bool
	HasAudio   bool
	AudioCodec string
}

// FormatAllowed reports whether the container is one we accept.
func (i Info) FormatAllowed() bool {
	for f := range strings.SplitSeq(i.FormatName, ",") {
		if slices.Contains(AllowedFormats, f) {
			return true
		}
	}
	return false
}

func (t *Tool) run(ctx context.Context, bin string, args ...string) ([]byte, error) {
	if !t.Available() {
		return nil, ErrNotInstalled
	}
	to := t.Timeout
	if to <= 0 {
		to = 3 * time.Minute
	}
	ctx, cancel := context.WithTimeout(ctx, to)
	defer cancel()
	cmd := exec.CommandContext(ctx, bin, args...)
	var out, stderr bytes.Buffer
	cmd.Stdout, cmd.Stderr = &out, &stderr
	if err := cmd.Run(); err != nil {
		if ctx.Err() != nil {
			return nil, fmt.Errorf("%s: %w", bin, ErrTimeout)
		}
		msg := stderr.String()
		if len(msg) > 400 {
			msg = msg[len(msg)-400:]
		}
		return nil, fmt.Errorf("%s: %w: %s", bin, err, strings.TrimSpace(msg))
	}
	return out.Bytes(), nil
}

// ErrUnreadable means ffprobe could not parse the file (not a video, or
// damaged). Callers treat it as invalid media, not a transient error.
var ErrUnreadable = errors.New("unreadable media")

// Probe inspects a local file.
func (t *Tool) Probe(ctx context.Context, path string) (Info, error) {
	out, err := t.run(ctx, t.FFprobe, "-v", "error", "-protocol_whitelist", "file", "-format_whitelist", demuxers,
		"-show_entries", "format=format_name,duration,bit_rate:stream=codec_type,codec_name,width,height,pix_fmt:stream_side_data=rotation:stream_tags=rotate",
		"-of", "json", "file:"+path)
	if errors.Is(err, ErrNotInstalled) || errors.Is(err, ErrTimeout) {
		return Info{}, err
	}
	if err != nil {
		return Info{}, fmt.Errorf("%w: %v", ErrUnreadable, err)
	}
	return parseProbe(out)
}

type probeJSON struct {
	Format struct {
		FormatName string `json:"format_name"`
		Duration   string `json:"duration"`
		BitRate    string `json:"bit_rate"`
	} `json:"format"`
	Streams []struct {
		CodecType string `json:"codec_type"`
		CodecName string `json:"codec_name"`
		Width     int    `json:"width"`
		Height    int    `json:"height"`
		PixFmt    string `json:"pix_fmt"`
		Tags      struct {
			Rotate string `json:"rotate"`
		} `json:"tags"`
		SideData []struct {
			Rotation *float64 `json:"rotation"`
		} `json:"side_data_list"`
	} `json:"streams"`
}

func parseProbe(b []byte) (Info, error) {
	var p probeJSON
	if err := json.Unmarshal(b, &p); err != nil {
		return Info{}, fmt.Errorf("%w: %v", ErrUnreadable, err)
	}
	in := Info{FormatName: p.Format.FormatName}
	if d, err := strconv.ParseFloat(p.Format.Duration, 64); err == nil && d > 0 {
		in.DurationMs = int(math.Round(d * 1000))
	}
	in.BitRate, _ = strconv.ParseInt(p.Format.BitRate, 10, 64)
	for _, s := range p.Streams {
		switch s.CodecType {
		case "video":
			if in.HasVideo {
				continue // first video stream only
			}
			in.HasVideo, in.VideoCodec, in.PixFmt = true, s.CodecName, s.PixFmt
			in.Width, in.Height = s.Width, s.Height
			if r, err := strconv.Atoi(s.Tags.Rotate); err == nil {
				in.Rotation = r
			}
			for _, sd := range s.SideData {
				if sd.Rotation != nil {
					in.Rotation = int(math.Round(*sd.Rotation))
				}
			}
			if r := ((in.Rotation % 360) + 360) % 360; r == 90 || r == 270 {
				in.Width, in.Height = in.Height, in.Width
			}
		case "audio":
			if !in.HasAudio {
				in.HasAudio, in.AudioCodec = true, s.CodecName
			}
		}
	}
	return in, nil
}

// CanRemux reports whether the file already meets the playback policy, so
// a cheap stream copy (no re-encode) is enough: H.264 yuv420p, short side
// ≤ 720, no rotation flag, bitrate within the cap, AAC or no audio.
func (i Info) CanRemux() bool {
	short := min(i.Width, i.Height)
	return i.VideoCodec == "h264" && i.PixFmt == "yuv420p" && short > 0 && short <= TargetShortSide &&
		i.Rotation%360 == 0 && i.BitRate > 0 && i.BitRate <= int64(MaxBitrateKbps+AudioKbps)*1000 &&
		(!i.HasAudio || i.AudioCodec == "aac")
}

// Transcode writes the playback MP4 (720p short side, never upscaled,
// faststart, metadata stripped). maxMs caps the output length. It remuxes
// instead of re-encoding when the input already fits (CanRemux).
func (t *Tool) Transcode(ctx context.Context, in Info, src, dst string, maxMs int) error {
	args := []string{"-v", "error", "-y", "-protocol_whitelist", "file", "-format_whitelist", demuxers, "-i", "file:" + src,
		"-map", "0:v:0", "-map", "0:a:0?", "-map_metadata", "-1", "-map_chapters", "-1", "-sn", "-dn",
		"-t", fmt.Sprintf("%.3f", float64(maxMs)/1000)}
	if in.CanRemux() {
		args = append(args, "-c", "copy")
	} else {
		// Scale the short side to ≤ 720 (keep even dimensions, no upscale).
		vf := fmt.Sprintf("scale='if(gte(iw,ih),-2,min(%[1]d,iw))':'if(gte(iw,ih),min(%[1]d,ih),-2)'", TargetShortSide)
		args = append(args, "-vf", vf, "-c:v", "libx264", "-preset", "veryfast", "-crf", "26",
			"-maxrate", fmt.Sprintf("%dk", MaxBitrateKbps), "-bufsize", fmt.Sprintf("%dk", 2*MaxBitrateKbps),
			"-profile:v", "high", "-pix_fmt", "yuv420p", "-g", "60",
			"-c:a", "aac", "-b:a", fmt.Sprintf("%dk", AudioKbps), "-ac", "2")
	}
	args = append(args, "-movflags", "+faststart", "-f", "mp4", "file:"+dst)
	_, err := t.run(ctx, t.FFmpeg, args...)
	return err
}

// Still writes one JPEG frame at atMs, longest side ≤ maxSide.
func (t *Tool) Still(ctx context.Context, src, dst string, atMs, maxSide int) error {
	vf := fmt.Sprintf("scale='if(gte(iw,ih),min(%[1]d,iw),-2)':'if(gte(iw,ih),-2,min(%[1]d,ih))'", maxSide)
	_, err := t.run(ctx, t.FFmpeg, "-v", "error", "-y", "-protocol_whitelist", "file",
		"-ss", fmt.Sprintf("%.3f", float64(atMs)/1000), "-format_whitelist", demuxers, "-i", "file:"+src,
		"-frames:v", "1", "-vf", vf, "-map_metadata", "-1", "-q:v", "4", "-f", "image2", "file:"+dst)
	return err
}
