/*From https://gist.github.com/raullenchai/2712516*/
/* PARALLELISIERTE VERSION mit fork() und Semaphoren */

#include <stdio.h>
#include <stdint.h>
#include <math.h>
#include <semaphore.h>
#include <sys/types.h>
#include <sys/ipc.h>
#include <sys/shm.h>
#include <unistd.h>
#include <sys/wait.h>
#include <string.h>
#include <stdlib.h>

/*
Fork From http://www.cs.technion.ac.il/~orrd/KATAN/katan.c
 Reference BITSLICED implementations of:
 KATAN32, KATAN48, KATAN64, KTANTAN32, KTANTAN48 and KTANTAN64.
 Each of the 64 slices corresponds to a distinct instance.
 
 To work with a single instance, use values in {0,1} 
 (ie, only consider the least significant slice).
 Authors: 
 Jean-Philippe Aumasson, FHNW, Windisch, Switzerland
 Miroslav Knezevic, Katholieke Universiteit Leuven, Belgium
 Orr Dunkelman, Weizmann Institute of Science, Israel
 Thanks goes to Bo Zhu for pointing out a bug in the KTANTAN part
 Thanks ges to Wei Lei for pointing out a bug in the KTANTAN part
*/

#ifndef U64
#define U64
typedef unsigned long long u64;
#endif 

#define ONES 0xFFFFFFFFFFFFFFFFULL

#define X1_32  12
#define X2_32  7
#define X3_32  8
#define X4_32  5
#define X5_32  3
#define Y1_32  18
#define Y2_32  7
#define Y3_32  12
#define Y4_32  10
#define Y5_32  8
#define Y6_32  3

#define X1_48  18
#define X2_48  12
#define X3_48  15
#define X4_48  7
#define X5_48  6
#define Y1_48  28
#define Y2_48  19
#define Y3_48  21
#define Y4_48  13
#define Y5_48  15
#define Y6_48  6

#define X1_64  24
#define X2_64  15
#define X3_64  20
#define X4_64  11
#define X5_64  9
#define Y1_64  38
#define Y2_64  25
#define Y3_64  33
#define Y4_64  21
#define Y5_64  14
#define Y6_64  9


// IR constants, either 1 for all slices, are 0 for all slices
const u64 IR[254] = {
  ONES,ONES,ONES,ONES,ONES,ONES,ONES,0,0,0, // 0-9 
  ONES,ONES,0,ONES,0,ONES,0,ONES,0,ONES,
  ONES,ONES,ONES,0,ONES,ONES,0,0,ONES,ONES,
  0,0,ONES,0,ONES,0,0,ONES,0,0,
  0,ONES,0,0,0,ONES,ONES,0,0,0,
  ONES,ONES,ONES,ONES,0,0,0,0,ONES,0,
  0,0,0,ONES,0,ONES,0,0,0,0, // 60-69
  0,ONES,ONES,ONES,ONES,ONES,0,0,ONES,ONES,
  ONES,ONES,ONES,ONES,0,ONES,0,ONES,0,0,
  0,ONES,0,ONES,0,ONES,0,0,ONES,ONES,
  0,0,0,0,ONES,ONES,0,0,ONES,ONES,
  ONES,0,ONES,ONES,ONES,ONES,ONES,0,ONES,ONES,
  ONES,0,ONES,0,0,ONES,0,ONES,0,ONES, // 120-129
  ONES,0,ONES,0,0,ONES,ONES,ONES,0,0,
  ONES,ONES,0,ONES,ONES,0,0,0,ONES,0,
  ONES,ONES,ONES,0,ONES,ONES,0,ONES,ONES,ONES,
  ONES,0,0,ONES,0,ONES,ONES,0,ONES,ONES,
  0,ONES,0,ONES,ONES,ONES,0,0,ONES,0,
  0,ONES,0,0,ONES,ONES,0,ONES,0,0, // 180-189
  0,ONES,ONES,ONES,0,0,0,ONES,0,0,
  ONES,ONES,ONES,ONES,0,ONES,0,0,0,0,
  ONES,ONES,ONES,0,ONES,0,ONES,ONES,0,0,
  0,0,0,ONES,0,ONES,ONES,0,0,ONES,
  0,0,0,0,0,0,ONES,ONES,0,ONES,
  ONES,ONES,0,0,0,0,0,0,0,ONES, // 240-249
  0,0,ONES,0,
};


