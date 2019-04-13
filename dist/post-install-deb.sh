#!/bin/bash
ln -sf /usr/local/diogenes/diogenes /usr/local/bin/diogenes
if [ -e /usr/bin/update-menus ]
then
    /usr/bin/update-menus
fi

