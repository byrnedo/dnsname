export GOPROXY=https://proxy.golang.org

GO ?= go
EPOCH_TEST_COMMIT ?= 394c06f491fe9f1c28a410e3b0b91916a5119406
DESTDIR ?=
LIBEXECDIR ?= ${PREFIX}/libexec/cni
PREFIX ?= /usr/local

PROJECT := github.com/containers/dnsname
FIRST_GOPATH := $(firstword $(subst :, ,$(GOPATH)))
GOPKGDIR := $(FIRST_GOPATH)/src/$(PROJECT)
GOPKGBASEDIR ?= $(shell dirname "$(GOPKGDIR)")

SELINUXOPT ?= $(shell test -x /usr/sbin/selinuxenabled && selinuxenabled && echo -Z)

COMMIT_NO ?= $(shell git rev-parse HEAD 2> /dev/null || true)
GIT_COMMIT ?= $(if $(shell git status --porcelain --untracked-files=no),${COMMIT_NO}-dirty,${COMMIT_NO})

LDFLAGS_DNSNAME ?= -X main.gitCommit=$(GIT_COMMIT)

GO_BUILD=$(GO) build
# Go module support: set `-mod=vendor` to use the vendored sources
ifeq ($(shell go help mod >/dev/null 2>&1 && echo true), true)
	GO_BUILD=GO111MODULE=on $(GO) build -mod=vendor
endif

GOBIN := $(shell $(GO) env GOBIN)
ifeq ($(GOBIN),)
GOBIN := $(FIRST_GOPATH)/bin
endif

all: binaries

validate: install.tools gofmt .gitvalidation lint

gofmt:
	find . -name '*.go' ! -path './vendor/*' -exec gofmt -s -w {} \+
	git diff --exit-code


binaries:
	$(GO_BUILD) -ldflags '$(LDFLAGS_DNSNAME)' -o bin/dnsname github.com/containers/dnsname/plugins/meta/dnsname

.PHONY: .gitvalidation
.gitvalidation:
	GIT_CHECK_EXCLUDE="./vendor" $(GOBIN)/git-validation -v -run DCO,short-subject,dangling-whitespace -range $(EPOCH_TEST_COMMIT)..$(HEAD)

.PHONY: install.tools
install.tools: .install.gitvalidation .install.ginkgo .install.golangci-lint

lint: .install.golangci-lint
	./bin/golangci-lint run

define go-get
	env GO111MODULE=off \
		$(GO) get -u ${1}
endef

.install.ginkgo:
	if [ ! -x "$(GOBIN)/ginkgo" ]; then \
		$(call go-get,github.com/onsi/ginkgo/ginkgo); \
	fi

.install.gitvalidation:
	if [ ! -x "$(GOBIN)/git-validation" ]; then \
		$(call go-get,github.com/vbatts/git-validation); \
	fi

.install.golangci-lint:
	if [ ! -x "./bin/golangci-lint" ]; then \
		curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s v1.45.2 ; \
	fi

install:
	install ${SELINUXOPT} -d -m 755 $(DESTDIR)$(LIBEXECDIR)
	install ${SELINUXOPT} -m 755 bin/dnsname $(DESTDIR)$(LIBEXECDIR)/dnsname

clean:
	rm -fr bin/

test: .install.ginkgo
	$(GO) test -v ./...

vendor:
	export GO111MODULE=on \
		$(GO) mod tidy && \
		$(GO) mod vendor && \
		$(GO) mod verify

.PHONY: vendor-in-container
vendor-in-container:
	podman run --privileged --rm --env HOME=/root -v `pwd`:/src -w /src docker.io/library/golang make vendor

.PHONY: \
	binaries \
	test \
	gofmt \
	lint \
	validate \
	vendor
