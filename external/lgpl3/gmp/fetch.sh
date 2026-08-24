#!/bin/sh

# Make sure we're in our directory (i.e., where this shell script is)
echo $0
cd `dirname $0`

# Configure fetch method
URL="https://ftp.gnu.org/gnu/gmp/gmp-5.1.3.tar.bz2"
BACKUP_URL="https://mirrors.kernel.org/gnu/gmp/gmp-5.1.3.tar.bz2"
FETCH=ftp
which curl >/dev/null
if [ $? -eq 0 ]; then
	FETCH="curl -O -f"
fi

# Fetch sources if not available
if [ ! -d dist ];
then
        if [ ! -f gmp-5.1.3.tar.bz2 ]; then
		$FETCH $URL
		if [ $? -ne 0 ]; then
			$FETCH $BACKUP_URL
		fi
	fi

	tar -oxjf gmp-5.1.3.tar.bz2
	mv gmp-5.1.3 dist && \
	cd dist && \
	cat ../patches/* |patch -p1
fi

