package main

import (
	"bufio"
	"encoding/json"
	"io/ioutil"
	"log"
	"net"
	"net/http"
	"os"
	"strings"
	"time"

	simplejson "github.com/bitly/go-simplejson"
	"github.com/jaredfolkins/badactor"
	"github.com/julienschmidt/httprouter"
	"github.com/tredoe/osutil/user/crypt/sha512_crypt"
	"github.com/urfave/negroni"
)

var st *badactor.Studio

func getDirectory() string {
	return "/tmp/docker-mailserver/postfix-accounts.cf"
}

func getHash(salt string, secret string) string {
	c := sha512_crypt.New()
	hash, err := c.Generate([]byte(secret), []byte(salt))
	if err != nil {
		panic(err)
	}
	return hash
}

type User struct {
	mail string
	hash string
	salt string
}

func findUser(mail string) User {
	directory := getDirectory()
	file, err := os.Open(directory)
	if err != nil {
		log.Fatal(err)
	}
	defer file.Close()
	var u User
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		str := scanner.Text()

		i := strings.Index(str, "|")
		email := str[:i]

		startSalt := strings.Index(str, "$")
		endSalt := strings.LastIndex(str, "$")
		salt := str[startSalt : endSalt+1]
		hash := str[startSalt:]
		if mail == email {
			u.hash = hash
			u.mail = email
			u.salt = salt
		}
	}
	if err := scanner.Err(); err != nil {
		log.Fatal(err)
	}
	return u
}

func writeToFile(mail string, newHash string) {
	directory := getDirectory()
	input, err := ioutil.ReadFile(directory)
	if err != nil {
		log.Fatalln(err)
	}

	lines := strings.Split(string(input), "\n")

	for i, line := range lines {
		if strings.HasPrefix(line, mail) {
			lines[i] = mail + "|{SHA512-CRYPT}" + newHash
		}
	}
	output := strings.Join(lines, "\n")
	err = ioutil.WriteFile(directory, []byte(output), 0644)
	if err != nil {
		log.Fatalln(err)
	}
}

type UserInput struct {
	Mail          string
	CurrentSecret string
	NewSecret     string
}

func changePassword(w http.ResponseWriter, r *http.Request, _ httprouter.Params) {
	var err error
	decoder := json.NewDecoder(r.Body)
	var u UserInput

	err = decoder.Decode(&u)
	if err != nil {
		panic(err)
	}
	an, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		panic(err)
	}

	json := simplejson.New()
	user := findUser(u.Mail)
	if (User{}) == user {
		err = st.Infraction(an, "Login")
		if err != nil {
			log.Printf("[%v] has err %v", an, err)
		}
		json.Set("status", "user not found")
		w.WriteHeader(http.StatusNotFound)
	} else {
		currentHash := getHash(string(user.salt), u.CurrentSecret)
		if currentHash == user.hash {
			newHash := getHash(string(user.salt), u.NewSecret)
			writeToFile(user.mail, newHash)
			json.Set("status", "changed password")
		} else {
			err = st.Infraction(an, "Login")
			if err != nil {
				log.Printf("[%v] has err %v", an, err)
			}
			json.Set("status", "wrong password")
			w.WriteHeader(http.StatusForbidden)
		}
	}
	payload, err := json.MarshalJSON()
	w.Header().Set("Content-Type", "application/json")
	w.Write(payload)
}

type MyAction struct{}

func (ma *MyAction) WhenJailed(a *badactor.Actor, r *badactor.Rule) error {
	return nil
}

func (ma *MyAction) WhenTimeServed(a *badactor.Actor, r *badactor.Rule) error {
	return nil
}

func main() {
	// studio capacity
	var sc int32
	// director capacity
	var dc int32

	sc = 1024
	dc = 1024
	st = badactor.NewStudio(sc)
	ru := &badactor.Rule{
		Name:        "Login",
		Message:     "You have failed to login too many times",
		StrikeLimit: 5,
		ExpireBase:  time.Second * 1,
		Sentence:    time.Second * 10,
		Action:      &MyAction{},
	}
	st.AddRule(ru)

	err := st.CreateDirectors(dc)
	if err != nil {
		log.Fatal(err)
	}
	//poll duration
	dur := time.Minute * time.Duration(60)
	// Start the reaper
	st.StartReaper(dur)

	router := httprouter.New()
	router.POST("/change", changePassword)

	// middleware
	n := negroni.Classic()
	n.Use(negroni.NewStatic(http.Dir("/usr/local/bin/update-user-password/static")))
	n.Use(NewBadActorMiddleware())
	n.UseHandler(router)
	n.Run(":8000")
}

// BadActorMiddleware Middleware
type BadActorMiddleware struct {
	negroni.Handler
}

// NewBadActorMiddleware restrict usage by IP
func NewBadActorMiddleware() *BadActorMiddleware {
	return &BadActorMiddleware{}
}

func (bam *BadActorMiddleware) ServeHTTP(w http.ResponseWriter, r *http.Request, next http.HandlerFunc) {

	// get IP
	an, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		panic(err)
	}

	// if the IP is jailed, send them StatusUnauthorized
	if st.IsJailed(an) {
		http.Error(w, http.StatusText(http.StatusNotFound), http.StatusNotFound)
		return
	}

	// call the next middleware in the chain
	next(w, r)
}
