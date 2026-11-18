// Command keepalive keeps one IMAP session open per hydroxide account.
//
// hydroxide only builds a folder's local message index (and so reports a
// real UIDNEXT) after a client fetches or searches that folder, and it drops
// all of an account's state when the account's last IMAP session logs out.
// Clients that poll (log in, read STATUS, log out) therefore always see
// UIDNEXT 1 and never download anything. Holding one session open keeps the
// account loaded, and opening every folder once builds the indexes. After
// that, hydroxide keeps them current from Proton's event stream.
//
// It is built inside the hydroxide module (see the Dockerfile), so it uses
// the same go-imap version and reads the account list from auth.json.
package main

import (
	"fmt"
	"log"
	"os"
	"time"

	"github.com/emersion/go-imap"
	"github.com/emersion/go-imap/client"
	"github.com/emersion/hydroxide/auth"
)

const (
	noopInterval = 4 * time.Minute
	minBackoff   = 5 * time.Second
	maxBackoff   = 5 * time.Minute
)

func main() {
	log.SetPrefix("keepalive: ")

	password := os.Getenv("HYDROXIDE_BRIDGE_PASS")
	if password == "" {
		log.Print("HYDROXIDE_BRIDGE_PASS is not set, not starting")
		return
	}

	port := os.Getenv("IMAP_PORT")
	if port == "" {
		port = "1143"
	}
	addr := "127.0.0.1:" + port

	// IMAP usernames must match the keys in auth.json exactly, so use them as is.
	usernames, err := auth.ListUsernames()
	if err != nil {
		log.Fatalf("reading accounts from auth.json: %v", err)
	}
	if len(usernames) == 0 {
		log.Fatal("auth.json has no accounts")
	}

	for _, username := range usernames {
		go run(addr, username, password)
	}
	select {}
}

// run keeps a session open for one account, reconnecting with backoff.
func run(addr, username, password string) {
	backoff := minBackoff
	for {
		start := time.Now()
		err := session(addr, username, password)
		if time.Since(start) > maxBackoff {
			backoff = minBackoff
		}
		log.Printf("%s: %v; retrying in %v", username, err, backoff)
		time.Sleep(backoff)
		if backoff *= 2; backoff > maxBackoff {
			backoff = maxBackoff
		}
	}
}

// session logs in, opens every folder once, then idles until the connection
// fails. It only returns with an error.
func session(addr, username, password string) error {
	c, err := client.Dial(addr)
	if err != nil {
		return fmt.Errorf("connecting to IMAP: %w", err)
	}
	defer c.Logout()

	if err := c.Login(username, password); err != nil {
		return fmt.Errorf("login failed (check HYDROXIDE_BRIDGE_PASS matches this account): %w", err)
	}

	infos := make(chan *imap.MailboxInfo, 16)
	listErr := make(chan error, 1)
	go func() { listErr <- c.List("", "*", infos) }()
	var folders []string
	for info := range infos {
		if !hasAttr(info.Attributes, imap.NoSelectAttr) {
			folders = append(folders, info.Name)
		}
	}
	if err := <-listErr; err != nil {
		return fmt.Errorf("listing folders: %w", err)
	}

	loaded := 0
	for _, folder := range folders {
		if _, err := c.Select(folder, true); err != nil {
			log.Printf("%s: opening %q: %v", username, folder, err)
			continue
		}
		// Any SEARCH makes hydroxide build the folder's index.
		uids, err := c.UidSearch(imap.NewSearchCriteria())
		if err != nil {
			log.Printf("%s: indexing %q: %v", username, folder, err)
			continue
		}
		log.Printf("%s: %q has %d messages", username, folder, len(uids))
		loaded++
	}
	log.Printf("%s: loaded %d of %d folders, staying connected", username, loaded, len(folders))

	ticker := time.NewTicker(noopInterval)
	defer ticker.Stop()
	for range ticker.C {
		if err := c.Noop(); err != nil {
			return fmt.Errorf("connection lost: %w", err)
		}
	}
	return nil
}

func hasAttr(attrs []string, attr string) bool {
	for _, a := range attrs {
		if a == attr {
			return true
		}
	}
	return false
}
