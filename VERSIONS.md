Versions
========

###Legend:
\+ Added feature

\* Improved / changed feature

\- Bug fixed

\! Known issue / missing feature

#### 0.6
------------
\* improved syntax: variable protection

\+ ability to use the script without bind with ldap administrator (without -a & -p parameters)

#### 0.5
------------
\* correction damain -> domain

\- delete '-x' parameter in ldapdearch 


#### 0.4
------------
\+ works now both with LDAP groups defined by objectClass posixGroup or groupOfNames.

\+ add parameter -t <LDAP group objectClass> (the type of group you want to sync, must be 'posixGroup' or 'groupOfNames')

\+ add auto-install of clean-email-list.py if needed


#### 0.3
------------

\- emails with numbers and _ are now supported


#### 0.2
------------
\+ add email notification support


#### 0.1
------------
Initial version