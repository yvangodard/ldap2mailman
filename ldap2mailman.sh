#! /bin/bash
#----------------------------------------
#          	LDAP2Mailman
#
# Synchronise une branche LDAP vers avec
#	   	  une liste Mailman
#
#             Yvan Godard 
#        godardyvan@gmail.com
#
#	Version 0.3 -- 6 décembre 2013
#         Soumis à la licence 
#   Creative Commons 4.0 BY NC SA
#
#         http://goo.gl/lriKvn
#----------------------------------------

VERSION="LDAP2Mailman v0.3 -- 2013, Yvan Godard [godardyvan@gmail.com]"
help="no"
SCRIPT_NAME=$(basename $0)
SCRIPT_DIR=$(dirname $0)
LIST_MEMBERS=$(mktemp /tmp/ldap2mailman_email_list_members.XXXXX)
LIST_SENDERS=$(mktemp /tmp/ldap2mailman_email_list_senders.XXXXX)
LIST_CLEAN_MEMBERS=$(mktemp /tmp/ldap2mailman_email_list_clean_members.XXXXX)
LIST_CLEAN_SENDERS=$(mktemp /tmp/ldap2mailman_email_list_clean_senders.XXXXX)
ACTUAL_LIST_CONFIG=$(mktemp /tmp/ldap2mailman_actual_list_config.XXXXX)
NEW_LIST_CONFIG=$(mktemp /tmp/ldap2mailman_new_list_config.XXXXX)
NEW_LIST_CONFIG_TEMP=$(mktemp /tmp/ldap2mailman_new_list_config_temp.XXXXX)
URL="ldap://127.0.0.1"
OPTIONS_MAILMAN="-a=no -d=no -w=no -g=no"
MAILMAN_BIN="/usr/lib/mailman/bin"
EMAIL_REPORT="nomail"
EMAIL_LEVEL=0
LOG="/var/log/ldap2mailman.log"
LOG_ACTIVE=0
LOG_TEMP=$(mktemp /tmp/ldap2mailman_log.XXXXX)

help () {
	echo -e "$VERSION\n"
	echo -e "Cet outil est destiné à assurer la synchronisation des adresses emails d'un groupe LDAP (branche) avec une liste Mailman."
	echo -e "La liste Mailman doit être préalablement créée sous Mailman avant d'utiliser cet outil."
	echo -e "\nDégagement de responsabilité :"
	echo -e "Cet outil est mis à disposition gracieuse sans aucun support ou aucune garantie."
	echo -e "L'auteur ne peut être tenu pour responsables des dommages causés à votre système d'information en cas d'utilisation."
	echo -e "\nUsage :"
	echo -e "\t$0 [-h] | -d <Racine LDAP> -a <DN relatif Admin LDAP> -p <Mot de passe Admin LDAP> -g <DN relatif du groupe> -l <Liste Mailman>"
	echo -e "\t         [-s <Serveur LDAP>] [-D <Domaine principal>] [-m <Options Liste Mailman>] [-b <Chemin bin Mailman>] [-e <Option rapport email>] [-E <Adresse email>] [-j <Fichier Log>]"
	echo -e "avec :"
	echo -e "\t-h:                               affiche l'aide et quitte"
	echo -e "\t*** Paramètres obligatoires ***"
	echo -e "\t-d <Racine LDAP> :                DN de (ex : dc=serveur,dc=office,dc=com)"
	echo -e "\t-a <DN relatif Admin LDAP> :      DN relatif de l'administrateur LDAP (ex : uid=diradmin,cn=users)"
	echo -e "\t-p <Mot de passe Admin LDAP> :    Mot de passe de l'administrateur LDAP (sera demandé si manquant)"
	echo -e "\t-g <DN relatif du groupe> :       DN relatif du groupe LDAP utilisé comme source (ex : cn=mongroupe,cn=groups)"
	echo -e "\t-l <Liste Mailman> :              Nom de la liste existante sur Mailman"
	echo -e "\t*** Paramètres optionnels ***"
	echo -e "\t-s <Serveur LDAP> :               URL du serveur LDAP [$URL]"
	echo -e "\t-D <Domaine principal> :          Domaine email principal prioritaire si l'utilisateur dispose de plusieurs adresses email enregistrées dans le LDAP (ex : mondomaine.fr)"
	echo -e "\t-m <Options Liste Mailman> :      Paramètres passés pour l'exécution de la commande Mailman 'sync_members' [$OPTIONS_MAILMAN]"
	echo -e "\t-b <Chemin bin Mailman> :         Chemin vers vers le répertoire Bin de votre installation Mailman [$MAILMAN_BIN]"
	echo -e "\t-e <Option rapport email> :       Paramètres pour l'envoi d'un rapport par email : [$EMAIL_REPORT] (ex : onerror|forcemail|nomail)"
	echo -e "\t-E <Adresse email> :              Adresse du rapport par email (obligatoire si -e forcemail ou -e onerror)"
	echo -e "\t-j <Fichier Log> :                Active la journalisation à place de la sortie standard. Préciser en argument le chemin complet vers le fichier Log [$LOG] ou utiliser la valeur 'default' pour $LOG"
	exit 0
}

