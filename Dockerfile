FROM ubuntu:jammy-20230816

COPY work /work/
WORKDIR /work

COPY artifacts/shimx64.efi /work/artifacts/

RUN DEBIAN_FRONTEND=noninteractive apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    binutils-x86-64-linux-gnu=2.38-4ubuntu2.3 \
    bzip2 \
    gcc=4:11.2.0-1ubuntu1 \
    less \
    libelf-dev \
    make \
    openssl \
    patch \
    sed \
    wget

ARG SHIM_VER=15.7
ARG SHIM_PKG_URL=https://github.com/rhboot/shim/releases/download/${SHIM_VER}/shim-${SHIM_VER}.tar.bz2
ARG SHIM_PKG_FILE=shim-${SHIM_VER}.tar.bz2
ARG SHIM_PKG_SHA256=87cdeb190e5c7fe441769dde11a1b507ed7328e70a178cd9858c7ac7065cfade

RUN wget --progress=dot "${SHIM_PKG_URL}" -O "/work/${SHIM_PKG_FILE}" && echo "${SHIM_PKG_SHA256} ${SHIM_PKG_FILE}" | sha256sum --check

RUN tar -xf "/work/${SHIM_PKG_FILE}"

RUN find /work/patches -type f -name '*.patch' -print0 | sort --zero-terminated | xargs -0 -I{} -- patch -p1 --directory="/work/shim-${SHIM_VER}" --input={}

RUN mkdir -p "/work/shim-${SHIM_VER}/data" && cp /work/sbat.csv "/work/shim-${SHIM_VER}/data"

RUN mkdir -p /work/shim-build-x64 && mkdir -p /work/shim-install-x64
RUN make ARCH=x86_64 VENDOR_CERT_FILE=/work/cert.der EFIDIR=sonicwall TOPDIR="/work/shim-${SHIM_VER}" DISABLE_EBS_PROTECTION=y -C /work/shim-build-x64 DESTDIR=/work/shim-install-x64 -f "/work/shim-${SHIM_VER}/Makefile" install

RUN echo "===== Review Materials ====="; \
    echo "Newly built EFI binary hashes"; sha256sum /work/shim-install-x64/boot/efi/EFI/sonicwall/shimx64.efi; \
    echo "Shim review submission EFI binary hashes"; sha256sum /work/artifacts/*.efi;

RUN objdump -s -j .sbatlevel /work/shim-install-x64/boot/efi/EFI/sonicwall/shimx64.efi
RUN objdump -fhp /work/shim-install-x64/boot/efi/EFI/sonicwall/shimx64.efi | sed -rn -e'/^SectionAlignment/p;/^DllCharacteristics/p;/^Sections:$/,$p'
