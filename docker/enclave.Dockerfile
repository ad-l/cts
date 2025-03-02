ARG CCF_VERSION=2.0.8
FROM mcr.microsoft.com/ccf/app/dev:${CCF_VERSION}-sgx as builder
ARG CCF_VERSION

WORKDIR /usr/src/app/

# Component specific to the CCF app
COPY ./3rdparty/attested-fetch /tmp/attested-fetch/
RUN mkdir /tmp/attested-fetch-build && \
    cd /tmp/attested-fetch-build && \
    CC="/opt/oe_lvi/clang-10" CXX="/opt/oe_lvi/clang++-10" cmake -GNinja \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_INSTALL_PREFIX=/usr/src/app/attested-fetch \
    /tmp/attested-fetch && \
    ninja && ninja install

WORKDIR /usr/src/app/attested-fetch

# Save MRENCLAVE
RUN /opt/openenclave/bin/oesign dump -e libafetch.enclave.so.signed > oesign.dump && \
    awk '/^mrenclave=/' oesign.dump | sed "s/mrenclave=//" > mrenclave.txt

WORKDIR /usr/src/app

# Build CCF app
COPY ./app /tmp/app/
RUN mkdir /tmp/app-build && \
    cd /tmp/app-build && \
    CC="/opt/oe_lvi/clang-10" CXX="/opt/oe_lvi/clang++-10" cmake -GNinja \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_INSTALL_PREFIX=/usr/src/app \
    -DCOMPILE_TARGETS="sgx" \
    -DBUILD_TESTS=OFF \
    -DATTESTED_FETCH_MRENCLAVE_HEX=`cat /usr/src/app/attested-fetch/mrenclave.txt` \
    /tmp/app && \
    ninja && ninja install

# Save MRENCLAVE
RUN /opt/openenclave/bin/oesign dump -e lib/libscitt.enclave.so.signed > oesign.dump && \
    awk '/^mrenclave=/' oesign.dump | sed "s/mrenclave=//" > mrenclave.txt

FROM mcr.microsoft.com/ccf/app/run:${CCF_VERSION}-sgx
ARG CCF_VERSION

RUN apt update && \
    apt install -y \
    wget \
    curl

# Install SGX quote library, which is required for out-of-proc attestation.
RUN wget -qO - https://download.01.org/intel-sgx/sgx_repo/ubuntu/intel-sgx-deb.key | apt-key add -
RUN apt update && apt install -y libsgx-quote-ex
RUN apt remove -y wget

WORKDIR /usr/src/app
COPY --from=builder /usr/src/app/lib/libscitt.enclave.so.signed libscitt.enclave.so.signed
COPY --from=builder /usr/src/app/mrenclave.txt mrenclave.txt

COPY app/fetch-did-web-doc-attested.sh /tmp/scitt/fetch-did-web-doc-attested.sh
COPY --from=builder /usr/src/app/attested-fetch /tmp/scitt/

WORKDIR /host/node

ENTRYPOINT ["cchost"]