error () {
	echo -e "*** Erreur ***"
	echo -e ${1}
	echo -e "\n"${VERSION}
	alldone 1
}

alldone () {
	exec 1>&6 6>&-
	[ $LOG_ACTIVE -eq 1 ] && cat $LOG_TEMP >> $LOG
	[ $LOG_ACTIVE -ne 1 ] && cat $LOG_TEMP
	[ $EMAIL_LEVEL -ne 0 ] && [ $1 -ne 0 ] && cat $LOG_TEMP | mail -s "[ERROR : ldap2mailman.sh] liste $LISTNAME (groupe LDAP $LDAPGROUP,$DNBASE)" ${EMAIL_ADRESSE}
	[ $EMAIL_LEVEL -eq 2 ] && [ $1 -eq 0 ] && cat $LOG_TEMP | mail -s "[OK : ldap2mailman.sh] liste $LISTNAME (groupe LDAP $LDAPGROUP,$DNBASE)" ${EMAIL_ADRESSE}
	rm $LOG_TEMP
	exit ${1}
}

optsCount=0

while getopts "hd:a:p:g:l:s:D:m:b:e:E:j:" OPTION
do
	case "$OPTION" in
		h)	help="yes"
						;;
		d)	DNBASE=${OPTARG}
			let optsCount=$optsCount+1
						;;
		a)	LDAPADMIN=${OPTARG}
			let optsCount=$optsCount+1
						;;
		p)	PASS=${OPTARG}
                        ;;
		g)	LDAPGROUP=${OPTARG}
			let optsCount=$optsCount+1
                        ;;
        l)	LISTNAME=${OPTARG}
			let optsCount=$optsCount+1
                        ;;
	    s) 	URL=${OPTARG}
						;;
		D)	DOMAIN=${OPTARG}
                        ;;
        m)	OPTIONS_MAILMAN=${OPTARG}
                        ;; 
        b)	MAILMAN_BIN=${OPTARG}
                        ;;
        e)	EMAIL_REPORT=${OPTARG}
                        ;;                             
        E)	EMAIL_ADRESSE=${OPTARG}
                        ;;
        j)	[ $OPTARG != "default" ] && LOG=${OPTARG}
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

if [[ ${PASS} = "" ]]
	then
	echo "Entrez le mot de passe pour $LDAPADMIN,$DNBASE :" 
	read -s PASS
fi

exec 6>&1
exec >> $LOG_TEMP

echo ""
echo "****************************** `date` ******************************"
echo ""
echo "$0 lancé pour la liste $LISTNAME" 
echo "(groupe LDAP $LDAPGROUP,$DNBASE)"

[ -f $LIST_MEMBERS ] && rm $LIST_MEMBERS
[ -f $LIST_CLEAN_MEMBERS ] && rm $LIST_CLEAN_MEMBERS
[ -f $LIST_SENDERS ] && rm $LIST_SENDERS
[ -f $LIST_CLEAN_SENDERS ] && rm $LIST_CLEAN_SENDERS
[ -f $ACTUAL_LIST_CONFIG ] && rm $ACTUAL_LIST_CONFIG
[ -f $NEW_LIST_CONFIG ] && rm $NEW_LIST_CONFIG
[ -f $NEW_LIST_CONFIG_TEMP ] && rm $NEW_LIST_CONFIG_TEMP

if [[ ${EMAIL_REPORT} = "forcemail" ]]
	then
	EMAIL_LEVEL=2
	if [[ -z $EMAIL_ADRESSE ]]
		then
		echo ""
		echo -e "Vous utilisez l'option -e $EMAIL_REPORT mais vous n'avez pas entré d'adressse email.\n\t-> Nous continuons le processus sans envoi d'email."
		EMAIL_LEVEL=0
	else
		echo "${EMAIL_ADRESSE}" | grep '^[a-zA-Z0-9]*@[a-zA-Z0-9]*\.[a-zA-Z0-9]*$' > /dev/null 2>&1
		if [ $? -ne 0 ]
			then
			echo ""
    		echo -e "L'adresse d'envoi des rapport ($EMAIL_ADRESSE) ne semble pas valide.\n\t-> Nous continuons le processus sans envoi d'email."
    		EMAIL_LEVEL=0
    	fi
    fi
