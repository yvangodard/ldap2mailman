#! /usr/bin/python

# Thanks to http://pagode.tuxfamily.org/doku.php?id=linux:mailman-ldap

import sys
import email.Utils
import re

class EmailAddressError(Exception):
    """Base class for email address validation errors."""
    pass

class MMBadEmailError(EmailAddressError):
    """Email address is invalid (empty string or not fully qualified)."""
    pass

class MMHostileAddress(EmailAddressError):
    """Email address has potentially hostile characters in it."""
    pass

_badchars = re.compile(r'[][()<>|;^,/\200-\377]')

# This takes an email address, and returns a tuple containing (user,host)
def ParseEmail(email):
    user = None
    domain = None
    email = email.lower()
    at_sign = email.find('@')
    if at_sign < 1:
        return email, None
    user = email[:at_sign]
    rest = email[at_sign+1:]
    domain = rest.split('.')
    return user, domain

def ValidateEmail(s):
    """Verify that the an email address isn't grossly evil."""
    # Pretty minimal, cheesy check.  We could do better...
    if not s or s.count(' ') > 0:
        raise MMBadEmailError
    if _badchars.search(s) or s[0] == '-':
        raise MMHostileAddress, s
    user, domain_parts = ParseEmail(s)
    # This means local, unqualified addresses, are no allowed
    if not domain_parts:
        raise MMBadEmailError, s
    if len(domain_parts) < 2:
        raise MMBadEmailError, s

def main():
    if len(sys.argv) < 2:
        sys.exit(1)
    filename = sys.argv[1]
    try:
        fp = open(filename)
    except IOError, (code, msg):
        usage(1, _('Cannot read address file: %(filename)s: %(msg)s'))
    try:
        filemembers = fp.readlines()
    finally:
        fp.close()

    for addr in filemembers:
        try:
            ValidateEmail(addr)
        except Exception,e:
            continue
        sys.stdout.write(addr)

main()