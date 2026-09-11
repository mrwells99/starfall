package updater

import (
	"archive/zip"
	"bytes"
	"context"
	"os"
	"runtime"
	"strings"
	"testing"
)

func linuxRelease(f *fixture, id string) {
	f.u.Linux = true
	var b bytes.Buffer
	z := zip.NewWriter(&b)
	files := map[string]File{}
	for _, name := range []string{"Starfall.x86_64", "Starfall.pck", "support.so"} {
		data := []byte(name + id)
		w, _ := z.Create(name)
		w.Write(data)
		files[name] = File{sum(data), int64(len(data))}
	}
	z.Close()
	f.archive = b.Bytes()
	build := strings.Repeat(id, 40)
	tag := "sha-" + build[:7]
	f.manifest = Manifest{1, build, "0.11.0", tag, f.u.AssetPrefix + tag + "/Starfall-Linux.zip", sum(f.archive), int64(len(f.archive)), files}
}
func TestLinuxLifecycle(t *testing.T) {
	f := setup(t)
	linuxRelease(f, "a")
	first := install(t, f)
	if !strings.HasSuffix(f.u.Executable(first), "Starfall.x86_64") {
		t.Fatal("wrong executable")
	}
	if i := install(t, f); i.Directory != first.Directory || f.downloads != 1 {
		t.Fatal("unnecessary download")
	}
	if runtime.GOOS == "linux" {
		info, _ := os.Stat(f.u.Executable(first))
		if info.Mode().Perm()&0100 == 0 {
			t.Fatal("not executable")
		}
		os.Chmod(f.u.Executable(first), 0600)
		if f.u.Verify(first) == nil {
			t.Fatal("missing execute permission accepted")
		}
		first = install(t, f)
	}
	linuxRelease(f, "b")
	second := install(t, f)
	linuxRelease(f, "c")
	f.archive[0] ^= 1
	if _, err := f.u.Update(context.Background(), nil); err == nil {
		t.Fatal("corrupt update accepted")
	}
	if got, err := f.u.Current(); err != nil || got.Directory != second.Directory {
		t.Fatal("current damaged")
	}
	linuxRelease(f, "a")
	if got := install(t, f); got.Directory != first.Directory {
		t.Fatal("rollback not reused")
	}
}
func TestPlatformSeparation(t *testing.T) {
	f := setup(t)
	f.u.Linux = true
	if err := f.u.validate(f.manifest); err == nil {
		t.Fatal("Linux accepted Windows")
	}
	linuxRelease(f, "a")
	f.u.Linux = false
	if err := f.u.validate(f.manifest); err == nil {
		t.Fatal("Windows accepted Linux")
	}
	for _, name := range []string{"other.exe", "support.dll", "../escape.so", "SUPPORT.SO", "Starfall.x86_64."} {
		linuxRelease(f, "a")
		f.manifest.Files[name] = f.manifest.Files["support.so"]
		if err := f.u.validate(f.manifest); err == nil {
			t.Fatalf("accepted %s", name)
		}
	}
	u := NewLinux(t.TempDir())
	if u.Feed != "https://play.leafmods.com/downloads/linux/manifest.json" || u.AssetPrefix != "https://play.leafmods.com/downloads/linux/releases/" {
		t.Fatal("wrong production feed")
	}
}
