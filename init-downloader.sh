#!/bin/sh

cvs -d :pserver:anonymous@gxp.cvs.sourceforge.net:/cvsroot/gxp co gxp3

wget --no-check-certificate https://raw.github.com/technomancy/leiningen/preview/bin/lein
chmod +x lein
