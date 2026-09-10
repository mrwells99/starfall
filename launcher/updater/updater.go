// Package updater installs verified game releases into versioned user folders.
package updater

import (
	"archive/zip"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"
)

const Feed = "https://play.leafmods.com/downloads/manifest.json"
const AssetPrefix = "https://play.leafmods.com/downloads/releases/"
const maxArchive int64 = 1 << 30
const maxInstalled int64 = 3 << 30

var hashPattern = regexp.MustCompile(`^[a-f0-9]{64}$`)
var buildPattern = regexp.MustCompile(`^[a-f0-9]{40}$`)
var filePattern = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9_.-]{0,80}$`)
var dirPattern = regexp.MustCompile(`^[a-f0-9]{40}-[0-9]+$`)

type File struct {
	SHA256 string `json:"sha256"`
	Size   int64  `json:"size"`
}
type Manifest struct {
	Schema    int             `json:"schema"`
	Build     string          `json:"build"`
	Version   string          `json:"version"`
	ServerTag string          `json:"server_tag"`
	URL       string          `json:"url"`
	SHA256    string          `json:"sha256"`
	Size      int64           `json:"size"`
	Files     map[string]File `json:"files"`
}
type Installation struct {
	Directory string   `json:"directory"`
	Manifest  Manifest `json:"manifest"`
}
type Progress func(message string, percent int)
type Updater struct {
	Root, Feed, AssetPrefix string
	Client                  *http.Client
}

func New(root string) *Updater {
	client := &http.Client{Timeout: 15 * time.Minute, Transport: &http.Transport{Proxy: http.ProxyFromEnvironment, ResponseHeaderTimeout: 20 * time.Second, TLSHandshakeTimeout: 15 * time.Second}}
	client.CheckRedirect = func(req *http.Request, via []*http.Request) error {
		if len(via) >= 8 {
			return errors.New("too many download redirects")
		}
		if req.URL.Scheme != "https" {
			return errors.New("refusing an insecure download redirect")
		}
		if req.URL.Host == "play.leafmods.com" && req.URL.User == nil {
			return nil
		}
		return errors.New("unexpected download host")
	}
	return &Updater{root, Feed, AssetPrefix, client}
}

func (u *Updater) validate(m Manifest) error {
	if m.Schema != 1 {
		return errors.New("this release needs a newer launcher; download StarfallLauncher.exe again")
	}
	if !buildPattern.MatchString(m.Build) || m.ServerTag != "sha-"+m.Build[:7] || len(m.Version) == 0 || len(m.Version) > 64 {
		return errors.New("invalid release identity")
	}
	parsed, err := url.Parse(m.URL)
	if err != nil || parsed.Scheme != "https" || parsed.User != nil || parsed.RawQuery != "" || parsed.Fragment != "" || m.URL != u.AssetPrefix+m.ServerTag+"/Starfall-Windows.zip" {
		return errors.New("unexpected game download address")
	}
	if !hashPattern.MatchString(m.SHA256) || m.Size <= 0 || m.Size > maxArchive {
		return errors.New("invalid download size or checksum")
	}
	if len(m.Files) < 2 || len(m.Files) > 128 {
		return errors.New("invalid game file list")
	}
	total := int64(0)
	seen := map[string]bool{}
	for name, f := range m.Files {
		lower := strings.ToLower(name)
		if !filePattern.MatchString(name) || strings.HasSuffix(name, ".") || seen[lower] || (name != "Starfall.exe" && name != "Starfall.pck" && !strings.HasSuffix(lower, ".dll")) {
			return errors.New("unexpected game filename")
		}
		if !hashPattern.MatchString(f.SHA256) || f.Size <= 0 || f.Size > maxInstalled-total {
			return errors.New("invalid installed file size or checksum")
		}
		total += f.Size
		seen[lower] = true
	}
	if _, ok := m.Files["Starfall.exe"]; !ok {
		return errors.New("release is missing Starfall.exe")
	}
	if _, ok := m.Files["Starfall.pck"]; !ok {
		return errors.New("release is missing game data")
	}
	return nil
}

func (u *Updater) Latest(ctx context.Context) (Manifest, error) {
	var m Manifest
	ctx, cancel := context.WithTimeout(ctx, 25*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, "GET", u.Feed, nil)
	if err != nil {
		return m, err
	}
	req.Header.Set("User-Agent", "StarfallLauncher/1")
	req.Header.Set("Cache-Control", "no-cache")
	resp, err := u.Client.Do(req)
	if err != nil {
		return m, fmt.Errorf("could not check for updates: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode == 404 {
		return m, errors.New("the first Windows release is not available yet; try again after it is published")
	}
	if resp.StatusCode != http.StatusOK {
		return m, fmt.Errorf("update service returned HTTP %d; try again shortly", resp.StatusCode)
	}
	data, err := io.ReadAll(io.LimitReader(resp.Body, 512*1024+1))
	if err != nil {
		return m, err
	}
	if len(data) > 512*1024 {
		return m, errors.New("release information is too large")
	}
	if err = json.Unmarshal(data, &m); err != nil {
		return m, errors.New("release information could not be read")
	}
	return m, u.validate(m)
}

func (u *Updater) Current() (Installation, error) {
	var install Installation
	data, err := os.ReadFile(filepath.Join(u.Root, "current.json"))
	if err != nil {
		return install, err
	}
	if err = json.Unmarshal(data, &install); err != nil {
		return install, err
	}
	return install, u.Verify(install)
}

func (u *Updater) Verify(i Installation) error {
	if !dirPattern.MatchString(i.Directory) || !strings.HasPrefix(i.Directory, i.Manifest.Build+"-") {
		return errors.New("invalid installation path")
	}
	if err := u.validate(i.Manifest); err != nil {
		return err
	}
	dir := filepath.Join(u.Root, "versions", i.Directory)
	info, err := os.Lstat(dir)
	if err != nil {
		return err
	}
	if !info.IsDir() || info.Mode()&os.ModeSymlink != 0 {
		return errors.New("invalid game directory")
	}
	for name, expected := range i.Manifest.Files {
		path := filepath.Join(dir, name)
		info, err := os.Lstat(path)
		if err != nil {
			return err
		}
		if !info.Mode().IsRegular() || info.Size() != expected.Size {
			return errors.New("installed game files are incomplete; use Retry to repair")
		}
		file, err := os.Open(path)
		if err != nil {
			return err
		}
		hash := sha256.New()
		_, err = io.Copy(hash, file)
		file.Close()
		if err != nil || hex.EncodeToString(hash.Sum(nil)) != expected.SHA256 {
			return errors.New("installed game files need repair; use Retry")
		}
	}
	return nil
}
func (u *Updater) Executable(i Installation) string {
	return filepath.Join(u.Root, "versions", i.Directory, "Starfall.exe")
}

// Update returns an error without changing the current installation on any
// download, checksum, extraction or state-write failure.
func (u *Updater) Update(ctx context.Context, report Progress) (Installation, error) {
	if report == nil {
		report = func(string, int) {}
	}
	report("Checking for updates…", 0)
	latest, err := u.Latest(ctx)
	if err != nil {
		return Installation{}, err
	}
	report("Checking installed files…", 0)
	current, currentErr := u.Current()
	if currentErr == nil && current.Manifest.Build == latest.Build && current.Manifest.SHA256 == latest.SHA256 {
		return current, nil
	}
	// A rollback can reuse the retained installation after full verification.
	versions := filepath.Join(u.Root, "versions")
	if err = os.MkdirAll(versions, 0700); err != nil {
		return Installation{}, err
	}
	entries, _ := os.ReadDir(versions)
	for _, entry := range entries {
		if !entry.IsDir() || !strings.HasPrefix(entry.Name(), latest.Build+"-") {
			continue
		}
		candidate := Installation{entry.Name(), latest}
		if u.Verify(candidate) == nil {
			if err = u.activate(candidate); err != nil {
				return Installation{}, err
			}
			u.cleanup(candidate, current)
			return candidate, nil
		}
	}
	stage, err := os.MkdirTemp(versions, latest.Build+"-")
	if err != nil {
		return Installation{}, err
	}
	activated := false
	defer func() {
		if !activated {
			os.RemoveAll(stage)
		}
	}()
	archive := filepath.Join(stage, "download.zip")
	if err = u.download(ctx, latest, archive, report); err != nil {
		return Installation{}, err
	}
	report("Unpacking verified update…", 95)
	if err = extract(ctx, archive, stage, latest); err != nil {
		return Installation{}, err
	}
	if err = os.Remove(archive); err != nil {
		return Installation{}, err
	}
	next := Installation{filepath.Base(stage), latest}
	if err = u.activate(next); err != nil {
		return Installation{}, err
	}
	activated = true
	u.cleanup(next, current)
	report("Ready to play", 100)
	return next, nil
}

func (u *Updater) activate(i Installation) error {
	data, err := json.Marshal(i)
	if err != nil {
		return err
	}
	if old, err := os.ReadFile(filepath.Join(u.Root, "current.json")); err == nil {
		if err = atomicWrite(filepath.Join(u.Root, "previous.json"), old); err != nil {
			return err
		}
	}
	return atomicWrite(filepath.Join(u.Root, "current.json"), data)
}
func (u *Updater) cleanup(current, previous Installation) {
	entries, _ := os.ReadDir(filepath.Join(u.Root, "versions"))
	for _, entry := range entries {
		// Only our version folders; never touch user settings, arbitrary folders or links.
		if entry.IsDir() && dirPattern.MatchString(entry.Name()) && entry.Name() != current.Directory && entry.Name() != previous.Directory {
			_ = os.RemoveAll(filepath.Join(u.Root, "versions", entry.Name()))
		}
	}
}
func atomicWrite(path string, data []byte) error {
	tmp, err := os.CreateTemp(filepath.Dir(path), "state-*.tmp")
	if err != nil {
		return err
	}
	defer os.Remove(tmp.Name())
	if _, err = tmp.Write(data); err != nil {
		tmp.Close()
		return err
	}
	if err = tmp.Sync(); err != nil {
		tmp.Close()
		return err
	}
	if err = tmp.Close(); err != nil {
		return err
	}
	return replaceFile(tmp.Name(), path)
}

type progressWriter struct {
	written, total int64
	last           int
	report         Progress
}

func (p *progressWriter) Write(data []byte) (int, error) {
	p.written += int64(len(data))
	percent := int(p.written * 90 / p.total)
	if percent != p.last {
		p.last = percent
		p.report(fmt.Sprintf("Downloading update… %d%%", percent*100/90), percent)
	}
	return len(data), nil
}
func (u *Updater) download(ctx context.Context, m Manifest, path string, report Progress) error {
	req, err := http.NewRequestWithContext(ctx, "GET", m.URL, nil)
	if err != nil {
		return err
	}
	req.Header.Set("User-Agent", "StarfallLauncher/1")
	resp, err := u.Client.Do(req)
	if err != nil {
		return fmt.Errorf("download failed: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return fmt.Errorf("download returned HTTP %d; your installed game is unchanged", resp.StatusCode)
	}
	file, err := os.OpenFile(path, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0600)
	if err != nil {
		return err
	}
	hash := sha256.New()
	progress := &progressWriter{total: m.Size, last: -1, report: report}
	n, err := io.Copy(io.MultiWriter(file, hash, progress), io.LimitReader(resp.Body, m.Size+1))
	closeErr := file.Close()
	if err != nil {
		return err
	}
	if closeErr != nil {
		return closeErr
	}
	if n != m.Size || hex.EncodeToString(hash.Sum(nil)) != m.SHA256 {
		return errors.New("download verification failed; your installed game is unchanged")
	}
	return nil
}
func extract(ctx context.Context, archive, dest string, m Manifest) error {
	reader, err := zip.OpenReader(archive)
	if err != nil {
		return err
	}
	defer reader.Close()
	if len(reader.File) != len(m.Files) {
		return errors.New("archive contains unexpected files")
	}
	seen := map[string]bool{}
	for _, entry := range reader.File {
		if err = ctx.Err(); err != nil {
			return err
		}
		expected, ok := m.Files[entry.Name]
		if !ok || seen[entry.Name] || !entry.Mode().IsRegular() || entry.UncompressedSize64 != uint64(expected.Size) {
			return errors.New("archive contains an invalid game file")
		}
		seen[entry.Name] = true
		source, err := entry.Open()
		if err != nil {
			return err
		}
		target, err := os.OpenFile(filepath.Join(dest, entry.Name), os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0700)
		if err != nil {
			source.Close()
			return err
		}
		hash := sha256.New()
		n, copyErr := io.Copy(io.MultiWriter(target, hash), io.LimitReader(source, expected.Size+1))
		source.Close()
		syncErr := target.Sync()
		closeErr := target.Close()
		if copyErr != nil {
			return copyErr
		}
		if syncErr != nil {
			return syncErr
		}
		if closeErr != nil {
			return closeErr
		}
		if n != expected.Size || hex.EncodeToString(hash.Sum(nil)) != expected.SHA256 {
			return errors.New("unpacked game file failed verification")
		}
	}
	return nil
}
