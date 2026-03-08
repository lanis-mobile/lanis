Name:           lanis
Version:        %{app_version}
Release:        1%{?dist}
Summary:        App for the Hessian school portal (SPH)
License:        GPL-3.0-only
URL:            https://github.com/lanis-mobile/lanis-mobile
BuildArch:      x86_64

# Fedora package names; adjust for other RPM-based distros
Requires:       gtk3
Requires:       libsecret
Requires:       webkit2gtk4.1

%description
Lanis Mobile is an unofficial app for the Hessian school portal (SPH),
used by 35,000+ students and teachers daily across schools in Hesse, Germany.

%install
# Install the pre-built Flutter bundle to /opt/lanis
mkdir -p %{buildroot}/opt/%{name}
cp -r %{_sourcedir}/bundle/. %{buildroot}/opt/%{name}/
# Ensure the binary is executable (cp may not preserve the bit from CI artifacts)
chmod 755 %{buildroot}/opt/%{name}/%{name}

# Launcher wrapper so the binary (and its rpath $ORIGIN/lib) resolves correctly
mkdir -p %{buildroot}%{_bindir}
cat > %{buildroot}%{_bindir}/%{name} << 'LAUNCHER'
#!/bin/sh
exec /opt/lanis/lanis "$@"
LAUNCHER
chmod 755 %{buildroot}%{_bindir}/%{name}

# Desktop entry
mkdir -p %{buildroot}%{_datadir}/applications
cat > %{buildroot}%{_datadir}/applications/%{name}.desktop << 'DESKTOP'
[Desktop Entry]
Name=Lanis Mobile
Comment=App for the Hessian school portal (SPH)
Exec=lanis
Icon=/opt/lanis/data/flutter_assets/assets/icon.png
Terminal=false
Type=Application
Categories=Education;Network;
StartupWMClass=lanis
DESKTOP

%files
/opt/%{name}/
%{_bindir}/%{name}
%{_datadir}/applications/%{name}.desktop

%changelog
* %(date "+%a %b %d %Y") CI Build <ci@github.com> - %{app_version}-1
- Automated build
