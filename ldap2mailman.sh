#! /bin/bash

#------------------------------------------#
#              LDAP2Mailman                #
#------------------------------------------#
#                                          #
# Synchronize LDAP Group to Mailman liste  #
#   	      (one way only)               #
#                                          #
#              Yvan Godard                 #
#          godardyvan@gmail.com            #
#                                          #
#     Version 0.8 -- january, 10 2015      #
#             Under Licence                #
#     Creative Commons 4.0 BY NC SA        #
#                                          #
#          http://goo.gl/lriKvn            #
#                                          #
#------------------------------------------#

# Variables initialisation
VERSION="LDAP2Mailman v0.8 - 2015, Yvan Godard [godardyvan@gmail.com]"
help="no"
SCRIPT_DIR=$(dirname $0)
SCRIPT_NAME=$(basename $0)
LIST_MEMBERS=$(mktemp /tmp/ldap2mailman_email_list_members.XXXXX)
LIST_SENDERS=$(mktemp /tmp/ldap2mailman_email_list_senders.XXXXX)
LIST_USERS=$(mktemp /tmp/ldap2mailman_email_list_users.XXXXX)
LIST_CLEAN_MEMBERS=$(mktemp /tmp/ldap2mailman_email_list_clean_members.XXXXX)
LIST_CLEAN_SENDERS=$(mktemp /tmp/ldap2mailman_email_list_clean_senders.XXXXX)
ACTUAL_LIST_CONFIG=$(mktemp /tmp/ldap2mailman_actual_list_config.XXXXX)
NEW_LIST_CONFIG=$(mktemp /tmp/ldap2mailman_new_list_config.XXXXX)
NEW_LIST_CONFIG_TEMP=$(mktemp /tmp/ldap2mailman_new_list_config_temp.XXXXX)
URL="ldap://127.0.0.1"
DN_USER_BRANCH="cn=users"
MAILMAN_OPTIONS="-a=no -d=no -w=no -g=no"
MAILMAN_BIN="/usr/lib/mailman/bin"
EMAIL_REPORT="nomail"
EMAIL_LEVEL=0
LOG="/var/log/ldap2mailman.log"
LOG_ACTIVE=0
LOG_TEMP=$(mktemp /tmp/ldap2mailman_log.XXXXX)
WITH_LDAP_BIND="no"

