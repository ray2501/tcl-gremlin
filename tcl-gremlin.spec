#
# openSUSE RPM spec for tcl-gremlin package
#

%define buildroot %{_tmppath}/%{name}
%define tarname gremlin

Name:          tcl-gremlin
Summary:       Gremlin Server driver for Tcl 
Version:       0.2
Release:       0
License:       MIT
Group:         Development/Libraries/Tcl
Source:        %{name}-%{version}.tar.gz
URL:           https://github.com/ray2501/tcl-gremlin
Requires:      tcl >= 8.6
Requires:      tcllib 
Requires:      rl_json
Requires:      tls
BuildArch:     noarch
BuildRoot:     %{buildroot}

%description
It is a Gremlin Server driver for Tcl, and supports PLAIN 
SASL (username/password) authentication mechanism.

%prep
%setup -q -n %{name}-%{version}

%build

%install
mkdir -p %{buildroot}%_datadir/tcl/%{tarname}%{version}
cp %{tarname}/*.tcl %{buildroot}%_datadir/tcl/%{tarname}%{version}

%clean
rm -rf %buildroot

%files
%defattr(-,root,root)
%doc LICENSE README.md
%_datadir/tcl

