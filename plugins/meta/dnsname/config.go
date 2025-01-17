package main

import (
	"errors"
	"os"
	"path/filepath"

	"github.com/containernetworking/cni/pkg/types"
)

const (
	// confFileName is the name of the dns masq conf file
	confFileName = "dnsmasq.conf"
	// hostsFileName is the name of the addnhosts file
	hostsFileName = "addnhosts"
	// pidFileName is the file where the dnsmasq file is stored
	pidFileName = "pidfile"
	// extraConfDir is the directory where users can add their own additional conf files
	extraConfDir = "dnsmasq.d"
)

const dnsMasqTemplate = `## WARNING: THIS IS AN AUTOGENERATED FILE
## AND SHOULD NOT BE EDITED MANUALLY AS IT
## LIKELY TO AUTOMATICALLY BE REPLACED.
strict-order
local=/{{.Domain}}/
domain={{.Domain}}
expand-hosts
pid-file={{.PidFile}}
except-interface=lo
bind-dynamic
no-hosts
interface={{.NetworkInterface}}
addn-hosts={{.AddOnHostsFile}}
conf-dir={{.ExtraConfDir}}`

var (
	// ErrBinaryNotFound means that the dnsmasq binary was not found
	ErrBinaryNotFound = errors.New("unable to locate dnsmasq in path")
	// ErrNoIPAddressFound means that CNI was unable to resolve an IP address in the CNI configuration
	ErrNoIPAddressFound = errors.New("no ip address was found in the network")
)

// DNSNameConf represents the cni config with the domain name attribute
type DNSNameConf struct {
	types.NetConf
	DomainName    string   `json:"domainName"`
	RuntimeConfig struct { // The capability arg
		Aliases map[string][]string `json:"aliases"`
	} `json:"runtimeConfig,omitempty"`
}

// dnsNameFile describes the plugin's attributes
type dnsNameFile struct {
	AddOnHostsFile   string
	Binary           string
	ConfigFile       string
	Domain           string
	NetworkInterface string
	PidFile          string
	ExtraConfDir     string
}

// dnsNameConfPath tells where we store the conf, pid, and hosts files
func dnsNameConfPath() string {
	xdgRuntimeDir := os.Getenv("XDG_RUNTIME_DIR")
	if xdgRuntimeDir != "" {
		return filepath.Join(xdgRuntimeDir, "containers/cni/dnsname")
	}
	return "/run/containers/cni/dnsname"
}