void katan32_encrypt( const u64 plain[32], u64 cipher[32], const u64 key[80], int rounds ) {

  u64 L1[13], L2[19], k[2*rounds], fa, fb;
  int i,j;

  for(i=0;i<19;++i) 
    L2[i] = plain[i];
  for(i=0;i<13;++i) 
    L1[i] = plain[i+19];

  for(i=0;i<80;++i)
    k[i]=key[i];
  for(i=80;i<2*rounds;++i)
    k[i]=k[i-80] ^ k[i-61] ^ k[i-50] ^ k[i-13] ;

  for(i=0;i<rounds;++i) {
    
    fa = L1[X1_32] ^ L1[X2_32] ^ (L1[X3_32] & L1[X4_32]) ^ (L1[X5_32] & IR[i])     ^ k[2*i];
    fb = L2[Y1_32] ^ L2[Y2_32] ^ (L2[Y3_32] & L2[Y4_32]) ^ (L2[Y5_32] & L2[Y6_32]) ^ k[2*i+1];

    for(j=12;j>0;--j)
      L1[j] = L1[j-1];
    for(j=18;j>0;--j)
      L2[j] = L2[j-1];
    L1[0] = fb;
    L2[0] = fa;
  }

  for(i=0;i<19;++i) 
    cipher[i] = L2[i];
  for(i=0;i<13;++i) 
    cipher[i+19] = L1[i];

}


void katan32_decrypt( const u64 cipher[32], u64 plain[32], const u64 key[80], int rounds ) {

  u64 L1[13], L2[19], k[2*rounds], fa, fb;
  int i,j;
  
  for(i=0;i<19;++i) 
    L2[i] = cipher[i];
  for(i=0;i<13;++i) 
    L1[i] = cipher[i+19];

  for(i=0;i<80;++i)
    k[i]=key[i];
  for(i=80;i<2*rounds;++i)
    k[i]=k[i-80] ^ k[i-61] ^ k[i-50] ^ k[i-13] ;

  for(i=rounds-1;i>=0;--i) {

    fb = L1[0];    
    fa = L2[0];
    for(j=0;j<12;++j)
      L1[j] = L1[j+1];
    for(j=0;j<18;++j)
      L2[j] = L2[j+1];
    
    L1[X1_32] = fa ^ L1[X2_32] ^ (L1[X3_32] & L1[X4_32]) ^ (L1[X5_32] & IR[i])     ^ k[2*i];
    L2[Y1_32] = fb ^ L2[Y2_32] ^ (L2[Y3_32] & L2[Y4_32]) ^ (L2[Y5_32] & L2[Y6_32]) ^ k[2*i+1];
  }
  
  for(i=0;i<19;++i) 
    plain[i] = L2[i];
  for(i=0;i<13;++i) 
    plain[i+19] = L1[i];
  
}


void katan48_encrypt( const u64 plain[48], u64 cipher[48], const u64 key[80], int rounds ) {

  u64 L1[19], L2[29], k[2*rounds], fa_1, fa_0, fb_1, fb_0;
  int i,j;

  for(i=0;i<29;++i) 
    L2[i] = plain[i];
  for(i=0;i<19;++i) 
    L1[i] = plain[i+29];

  for(i=0;i<80;++i)
    k[i]=key[i];
  for(i=80;i<2*rounds;++i)
    k[i]=k[i-80] ^ k[i-61] ^ k[i-50] ^ k[i-13];

  for(i=0;i<rounds;++i) {
    
    fa_1 = L1[X1_48]   ^ L1[X2_48]   ^ (L1[X3_48] & L1[X4_48])     ^ (L1[X5_48] & IR[i])         ^ k[2*i];
    fa_0 = L1[X1_48-1] ^ L1[X2_48-1] ^ (L1[X3_48-1] & L1[X4_48-1]) ^ (L1[X5_48-1] & IR[i])       ^ k[2*i];
    fb_1 = L2[Y1_48]   ^ L2[Y2_48]   ^ (L2[Y3_48] & L2[Y4_48])     ^ (L2[Y5_48] & L2[Y6_48])     ^ k[2*i+1];
    fb_0 = L2[Y1_48-1] ^ L2[Y2_48-1] ^ (L2[Y3_48-1] & L2[Y4_48-1]) ^ (L2[Y5_48-1] & L2[Y6_48-1]) ^ k[2*i+1];

    for(j=18;j>1;--j)
      L1[j] = L1[j-2];
    for(j=28;j>1;--j)
      L2[j] = L2[j-2];
    L1[1] = fb_1;
    L1[0] = fb_0;
    L2[1] = fa_1;
    L2[0] = fa_0;
  }

  for(i=0;i<29;++i) 
    cipher[i] = L2[i];
  for(i=0;i<19;++i) 
    cipher[i+29] = L1[i];

}


