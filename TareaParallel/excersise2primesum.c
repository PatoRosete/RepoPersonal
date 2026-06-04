/*
 * Exercise 2 - Sum of prime numbers <= n
 * Uses trial division up to sqrt(x) to identify primes.
 *
 * Example: sum of primes <= 10 = 2 + 3 + 5 + 7 = 17
 *
 * Carlos Enrique Rosete Pascual
 * 2026-06-03
 */

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <pthread.h>
#include <time.h>

// Structure to share data with the threads
typedef struct {
    int id;
    long start;
    long end;
    unsigned long long * total;
    pthread_mutex_t * mutex;
} data_t;

// Pointer-to-function type: takes (n, threads) and returns the sum
typedef unsigned long long (*primes_function_t)(long, int);

// Function declarations
int isPrime(long x);
unsigned long long sumPrimes(long n, int threads);
unsigned long long parallelSumPrimes(long n, int threads);
void * sumPrimesRange(void * arg);
void timeFunction(primes_function_t fun, long n, int threads);
double timespecToSeconds(struct timespec ts_begin, struct timespec ts_end);

int main(int argc, char * argv[])
{
    long n      = 10;
    int threads = 4;

    if (argc == 3) {
        threads = atoi(argv[2]);
    }
    if (argc > 1) {
        n = atol(argv[1]);
    }

    printf("PARALLEL VERSION\n");
    timeFunction(parallelSumPrimes, n, threads);

    printf("SEQUENTIAL VERSION\n");
    timeFunction(sumPrimes, n, threads);

    return 0;
}

// Return 1 if x is prime, 0 otherwise
// Uses i * i <= x instead of sqrt to avoid floating point
int isPrime(long x)
{
    if (x < 2) return 0;
    if (x == 2) return 1;

    for (long i = 2; i * i <= x; i++) {
        if (x % i == 0) return 0;
    }
    return 1;
}

// Compute the sum of all primes <= n sequentially
// The 'threads' parameter is ignored; it exists to match the function pointer type
unsigned long long sumPrimes(long n, int threads)
{
    (void) threads;
    unsigned long long sum = 0;

    for (long i = 2; i <= n; i++) {
        if (isPrime(i)) {
            sum += i;
        }
    }

    return sum;
}

// Thread function: sum all primes in [start, end] and
// accumulate the partial sum into the shared total
void * sumPrimesRange(void * arg)
{
    data_t * d = (data_t *) arg;
    unsigned long long local_sum = 0;

    for (long i = d->start; i <= d->end; i++) {
        if (isPrime(i)) {
            local_sum += i;
        }
    }

    pthread_mutex_lock(d->mutex);
    *(d->total) += local_sum;
    pthread_mutex_unlock(d->mutex);

    pthread_exit(NULL);
}

// Compute the sum of all primes <= n using 'threads' threads
unsigned long long parallelSumPrimes(long n, int threads)
{
    long rangeSize = n / threads;
    long remainder = n % threads;

    data_t thread_data[threads];
    pthread_t tids[threads];
    pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;

    unsigned long long total = 0;
    int status;

    for (int i = 0; i < threads; i++) {
        thread_data[i].id    = i;
        thread_data[i].start = i * rangeSize + 2;
        thread_data[i].end   = (i + 1) * rangeSize + 1;
        thread_data[i].total = &total;
        thread_data[i].mutex = &mutex;

        // Assign leftover numbers to the last thread
        if (i == threads - 1) {
            thread_data[i].end = n;
        }

        printf("ID: %d [%ld, %ld]\n", thread_data[i].id,
               thread_data[i].start, thread_data[i].end);

        status = pthread_create(&tids[i], NULL, sumPrimesRange, &thread_data[i]);
        if (status == -1) {
            perror("ERROR: pthread_create");
        }
    }

    for (int i = 0; i < threads; i++) {
        status = pthread_join(tids[i], NULL);
        if (status == -1) {
            perror("ERROR: pthread_join");
        }
    }

    return total;
}

// Wrapper that measures wall time and CPU time of a function call
void timeFunction(primes_function_t fun, long n, int threads)
{
    struct timespec ts_wall_begin, ts_wall_end;
    struct timespec ts_cpu_begin, ts_cpu_end;
    double elapsed_wall;
    double elapsed_cpu;

    clock_gettime(CLOCK_REALTIME, &ts_wall_begin);
    clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &ts_cpu_begin);

    unsigned long long result = fun(n, threads);

    clock_gettime(CLOCK_REALTIME, &ts_wall_end);
    clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &ts_cpu_end);

    elapsed_wall = timespecToSeconds(ts_wall_begin, ts_wall_end);
    elapsed_cpu  = timespecToSeconds(ts_cpu_begin,  ts_cpu_end);

    printf("N: %ld | Sum of primes: %llu | Time: %lf | CPU: %lf\n",
           n, result, elapsed_wall, elapsed_cpu);
}

// Compute elapsed seconds between two timespec values
double timespecToSeconds(struct timespec ts_begin, struct timespec ts_end)
{
    long seconds     = ts_end.tv_sec  - ts_begin.tv_sec;
    long nanoseconds = ts_end.tv_nsec - ts_begin.tv_nsec;
    return seconds + nanoseconds * 1e-9;
}
