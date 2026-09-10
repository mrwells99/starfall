//go:build windows

package main

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"starfall/launcher/updater"
	"strings"
	"syscall"
	"time"
	"unsafe"
)

var user = syscall.NewLazyDLL("user32.dll")
var kernel = syscall.NewLazyDLL("kernel32.dll")
var gdi = syscall.NewLazyDLL("gdi32.dll")
var createWindow = user.NewProc("CreateWindowExW")
var sendMessage = user.NewProc("SendMessageW")
var setText = user.NewProc("SetWindowTextW")
var enableWindow = user.NewProc("EnableWindow")
var defaultProc = user.NewProc("DefWindowProcW")
var window, statusLabel, versionLabel, progressBar, playButton, retryButton uintptr
var background, font, titleFont uintptr
var manager *updater.Updater
var installed updater.Installation
var busy, ready, gameRunning bool
var ctx context.Context
var cancel context.CancelFunc
var updates = make(chan update, 128)
var smoke bool
var scale = 1.0

type update struct {
	text    string
	percent int
	done    bool
	install updater.Installation
	err     error
	running bool
}
type point struct{ X, Y int32 }
type message struct {
	Window         uintptr
	ID             uint32
	WParam, LParam uintptr
	Time           uint32
	Point          point
	Private        uint32
}
type windowClass struct {
	Size, Style                        uint32
	Proc                               uintptr
	ClassExtra, WindowExtra            int32
	Instance, Icon, Cursor, Background uintptr
	Menu, Name                         *uint16
	SmallIcon                          uintptr
}

