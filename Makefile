default: all

MWD := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))
AUX := $(MWD)/exe
export PATH := $(AUX):$(PATH)

URL ?= http://ncode.syosetu.com/n2267be
O   ?= build
RNG ?= 1-2

MINMAX = 1 2
ifneq ($(wildcard $(O)/index.urls),)
  MINMAX = $(shell $(AUX)/get-minmax "$(O)/index.urls")
endif
# NOTE: Always derive from *.urls containing total available set
TARGS  = $(shell $(AUX)/get-range $(MINMAX) 03 -- "$(RNG)")

define CHAIN :=
$(O)/01-html/%.html
$(O)/02-content/%.txt
$(O)/03-sentences/%.txt
endef

dirnm = $(patsubst %/,%,$(dir $(1)))
stage = $(word $(1),$(CHAIN))
mkdir = $(call dirnm,$(call stage,$(1)))
targs = $(TARGS:%=$(call stage,$(1)))

all: $(call targs,3)

$(O) $(foreach t,$(CHAIN),$(call dirnm,$t)): ; mkdir -p "$@"

$(O)/index.html: | $(O)
	fetch-one "$(URL)" "$@"

$(O)/index.urls: $(O)/index.html
	parse-hrefs "$(URL)" "$<" > "$@"

page = $(shell grep "/$$((10\#$*))$$" "$(word 1,$|)")

$(call targs,1): $(call stage,1) : | $(O)/index.urls $(call mkdir,1)
	fetch-one "$(page)" "$@"

$(call targs,2): $(call stage,2) : $(call stage,1) $(AUX)/parse-content | $(call mkdir,2)
	parse-content "$<" "$@"

$(call targs,3): $(call stage,3) : $(call stage,2) $(AUX)/text-split | $(call mkdir,3)
	text-split 42 "$<" "$@"
