EMACS ?= emacs
ECSS_DIR ?= ../ecss
TP_DIR ?= ../tp
LOAD_PATH = -L . -L ../ebox -L $(ECSS_DIR) -L $(TP_DIR)

.PHONY: all compile test check checkdoc load performance-evaluator clean

all: check

compile:
	rm -f *.elc tests/*.elc
	$(EMACS) -Q --batch $(LOAD_PATH) --eval '(setq load-prefer-newer t)' \
		--eval '(load-file "ebox-playground.el")' \
		--eval '(byte-compile-file "ebox-playground.el")'

test: compile
	$(EMACS) -Q --batch $(LOAD_PATH) --eval '(setq load-prefer-newer t)' \
		-l tests/ebox-playground-tests.el -f ert-run-tests-batch-and-exit

load: compile
	$(EMACS) -Q --batch $(LOAD_PATH) --eval '(require (quote ebox-playground))' \
		--eval '(princ "ebox-playground load OK\n")'

performance-evaluator:
	EMACS="$(EMACS)" ./scripts/flex-resize-evaluator.sh

checkdoc:
	$(EMACS) -Q --batch --eval '(progn (require (quote checkdoc)) (dolist (file (directory-files "." t)) (when (string-suffix-p ".el" file) (checkdoc-file file))))'

check: checkdoc compile test

clean:
	rm -f *.elc tests/*.elc
