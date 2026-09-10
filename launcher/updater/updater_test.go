package updater

import (
	"archive/zip"
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func sum(b []byte) string { s := sha256.Sum256(b); return hex.EncodeToString(s[:]) }

type fixture struct {
	u         *Updater
	manifest  Manifest
	archive   []byte
	downloads int
	fail      bool
}

func setup(t *testing.T) *fixture {
	t.Helper()
	f := &fixture{}
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if f.fail {
			http.Error(w, "Unavailable", 503)
			return
		}
		if r.URL.Path == "/manifest.json" {
			json.NewEncoder(w).Encode(f.manifest)
			return
		}
		f.downloads++
		w.Write(f.archive)
	}))
	t.Cleanup(server.Close)
	f.u = &Updater{Root: t.TempDir(), Feed: server.URL + "/manifest.json", AssetPrefix: server.URL + "/releases/", Client: server.Client()}
	f.release("a")
	return f
}
func (f *fixture) release(id string) {
	var b bytes.Buffer
	z := zip.NewWriter(&b)
	files := map[string]File{}
	for _, name := range []string{"Starfall.exe", "Starfall.pck", "support.dll"} {
		data := []byte(name + id)
		w, _ := z.Create(name)
		w.Write(data)
		files[name] = File{sum(data), int64(len(data))}
	}
	z.Close()
	f.archive = b.Bytes()
	build := strings.Repeat(id, 40)
	tag := "sha-" + build[:7]
	f.manifest = Manifest{1, build, "0.11.0", tag, f.u.AssetPrefix + tag + "/Starfall-Windows.zip", sum(f.archive), int64(len(f.archive)), files}
}
func install(t *testing.T, f *fixture) Installation {
	t.Helper()
	i, err := f.u.Update(context.Background(), nil)
	if err != nil {
		t.Fatal(err)
	}
	return i
}
func TestInstallUpdateRollbackPreserveSettings(t *testing.T) {
	f := setup(t)
	settings := filepath.Join(f.u.Root, "settings.cfg")
	os.WriteFile(settings, []byte("keep me"), 0600)
	first := install(t, f)
	if next := install(t, f); next.Directory != first.Directory || f.downloads != 1 {
		t.Fatal("unchanged release was downloaded again")
	}
	f.release("b")
	second := install(t, f)
	if f.u.Verify(first) != nil || second.Directory == first.Directory {
		t.Fatal("previous installation not retained")
	}
	f.release("a")
	rollback := install(t, f)
	if rollback.Directory != first.Directory || f.downloads != 2 {
		t.Fatal("rollback should reuse verified previous files")
	}
	data, _ := os.ReadFile(settings)
	if string(data) != "keep me" {
		t.Fatal("settings changed")
	}
}
func TestFailuresLeaveCurrentIntact(t *testing.T) {
	for _, fault := range []string{"hash", "truncated", "oversized", "server", "cancel", "zip", "unpacked_hash", "missing_file", "duplicate", "traversal", "symlink"} {
		t.Run(fault, func(t *testing.T) {
			f := setup(t)
			first := install(t, f)
			f.release("b")
			ctx := context.Background()
			switch fault {
			case "hash":
				f.archive[0] ^= 1
			case "truncated":
				f.archive = f.archive[:len(f.archive)-1]
			case "oversized":
				f.archive = append(f.archive, 0)
			case "server":
				f.fail = true
			case "cancel":
				var cancel context.CancelFunc
				ctx, cancel = context.WithCancel(ctx)
				cancel()
			case "zip":
				f.archive = []byte("invalid zip")
				f.manifest.Size = int64(len(f.archive))
				f.manifest.SHA256 = sum(f.archive)
			case "unpacked_hash":
				x := f.manifest.Files["Starfall.exe"]
				x.SHA256 = strings.Repeat("0", 64)
				f.manifest.Files["Starfall.exe"] = x
			default:
				var b bytes.Buffer
				z := zip.NewWriter(&b)
				names := []string{"Starfall.exe", "Starfall.pck", "support.dll"}
				if fault == "missing_file" {
					names = names[:2]
				}
				if fault == "duplicate" {
					names[2] = "Starfall.exe"
				}
				if fault == "traversal" {
					names[2] = "../outside.dll"
				}
				for _, name := range names {
					h := &zip.FileHeader{Name: name}
					h.SetMode(0600)
					if fault == "symlink" && name == "support.dll" {
						h.SetMode(os.ModeSymlink | 0600)
					}
					w, _ := z.CreateHeader(h)
					w.Write([]byte(name + "b"))
				}
				z.Close()
				f.archive = b.Bytes()
				f.manifest.Size = int64(len(f.archive))
				f.manifest.SHA256 = sum(f.archive)
			}
			if _, err := f.u.Update(ctx, nil); err == nil {
				t.Fatal("bad update accepted")
			}
			got, err := f.u.Current()
			if err != nil || got.Directory != first.Directory {
				t.Fatal("failed update damaged current", err)
			}
			dirs, _ := os.ReadDir(filepath.Join(f.u.Root, "versions"))
			if len(dirs) != 1 {
				t.Fatal("staging files leaked")
			}
		})
	}
}
func TestCorruptInstallationIsRepaired(t *testing.T) {
	f := setup(t)
	first := install(t, f)
	os.WriteFile(f.u.Executable(first), []byte("corrupt"), 0700)
	if _, err := f.u.Current(); err == nil {
		t.Fatal("corruption not detected")
	}
	second := install(t, f)
	if second.Directory == first.Directory || f.u.Verify(second) != nil || f.downloads != 2 {
		t.Fatal("corruption not repaired")
	}
}
func TestManifestValidation(t *testing.T) {
	cases := map[string]func(*Manifest){
		"http": func(m *Manifest) { m.URL = strings.Replace(m.URL, "https:", "http:", 1) },
		"host": func(m *Manifest) { m.URL = "https://evil.example/Starfall-Windows.zip" },
		"traversal": func(m *Manifest) {
			m.URL = strings.Replace(m.URL, "/Starfall-Windows.zip", "/../bad/Starfall-Windows.zip", 1)
		},
		"tag":            func(m *Manifest) { m.ServerTag = "sha-fffffff" },
		"schema":         func(m *Manifest) { m.Schema = 2 },
		"empty build":    func(m *Manifest) { m.Build = "" },
		"size":           func(m *Manifest) { m.Size = maxArchive + 1 },
		"filename":       func(m *Manifest) { m.Files["../escape.dll"] = m.Files["support.dll"] },
		"case collision": func(m *Manifest) { m.Files["SUPPORT.DLL"] = m.Files["support.dll"] },
		"missing exe":    func(m *Manifest) { delete(m.Files, "Starfall.exe") },
	}
	for name, change := range cases {
		t.Run(name, func(t *testing.T) {
			f := setup(t)
			change(&f.manifest)
			if _, err := f.u.Update(context.Background(), nil); err == nil {
				t.Fatal("invalid manifest accepted")
			}
			if f.downloads != 0 {
				t.Fatal("download started before validation")
			}
		})
	}
}
func TestStateWriteFailureKeepsCurrent(t *testing.T) {
	f := setup(t)
	first := install(t, f)
	f.release("b")
	// A directory at the backup destination forces an atomic state-write failure.
	os.Mkdir(filepath.Join(f.u.Root, "previous.json"), 0700)
	if _, err := f.u.Update(context.Background(), nil); err == nil {
		t.Fatal("expected state failure")
	}
	got, err := f.u.Current()
	if err != nil || got.Directory != first.Directory {
		t.Fatal("state changed despite failure")
	}
}
func TestCleanupOnlyRemovesOldVersions(t *testing.T) {
	f := setup(t)
	first := install(t, f)
	f.release("b")
	second := install(t, f)
	arbitrary := filepath.Join(f.u.Root, "versions", "my-files")
	os.Mkdir(arbitrary, 0700)
	f.release("c")
	third := install(t, f)
	if _, err := os.Stat(filepath.Dir(f.u.Executable(first))); !os.IsNotExist(err) {
		t.Fatal("old version not removed")
	}
	if f.u.Verify(second) != nil || f.u.Verify(third) != nil {
		t.Fatal("current or previous removed")
	}
	if _, err := os.Stat(arbitrary); err != nil {
		t.Fatal("unrelated folder removed")
	}
}
