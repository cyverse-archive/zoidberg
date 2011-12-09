# Commands used in this makefile.
COFFEE = coffee -c
MKDIR  = mkdir -p
RM     = rm -rf
CP     = cp
NODE   = node

# Relevant directories.
BUILD = build
CONF  = conf
RUN   = run
SRC   = src

# Paths to important files.
MAIN_FILE = $(BUILD)/zoidberg.js
CONF_FILE = $(CONF)/zoidberg.conf
PID_FILE  = $(RUN)/zoidberg.pid

# Phony targets.
.PHONY: build clean test_run

# Build the application.
build:
	$(MKDIR) $(BUILD)
	$(CP) README.markdown $(BUILD)
	$(COFFEE) -o $(BUILD) $(SRC)/*.coffee

# Clean the application.
clean:
	$(RM) $(BUILD) $(RUN)

# Test-run the application.
test_run: build
	$(MKDIR) $(RUN)
	$(NODE) $(MAIN_FILE) $(CONF_FILE) $(PID_FILE)