void katan48_decrypt( const u64 cipher[48], u64 plain[48], const u64 key[80], int rounds ) {

  u64 L1[19], L2[29], k[2*rounds], fa_1, fa_0, fb_1, fb_0;
  int i,j;

  
  for(i=0;i<29;++i) 
    L2[i] = cipher[i];
  for(i=0;i<19;++i) 
    L1[i] = cipher[i+29];

  for(i=0;i<80;++i)
    k[i]=key[i];
  for(i=80;i<2*rounds;++i)
    k[i]=k[i-80] ^ k[i-61] ^ k[i-50] ^ k[i-13] ;

  for(i=rounds-1;i>=0;--i) {

    fb_1 = L1[1];    
    fb_0 = L1[0];    
    fa_1 = L2[1];
    fa_0 = L2[0];
    for(j=0;j<17;++j)
      L1[j] = L1[j+2];
    for(j=0;j<27;++j)
      L2[j] = L2[j+2];

    L1[X1_48]   = fa_1 ^ L1[X2_48]   ^ (L1[X3_48] & L1[X4_48])     ^ (L1[X5_48] & IR[i])         ^ k[2*i];
    L1[X1_48-1] = fa_0 ^ L1[X2_48-1] ^ (L1[X3_48-1] & L1[X4_48-1]) ^ (L1[X5_48-1] & IR[i])       ^ k[2*i];
    L2[Y1_48]   = fb_1 ^ L2[Y2_48]   ^ (L2[Y3_48] & L2[Y4_48])     ^ (L2[Y5_48] & L2[Y6_48])     ^ k[2*i+1];
    L2[Y1_48-1] = fb_0 ^ L2[Y2_48-1] ^ (L2[Y3_48-1] & L2[Y4_48-1]) ^ (L2[Y5_48-1] & L2[Y6_48-1]) ^ k[2*i+1];
  }
  
  for(i=0;i<29;++i) 
    plain[i] = L2[i];
  for(i=0;i<19;++i) 
    plain[i+29] = L1[i];

}


void katan64_encrypt( const u64 plain[64], u64 cipher[64], const u64 key[80], int rounds ) {

  u64 L1[25], L2[39], k[2*rounds], fa_2, fa_1, fa_0, fb_2, fb_1, fb_0;
  int i,j;

  for(i=0;i<39;++i) 
    L2[i] = plain[i];
  for(i=0;i<25;++i) 
    L1[i] = plain[i+39];

  for(i=0;i<80;++i)
    k[i]=key[i];
  for(i=80;i<2*rounds;++i)
    k[i]=k[i-80] ^ k[i-61] ^ k[i-50] ^ k[i-13] ;

  for(i=0;i<rounds;++i) {
    
    fa_2 = L1[X1_64]   ^ L1[X2_64]   ^ (L1[X3_64] & L1[X4_64])     ^ (L1[X5_64] & IR[i])         ^ k[2*i];
    fa_1 = L1[X1_64-1] ^ L1[X2_64-1] ^ (L1[X3_64-1] & L1[X4_64-1]) ^ (L1[X5_64-1] & IR[i])       ^ k[2*i];
    fa_0 = L1[X1_64-2] ^ L1[X2_64-2] ^ (L1[X3_64-2] & L1[X4_64-2]) ^ (L1[X5_64-2] & IR[i])       ^ k[2*i];
    fb_2 = L2[Y1_64]   ^ L2[Y2_64]   ^ (L2[Y3_64] & L2[Y4_64])     ^ (L2[Y5_64] & L2[Y6_64])     ^ k[2*i+1];
    fb_1 = L2[Y1_64-1] ^ L2[Y2_64-1] ^ (L2[Y3_64-1] & L2[Y4_64-1]) ^ (L2[Y5_64-1] & L2[Y6_64-1]) ^ k[2*i+1];
    fb_0 = L2[Y1_64-2] ^ L2[Y2_64-2] ^ (L2[Y3_64-2] & L2[Y4_64-2]) ^ (L2[Y5_64-2] & L2[Y6_64-2]) ^ k[2*i+1];

    for(j=24;j>2;--j)
      L1[j] = L1[j-3];
    for(j=38;j>2;--j)
      L2[j] = L2[j-3];
    L1[2] = fb_2;
    L1[1] = fb_1;
    L1[0] = fb_0;
    L2[2] = fa_2;
    L2[1] = fa_1;
    L2[0] = fa_0;
  }

  for(i=0;i<39;++i) 
    cipher[i] = L2[i];
  for(i=0;i<25;++i) 
    cipher[i+39] = L1[i];

}


