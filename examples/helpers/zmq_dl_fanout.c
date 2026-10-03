/* ZMQ DL fan-out for srsRAN loopback. One REQ client pulls the DL baseband
   blocks from srsenb's TX (ZMQ_REP). Two REP servers hand the SAME block to
   two consumers: a real UE (srsue) and a passive sniffer (LTESniffer). A block
   is pulled from srsenb only after BOTH consumers have taken the previous one,
   so the eNB stays in flow-control lockstep and both see every TTI in order.
   Pure localhost loopback helper, no RF. srsRAN zmq protocol: request is a
   single dummy byte, reply is nsamples cf32 (variable size). */
#include <zmq.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#define MAXBUF (16*1024*1024)
static volatile int run = 1;
static void on_int(int s){ (void)s; run = 0; }
int main(int argc, char** argv){
  const char* up_ep = argc>1 ? argv[1] : "tcp://localhost:2000"; /* srsenb TX */
  const char* d1_ep = argc>2 ? argv[2] : "tcp://*:2200";         /* srsue RX */
  const char* d2_ep = argc>3 ? argv[3] : "tcp://*:2201";         /* sniffer RX */
  signal(SIGINT,on_int); signal(SIGTERM,on_int);
  void* ctx = zmq_ctx_new();
  void* up = zmq_socket(ctx, ZMQ_REQ);
  void* d1 = zmq_socket(ctx, ZMQ_REP);
  void* d2 = zmq_socket(ctx, ZMQ_REP);
  int to = 2000;
  zmq_setsockopt(up, ZMQ_RCVTIMEO, &to, sizeof(to));
  zmq_setsockopt(up, ZMQ_SNDTIMEO, &to, sizeof(to));
  zmq_setsockopt(d1, ZMQ_RCVTIMEO, &to, sizeof(to));
  zmq_setsockopt(d2, ZMQ_RCVTIMEO, &to, sizeof(to));
  if (zmq_connect(up, up_ep)){ fprintf(stderr,"connect %s failed\n",up_ep); return 1; }
  if (zmq_bind(d1, d1_ep)){ fprintf(stderr,"bind %s failed\n",d1_ep); return 1; }
  if (zmq_bind(d2, d2_ep)){ fprintf(stderr,"bind %s failed\n",d2_ep); return 1; }
  char* buf = malloc(MAXBUF); unsigned char req[64]; unsigned char dummy=0xFF;
  fprintf(stderr,"fanout up=%s d1=%s d2=%s\n",up_ep,d1_ep,d2_ep);
  long blocks=0;
  while (run){
    /* pull one DL block from srsenb */
    int n;
    do { if(!run) goto done; n = zmq_send(up,&dummy,1,0); } while(n<0 && run);
    do { if(!run) goto done; n = zmq_recv(up,buf,MAXBUF,0); } while(n<0 && run);
    if (n<0) continue;
    /* barrier: serve srsue, then sniffer, this same block */
    int r;
    do { if(!run) goto done; r = zmq_recv(d1,req,sizeof(req),0); } while(r<0 && run);
    zmq_send(d1,buf,n,0);
    do { if(!run) goto done; r = zmq_recv(d2,req,sizeof(req),0); } while(r<0 && run);
    zmq_send(d2,buf,n,0);
    blocks++;
  }
done:
  fprintf(stderr,"fanout stop, %ld blocks relayed\n",blocks);
  zmq_close(up); zmq_close(d1); zmq_close(d2); zmq_ctx_destroy(ctx); free(buf);
  return 0;
}