elif [[ ${EMAIL_REPORT} = "onerror" ]]
	then
	EMAIL_LEVEL=1
	if [[ -z $EMAIL_ADRESSE ]]
		then
		echo ""
		echo -e "Vous utilisez l'option -e $EMAIL_REPORT mais vous n'avez pas entré d'adressse email.\n\t-> Nous continuons le processus sans envoi d'email."
		EMAIL_LEVEL=0
	else
		echo "${EMAIL_ADRESSE}" | grep '^[a-zA-Z0-9]*@[a-zA-Z0-9]*\.[a-zA-Z0-9]*$' > /dev/null 2>&1
		if [ $? -ne 0 ]
			then	
			echo ""
    		echo -e "L'adresse d'envoi des rapport ($EMAIL_ADRESSE) ne semble pas valide.\n\t-> Nous continuons le processus sans envoi d'email."
    		EMAIL_LEVEL=0
    	fi
    fi
elif [[ ${EMAIL_REPORT} != "nomail" ]]
	then
	echo ""
	echo -e "L'option -e $EMAIL_REPORT est invalide (valeurs possibles : onerror|forcemail|nomail).\n\t-> Nous continuons le processus sans envoi d'email."
	EMAIL_LEVEL=0
elif [[ ${EMAIL_REPORT} = "nomail" ]]
	then
	EMAIL_LEVEL=0
fi

echo ""
echo "Test de la présence de la liste Mailman"
if [ -f $MAILMAN_BIN/list_lists ] 
	then  
	$MAILMAN_BIN/list_lists | grep -i $LISTNAME > /dev/null 2>&1
	if [ $? -ne 0 ] 
		then
		error "La liste Mailman que vous essayez de synchroniser n'existe pas.\nMerci de créer préalablement la liste avant de relancer cette commande."
	else
		echo -e "\t-> La liste Mailman semble correcte."
	fi
else
	error "$MAILMAN_BIN/list_lists absent.\nMerci de vérifier votre installation Mailman."
fi

echo ""
echo "Recherche LDAP sur $URL ..."
echo ""
ldapsearch -LLL -H $URL -D $LDAPADMIN,$DNBASE -b $LDAPGROUP,$DNBASE -w $PASS memberUid
# Test de la connexion au LDAP
ldapsearch -LLL -H $URL -D $LDAPADMIN,$DNBASE -b $LDAPGROUP,$DNBASE -w $PASS > /dev/null 2>&1
if [ $? -ne 0 ]
	then 
	error "Erreur de connexion au serveur LDAP.\nVérifiez votre URL et les identifiants de connexion."
fi
# Test si la liste des usagers n'est pas vide
if [[ -z $(ldapsearch -LLL -H $URL -D $LDAPADMIN,$DNBASE -b $LDAPGROUP,$DNBASE -w $PASS member | grep member: | awk '{print $2}' | awk -F',' '{ print $1 }') ]] 
	then 
	error "Liste d'usagers du groupe LDAP vide."
