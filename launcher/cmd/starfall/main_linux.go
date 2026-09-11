//go:build linux

package main

import (
	"context"
	"crypto/rand"
	_ "embed"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strings"
	"sync"
	"syscall"
	"time"

	"starfall/launcher/updater"
)

//go:embed panel.html
var panel string

type status struct {
	Message   string `json:"message"`
	Percent   int    `json:"percent"`
	Busy      bool   `json:"busy"`
	Running   bool   `json:"running"`
	Installed bool   `json:"installed"`
	Version   string `json:"version"`
	Failed    bool   `json:"failed"`
}
type launcher struct {
	work     sync.WaitGroup
	mu       sync.Mutex
	state    status
	manager  *updater.Updater
	ctx      context.Context
	cancel   context.CancelFunc
	lastSeen time.Time
	preview  bool
}

func (a *launcher) update(play bool, installedOnly bool) {
	a.mu.Lock()
	if a.state.Busy || a.state.Running || a.preview || a.ctx.Err() != nil {
		a.mu.Unlock()
		return
	}
	a.state.Busy = true
	a.state.Failed = false
	a.state.Message = "Checking for updates…"
	a.work.Add(1)
	a.mu.Unlock()
	go func() {
		defer a.work.Done()
		var i updater.Installation
		var err error
		if installedOnly {
			i, err = a.manager.Current()
		} else {
			i, err = a.manager.Update(a.ctx, func(message string, percent int) {
				a.mu.Lock()
				a.state.Message = message
				a.state.Percent = percent
				a.mu.Unlock()
			})
		}
		if err != nil {
			log.Print(err)
			current, currentErr := a.manager.Current()
			a.mu.Lock()
			a.state.Busy = false
			a.state.Failed = true
			a.state.Installed = currentErr == nil
			a.state.Message = err.Error()
			if currentErr == nil {
				a.state.Version = current.Manifest.Version + " · " + current.Manifest.Build[:7]
			}
			a.mu.Unlock()
			return
		}
		a.mu.Lock()
		a.state.Installed = true
		a.state.Version = i.Manifest.Version + " · " + i.Manifest.Build[:7]
		a.state.Percent = 100
		a.state.Message = "You're up to date. Ready for your next fight."
		if !play {
			a.state.Busy = false
			a.mu.Unlock()
			return
		}
		a.mu.Unlock()
		// Current/Update has verified every file. Keep the launcher lock while the
		// game runs so another instance cannot clean up its version folder.
		cmd := exec.Command(a.manager.Executable(i))
		cmd.Dir = filepath.Dir(a.manager.Executable(i))
		cmd.Stdout = log.Writer()
		cmd.Stderr = log.Writer()
		err = a.ctx.Err()
		if err == nil {
			err = cmd.Start()
		}
		if err == nil {
			a.mu.Lock()
			a.state.Running = true
			a.state.Message = "Game is running. See you in the arena."
			a.mu.Unlock()
			err = cmd.Wait()
		}
		a.mu.Lock()
		a.state.Busy = false
		a.state.Running = false
		a.state.Message = "Ready for another round."
		if err != nil {
			log.Print(err)
			a.state.Message = "The game could not start or closed unexpectedly. See launcher.log in your Starfall data folder."
		}
		a.lastSeen = time.Now()
		a.mu.Unlock()
	}()
}

