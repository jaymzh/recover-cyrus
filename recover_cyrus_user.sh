#!/bin/bash

# This script was originally written by Kai Lindenberg <kai@ldbg.de>
# in https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=1037346
#
# Added to git with some minor fixes by Phil Dibowitz <phil@ipom.com>
# to allow collaborative editing.

# the cyrus spool dir
SPOOLDIR=/var/spool/cyrus/mail/

usage() {
    cat <<EOF
Usage: $0 <userhashpath>

Where <userhashpath> is something like 'k/user/kai' or 'p/user/phil', i.e.
the relative path fo the user under the /var/spool/cyrus/mail.
EOF
}

if [[ -z "$1" ]] || ! [[ $1 =~ / ]]; then
    usage
    exit
fi

# first argument is relative spool dir of user e.g.: $ scriptname k/user/kai
# extract user and reformat for cm command of cyadmin
# k/user/kai -> user.kai 		
USER=$(echo $1 | cut -d/ -f 2,3 | tr "/" ".")	 

# find all mailboxes of user and reformat for cm
MBXLIST=$(find $SPOOLDIR$1 -type d|cut -d/ -f 1-8 --complement|tr "/ " "._")

# generate a script for cyradm to create new mailboxes
for MBX in $MBXLIST; do
   echo cm $USER.$MBX
done > creatembx.cyradm
echo starting shell to examine the situation
echo creatembx.cyradm created to feed cyradm
echo please review the file and then:
echo '   cat creatembx.cyradm | cyradm --user cyrus localhost'
echo 'once complete, continue with "exit"'

# start a shell to check cyradmin script and general situation
bash

# generate a script to hard-link to the new location
for MBX in $MBXLIST; do
    # get path of created mailbox
    NEWPATH=$(/usr/lib/cyrus/bin/mbpath $USER.$MBX)
    # get original path of mailbox
    OLDPATH=$SPOOLDIR$1/${MBX//\./\/}
    # link it
    echo ln -f ${OLDPATH//_/\\ }/\* $NEWPATH
done | tee linkmbx.bash
echo linkmbx.bash created, please review before executing and then run it
echo manual work:
echo 1. might be too many argument, review output
echo 2. main inbox not linked, create inbox_recovered and link the contents
# That would look something like:
# cm user.<whatever>.inbox_recovered
# cd `mbpath user.<whatever>.inbox_recovered`
# ls -f /var/spool/cyrus/mail/<hashletter>/user/<whatever>/ | xargs -I{} ln -f '/var/spool/cyrus/mail/<hashletter>/user/<whatever>/{}' .
