%{!?dope_notes_version:%global dope_notes_version 0.1.0}
%{!?dope_notes_release:%global dope_notes_release 1}
%{!?llvm_config:%global llvm_config %{_bindir}/llvm-config}
%global odin_version dev-2026-07a
%global odin_dir Odin-%{odin_version}

Name:           dope-notes
Version:        %{dope_notes_version}
Release:        %{dope_notes_release}%{?dist}
Summary:        Desktop Markdown notes editor
License:        MIT
URL:            https://github.com/mtnyoni/dope-notes
Source0:        %{url}/archive/v%{version}/%{name}-%{version}.tar.gz
# Fedora does not currently package the Odin compiler, so build a pinned
# compiler from its upstream source before building Dope Notes.
Source1:        https://github.com/odin-lang/Odin/archive/%{odin_version}/Odin-%{odin_version}.tar.gz

ExclusiveArch:  x86_64

BuildRequires:  binutils
BuildRequires:  clang
BuildRequires:  desktop-file-utils
BuildRequires:  gcc
BuildRequires:  freetype-devel
BuildRequires:  libstdc++-devel
BuildRequires:  llvm-devel
BuildRequires:  pkgconfig(sdl3)
BuildRequires:  pkgconfig(sdl3-image)


%description
Dope Notes is a desktop Markdown notes editor built with Odin, SDL3, Clay,
and FreeType.

%prep
%autosetup -n %{name}-%{version}
tar -xzf %{SOURCE1}
# Odin defaults to static LLVM component libraries. Fedora ships the shared
# library with llvm-devel, which is sufficient for this temporary compiler.
sed -i 's/--libs core native/--link-shared --libs core native/' \
    %{odin_dir}/build_odin.sh

%build
pushd %{odin_dir}
LLVM_CONFIG=%{llvm_config} CXX=clang++ ./build_odin.sh release
popd

bash font/build.sh
mkdir -p odin_shared
ln -sfnT ../shared/clay/bindings/odin/clay-odin odin_shared/clay
./%{odin_dir}/odin build . \
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
