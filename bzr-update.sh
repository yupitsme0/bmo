#!/bin/bash
echo "+ bzr pull --overwrite -rtag:current-production"
output=`bzr pull --overwrite -rtag:current-production 2>&1`
echo "$output"
echo "$output" | grep "Now on revision" | sed -e 's/Now on revision //' -e 's/\.$//' | xargs -i{} echo bzr pull --overwrite -r{} \# `date` >> `dirname $0`/cvs-update.log
contrib/fixperms.pl