void katan64_decrypt( const u64 cipher[64], u64 plain[64], const u64 key[80], int rounds ) {

  u64 L1[25], L2[39], k[2*rounds], fa_2, fa_1, fa_0, fb_2, fb_1, fb_0;
  int i,j;

  
  for(i=0;i<39;++i) 
    L2[i] = cipher[i];
  for(i=0;i<25;++i) 
    L1[i] = cipher[i+39];

  for(i=0;i<80;++i)
    k[i]=key[i];
  for(i=80;i<2*rounds;++i)
    k[i]=k[i-80] ^ k[i-61] ^ k[i-50] ^ k[i-13];

  for(i=rounds-1;i>=0;--i) {

    fb_2 = L1[2];    
    fb_1 = L1[1];    
    fb_0 = L1[0];    
    fa_2 = L2[2];
    fa_1 = L2[1];
    fa_0 = L2[0];
    for(j=0;j<22;++j)
      L1[j] = L1[j+3];
    for(j=0;j<36;++j)
      L2[j] = L2[j+3];

    L1[X1_64]   = fa_2 ^ L1[X2_64]   ^ (L1[X3_64] & L1[X4_64])     ^ (L1[X5_64] & IR[i])         ^ k[2*i];
    L1[X1_64-1] = fa_1 ^ L1[X2_64-1] ^ (L1[X3_64-1] & L1[X4_64-1]) ^ (L1[X5_64-1] & IR[i])       ^ k[2*i];
    L1[X1_64-2] = fa_0 ^ L1[X2_64-2] ^ (L1[X3_64-2] & L1[X4_64-2]) ^ (L1[X5_64-2] & IR[i])       ^ k[2*i];
    L2[Y1_64]   = fb_2 ^ L2[Y2_64]   ^ (L2[Y3_64] & L2[Y4_64])     ^ (L2[Y5_64] & L2[Y6_64])     ^ k[2*i+1];
    L2[Y1_64-1] = fb_1 ^ L2[Y2_64-1] ^ (L2[Y3_64-1] & L2[Y4_64-1]) ^ (L2[Y5_64-1] & L2[Y6_64-1]) ^ k[2*i+1];
    L2[Y1_64-2] = fb_0 ^ L2[Y2_64-2] ^ (L2[Y3_64-2] & L2[Y4_64-2]) ^ (L2[Y5_64-2] & L2[Y6_64-2]) ^ k[2*i+1];

  }
  
  for(i=0;i<39;++i) 
    plain[i] = L2[i];
  for(i=0;i<25;++i) 
    plain[i+39] = L1[i];

}

static void bits_from_u32(uint32_t value, u64 bits[32]) {
  for (int i = 0; i < 32; ++i) {
    bits[i] = (value >> i) & 1U;
  }
}

static uint32_t u32_from_bits(const u64 bits[32]) {
  uint32_t value = 0;
  for (int i = 0; i < 32; ++i) {
    value |= ((uint32_t)(bits[i] & 1U)) << i;
  }
  return value;
}

void katan32_encrypt_without_key_schedule(const u64 plain[32], u64 cipher[32], const u64 k[], int rounds) {
  u64 L1[13], L2[19], fa, fb;
  int i,j;

  for(i=0;i<19;++i) 
    L2[i] = plain[i];
  for(i=0;i<13;++i) 
    L1[i] = plain[i+19];

  for(i=0;i<rounds;++i) {
    
    fa = L1[X1_32] ^ L1[X2_32] ^ (L1[X3_32] & L1[X4_32]) ^ (L1[X5_32] & IR[i])     ^ k[2*i];
    fb = L2[Y1_32] ^ L2[Y2_32] ^ (L2[Y3_32] & L2[Y4_32]) ^ (L2[Y5_32] & L2[Y6_32]) ^ k[2*i+1];

    for(j=12;j>0;--j)
      L1[j] = L1[j-1];
    for(j=18;j>0;--j)
      L2[j] = L2[j-1];
    L1[0] = fb;
    L2[0] = fa;
  }

  for(i=0;i<19;++i) 
    cipher[i] = L2[i];
  for(i=0;i<13;++i) 
    cipher[i+19] = L1[i];
}

void katan32_key_schedule_precomputation(const u64 key[80], u64 k[], int rounds) {
  int i;
  for(i=0;i<80;++i)
    k[i]=key[i];
  for(i=80;i<2*rounds;++i)
    k[i]=k[i-80] ^ k[i-61] ^ k[i-50] ^ k[i-13] ;
}

