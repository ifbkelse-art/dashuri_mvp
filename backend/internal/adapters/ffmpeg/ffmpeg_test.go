package ffmpeg

import "testing"

func TestParseProbeAppliesRotationAndReadsStreams(t *testing.T) {
	in, err := parseProbe([]byte(`{"format":{"format_name":"mov,mp4,m4a,3gp,3g2,mj2","duration":"21.480000","bit_rate":"9000000"},
	  "streams":[{"codec_type":"video","codec_name":"hevc","width":1920,"height":1080,"pix_fmt":"yuv420p10le",
	    "side_data_list":[{"rotation":-90}]},{"codec_type":"audio","codec_name":"aac"}]}`))
	if err != nil {
		t.Fatal(err)
	}
	if in.DurationMs != 21480 || in.Width != 1080 || in.Height != 1920 || in.Rotation != -90 || !in.HasAudio || !in.FormatAllowed() {
		t.Fatalf("info: %+v", in)
	}
	if in.CanRemux() {
		t.Fatal("HEVC 10-bit rotated 1080p must be re-encoded")
	}
}

func TestCanRemuxOnlyWhenAlreadyWithinPolicy(t *testing.T) {
	ok := Info{VideoCodec: "h264", PixFmt: "yuv420p", Width: 720, Height: 1280, BitRate: 2_000_000, HasAudio: true, AudioCodec: "aac"}
	if !ok.CanRemux() {
		t.Fatal("compliant file should be remuxed")
	}
	for name, mod := range map[string]func(*Info){
		"too big":    func(i *Info) { i.Width, i.Height = 1080, 1920 },
		"bitrate":    func(i *Info) { i.BitRate = 8_000_000 },
		"unknown br": func(i *Info) { i.BitRate = 0 },
		"rotated":    func(i *Info) { i.Rotation = 90 },
		"opus audio": func(i *Info) { i.AudioCodec = "opus" },
		"10-bit":     func(i *Info) { i.PixFmt = "yuv420p10le" },
	} {
		i := ok
		mod(&i)
		if i.CanRemux() {
			t.Errorf("%s: should re-encode", name)
		}
	}
}

func TestFormatAllowlist(t *testing.T) {
	for _, f := range []string{"hls", "concat", "image2", "tty", "matroska_x"} {
		if (Info{FormatName: f}).FormatAllowed() {
			t.Errorf("%s accepted", f)
		}
	}
	if !(Info{FormatName: "matroska,webm"}).FormatAllowed() {
		t.Error("webm refused")
	}
}