help () {
	echo -e "$VERSION\n"
	echo -e "This tool is designed to synchronize email addresses from an LDAP group to a Mailman list."
	echo -e "It works both with LDAP groups defined by objectClass posixGroup or groupOfNames."
	echo -e "Mailman list must first be created in Mailman before using this tool."
	echo -e "\nDisclamer:"
	echo -e "This tool is provide without any support and guarantee."
	echo -e "\nSynopsis:"
	echo -e "./$SCRIPT_NAME [-h] | -d <base namespace> -t <LDAP group objectClass> -g <relative DN of LDAP group> -l <Mailman list name>" 
	echo -e "                  [-s <LDAP server>] [-a <LDAP admin UID>] [-p <LDAP admin password>]"
	echo -e "                  [-u <relative DN of user banch>] [-D <main domain>]"
	echo -e "                  [-m <Mailman sync options>] [-b <Mailman bin path>]"
	echo -e "                  [-e <email report option>] [-E <email address>] [-j <log file>]"
	echo -e "\n\t-h:                             prints this help then exit"
	echo -e "\nMandatory options:"
	echo -e "\t-d <base namespace>:              the base DN for each LDAP entry (e.g.: 'dc=server,dc=office,dc=com')"
	echo -e "\t-t <LDAP group objectClass>:      the type of group you want to sync, must be 'posixGroup' or 'groupOfNames'"	
	echo -e "\t-g <relative DN of LDAP group>:   the relative DN of the LDAP group to sync to Mailman list (e.g.: 'cn=mygroup,cn=groups' or 'cn=mygroup,ou=lists')"
	echo -e "\t-l <Mailman list name>:           the name of the existing list to populate on Mailman"
	echo -e "\nOptional options:"
	echo -e "\t-s <LDAP server>:                 the LDAP server URL (default: '${URL}')"
	echo -e "\t-a <LDAP admin UID>:              LDAP administrator UID, if bind is needed to access LDAP (e.g.: 'diradmin')"
	echo -e "\t-p <LDAP admin password>:         the password of the LDAP administrator (asked if missing)"
	echo -e "\t-u <relative DN of user banch>:   the relative DN of the LDAP branch that contains the users (e.g.: 'cn=allusers', default: '${DN_USER_BRANCH}')"
	echo -e "\t-D <main domain>:                 main domain if the user has multiple email addresses registered in the LDAP (e.g.: 'mydomain.fr')"
	echo -e "\t-m <Mailman sync options>:        are the parameters passed to mailman's sync_members command (default: '${MAILMAN_OPTIONS}')"
	echo -e "\t-b <Mailman bin path>:            path to the bin directory of your Mailman installation (default: '${MAILMAN_BIN}')"
	echo -e "\t-e <email report option>:         settings for sending a report by email, must be 'onerror', 'forcemail' or 'nomail' (default: '${EMAIL_REPORT}')"
	echo -e "\t-E <email address>:               email address to send the report (must be filled if '-e forcemail' or '-e onerror' options is used)"
	echo -e "\t-j <log file>:                    enables logging instead of standard output. Specify an argument for the full path to the log file"
	echo -e "\t                                  (e.g.: '${LOG}') or use 'default' (${LOG})"
	exit 0
}

error () {
	echo -e "\n*** Error ***"
	echo -e ${1}
	echo -e "\n"${VERSION}
	alldone 1
}

function alldone () {
	# Remove temp files
	[ -f ${LIST_USERS} ] && rm ${LIST_USERS}
	[ -f ${LIST_MEMBERS} ] && rm ${LIST_MEMBERS}
	[ -f ${LIST_CLEAN_MEMBERS} ] && rm ${LIST_CLEAN_MEMBERS}
	[ -f ${LIST_SENDERS} ] && rm ${LIST_SENDERS}
	[ -f ${LIST_CLEAN_SENDERS} ] && rm ${LIST_CLEAN_SENDERS}
	[ -f ${ACTUAL_LIST_CONFIG} ] && rm ${ACTUAL_LIST_CONFIG}
	[ -f ${NEW_LIST_CONFIG} ] && rm ${NEW_LIST_CONFIG}
	[ -f ${NEW_LIST_CONFIG_TEMP} ] && rm ${NEW_LIST_CONFIG_TEMP}
	# Redirect standard outpout
	exec 1>&6 6>&-
	# Logging if needed 
	[ ${LOG_ACTIVE} -eq 1 ] && cat ${LOG_TEMP} >> ${LOG}
	# Print current log to standard outpout
	[ ${LOG_ACTIVE} -ne 1 ] && cat ${LOG_TEMP}
	[ ${EMAIL_LEVEL} -ne 0 ] && [ ${1} -ne 0 ] && cat ${LOG_TEMP} | mail -s "[ERROR : ldap2mailman.sh] list ${LISTNAME} (LDAP group ${LDAPGROUP},${DNBASE})" ${EMAIL_ADDRESS}
	[ ${EMAIL_LEVEL} -eq 2 ] && [ ${1} -eq 0 ] && cat ${LOG_TEMP} | mail -s "[OK : ldap2mailman.sh] list ${LISTNAME} (LDAP group $LDAPGROUP,$DNBASE)" ${EMAIL_ADDRESS}
	rm ${LOG_TEMP}
	exit ${1}
}