// ============ PARALLELISIERUNGSCODE ============

typedef struct {
  unsigned long long match;
  int num_children;
} shared_data_t;

void worker_process(int key, int num_children, int child_id, u64 k[], int rounds, 
                    int shmid, sem_t *sem, uint32_t input_diff) {
  uint64_t all_plain = 1ULL << 32;
  uint64_t chunk = all_plain / num_children;
  uint64_t start = child_id * chunk;
  uint64_t end = (child_id == num_children - 1) ? all_plain : (child_id + 1) * chunk;
  
  u64 plain1[32], plain2[32], cipher1[32], cipher2[32];
  unsigned long long local_match = 0;
  
  for (uint64_t plain = start; plain < end; plain++) {
    uint32_t p1 = (uint32_t)plain;
    uint32_t p2 = p1 ^ input_diff;
    
    bits_from_u32(p1, plain1);
    bits_from_u32(p2, plain2);
    
    katan32_encrypt_without_key_schedule(plain1, cipher1, k, rounds);
    katan32_encrypt_without_key_schedule(plain2, cipher2, k, rounds);
    
    uint32_t c1 = u32_from_bits(cipher1);
    uint32_t c2 = u32_from_bits(cipher2);
    if ((c1 ^ c2) == 0x08000020U) {
      local_match++;
    }
    
    if (plain % 10000000 == 0) {
      printf("[Child %d] Plaintext: %llu\r", child_id, plain);
      fflush(stdout);
    }
  }
  
  // Kritischer Bereich: Zugriff auf gemeinsamen Speicher mit Semaphor schützen
  shared_data_t *data = (shared_data_t *)shmat(shmid, NULL, 0);
  sem_wait(sem);
  data->match += local_match;
  sem_post(sem);
  shmdt(data);
  
  printf("\n[Child %d] Abgeschlossen. Lokale Treffer: %llu\n", child_id, local_match);
  exit(0);
}

int main() {
  uint32_t input_diff = 0x00008010;
  int rounds = 71;
  int num_children = 4;  // Anzahl der parallelen Prozesse
  
  // Shared Memory erstellen
  int shmid = shmget(IPC_PRIVATE, sizeof(shared_data_t), IPC_CREAT | 0666);
  if (shmid < 0) {
    perror("shmget");
    return 1;
  }
  
  shared_data_t *shared_data = (shared_data_t *)shmat(shmid, NULL, 0);
  if (shared_data == (void *)-1) {
    perror("shmat");
    return 1;
  }
  
  shared_data->match = 0;
  shared_data->num_children = num_children;
  
  // Semaphor erstellen (unnamed semaphore)
  sem_t sem;
  if (sem_init(&sem, 1, 1) == -1) {
    perror("sem_init");
    return 1;
  }
  
  // Hauptschleife über Keys
  for (int key = 0; key < 10; key++) {
    shared_data->match = 0;  // Reset für jeden Key
    
    u64 key_array[80];
    for (int i = 0; i < 80; i++) {
      key_array[i] = 0;
    }
    for (int i = 0; i < 32; i++) {
      key_array[i] = (key >> i) & 1;
    }
    
    u64 k[2 * rounds];
    katan32_key_schedule_precomputation(key_array, k, rounds);
    
    printf("\n========== Testing key: %u ==========\n", key);
    
    // Child-Prozesse forken
    pid_t pids[num_children];
    for (int i = 0; i < num_children; i++) {
      pids[i] = fork();
      if (pids[i] == 0) {
        // Im Child-Prozess
        worker_process(key, num_children, i, k, rounds, shmid, &sem, input_diff);
      } else if (pids[i] < 0) {
        perror("fork");
        return 1;
      }
    }
    
    // Auf alle Children warten
    for (int i = 0; i < num_children; i++) {
      waitpid(pids[i], NULL, 0);
    }
    
    // Ergebnisse ausgeben
    printf("\nNumber of matching output differences: %llu\n", shared_data->match);
    double all_plain = 1ULL << 32;
    double weight = log2(all_plain / (double)shared_data->match);
    printf("Differential probability ≈ 2^(-%.2f)\n", weight);
  }
  
  // Aufräumen
  sem_destroy(&sem);
  shmdt(shared_data);
  shmctl(shmid, IPC_RMID, NULL);
  
  return 0;
}

// Kompilieren: gcc -Ofast -march=native -flto -funroll-loops -DNDEBUG -o katan_parallel benchmark_KATAN32_parallel.c -lm -lpthread
