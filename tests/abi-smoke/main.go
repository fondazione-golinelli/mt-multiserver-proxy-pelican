package main

import (
	"log"

	proxy "github.com/HimbeerserverDE/mt-multiserver-proxy"
)

func init() {
	_ = proxy.Conf()
	log.Print("SKYSS plugin ABI smoke passed")
}
