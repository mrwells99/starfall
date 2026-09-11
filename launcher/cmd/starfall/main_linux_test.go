//go:build linux

package main

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
	"time"

	"starfall/launcher/updater"
)

func TestPanelRequestIsolation(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	a := &launcher{ctx: ctx, cancel: cancel, preview: true}
	h := a.handler("127.0.0.1:12345", "secret")
	for _, test := range []struct {
		method, path, host, origin string
		code                       int
	}{
		{"GET", "/secret/", "127.0.0.1:12345", "", 200},
		{"GET", "/secret/status", "127.0.0.1:12345", "", 200},
		{"GET", "/secret/play", "127.0.0.1:12345", "", 405},
		{"POST", "/secret/check", "127.0.0.1:12345", "http://127.0.0.1:12345", 204},
		{"POST", "/secret/play", "127.0.0.1:12345", "https://evil.example", 404},
		{"POST", "/secret/play", "evil.example", "", 404},
		{"POST", "/wrong/play", "127.0.0.1:12345", "", 404},
	} {
		r := httptest.NewRequest(test.method, "http://"+test.host+test.path, nil)
		r.Header.Set("Origin", test.origin)
		w := httptest.NewRecorder()
		h.ServeHTTP(w, r)
		if w.Code != test.code {
			t.Fatalf("%+v got %d", test, w.Code)
		}
	}
	a.state.Running = true
	r := httptest.NewRequest("POST", "http://127.0.0.1:12345/secret/quit", nil)
	w := httptest.NewRecorder()
	h.ServeHTTP(w, r)
	if w.Code != 409 {
		t.Fatal("quit allowed while game running")
	}
	a.state.Running = false
	w = httptest.NewRecorder()
	h.ServeHTTP(w, r)
	if ctx.Err() == nil {
		t.Fatal("quit did not cancel")
	}
}
func hash(data []byte) string { s := sha256.Sum256(data); return hex.EncodeToString(s[:]) }
func TestInstallPlayAndOfflineRecovery(t *testing.T) {
	var archive bytes.Buffer
	z := zip.NewWriter(&archive)
	files := map[string]updater.File{}
	for name, data := range map[string][]byte{"Starfall.x86_64": []byte("#!/bin/sh\nprintf played > played.txt\n"), "Starfall.pck": []byte("fixture")} {
		w, _ := z.Create(name)
		w.Write(data)
		files[name] = updater.File{SHA256: hash(data), Size: int64(len(data))}
	}
	z.Close()
	build := strings.Repeat("a", 40)
	manifest := updater.Manifest{Schema: 1, Build: build, Version: "test", ServerTag: "sha-aaaaaaa", SHA256: hash(archive.Bytes()), Size: int64(archive.Len()), Files: files}
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/manifest.json" {
			json.NewEncoder(w).Encode(manifest)
		} else {
			w.Write(archive.Bytes())
		}
	}))
	defer server.Close()
	manifest.URL = server.URL + "/releases/sha-aaaaaaa/Starfall-Linux.zip"
	u := updater.NewLinux(t.TempDir())
	u.Feed = server.URL + "/manifest.json"
	u.AssetPrefix = server.URL + "/releases/"
	u.Client = server.Client()
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	a := &launcher{ctx: ctx, cancel: cancel, manager: u}
	wait := func() {
		t.Helper()
		deadline := time.Now().Add(5 * time.Second)
		for time.Now().Before(deadline) {
			a.mu.Lock()
			busy := a.state.Busy
			a.mu.Unlock()
			if !busy {
				return
			}
			time.Sleep(10 * time.Millisecond)
		}
		t.Fatal("launcher timed out")
	}
	a.update(true, false)
	wait()
	a.mu.Lock()
	failed := a.state.Failed
	a.mu.Unlock()
	if failed {
		t.Fatal("install/play failed")
	}
	current, err := u.Current()
	if err != nil {
		t.Fatal(err)
	}
	marker := filepath.Join(filepath.Dir(u.Executable(current)), "played.txt")
	if data, err := os.ReadFile(marker); err != nil || string(data) != "played" {
		t.Fatal("native game not launched in install directory")
	}
	server.Close()
	a.update(false, false)
	wait()
	a.mu.Lock()
	fallback := a.state.Failed && a.state.Installed
	a.mu.Unlock()
	if !fallback {
		t.Fatal("offline fallback missing")
	}
	os.Remove(marker)
	a.update(true, true)
	wait()
	if _, err := os.Stat(marker); err != nil {
		t.Fatal("offline Play did not run installed game")
	}
}
func TestDataDirectory(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_DATA_HOME", "relative")
	if got, _ := dataRoot(); got != filepath.Join(home, ".local/share/Starfall") {
		t.Fatal(got)
	}
	t.Setenv("XDG_DATA_HOME", home)
	if got, _ := dataRoot(); got != filepath.Join(home, "Starfall") {
		t.Fatal(got)
	}
}
