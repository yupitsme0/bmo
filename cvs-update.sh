#!/bin/sh
#
# Keep a record of all cvs updates made from a given directory.
#
# Later, if changes need to be backed out, look at the log file
# and run the cvs command with the date that you want to back
# out to. (Probably the second to last entry).

#DATE=`date +%e/%m/%Y\ %k:%M:%S\ %Z`
DATE=`date`
BRANCH="-rBUGZILLA-3_0-BRANCH"
#BRANCH="-A"
echo "========================================="
echo "== BACKING OUT EXISTING CUSTOMIZATIONS =="
echo "========================================="
ssh dm-bugstage01 cat /root/huge-bmo-patch12-makeup.diff | patch -p0 -R
ssh dm-bugstage01 cat /root/huge-bmo-patch12.diff | patch -p0 -R
echo
echo
echo "========================================="
echo "== CVS UPDATING TO $BRANCH =="
echo "========================================="
COMMAND="cvs -q update -d -P $BRANCH -D" 
echo $COMMAND \"$DATE\" >> cvs-update.log
$COMMAND "$DATE" -C
echo
echo
echo "====================================="
echo "== APPLYING UPDATED CUSTOMIZATIONS =="
echo "====================================="
ssh dm-bugstage01 cat /root/huge-bmo-patch13.diff | patch -p0
ssh dm-bugstage01 cat /root/huge-bmo-patch13+mailqueue.diff | patch -p0
sed -i -e 's/Options +Includes//' .htaccess
find . -name '.#*' -exec echo -n "deleting " \; -print -exec rm {} \;
find . -name \*~ -exec echo -n "deleting " \; -print -exec rm {} \;
find . -name \*.orig -exec echo -n "deleting " \; -print -exec rm {} \;
find . -name \*.rej -exec echo -n "deleting " \; -print -exec rm {} \;
rsync -av --delete -e ssh dm-bugstage01:/root/landfill.bugzilla.org/template/en/custom/ template/en/custom
rsync -av --delete -e ssh dm-bugstage01:/root/landfill.bugzilla.org/skins/custom/ skins/custom
echo
echo
echo "==========================="
echo "== RUNNING UPDATE SCRIPT =="
echo "==========================="
perl checksetup.pl

# we'll stop twice just because apache is funky sometimes.
service httpd stop
service httpd stop
service httpd start
# sample log file
#cvs update -P -D "11/04/2000 20:22:08 PDT"
#cvs update -P -D "11/05/2000 20:22:22 PDT"
#cvs update -P -D "11/07/2000 20:26:29 PDT"
#cvs update -P -D "11/08/2000 20:27:10 PDT"