# Fonction utilisée plus tard pour les résultats de requêtes LDAP encodées en base64
function base64decode () {
	echo ${1} | grep :: > /dev/null 2>&1
	if [ $? -eq 0 ] 
		then
		VALUE=$(echo ${1} | grep :: | awk '{print $2}' | openssl enc -base64 -d )
		ATTRIBUTE=$(echo ${1} | grep :: | awk '{print $1}' | awk 'sub( ".$", "" )' )
		echo "${VALUE}"
	else
		VALUE=$(echo ${1} | grep : | awk '{print $2}')
		echo "${VALUE}"
	fi
}

optsCount=0

while getopts "hd:a:p:t:g:l:s:u:D:m:b:e:E:j:" OPTION
do
	case "$OPTION" in
		h)	help="yes"
						;;
		d)	DNBASE=${OPTARG}
			let optsCount=$optsCount+1
						;;
		a)	LDAPADMIN_UID=${OPTARG}
			[[ ${LDAPADMIN_UID} != "" ]] && WITH_LDAP_BIND="yes"
						;;
		p)	PASS=${OPTARG}
                        ;;
        t)	LDAPGROUP_OBJECTCLASS=${OPTARG}
			let optsCount=$optsCount+1
                        ;;
		g)	LDAPGROUP=${OPTARG}
			let optsCount=$optsCount+1
                        ;;
        l)	LISTNAME=${OPTARG}
			let optsCount=$optsCount+1
                        ;;
	    s) 	URL=${OPTARG}
						;;
		u) 	DN_USER_BRANCH=${OPTARG}
						;;
		D)	DOMAIN=${OPTARG}
                        ;;
        m)	MAILMAN_OPTIONS=${OPTARG}
                        ;; 
        b)	MAILMAN_BIN=${OPTARG}
                        ;;
        e)	EMAIL_REPORT=${OPTARG}
                        ;;                             
        E)	EMAIL_ADDRESS=${OPTARG}
                        ;;
        j)	[ ${OPTARG} != "default" ] && LOG=${OPTARG}
			LOG_ACTIVE=1
                        ;;
	esac
done

if [[ ${optsCount} != "4" ]]
	then
        help
        alldone 1
fi

if [[ ${help} = "yes" ]]
	then
	help
fi

if [[ ${WITH_LDAP_BIND} = "yes" ]] && [[ ${PASS} = "" ]]
	then
	echo "Password for ${LDAPADMIN_UID},${DN_USER_BRANCH},${DNBASE}?" 
	read -s PASS
fi

# Redirect standard outpout to temp file
exec 6>&1
exec >> ${LOG_TEMP}

# Start temp log file
echo -e "\n****************************** `date` ******************************\n"
echo -e "$0 started for Mailmman list ${LISTNAME}\n(LDAP group ${LDAPGROUP},${DNBASE})\n"

# Test of sending email parameter and check the consistency of the parameter email address
if [[ ${EMAIL_REPORT} = "forcemail" ]]
	then
	EMAIL_LEVEL=2
	if [[ -z $EMAIL_ADDRESS ]]
		then
		echo -e "You use option '-e ${EMAIL_REPORT}' but you have not entered any email info.\n\t-> We continue the process without sending email."
		EMAIL_LEVEL=0
	else
		echo "${EMAIL_ADDRESS}" | grep '^[a-zA-Z0-9._-]*@[a-zA-Z0-9._-]*\.[a-zA-Z0-9._-]*$' > /dev/null 2>&1
		if [ $? -ne 0 ]
			then
    		echo -e "This address '${EMAIL_ADDRESS}' does not seem valid.\n\t-> We continue the process without sending email."
    		EMAIL_LEVEL=0
    	fi
    fi
