if test $(id -u ) != 0 ; then
    echo non-root
    exit 
fi

echo "Checking lastest versions..."
dialog=$(whereis -b dialog | cut -d":" -f 2 | sed 's/ //g')
if test -f "$dialog" ; then
	DIR_TOR=$(dialog --title "Tor Version" --menu "Select:" 0 0 0 $(for i in $(curl --silent https://dist.torproject.org/ | grep -e "compressed.gif" | grep -v alpha  | cut -d"\"" -f6 | sed 's/.tar.gz//g'| sort -r); do echo $i $i ; done) 3>&1 1>&2 2>&3)
	echo -$DIR_TOR
	if ! test "$DIR_TOR" ; then
	    echo "Exiting..."
	    exit
	fi
else
	DIR_TOR=$(for i in $(curl --silent https://dist.torproject.org/ | grep -e "compressed.gif" | grep -v alpha  | cut -d"\"" -f6); do VER=$i ; done ; echo $VER | sed 's/.tar.gz//g')	
fi 


if test -f "$DIR_TOR.tar.gz" ; then
    rm -f $DIR_TOR.tar.gz
fi 
if test -d "$DIR_TOR" ; then
    rm -Rf $DIR_TOR/*
fi 

wget https://dist.torproject.org/$DIR_TOR.tar.gz
if ! test -f "$DIR_TOR.tar.gz" ; then
    echo "Not downloaded!"
    exit
fi

tar -zxvf $DIR_TOR.tar.gz
if test "$DIR_TOR.tar.gz" ; then
    rm -f $DIR_TOR.tar.gz
fi 
sudo apt-get update
sudo apt-get install -y build-essential libevent-dev libssl-dev zlib1g-dev

libevent=$(dpkg -L libevent-dev | sort | uniq | grep -e .a$ | awk -F/ '{ $NF = "" ; print }' | tr " " / | uniq)
libssl=$(dpkg -L libssl-dev | sort | uniq | grep -e .a$ | awk -F/ '{ $NF = "" ; print }' | tr " " / | uniq)
zlib1g=$(dpkg -L zlib1g-dev | sort | uniq | grep -e .a$ | awk -F/ '{ $NF = "" ; print }' | tr " " / | uniq)
echo $libevent $libssl $zlib1g
if ! test -d "$libevent" || ! test -d "$libssl" || ! test -d "$zlib1g" ; then
    echo "Libraries not found!"
    exit
fi    

cd $DIR_TOR

#tor_openssl_any_linkable=yes
#tor_cv_library_openssl_dir=$tor_trydir
#tor_cv_library_openssl_linker_option=$tor_tryextra
l_linkable=$(cat configure | grep -B 10 -n -e "tor_openssl_any_linkable=yes" | grep -e "if test" | cut -d- -f1)
l_buildable=$(cat configure | grep -B 10 -n -e "tor_cv_library_openssl_dir=$tor_trydir" | grep -e "if test" | cut -d- -f1)
l_runnable=$(cat configure | grep -B 10 -n -e "tor_cv_library_openssl_linker_option=$tor_tryextra" | grep -e "if test" | cut -d- -f1)

cat > configure.patch <<- EOP
@@ -$l_linkable +$l_linkable @@
+    linkable=yes ; if test "\$linkable" = yes; then
-    if test "\$linkable" = yes; then
@@ -$l_buildable +$l_buildable @@
+      buildable=yes ; if test "\$buildable" = yes; then
-      if test "\$buildable" = yes; then
@@ -$l_runnable +$l_runnable @@
+     runnable=yes ; if test "\$runnable" = yes; then
-     if test "\$runnable" = yes; then
EOP
patch configure configure.patch

./configure --enable-static-openssl --with-openssl-dir=$libssl --enable-static-libevent --with-libevent-dir=$libevent --enable-static-zlib --with-zlib-dir=$zlib1g --enable-static-tor 
make
tor_app=$(find src/ -iname tor)
if [ "$(ldd $tor_app | wc -l)" -eq "1" ] ; then
    echo cp -y $tor_app ../$DIR_TOR-$(uname -p)
    cp -f $tor_app ../$DIR_TOR-$(uname -p)
fi
cd ..
rm -Rf $DIR_TOR/*
