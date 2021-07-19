# Makefile
#
# bats-core manpages
#
RONN := ronn -W
PAGES := bats.1 bats.7
ORG := bats-core
MANUAL := 'Bash Automated Testing System'
ISOFMT := $(shell date -I)
RM := rm -f

.PHONY: all clean

all: $(PAGES)

bats.1: bats.1.ronn
	$(RONN) --date=$(ISOFMT) --manual=$(MANUAL) --organization=$(ORG) --roff $<

bats.7: bats.7.ronn
	$(RONN) --date=$(ISOFMT) --manual=$(MANUAL) --organization=$(ORG) --roff $<

clean:
	$(RM) $(PAGES)