elif [[ ${EMAIL_REPORT} = "onerror" ]]
	then
	EMAIL_LEVEL=1
	if [[ -z $EMAIL_ADDRESS ]]
		then
		echo -e "You use option '-e ${EMAIL_REPORT}' but you have not entered any email info.\n\t-> We continue the process without sending email."
		EMAIL_LEVEL=0
	else
		echo "${EMAIL_ADDRESS}" | grep '^[a-zA-Z0-9._-]*@[a-zA-Z0-9._-]*\.[a-zA-Z0-9._-]*$' > /dev/null 2>&1
		if [ $? -ne 0 ]
			then	
    		echo -e "This address '${EMAIL_ADDRESS}' does not seem valid.\n\t-> We continue the process without sending email."
    		EMAIL_LEVEL=0
    	fi
    fi
elif [[ ${EMAIL_REPORT} != "nomail" ]]
	then
	echo -e "\nOption '-e ${EMAIL_REPORT}' is not valid (must be: 'onerror', 'forcemail' or 'nomail').\n\t-> We continue the process without sending email."
	EMAIL_LEVEL=0
elif [[ ${EMAIL_REPORT} = "nomail" ]]
	then
	EMAIL_LEVEL=0
fi

# Verification of LDAPGROUP_OBJECTCLASS parameter
[[ ${LDAPGROUP_OBJECTCLASS} != "posixGroup" ]] && [[ ${LDAPGROUP_OBJECTCLASS} != "groupOfNames" ]] && error "Parameter '-t ${LDAPGROUP_OBJECTCLASS}' is not correct.\n-t must be 'posixGroup' or 'groupOfNames'"

# Verification of presence of the Mailman list to populate
echo -e "\nTest for the presence of Mailman list"
if [ -f ${MAILMAN_BIN}/list_lists ] 
	then  
	${MAILMAN_BIN}/list_lists | grep -i ${LISTNAME} > /dev/null 2>&1
	if [ $? -ne 0 ] 
		then
		error "Mailman list you try to sync does not exist.\nPlease create the list before re-launching this tool."
	else
		echo -e "\t-> Mailman list seems correct."
	fi
else
	error "${MAILMAN_BIN}/list_lists is missing.\Check your Mailman installation."
fi

# Verification of LDAP_SERVER_URL parameter
[[ ${URL} = "" ]] && echo -e "You used option '-s' but you have not entered any LDAP url. Wi'll try to continue with url 'ldap://127.0.0.1'" && URL="ldap://127.0.0.1"

# LDAP connection test
echo -e "\nConnecting LDAP at $URL ...\n"

[[ ${WITH_LDAP_BIND} = "yes" ]] && LDAP_COMMAND_BEGIN="ldapsearch -LLL -H ${URL} -b ${LDAPGROUP},${DNBASE} -D uid=${LDAPADMIN_UID},${DN_USER_BRANCH},${DNBASE} -w ${PASS}"
[[ ${WITH_LDAP_BIND} = "no" ]] && LDAP_COMMAND_BEGIN="ldapsearch -LLL -H ${URL} -b ${LDAPGROUP},${DNBASE} -x"

${LDAP_COMMAND_BEGIN} > /dev/null 2>&1
if [ $? -ne 0 ]
	then 
	error "Error connecting to LDAP server.\nPlease verify your URL and user/pass (if needed)."
fi

# Test if user list is not empty
if [[ ${LDAPGROUP_OBJECTCLASS} = "groupOfNames" ]] 
	then
	if [[ -z $(${LDAP_COMMAND_BEGIN} member | grep member: | awk '{print $2}' | awk -F',' '{print $1}') ]] 
		then 
		error "User list on LDAP group is empty!"
	else
		${LDAP_COMMAND_BEGIN} member | grep member: | awk '{print $2}' | awk -F',' '{print $1}' >> ${LIST_USERS}
	fi
elif [[ ${LDAPGROUP_OBJECTCLASS} = "posixGroup" ]]
	then
	if [[ -z $(${LDAP_COMMAND_BEGIN} memberUid | grep memberUid: | awk '{print $2}' | sed -e 's/^./uid=&/g') ]] 
		then 
		error "User list on LDAP group is empty"
	else
		${LDAP_COMMAND_BEGIN} memberUid | grep memberUid: | awk '{print $2}' | sed -e 's/^./uid=&/g' >> ${LIST_USERS}
	fi
