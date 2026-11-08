%{!?dope_notes_version:%global dope_notes_version 0.1.0}
%{!?dope_notes_release:%global dope_notes_release 1}
%{!?odin_bin:%global odin_bin odin}

Name:           dope-notes
Version:        %{dope_notes_version}
Release:        %{dope_notes_release}%{?dist}
Summary:        Desktop Markdown notes editor
License:        MIT
URL:            https://github.com/mtnyoni/dope-notes
Source0:        %{url}/archive/v%{version}/%{name}-%{version}.tar.gz

ExclusiveArch:  x86_64

BuildRequires:  clang
BuildRequires:  desktop-file-utils
BuildRequires:  gcc
BuildRequires:  freetype-devel
BuildRequires:  pkgconfig(sdl3)
BuildRequires:  pkgconfig(sdl3-image)


%description
Dope Notes is a desktop Markdown notes editor built with Odin, SDL3, Clay,
and FreeType.

%prep
%autosetup -n %{name}-%{version}

%build
bash font/build.sh
mkdir -p odin_shared
ln -sfnT ../shared/clay/bindings/odin/clay-odin odin_shared/clay
%{odin_bin} build . \
    -define:DOPE_NOTES_DEV=false \
    -collection:shared=./odin_shared \
    -out:dope-notes \
    -no-rpath \
    -reloc-mode:pic \
    '-extra-linker-flags:-pie' \
    -debug \
    -o:speed

%install
install -Dm0755 dope-notes %{buildroot}%{_bindir}/dope-notes
install -Dm0644 packaging/dope-notes.desktop \
    %{buildroot}%{_datadir}/applications/dope-notes.desktop
install -Dm0644 font/Roboto-Regular.ttf \
    %{buildroot}%{_datadir}/dope-notes/font/Roboto-Regular.ttf
install -d %{buildroot}%{_datadir}/dope-notes/assets/icons
install -m0644 assets/icons/*.png \
    %{buildroot}%{_datadir}/dope-notes/assets/icons/
install -Dm0644 packaging/icons/dope-notes.png \
    %{buildroot}%{_datadir}/icons/hicolor/512x512/apps/dope-notes.png

%check
desktop-file-validate packaging/dope-notes.desktop

%files
%license LICENSE
%doc README.md
%{_bindir}/dope-notes
%{_datadir}/applications/dope-notes.desktop
%{_datadir}/icons/hicolor/512x512/apps/dope-notes.png
%{_datadir}/dope-notes/font/Roboto-Regular.ttf
%{_datadir}/dope-notes/assets/icons/*.png
