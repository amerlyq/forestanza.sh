.DEFAULT_GOAL := all
.SUFFIXES:

MWD := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))
AUX := $(MWD)/exe
RES := $(MWD)/res
export PATH := $(AUX):$(PATH)

# https://en.wikipedia.org/wiki/List_of_Re:Zero_-Starting_Life_in_Another_World-_episodes
URL ?= http://ncode.syosetu.com/n2267be
NAM ?= $(notdir $(URL))
O   ?= build
RNG ?= 117

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
$(O)/04-mtl-google/%.json
$(O)/05-fmt-fza/%.fza
$(O)/06-fmt-xhtml/%.xhtml
endef

dirnm = $(patsubst %/,%,$(dir $(1)))
stage = $(word $(1),$(CHAIN))
mkdir = $(call dirnm,$(call stage,$(1)))
targs = $(TARGS:%=$(call stage,$(1)))

all: $(call targs,6)
# all: $(TARGS:%=$(O)/04-mtl-baidu/%.json)

# DEV:(target) check:
# 	force TL for chapters -> sync damage/differences

$(O) $(foreach t,$(CHAIN),$(call dirnm,$t)): ; mkdir -p "$@"

$(O)/index.html: | $(O)
	fetch-one "$(URL)" "$@"

$(O)/index.urls: $(O)/index.html
	map-guard parse-hrefs "$(URL)" "$<" > "$@"

page = $(shell grep "/$$((10\#$*))$$" "$(word 1,$|)")

$(call targs,1): $(call stage,1) : | $(O)/index.urls $(call mkdir,1)
	fetch-one "$(page)" "$@"

$(call targs,2): $(call stage,2) : $(call stage,1) $(AUX)/parse-content | $(call mkdir,2)
	map-guard parse-content "$<" "$@"

$(call targs,3): $(call stage,3) : $(call stage,2) $(AUX)/text-split | $(call mkdir,3)
	map-guard text-split 42 "$<" "$@"

# NOTE: this must depend on all scripts in mtl/google/*
$(call targs,4): export LOG := $(O)/mtl-google.log
$(call targs,4): $(call stage,4) : $(call stage,3) $(AUX)/mtl-one | $(call mkdir,4)
	map-guard mtl-one "$(AUX)/mtl/google" "$<" "$@"

$(O)/04-mtl-baidu/%.json: export LOG=$(O)/mtl-baidu.log
$(O)/04-mtl-baidu/%.json :: $(O)/03-sentences/%.txt $(AUX)/mtl-one
	map-guard mtl-one "$(AUX)/mtl/baidu" "$<" "$@"

$(O)/04-mtl-yandex/%.json: export LOG=$(O)/mtl-yandex.log
$(O)/04-mtl-yandex/%.json :: $(O)/03-sentences/%.txt $(AUX)/mtl/yandex/mtl
	map-guard "$(AUX)"/mtl/yandex/mtl "$<" "$@"

$(O)/04-mtl-bing/%.json: export LOG=$(O)/mtl-bing.log
$(O)/04-mtl-bing/%.json :: $(O)/03-sentences/%.txt $(AUX)/mtl/bing/mtl
	map-guard "$(AUX)"/mtl/bing/mtl "$<" "$@"

$(O)/04-mtl-babylon/%.json: export LOG=$(O)/mtl-babylon.log
$(O)/04-mtl-babylon/%.json :: $(O)/03-sentences/%.txt $(AUX)/mtl-one
	map-guard mtl-one "$(AUX)/mtl/babylon" "$<" "$@"

$(O)/04-mtl-excite/%.json: export LOG=$(O)/mtl-excite.log
$(O)/04-mtl-excite/%.json :: $(O)/03-sentences/%.txt $(AUX)/mtl-one
	map-guard mtl-one "$(AUX)/mtl/excite" "$<" "$@"

$(O)/04-mtl-freesdl/%.json: export LOG=$(O)/mtl-freesdl.log
$(O)/04-mtl-freesdl/%.json :: $(O)/03-sentences/%.txt $(AUX)/mtl-one
	map-guard mtl-one "$(AUX)/mtl/freesdl" "$<" "$@"

$(call targs,5): $(call stage,5) : \
  $(O)/04-mtl-google/%.json \
  $(O)/04-mtl-yandex/%.json \
  $(O)/04-mtl-bing/%.json \
  $(O)/04-mtl-excite/%.json \
  $(O)/04-mtl-freesdl/%.json \
  $(AUX)/fmt-fza | $(call mkdir,5)
	map-guard 2 fmt-fza "$@" -- $(wordlist 1,5,$^)


# xhtml
res := color-theme.css scroll_pos.js
fza := $(dir $(call targs,6))/fza
$(fza)/%: $(RES)/xhtml/%
	@mkdir -p "$(call dirnm,$@)"
	cp -fT "$<" "$@"

.PHONY: xhtml/fza
xhtml/fza :: $(AUX)/fmt-xhtml $(res:%=$(fza)/%) ;

$(call targs,6): $(call stage,6) : $(call stage,5) xhtml/fza | $(call mkdir,6)
	map-guard fmt-xhtml "$(NAM)" "$<" "$@"