fi

# Processing each user
for USER in $(cat $LIST_USERS)
do
	PRINCIPAL_EMAIL=""
    echo "- Processing user: ${USER}"
    EMAILS=$(mktemp /tmp/mailman_emails.XXXXX)
    EMAILS_CLEAN_TEMP=$(mktemp /tmp/mailman_emails_clean_tmp.XXXXX)
    EMAILS_CLEAN=$(mktemp /tmp/mailman_emails_clean.XXXXX)
    SECONDARY_EMAILS=$(mktemp /tmp/mailman_secondry_emails.XXXXX)
    [[ ${WITH_LDAP_BIND} = "yes" ]] && ldapsearch -LLL -H ${URL} -D uid=${LDAPADMIN_UID},${DN_USER_BRANCH},${DNBASE} -b ${DN_USER_BRANCH},${DNBASE} -w ${PASS} ${USER} mail | grep ^mail: >> ${EMAILS}
    [[ ${WITH_LDAP_BIND} = "no" ]] && ldapsearch -LLL -H ${URL} -b ${DN_USER_BRANCH},${DNBASE} -x ${USER} mail | grep mail: >> ${EMAILS}
    # Correction to support LDIF splitted lines, thanks to Guillaume Bougard (gbougard@pkg.fr)
	perl -n -e 'chomp ; print "\n" unless (substr($_,0,1) eq " " || !defined($lines)); $_ =~ s/^\s+// ; print $_ ; $lines++;' -i "${EMAILS}"
    # Decode if Base64 encoding is used
	OLDIFS=$IFS; IFS=$'\n'
	for LINE in $(cat ${EMAILS})
	do
		base64decode $LINE >> ${EMAILS_CLEAN_TEMP}
	done
	IFS=$OLDIFS
	# test if address are correct
	for LINE in $(cat ${EMAILS_CLEAN_TEMP})
	do
		echo "${LINE}" | grep '^[a-zA-Z0-9._-]*@[a-zA-Z0-9._-]*\.[a-zA-Z0-9._-]*$' > /dev/null 2>&1
		if [ $? -ne 0 ]; then
			echo "\tThis address '${LINE}' does not seem valid.\n\t-> We do not use this address."
		else
			echo "${LINE}" >> ${EMAILS_CLEAN}
		fi
	done
    LINES_NUMBER=$(cat ${EMAILS_CLEAN} | grep "." | wc -l) 
    echo -e "\tNumber of lines/emails: ${LINES_NUMBER}"
    # If no email -> skip
    if [[ -z $(cat ${EMAILS_CLEAN}) ]] 
    	then
    	echo -e "\tPas d'email"
    # If only one mail, keep this mail
    elif [ ${LINES_NUMBER} -eq 1 ]
    	then
    	PRINCIPAL_EMAIL=$(head -n 1 ${EMAILS_CLEAN})
    	echo -e "\tOnly one email address: ${PRINCIPAL_EMAIL}"
    # If multiples mails
	elif [ ${LINES_NUMBER} -gt 1 ]
    	then
    	echo -e "\tMultiples email addresses found."

    	if [[ -z ${DOMAIN} ]]
    		# No main domain defined -> keep first mail
    		then
    		PRINCIPAL_EMAIL=$(head -n 1 ${EMAILS_CLEAN})
	    	echo -e "\t-> Keep first one: ${PRINCIPAL_EMAIL}"
	    else
	    	# Main domain defined -> search first mail in domain
	    	cat ${EMAILS_CLEAN} | grep ${DOMAIN} > /dev/null 2>&1
	    	if [ $? -ne 0 ]
	    		then
	    		PRINCIPAL_EMAIL=$(head -n 1 ${EMAILS_CLEAN})
	    		echo -e "\t-> No email containing the main domain defined, we keep the first user email: ${PRINCIPAL_EMAIL}"		
	    	else
	    		PRINCIPAL_EMAIL=$(cat ${EMAILS_CLEAN} | grep ${DOMAIN} | head -n 1)
	    		echo -e "\t-> Email with main domain found: ${PRINCIPAL_EMAIL}"
	    	fi
	    fi
	    # Creating list of address authorized to send email
	    cat ${EMAILS_CLEAN} | grep -v ${PRINCIPAL_EMAIL} >> ${SECONDARY_EMAILS}
	    echo -e "\tAllowed senders list:"
	    echo -e "\t-> $(cat ${SECONDARY_EMAILS} | perl -p -e 's/\n/ - /g' | awk 'sub( "...$", "" )')"
    fi
    # Add address to allowed senders list
    echo ${PRINCIPAL_EMAIL} >> ${LIST_MEMBERS}
    [[ ! -z $(cat ${SECONDARY_EMAILS}) ]] && cat ${SECONDARY_EMAILS} >> ${LIST_SENDERS}
    # Remove email temp files 
    rm ${EMAILS}
    rm ${EMAILS_CLEAN}
    rm ${EMAILS_CLEAN_TEMP}
    rm ${SECONDARY_EMAILS}
    echo ""
