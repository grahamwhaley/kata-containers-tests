# Copyright (c) 2017-2018 Intel Corporation
#
# SPDX-License-Identifier: Apache-2.0

TARGET     := checkmetrics
PREFIX     := /usr
BINDIR     := $(PREFIX)/bin
SYSCONFDIR := /etc
DESTTARGET := $(BINDIR)/$(TARGET)
BASEFILE   := $(TARGET).toml
BASELINE   := baseline/$(BASEFILE)
DESTBASE   := $(SYSCONFDIR)/$(TARGET)/$(BASEFILE)

all:
	go build -ldflags "-X main.sysBaseFile=$(DESTBASE)" -o $(TARGET)

install:
	install -D $(TARGET) $(DESTTARGET)
	install -D $(BASELINE) $(DESTBASE)

clean:
	rm -f $(DESTTARGET)
	rm -rf $(SYSCONFDIR)/$(TARGET)

.PHONY: install clean
