EMACS ?= emacs
LOAD_PATH = -L . -L ../emacs-box

.PHONY: all compile test check checkdoc load clean

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

checkdoc:
	$(EMACS) -Q --batch --eval '(progn (require (quote checkdoc)) (dolist (file (directory-files "." t)) (when (string-suffix-p ".el" file) (checkdoc-file file))))'

check: checkdoc compile test

clean:
	rm -f *.elc tests/*.elc