done

echo -e "*************\nFor information, LIST_MEMBERS:"
cat ${LIST_MEMBERS}
echo "*************"
if [ -f ${LIST_SENDERS} ] && [[ ! -z $(cat ${LIST_SENDERS}) ]] 
	then
	echo "For information, LIST_SENDERS:"
	cat ${LIST_SENDERS}
	echo "*************"
fi

# Installing $SCRIPT_DIR/clean-email-list.py if needed
if [ ! -f ${SCRIPT_DIR}/clean-email-list.py ] 
	then
	echo -e "\nInstalling ${SCRIPT_DIR}/clean-email-list.py..."
	wget -O ${SCRIPT_DIR}/clean-email-list.py --no-check-certificate https://raw.github.com/yvangodard/ldap2mailman/master/clean-email-list.py 
	if [ $? -ne 0 ] 
		then
		ERROR_MESSAGE=$(echo $?)
		error "Error while downloading https://raw.github.com/yvangodard/ldap2mailman/master/clean-email-list.py.\n${ERROR_MESSAGE}.\nYou need to solve this before re-launching this tool."
	else
		echo -e "\t-> Installation OK"
		chmod +x ${SCRIPT_DIR}/clean-email-list.py
	fi
fi

echo -e "\nProcessing the lists with ${SCRIPT_DIR}/clean-email-list.py"
if [ -f ${SCRIPT_DIR}/clean-email-list.py ] 
	then 
	${SCRIPT_DIR}/clean-email-list.py ${LIST_MEMBERS} > ${LIST_CLEAN_MEMBERS}
	[ -f ${LIST_SENDERS} ] && [[ ! -z $(cat ${LIST_SENDERS}) ]] && ${SCRIPT_DIR}/clean-email-list.py ${LIST_SENDERS} > ${LIST_CLEAN_SENDERS}
else
	error "${SCRIPT_DIR}/clean-email-list.py missing.\nTry to install it manually before re-launching this tool.\nGo to https://github.com/yvangodard/ldap2mailman."
fi

echo -e "\n*************"
echo "For information, LIST_CLEAN_MEMBERS:"
cat ${LIST_CLEAN_MEMBERS}
echo "*************"
if [ -f ${LIST_CLEAN_SENDERS} ] && [[ ! -z $(cat ${LIST_CLEAN_SENDERS}) ]]
	then
	echo "For information, LIST_CLEAN_SENDERS:"
	cat ${LIST_CLEAN_SENDERS}
	echo "*************"
fi

