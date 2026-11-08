run: setup-shared font-build
    odin run . -collection:shared=./odin_shared -define:DOPE_NOTES_DEV=true

build: setup-shared font-build
    odin build . -collection:shared=./odin_shared -define:DOPE_NOTES_DEV=true

package version:
    bash package-rpm.sh {{version}}

font-build:
    bash font/build.sh

setup-shared:
    mkdir -p odin_shared
    ln -sfnT ../shared/clay/bindings/odin/clay-odin odin_shared/clay