fi
# Traitement des utilisateurs
for USER in `ldapsearch -LLL -H $URL -D $LDAPADMIN,$DNBASE -b $LDAPGROUP,$DNBASE -w $PASS member | grep member: | awk '{print $2}' | awk -F',' '{ print $1 }'`
do
	EMAIL_PRINCIPAL=""
    echo "- Traitement de l'usager : $USER"
    EMAILS=$(mktemp /tmp/mailman_emails.XXXXX)
    EMAILS_SECONDAIRES=$(mktemp /tmp/mailman_email_secondaires.XXXXX)
    ldapsearch -LLL -H $URL -D $LDAPADMIN,$DNBASE -b "cn=users,"$DNBASE -w $PASS -x $USER mail | grep mail: | awk '{print $2}' | grep '.' | sed '/^$/d' | awk '!x[$0]++' >> $EMAILS
    NOMBRE_DE_LIGNES=$(cat $EMAILS | grep "." | wc -l) 
    echo -e "\tNombre de lignes emails : $NOMBRE_DE_LIGNES"
    # Cas 1 : pas d'email -> skip
    if [[ -z $(cat $EMAILS) ]] 
    	then
    	echo -e "\tPas d'email"
    # Cas 2 : un seul email -> on garde celui-là
    elif [ $NOMBRE_DE_LIGNES -eq 1 ]
    	then
    	EMAIL_PRINCIPAL=$(head -n 1 $EMAILS)
    	echo -e "\tUn seul email : $EMAIL_PRINCIPAL"
    # Cas 3 : plusieurs emails
	elif [ $NOMBRE_DE_LIGNES -gt 1 ]
    	then
    	echo -e "\tPlusieurs emails ont été trouvés pour cet utilisateur."

    	if [[ -z $DOMAIN ]]
    		# Pas de domaine principal défini, on garde le premier email
    		then
    		EMAIL_PRINCIPAL=$(head -n 1 $EMAILS)
	    	echo -e "\t-> Nous gardons le premier email de l'utilisateur : $EMAIL_PRINCIPAL"
	    else
	    	# Paramètre domaine principal défini : on cherche si un email contient le domaine principal 
	    	cat $EMAILS | grep $DOMAIN > /dev/null 2>&1
	    	if [ $? -ne 0 ]
	    		then
	    		EMAIL_PRINCIPAL=$(head -n 1 $EMAILS)
	    		echo -e "\t-> Pas d'email contenant le domaine, nous gardons le premier email de l'utilisateur : $EMAIL_PRINCIPAL"		
	    	else
	    		EMAIL_PRINCIPAL=$(cat $EMAILS | grep $DOMAIN | head -n 1)
	    		echo -e "\t-> Email contenant le domaine, nous gardons l'adresse : $EMAIL_PRINCIPAL"
	    	fi
	    fi
	    # Création d'une liste des personnes autorisées à envoyer
	    cat $EMAILS | grep -v ${EMAIL_PRINCIPAL} >> $EMAILS_SECONDAIRES
	    echo -e "\tListe des expéditeurs également autorisés :"
	    # cat $EMAILS_SECONDAIRES
	    echo -e "\t-> $(cat $EMAILS_SECONDAIRES | perl -p -e 's/\n/ - /g')"
    fi
    # Ajout de l'adresse à la liste et des emails secondaires à la liste des senders
    echo $EMAIL_PRINCIPAL >> $LIST_MEMBERS
    [[ -z $(cat $EMAILS_SECONDAIRES) ]] || cat $EMAILS_SECONDAIRES >> $LIST_SENDERS
    # Suppression des fichiers temporaire d'emails
    rm $EMAILS
    rm $EMAILS_SECONDAIRES
    echo ""
done

echo "*************"
echo "Pour info, LIST_MEMBERS :"
cat $LIST_MEMBERS
echo "*************"
if [ -f $LIST_SENDERS ] && [[ ! -z $(cat $LIST_SENDERS) ]] 
	then
	echo "Pour info, LIST_SENDERS :"
	cat $LIST_SENDERS
	echo "*************"
fi

echo ""
echo "Traitement des listes avec le script $SCRIPT_DIR/clean-email-list.py"
if [ -f $SCRIPT_DIR/clean-email-list.py ] 
	then 
	$SCRIPT_DIR/clean-email-list.py $LIST_MEMBERS > $LIST_CLEAN_MEMBERS
	[ -f $LIST_SENDERS ] && [[ ! -z $(cat $LIST_SENDERS) ]] && $SCRIPT_DIR/clean-email-list.py $LIST_SENDERS > $LIST_CLEAN_SENDERS
else
	error "$SCRIPT_DIR/clean-email-list.py absent.\nMerci d'installer ce sous-script.\nVous pouvez le trouver à l'adresse https://github.com/yvangodard/ldap2mailman."
fi
echo ""

echo "*************"
echo "Pour info, LIST_CLEAN_MEMBERS :"
cat $LIST_CLEAN_MEMBERS
echo "*************"
if [ -f $LIST_CLEAN_SENDERS ] && [[ ! -z $(cat $LIST_CLEAN_SENDERS) ]]
	then
	echo "Pour info, LIST_CLEAN_SENDERS :"
	cat $LIST_CLEAN_SENDERS
	echo "*************"
fi

# Lancement de la commande synchronisation de la liste
echo ""
echo "Traiement de la liste avec la commande $MAILMAN_BIN/sync_members $OPTIONS_MAILMAN -f $LIST_CLEAN_MEMBERS $LISTNAME"
if [ -f $MAILMAN_BIN/sync_members ] 
	then 
	echo -e "Résultat de la commande : "
	$MAILMAN_BIN/sync_members $OPTIONS_MAILMAN -f $LIST_CLEAN_MEMBERS $LISTNAME
	if [ $? -ne 0 ] 
		then
		ERROR_MESSAGE=$(echo $?)
		error "Problème lors de l'utilisation de la commande $MAILMAN_BIN/sync_members.\n$ERROR_MESSAGE.\nUtilisez le man de Mailman pour corriger ce problème."
	fi