# Sync with Mailman
echo -e "\nList processing with command: ${MAILMAN_BIN}/sync_members ${MAILMAN_OPTIONS} -f ${LIST_CLEAN_MEMBERS} ${LISTNAME}"
if [ -f ${MAILMAN_BIN}/sync_members ] 
	then 
	echo -e "Result of the command: "
	${MAILMAN_BIN}/sync_members ${MAILMAN_OPTIONS} -f ${LIST_CLEAN_MEMBERS} ${LISTNAME}
	if [ $? -ne 0 ] 
		then
		ERROR_MESSAGE1=$(echo $?)
		error "Error with the command: ${MAILMAN_BIN}/sync_members.\n${ERROR_MESSAGE1}.\nPlease try solving this with Mailman's man."
	fi
else
	error "${MAILMAN_BIN}/sync_members.\nCheck your Mailman installation."
fi

if [ -f ${MAILMAN_BIN}/config_list ]
	then
	# If list is not empty we add allowed senders (variable accept_these_nonmembers = [])
	if [ -f ${LIST_CLEAN_SENDERS} ] && [[ ! -z $(cat ${LIST_CLEAN_SENDERS}) ]]
		then
		echo ""
		# Saving actual configuration of the list
		${MAILMAN_BIN}/config_list -o ${ACTUAL_LIST_CONFIG} ${LISTNAME}
		# Checking if there is already some allowed non members
		grep "accept_these_nonmembers = \['" ${ACTUAL_LIST_CONFIG} > /dev/null 2>&1
		if [ $? -ne 0 ] 
			then
			echo "No old list of secondary emails detected in the variable 'accept_these_nonmembers' in the Mailman list"
		else
			echo "Saving emails actually set in variable 'accept_these_nonmembers' in the Mailman list:"
			LIST=$(grep "accept_these_nonmembers = " ${ACTUAL_LIST_CONFIG} | sed -e 's/.*\[\(.*\)\].*/\1/' | sed "s/,/\n/g" | sed "s/ //g" | sed "s/'//g")
			echo ${LIST} | perl -p -e 's/ / - /g'
			for OLD_ADDRESS in ${LIST}
			do
				echo ${OLD_ADDRESS} >> ${LIST_CLEAN_SENDERS}
			done
		fi
		NEW_LIST_SENDERS=$(cat ${LIST_CLEAN_SENDERS} | grep '.' | sed '/^$/d' | awk '!x[$0]++')
		echo "accept_these_nonmembers = [" > ${NEW_LIST_CONFIG_TEMP}
		for NEW_ADDRESS in ${NEW_LIST_SENDERS} 
		do
			echo "'${NEW_ADDRESS}', " >> ${NEW_LIST_CONFIG_TEMP}
		done
		echo "]" >> ${NEW_LIST_CONFIG_TEMP}
		echo -e "\t-> New config:"
		cat ${NEW_LIST_CONFIG_TEMP} | perl -p -e 's/\n//g' > ${NEW_LIST_CONFIG}
		cat ${NEW_LIST_CONFIG}
		echo -e "\nImporting new emails list in the variable 'accept_these_nonmembers' in the Mailman list"
		${MAILMAN_BIN}/config_list -i ${NEW_LIST_CONFIG} ${LISTNAME}
		if [ $? -ne 0 ] 
			then
			ERROR_MESSAGE=$(echo $?)
			error "Error while running command: ${MAILMAN_BIN}/config_list -i ${NEW_LIST_CONFIG} ${LISTNAME}.\n${ERROR_MESSAGE}."
		else
			echo -e "\t-> Import OK"
		fi
	fi
else
	echo ""
	error "Error while running command: ${MAILMAN_BIN}/config_list.\nPlease try solving this with Mailman's man or check your Mailman installation"
fi

echo ""

echo "****************************** FINAL RESULT ******************************"
echo -e "$0 finished for Mailmman list ${LISTNAME}\n(LDAP group ${LDAPGROUP},${DNBASE})"

alldone 0