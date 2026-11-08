run: setup-shared
    odin run . -collection:shared=./odin_shared

build:
    bash font/build.sh

setup-shared:
    mkdir -p odin_shared
    ln -sfnT ../shared/clay/bindings/odin/clay-odin odin_shared/clay