else
	error "$MAILMAN_BIN/sync_members absent.\nMerci de vérifier votre installation Mailman."
fi

if [ -f $MAILMAN_BIN/config_list ]
	then
	# Si la liste senders n'est pas vide nous allons ajouter ces emails à la configuration de la liste Mailman (variable accept_these_nonmembers = [])
	if [ -f $LIST_CLEAN_SENDERS ] && [[ ! -z $(cat $LIST_CLEAN_SENDERS) ]]
		then
		echo ""
		# Récupérons le contenu actuel de la configuration de la liste
		$MAILMAN_BIN/config_list -o $ACTUAL_LIST_CONFIG $LISTNAME
		# Vérifions si il y a déjà des emails 
		grep "accept_these_nonmembers = \['" $ACTUAL_LIST_CONFIG > /dev/null 2>&1
		if [ $? -ne 0 ] 
			then
			# Pas d'ancienne liste
			echo "Pas d'ancienne liste d'emails secondaires détectée dans la variable 'accept_these_nonmembers' de la liste Mailman"
		else
			# Il y a une ancienne liste
			echo "Récupération des anciens emails autorisés à poster sur la liste (variable 'accept_these_nonmembers' de la liste Mailman) :"
			LIST=$(grep "accept_these_nonmembers = " $ACTUAL_LIST_CONFIG | sed -e 's/.*\[\(.*\)\].*/\1/' | sed "s/,/\n/g" | sed "s/ //g" | sed "s/'//g")
			echo $LIST | perl -p -e 's/ / - /g'
			for OLD_ADDRESS in $LIST
			do
				echo $OLD_ADDRESS >> $LIST_CLEAN_SENDERS
			done
		fi
		NEW_LIST_SENDERS=$(cat $LIST_CLEAN_SENDERS | grep '.' | sed '/^$/d' | awk '!x[$0]++')
		echo "accept_these_nonmembers = [" > $NEW_LIST_CONFIG_TEMP
		for NEW_ADDRESS in $NEW_LIST_SENDERS 
		do
			echo "'$NEW_ADDRESS', " >> $NEW_LIST_CONFIG_TEMP
		done
		echo "]" >> $NEW_LIST_CONFIG_TEMP
		echo -e "\t-> Nouvelle configuration :"
		cat $NEW_LIST_CONFIG_TEMP | perl -p -e 's/\n//g' > $NEW_LIST_CONFIG
		cat $NEW_LIST_CONFIG
		echo ""
		echo "Import de la liste des emails secondaires dans la variable 'accept_these_nonmembers' de la liste Mailman"
		$MAILMAN_BIN/config_list -i $NEW_LIST_CONFIG $LISTNAME
		if [ $? -ne 0 ] 
			then
			ERROR_MESSAGE=$(echo $?)
			error "Problème lors de l'utilisation de la commande $MAILMAN_BIN/config_list -i $NEW_LIST_CONFIG $LISTNAME.\n$ERROR_MESSAGE."
		else
			echo -e "\t-> Import OK"
		fi
	fi
else
	echo ""
	error "Problème lors de l'utilisation de la commande $MAILMAN_BIN/config_list.\nUtilisez le man de Mailman pour corriger ce problème ou vérifiez votre installation."
fi

echo ""

[ -f $LIST_MEMBERS ] && rm $LIST_MEMBERS
[ -f $LIST_CLEAN_MEMBERS ] && rm $LIST_CLEAN_MEMBERS
[ -f $LIST_SENDERS ] && rm $LIST_SENDERS
[ -f $LIST_CLEAN_SENDERS ] && rm $LIST_CLEAN_SENDERS
[ -f $ACTUAL_LIST_CONFIG ] && rm $ACTUAL_LIST_CONFIG
[ -f $NEW_LIST_CONFIG ] && rm $NEW_LIST_CONFIG
[ -f $NEW_LIST_CONFIG_TEMP ] && rm $NEW_LIST_CONFIG_TEMP

echo "****************************** RÉSULTAT FINAL ******************************"
echo "$0 terminé pour la liste $LISTNAME (groupe LDAP $LDAPGROUP,$DNBASE)"

alldone 0