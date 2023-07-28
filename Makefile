##
# SafeOauth
#
# @safeoath.sh
# @version 1.0
PROG=safeoauth.sh
DEST=/usr/local/bin
PROGDEST=safeoauth

install:
		install -m 755 "$(PROG)" "$(DEST)/$(PROGDEST)"
		@echo "$(PROGDEST) has been installed\nYou can now run it."

uninstall:
		rm -f "$(DEST)/$(PROGDEST)"

.PHONY: install uninstall
# end
