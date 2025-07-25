FROM ubuntu:18.04

# TODO remove sudo for user "magma" to avoid unwanted priv escalation from
# other attack vectors.

RUN apt-get update && apt-get install -y sudo

## Magma directory hierarchy
# magma_root is relative to the docker-build's working directory
# The Docker image must be built in the root of the magma directory
ARG magma_root=./

## Path variables inside the container
ENV MAGMA_R=/magma
ENV OUT=/magma_out
ENV SHARED=/magma_shared
ENV MAGMA_HOME=/home

ENV CC  /usr/bin/gcc
ENV CXX /usr/bin/g++
ENV LD /usr/bin/ld
ENV AR /usr/bin/ar
ENV AS /usr/bin/as
ENV NM /usr/bin/nm
ENV RANLIB /usr/bin/ranlib

ARG USER_ID=1000
ARG GROUP_ID=1000
RUN mkdir -p ${MAGMA_HOME} && \
	groupadd -g ${GROUP_ID} magma && \
	useradd -l -u ${USER_ID} -K UMASK=0000 -d ${MAGMA_HOME} -g magma magma && \
	chown magma:magma ${MAGMA_HOME}
RUN	echo "magma:amgam" | chpasswd && usermod -a -G sudo magma && \
	echo 'magma  ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

RUN mkdir -p ${SHARED} ${OUT} && \
	chown magma:magma ${SHARED} ${OUT} && \
	chmod 744 ${SHARED} ${OUT}

ARG magma_path=magma
ENV MAGMA 	${MAGMA_R}/${magma_path}
USER root:root
RUN mkdir -p ${MAGMA} && chown magma:magma ${MAGMA}
COPY --chown=magma:magma ${magma_root}/${magma_path}/preinstall.sh ${MAGMA}/
RUN ${MAGMA}/preinstall.sh
USER magma:magma
COPY --chown=magma:magma \
    ${magma_root}/${magma_path}/prebuild.sh \
    ${magma_root}/${magma_path}/build.sh \
    ${MAGMA}/
COPY --chown=magma:magma ${magma_root}/${magma_path}/src ${MAGMA}/src
RUN ${MAGMA}/prebuild.sh

ARG fuzzer_name
ARG fuzzer_path=fuzzers/${fuzzer_name}
ENV FUZZER 	${MAGMA_R}/${fuzzer_path}
USER root:root
RUN mkdir -p ${FUZZER} && chown magma:magma ${FUZZER}
COPY --chown=magma:magma ${magma_root}/${fuzzer_path}/preinstall.sh ${FUZZER}/
RUN ${FUZZER}/preinstall.sh
USER magma:magma
COPY --chown=magma:magma ${magma_root}/${fuzzer_path} ${FUZZER}/
# Docker does not support variables in --mount options
# synch values with USER_ID and GROUP_ID
RUN --mount=type=ssh,uid=1000,gid=1000 ${FUZZER}/fetch.sh
RUN --mount=type=ssh,uid=1000,gid=1000 ${FUZZER}/build.sh

ARG target_name
ARG target_path=targets/${target_name}
ENV TARGET 	${MAGMA_R}/${target_path}
USER root:root
RUN mkdir -p ${TARGET} && chown magma:magma ${TARGET}
COPY --chown=magma:magma ${magma_root}/${target_path} ${TARGET}/
RUN ${TARGET}/preinstall.sh
USER magma:magma
RUN ${TARGET}/fetch.sh

ARG bug
ENV MAGMA_BUG=$bug
ENV MAGMA_BUG_FILE=${bug:+"$OUT/bug_$bug.diff"}
COPY --chown=magma:magma ${magma_root}/${magma_path}/apply_patches.sh ${MAGMA}/
RUN ${MAGMA}/apply_patches.sh

## Configuration parameters
ARG isan
ARG harden
ARG canaries
ARG fixes

ARG ISAN_FLAG=${isan:+-DMAGMA_FATAL_CANARIES}
ARG HARDEN_FLAG=${harden:+-DMAGMA_HARDEN_CANARIES}
ARG CANARIES_FLAG=${canaries:+-DMAGMA_ENABLE_CANARIES}
ARG FIXES_FLAG=${fixes:+-DMAGMA_ENABLE_FIXES}
ARG BUILD_FLAGS="-include ${MAGMA}/src/canary.h ${CANARIES_FLAG} ${FIXES_FLAG} ${ISAN_FLAG} ${HARDEN_FLAG} -g -O0"

ENV CFLAGS=${BUILD_FLAGS}
ENV CXXFLAGS=${BUILD_FLAGS}
ENV LIBS="-l:magma.o -lrt"
ENV LDFLAGS="-L$OUT -g"

COPY --chown=magma:magma \
    ${magma_root}/${magma_path}/directed.sh \
    ${magma_root}/${magma_path}/gather_resusage.sh \
    ${magma_root}/${magma_path}/sanitizers.sh \
    ${magma_root}/${magma_path}/showlinenum.awk \
    ${MAGMA}/

RUN "${MAGMA}/gather_resusage.sh" "${FUZZER}/instrument.sh"

COPY --chown=magma:magma \
    ${magma_root}/${magma_path}/all_findings.sh \
    ${magma_root}/${magma_path}/fix_seeds.sh \
    ${magma_root}/${magma_path}/run.sh \
    ${magma_root}/${magma_path}/runonce.sh \
    ${MAGMA}/

ENTRYPOINT "${MAGMA}/run.sh"
