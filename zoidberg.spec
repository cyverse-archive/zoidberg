Summary: Tool Integration Backend Service
Name: iplant-zoidberg
Version: 0.2.0
Release: 4
Epoch: 0
Group: Applications
BuildRoot: %{_tmppath}/%{name}-%{version}-buildroot
License: Foo
Requires(pre): shadow-utils
Provides: iplant-zoidberg
Requires: node >= 0.4.0
Requires: iplant-nodejs-libs >= v0.4.0-3
Requires: iplant-node-launch >= 0.0.1-1
Source0: %{name}-%{version}.tar.gz

%description
Tool Integration Backend Service

%pre
getent group iplant > /dev/null || groupadd -r iplant
getent passwd iplant > /dev/null || useradd -r -g iplant -d /home/iplant -s /sbin/nologin -c "User for the iPlant services." iplant
exit 0

%prep
%setup -q
mkdir -p $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT/usr/local/lib/node/iplant-zoidberg
mkdir -p $RPM_BUILD_ROOT/usr/local/bin
mkdir -p $RPM_BUILD_ROOT/var/log/iplant-zoidberg
mkdir -p $RPM_BUILD_ROOT/etc/init.d/

%build
make

%install
install -m755 build/* $RPM_BUILD_ROOT/usr/local/lib/node/iplant-zoidberg
install -m755 src/iplant-zoidberg $RPM_BUILD_ROOT/etc/init.d/
install -m755 conf/zoidberg.conf $RPM_BUILD_ROOT/etc/iplant-zoidberg.conf
install -m755 scripts/import-tool.pl $RPM_BUILD_ROOT/usr/local/bin/

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(0775,iplant,iplant)
/usr/local/lib/node/iplant-zoidberg
/usr/local/bin/import-tool.pl
%config /var/log/iplant-zoidberg
/etc/init.d/iplant-zoidberg
%config /etc/iplant-zoidberg.conf
