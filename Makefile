EMACS ?= emacs
ECSS_DIR ?= ../ecss
TP_DIR ?= ../tp
LOAD_PATH = -L . -L ../ebox -L $(ECSS_DIR) -L $(TP_DIR)
EBOX_NATIVE_RELEASE_DIR = $(shell $(EMACS) -Q --batch $(LOAD_PATH) \
	--eval '(setq native-comp-jit-compilation nil)' \
	-l ../ebox/ebox-native-reflow.el \
	--eval '(princ (expand-file-name (format "../ebox/native/target/%s/release/" (ebox-native-reflow--rust-target))))')

.PHONY: all compile test size-tests interaction-tests check checkdoc load performance performance-prepare \
	performance-evaluator clean

all: check

compile:
	rm -f *.elc tests/*.elc examples/*.elc
	$(EMACS) -Q --batch $(LOAD_PATH) \
		--eval '(setq load-prefer-newer t native-comp-jit-compilation nil byte-compile-error-on-warn t)' \
		--eval '(load-file "ebox-playground.el")' \
		--eval '(byte-compile-file "ebox-playground.el")' \
		--eval '(dolist (file (directory-files "examples" t)) (when (string-suffix-p ".el" file) (unless (byte-compile-file file) (error "Companion compilation failed: %s" file))))' \
		--eval '(byte-compile-file "scripts/ebox-playground-flex-resize-evaluator.el")'

test: compile
	$(EMACS) -Q --batch $(LOAD_PATH) \
		--eval '(setq load-prefer-newer t native-comp-jit-compilation nil)' \
		-l tests/ebox-playground-tests.el -l tests/ebox-playground-size-tests.el \
		-l tests/ebox-playground-interaction-tests.el -f ert-run-tests-batch-and-exit

interaction-tests: compile
	$(MAKE) -C ../ebox interaction-tests EMACS="$(EMACS)" ECSS_DIR="$(ECSS_DIR)" TP_DIR="$(TP_DIR)"
	$(EMACS) -Q --batch $(LOAD_PATH) \
		--eval '(setq load-prefer-newer t native-comp-jit-compilation nil)' \
		-l tests/ebox-playground-interaction-tests.el -f ert-run-tests-batch-and-exit

size-tests: compile
	$(MAKE) -C ../ebox size-tests EMACS="$(EMACS)" ECSS_DIR="$(ECSS_DIR)" TP_DIR="$(TP_DIR)"
	$(EMACS) -Q --batch $(LOAD_PATH) \
		--eval '(setq load-prefer-newer t native-comp-jit-compilation nil)' \
		-l tests/ebox-playground-size-tests.el -f ert-run-tests-batch-and-exit

load: compile
	$(EMACS) -Q --batch $(LOAD_PATH) \
		--eval '(setq native-comp-jit-compilation nil)' \
		--eval '(require (quote ebox-playground))' \
		--eval '(princ "ebox-playground load OK\n")'

performance:
	$(MAKE) performance-prepare EMACS="$(EMACS)" ECSS_DIR="$(ECSS_DIR)" TP_DIR="$(TP_DIR)"
	$(MAKE) performance-evaluator EMACS="$(EMACS)" ECSS_DIR="$(ECSS_DIR)" TP_DIR="$(TP_DIR)"

performance-prepare:
	$(MAKE) -C $(ECSS_DIR) compile EMACS="$(EMACS)"
	$(MAKE) -C $(TP_DIR) compile EMACS="$(EMACS)"
	$(MAKE) -C ../ebox compile EMACS="$(EMACS)" ECSS_DIR="$(ECSS_DIR)" TP_DIR="$(TP_DIR)"
	$(MAKE) compile EMACS="$(EMACS)" ECSS_DIR="$(ECSS_DIR)" TP_DIR="$(TP_DIR)"
	$(MAKE) -C ../ebox native-build EMACS="$(EMACS)" ECSS_DIR="$(ECSS_DIR)" TP_DIR="$(TP_DIR)"

performance-evaluator:
	EBOX_NATIVE_REFLOW_MODULE_PATH="$(EBOX_NATIVE_RELEASE_DIR)" \
	EMACS="$(EMACS)" ./scripts/flex-resize-evaluator.sh

checkdoc:
	$(EMACS) -Q --batch --eval '(progn (require (quote checkdoc)) (dolist (directory (quote ("." "examples"))) (dolist (file (directory-files directory t)) (when (string-suffix-p ".el" file) (checkdoc-file file)))))'

check: checkdoc compile test

clean:
	rm -f *.elc tests/*.elc examples/*.elc
