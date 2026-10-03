/* Minimal ZMQ_REP server: replies with a chunk of zero cf32 samples to each
   request. Feeds a srsRAN zmq RX (ZMQ_REQ) with silence so the eNB advances
   without a UE. Pure loopback helper, no RF. */
#include <zmq.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
static volatile int run = 1;
static void on_int(int s){ (void)s; run = 0; }
int main(int argc, char** argv){
  const char* ep = argc > 1 ? argv[1] : "tcp://*:2101";
  int nsamp = argc > 2 ? atoi(argv[2]) : 5760;      /* one 25-PRB subframe */
  size_t nbytes = (size_t)nsamp * 8;                 /* cf32 = 8 bytes */
  signal(SIGINT, on_int); signal(SIGTERM, on_int);
  void* ctx = zmq_ctx_new();
  void* s = zmq_socket(ctx, ZMQ_REP);
  int to = 1000; zmq_setsockopt(s, ZMQ_RCVTIMEO, &to, sizeof(to));
  if (zmq_bind(s, ep)) { fprintf(stderr, "bind %s failed\n", ep); return 1; }
  char* zeros = calloc(1, nbytes);
  unsigned char req[64];
  fprintf(stderr, "zeros-REP on %s, %d samples/reply\n", ep, nsamp);
  while (run) {
    int n = zmq_recv(s, req, sizeof(req), 0);
    if (n < 0) continue;              /* timeout: loop to re-check run */
    zmq_send(s, zeros, nbytes, 0);
  }
  zmq_close(s); zmq_ctx_destroy(ctx); free(zeros);
  return 0;
}
