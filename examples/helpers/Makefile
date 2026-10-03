# Build the ZeroMQ loopback helpers. Needs libzmq (brew install zeromq).
ZMQ_PREFIX ?= $(shell brew --prefix zeromq)
CFLAGS  += -O2 -I$(ZMQ_PREFIX)/include
LDFLAGS += -L$(ZMQ_PREFIX)/lib -lzmq
BINS = zmq_zeros_rep zmq_dl_fanout zmq_ul_fanout

all: $(BINS)
%: %.c
	$(CC) $(CFLAGS) $< $(LDFLAGS) -o $@
clean:
	rm -f $(BINS)