func (a *launcher) handler(host, token string) http.Handler {
	prefix := "/" + token + "/"
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cache-Control", "no-store")
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("Referrer-Policy", "no-referrer")
		w.Header().Set("Content-Security-Policy", "default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'")
		// Exact Host and Origin checks prevent DNS rebinding and cross-site actions.
		// A random per-launch capability also protects requests without Origin.
		if r.Host != host || (r.Header.Get("Origin") != "" && r.Header.Get("Origin") != "http://"+host) || !strings.HasPrefix(r.URL.Path, prefix) {
			http.Error(w, "Not found", http.StatusNotFound)
			return
		}
		action := strings.TrimPrefix(r.URL.Path, prefix)
		if r.Method == http.MethodGet && action == "" {
			w.Header().Set("Content-Type", "text/html; charset=utf-8")
			io.WriteString(w, panel)
			return
		}
		if r.Method == http.MethodGet && action == "status" {
			a.mu.Lock()
			a.lastSeen = time.Now()
			snapshot := a.state
			a.mu.Unlock()
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(snapshot)
			return
		}
		if r.Method != http.MethodPost {
			http.Error(w, "Method not allowed", 405)
			return
		}
		switch action {
		case "check":
			a.update(false, false)
		case "play":
			a.update(true, false)
		case "installed":
			a.update(true, true)
		case "quit":
			a.mu.Lock()
			running := a.state.Running
			a.mu.Unlock()
			if running {
				http.Error(w, "Close the game first", 409)
				return
			}
			a.cancel()
		default:
			http.NotFound(w, r)
			return
		}
		w.WriteHeader(http.StatusNoContent)
	})
}
func openBrowser(url string) error {
	if path, err := exec.LookPath("xdg-open"); err == nil {
		return exec.Command(path, url).Run()
	}
	if path, err := exec.LookPath("gio"); err == nil {
		return exec.Command(path, "open", url).Run()
	}
	return errors.New("could not find a desktop browser opener; open the printed address in your browser")
}
func dataRoot() (string, error) {
	root := os.Getenv("XDG_DATA_HOME")
	if !filepath.IsAbs(root) {
		home, err := os.UserHomeDir()
		if err != nil {
			return "", err
		}
		root = filepath.Join(home, ".local", "share")
	}
	return filepath.Join(root, "Starfall"), nil
}
func run() error {
	root, err := dataRoot()
	if err != nil {
		return err
	}
	if err = os.MkdirAll(root, 0700); err != nil {
		return err
	}
	lock, err := os.OpenFile(filepath.Join(root, "launcher.lock"), os.O_CREATE|os.O_RDWR, 0600)
	if err != nil {
		return err
	}
	defer lock.Close()
	endpoint := filepath.Join(root, "launcher.url")
	if err = syscall.Flock(int(lock.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		if err != syscall.EWOULDBLOCK && err != syscall.EAGAIN {
			return err
		}
		// The first instance may still be binding its socket.
		for attempt := 0; attempt < 20; attempt++ {
			data, readErr := os.ReadFile(endpoint)
			if readErr == nil && strings.HasPrefix(string(data), "http://127.0.0.1:") {
				return openBrowser(string(data))
			}
			time.Sleep(100 * time.Millisecond)
		}
		return errors.New("Starfall Launcher is already starting; try opening it again shortly")
	}
	defer syscall.Flock(int(lock.Fd()), syscall.LOCK_UN)
	os.Remove(endpoint)
	logs, err := os.OpenFile(filepath.Join(root, "launcher.log"), os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0600)
	if err != nil {
		return err
	}
	defer logs.Close()
	log.SetOutput(logs)
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()
	a := &launcher{ctx: ctx, cancel: cancel, manager: updater.NewLinux(root), lastSeen: time.Now()}
	defer func() { a.mu.Lock(); cancel(); a.mu.Unlock(); a.work.Wait() }()
	noBrowser := false
	for _, arg := range os.Args[1:] {
		switch arg {
		case "--no-browser":
			noBrowser = true
		case "--preview":
			a.preview = true
		default:
			return fmt.Errorf("unknown option %s", arg)
		}
	}
	if a.preview {
		a.state = status{Message: "You're up to date. Ready for your next fight.", Percent: 100, Version: "Preview · Linux x86-64"}
	}
	listener, err := net.Listen("tcp4", "127.0.0.1:0")
	if err != nil {
		return err
	}
	defer listener.Close()
	secret := make([]byte, 32)
	if _, err = rand.Read(secret); err != nil {
		return err
	}
	host := listener.Addr().String()
	url := "http://" + host + "/" + hex.EncodeToString(secret) + "/"
	server := &http.Server{Handler: a.handler(host, hex.EncodeToString(secret)), ReadHeaderTimeout: 5 * time.Second, IdleTimeout: 30 * time.Second}
	defer server.Close()
	go func() {
		if err := server.Serve(listener); err != nil && err != http.ErrServerClosed {
			log.Print(err)
			cancel()
		}
	}()
	if err = os.WriteFile(endpoint, []byte(url), 0600); err != nil {
		return err
	}
	defer os.Remove(endpoint)
	fmt.Println("Starfall Launcher:", url)
	if !a.preview {
		a.update(false, false)
	}
	if !noBrowser {
		go func() {
			if err := openBrowser(url); err != nil {
				log.Print(err)
				fmt.Fprintln(os.Stderr, err)
			}
		}()
	}
	ticker := time.NewTicker(15 * time.Second)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return nil
		case <-ticker.C:
			a.mu.Lock()
			idle := !a.state.Busy && !a.state.Running && time.Since(a.lastSeen) > 3*time.Minute
			a.mu.Unlock()
			if idle {
				return nil
			}
		}
	}
}
func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "Starfall:", err)
		os.Exit(1)
	}
}
