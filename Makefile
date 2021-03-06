.PHONY: vendor docs mocks
GO_PACKAGES=$(shell go list ./...)
GO ?= $(shell command -v go 2> /dev/null)
BUILD_HASH ?= $(shell git rev-parse HEAD)
BUILD_VERSION ?= $(shell git ls-remote --tags --refs --sort="v:refname" git://github.com/mattermost/mmctl | tail -n1 | sed 's/.*\///')
# Needed to avoid install shadow in brew which is not permitted
ADVANCED_VET ?= TRUE

LDFLAGS += -X "github.com/mattermost/mmctl/commands.BuildHash=$(BUILD_HASH)"
LDFLAGS += -X "github.com/mattermost/mmctl/commands.Version=$(BUILD_VERSION)"

all: build

build: vendor check
	go build -ldflags '$(LDFLAGS)' -mod=vendor

install: vendor check
	go install -ldflags '$(LDFLAGS)' -mod=vendor

package: vendor check
	mkdir -p build

	@echo Build Linux amd64
	env GOOS=linux GOARCH=amd64 go build -mod=vendor
	tar cf build/linux_amd64.tar mmctl

	@echo Build OSX amd64
	env GOOS=darwin GOARCH=amd64 go build -mod=vendor
	tar cf build/darwin_amd64.tar mmctl

	@echo Build Windows amd64
	env GOOS=windows GOARCH=amd64 go build -mod=vendor
	zip build/windows_amd64.zip mmctl.exe

	rm mmctl mmctl.exe

gofmt:
	@echo Running gofmt
	@for package in $(GO_PACKAGES); do \
		echo "Checking "$$package; \
		files=$$(go list -f '{{range .GoFiles}}{{$$.Dir}}/{{.}} {{end}}' $$package); \
		if [ "$$files" ]; then \
			gofmt_output=$$(gofmt -d -s $$files 2>&1); \
			if [ "$$gofmt_output" ]; then \
				echo "$$gofmt_output"; \
				echo "Gofmt failure"; \
				exit 1; \
			fi; \
		fi; \
	done
	@echo Gofmt success

govet:
	@echo Running govet
	$(GO) vet $(GO_PACKAGES)
ifeq ($(ADVANCED_VET), TRUE)
	@if ! [ -x "$$(command -v mattermost-govet)" ]; then \
		echo "mattermost-govet is not installed. Please install it executing \"GO111MODULE=off go get -u github.com/mattermost/mattermost-govet\""; \
		exit 1; \
	fi;
	@echo Running mattermost-govet
	$(GO) vet -vettool=$(GOPATH)/bin/mattermost-govet -license -structuredLogging -inconsistentReceiverName ./...
	@if ! [ -x "$$(command -v shadow)" ]; then \
		echo "shadow vet tool is not installed. Please install it executing \"GO111MODULE=off go get -u golang.org/x/tools/go/analysis/passes/shadow/cmd/shadow\""; \
		exit 1; \
	fi;
	@echo Running shadow analysis
	$(GO) vet -vettool=$(GOPATH)/bin/shadow $(GO_PACKAGES)
endif
	@echo Govet success

test: test-unit

test-unit:
	@echo Running unit tests
	$(GO) test -mod=vendor -race -v -tags unit $(GO_PACKAGES)

test-e2e:
	@echo Running e2e tests
	$(GO) test -mod=vendor -race -v -tags e2e $(GO_PACKAGES)

test-all:
	@echo Running all tests
	$(GO) test -mod=vendor -race -v -tags 'unit e2e' $(GO_PACKAGES)

check: gofmt govet

vendor:
	go mod vendor
	go mod tidy

mocks:
	mockgen -destination=mocks/client_mock.go -copyright_file=mocks/copyright.txt -package=mocks github.com/mattermost/mmctl/client Client

docs:
	rm -rf docs
	go run -mod=vendor mmctl.go docs