func wide(s string) *uint16         { v, _ := syscall.UTF16PtrFromString(s); return v }
func ptr(s string) uintptr          { return uintptr(unsafe.Pointer(wide(s))) }
func px(n int) uintptr              { return uintptr(float64(n) * scale) }
func text(handle uintptr, s string) { setText.Call(handle, ptr(s)) }
func enabled(handle uintptr, on bool) {
	var value uintptr
	if on {
		value = 1
	}
	enableWindow.Call(handle, value)
}
func child(class, title string, style uintptr, x, y, w, h, id int) uintptr {
	handle, _, _ := createWindow.Call(0, ptr(class), ptr(title), style|0x50000000, px(x), px(y), px(w), px(h), window, uintptr(id), 0, 0)
	sendMessage.Call(handle, 0x30, font, 1)
	return handle
}
func publish(event update) {
	select {
	case updates <- event:
	case <-ctx.Done():
	}
}
func report(s string, p int) { publish(update{text: s, percent: p}) }
func logError(err error) {
	file, e := os.OpenFile(filepath.Join(manager.Root, "launcher.log"), os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0600)
	if e == nil {
		fmt.Fprintf(file, "%s %v\n", time.Now().Format(time.RFC3339), err)
		file.Close()
	}
}
func check(launch bool) {
	if busy || gameRunning {
		return
	}
	busy = true
	enabled(playButton, false)
	enabled(retryButton, false)
	text(statusLabel, "Checking for updates…")
	go func() {
		next, err := manager.Update(ctx, report)
		if err != nil {
			logError(err)
			previous, verifyErr := manager.Current()
			if verifyErr != nil {
				previous = updater.Installation{}
			}
			publish(update{text: err.Error(), done: true, install: previous, err: err})
			return
		}
		if launch {
			runGame(next)
			return
		}
		publish(update{text: "You're up to date. Ready for your next fight.", percent: 100, done: true, install: next})
	}()
}
func runGame(i updater.Installation) {
	if err := manager.Verify(i); err != nil {
		publish(update{text: err.Error(), done: true, err: err})
		return
	}
	command := exec.Command(manager.Executable(i))
	command.Dir = filepath.Dir(manager.Executable(i))
	if err := command.Start(); err != nil {
		logError(err)
		publish(update{text: "Windows could not start the game. Use Retry to check the installation.", done: true, install: i, err: err})
		return
	}
	publish(update{text: "Game is running. Your launcher will be ready when you finish.", running: true, install: i})
	err := command.Wait()
	if err != nil {
		logError(err)
		publish(update{text: "The game closed unexpectedly. Your installed files are safe; try again or check launcher.log.", done: true, install: i, err: err})
		return
	}
	publish(update{text: "Ready for another round.", percent: 100, done: true, install: i})
}
func drain() {
	for {
		select {
		case event := <-updates:
			text(statusLabel, event.text)
			sendMessage.Call(progressBar, 0x402, uintptr(event.percent), 0)
			if event.running {
				gameRunning = true
				busy = false
				installed = event.install
				text(playButton, "Playing")
				continue
			}
			if event.done {
				busy = false
				gameRunning = false
				installed = event.install
				ready = event.err == nil
				canPlay := installed.Directory != ""
				enabled(playButton, canPlay)
				enabled(retryButton, true)
				if ready {
					text(playButton, "Play")
				} else {
					text(playButton, "Play installed")
				}
				if canPlay {
					text(versionLabel, "Installed: "+installed.Manifest.Version+"  ·  "+installed.Manifest.Build[:7])
				}
			}
		default:
			return
		}
	}
}
func procedure(hwnd uintptr, msg uint32, w, l uintptr) uintptr {
	switch msg {
	case 0x113: // WM_TIMER: update controls only on their owning UI thread.
		drain()
		return 0
	case 0x111: // WM_COMMAND
		switch w & 0xffff {
		case 101:
			if !busy && !gameRunning {
				if ready {
					check(true)
				} else if installed.Directory != "" {
					busy = true
					enabled(playButton, false)
					enabled(retryButton, false)
					go runGame(installed)
				}
			}
		case 102:
			check(false)
		}
		return 0
	case 0x138: // WM_CTLCOLORSTATIC
		gdi.NewProc("SetTextColor").Call(w, 0x00f1e4e8)
		gdi.NewProc("SetBkColor").Call(w, 0x00231a16)
		return background
	case 0x10:
		cancel()
		user.NewProc("DestroyWindow").Call(hwnd)
		return 0
	case 0x2:
		user.NewProc("PostQuitMessage").Call(0)
		return 0
	}
	result, _, _ := defaultProc.Call(hwnd, uintptr(msg), w, l)
	return result
}
func main() {
	runtime.LockOSThread()
	smoke = len(os.Args) > 1 && os.Args[1] == "--smoke-test"
	ctx, cancel = context.WithCancel(context.Background())
	defer cancel()
	root := os.Getenv("LOCALAPPDATA")
	if root == "" {
		user.NewProc("MessageBoxW").Call(0, ptr("Windows could not find your user data folder."), ptr("Starfall"), 0x10)
		os.Exit(1)
	}
	manager = updater.New(filepath.Join(root, "Starfall"))
	if err := os.MkdirAll(manager.Root, 0700); err != nil {
		user.NewProc("MessageBoxW").Call(0, ptr("Starfall could not create its game folder. "+err.Error()), ptr("Starfall"), 0x10)
		os.Exit(1)
	}
	mutex, _, err := kernel.NewProc("CreateMutexW").Call(0, 0, ptr("Local\\StarfallLauncher"))
	if mutex == 0 {
		os.Exit(1)
	}
	defer syscall.CloseHandle(syscall.Handle(mutex))
	if err == syscall.Errno(183) {
		user.NewProc("MessageBoxW").Call(0, ptr("Starfall Launcher is already open. Check your taskbar."), ptr("Starfall"), 0x40)
		return
	}
	user.NewProc("SetProcessDPIAware").Call()
	if dpiProc := user.NewProc("GetDpiForSystem"); dpiProc.Find() == nil {
		dpi, _, _ := dpiProc.Call()
		if dpi > 0 {
			scale = float64(dpi) / 96
		}
	}
	background, _, _ = gdi.NewProc("CreateSolidBrush").Call(0x00231a16)
	createFont := func(height, weight int) uintptr {
		h := int32(-int(float64(height) * scale))
		result, _, _ := gdi.NewProc("CreateFontW").Call(uintptr(h), 0, 0, 0, uintptr(weight), 0, 0, 0, 1, 0, 0, 5, 0, ptr("Segoe UI"))
		return result
	}
	font = createFont(17, 400)
	titleFont = createFont(40, 700)
	defer gdi.NewProc("DeleteObject").Call(background)
	defer gdi.NewProc("DeleteObject").Call(font)
	defer gdi.NewProc("DeleteObject").Call(titleFont)
	instance, _, _ := kernel.NewProc("GetModuleHandleW").Call(0)
	cursor, _, _ := user.NewProc("LoadCursorW").Call(0, 32512)
	class := windowClass{Proc: syscall.NewCallback(procedure), Instance: instance, Cursor: cursor, Background: background, Name: wide("StarfallLauncherWindow")}
	class.Size = uint32(unsafe.Sizeof(class))
	atom, _, _ := user.NewProc("RegisterClassExW").Call(uintptr(unsafe.Pointer(&class)))
	if atom == 0 {
		os.Exit(1)
	}
	// Fixed layout, scaled to the Windows DPI setting. No console or runtime install.
	window, _, _ = createWindow.Call(0, uintptr(unsafe.Pointer(class.Name)), ptr("Starfall Launcher"), 0x00ca0000, 0x80000000, 0x80000000, px(630), px(410), 0, 0, instance, 0)
	if window == 0 {
		os.Exit(1)
	}
	title := child("STATIC", "STARFALL", 0, 32, 24, 550, 55, 0)
	sendMessage.Call(title, 0x30, titleFont, 1)
	child("STATIC", "One arena. Your next fight.", 0, 34, 82, 540, 30, 0)
	versionLabel = child("STATIC", "Windows edition", 0, 34, 126, 540, 25, 0)
	statusLabel = child("STATIC", "Checking for updates…", 0, 34, 164, 546, 80, 0)
	// Loading comctl32 registers the native progress control.
	syscall.NewLazyDLL("comctl32.dll").NewProc("InitCommonControls").Call()
	progressBar = child("msctls_progress32", "", 0, 34, 250, 546, 8, 0)
	sendMessage.Call(progressBar, 0x406, 0, 100)
	playButton = child("BUTTON", "Play", 0x10001, 34, 282, 354, 46, 101)
	retryButton = child("BUTTON", "Retry / check updates", 0x10000, 402, 282, 178, 46, 102)
	child("STATIC", "Updates keep your keybinds, HUD layout, and settings.", 0, 34, 343, 550, 24, 0)
	user.NewProc("SetTimer").Call(window, 1, 100, 0)
	user.NewProc("ShowWindow").Call(window, 5)
	user.NewProc("UpdateWindow").Call(window)
	if smoke {
		if statusLabel == 0 || progressBar == 0 || playButton == 0 || retryButton == 0 {
			os.Exit(1)
		}
		// The Windows CI runner checks real creation and message dispatch, without a release feed.
		user.NewProc("PostMessageW").Call(window, 0x10, 0, 0)
	} else if len(os.Args) > 1 && strings.EqualFold(os.Args[1], "--preview") {
		text(statusLabel, "You're up to date. Ready for your next fight.")
		text(versionLabel, "Installed: preview")
		enabled(playButton, false)
		enabled(retryButton, false)
	} else {
		check(false)
	}
	var m message
	for {
		result, _, _ := user.NewProc("GetMessageW").Call(uintptr(unsafe.Pointer(&m)), 0, 0, 0)
		if int32(result) <= 0 {
			break
		}
		user.NewProc("TranslateMessage").Call(uintptr(unsafe.Pointer(&m)))
		user.NewProc("DispatchMessageW").Call(uintptr(unsafe.Pointer(&m)))
	}
}
