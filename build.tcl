#!/usr/bin/tclsh

set arch "noarch"
set base "tcl-gremlin-0.3"

set var2 [list git clone https://github.com/ray2501/tcl-gremlin.git $base]
exec >@stdout 2>@stderr {*}$var2

cd $base

set var2 [list git checkout e573b7735a113c66d8f6c6bf5c0bda5692a707d5]
exec >@stdout 2>@stderr {*}$var2

set var2 [list git reset --hard]
exec >@stdout 2>@stderr {*}$var2

file delete -force .git

cd ..

set var2 [list tar czvf ${base}.tar.gz $base]
exec >@stdout 2>@stderr {*}$var2

if {[file exists build]} {
    file delete -force build
}

file mkdir build/BUILD build/RPMS build/SOURCES build/SPECS build/SRPMS
file copy -force $base.tar.gz build/SOURCES

set buildit [list rpmbuild --target $arch --define "_topdir [pwd]/build" -bb tcl-gremlin.spec]
exec >@stdout 2>@stderr {*}$buildit

# Remove our source code
file delete -force $base
file delete -force $base.tar.gz
