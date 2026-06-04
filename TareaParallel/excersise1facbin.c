/*
 * Exercise 1 - Bits set to 1 in n!
 * Computes n! and returns the count of bits equal to 1
 * in the binary representation of the result.
 *
 * Example: 6! = 720 = 1011010000b -> 4 bits set to 1
 *
 *
 * Carlos Enrique Rosete Pascual
 * 2026-06-03
 */

#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <time.h>

// Structure to share data with the threads
typedef struct {
    int id;
    int start;
    int end;
    unsigned long long * result;
    pthread_mutex_t * mutex;
} data_t;

// Pointer-to-function type: takes (n, threads) and returns the factorial
typedef unsigned long long (*factorial_function_t)(int, int);

// Function declarations
int countBits(unsigned long long n);
void printBinary(unsigned long long n);
unsigned long long factorial(int n, int threads);
unsigned long long parallelFactorial(int n, int threads);
void * multiplyRange(void * arg);
void timeFunction(factorial_function_t fun, int n, int threads);
double timespecToSeconds(struct timespec ts_begin, struct timespec ts_end);

int main(int argc, char * argv[])
{
    int n       = 20;
    int threads = 4;

    if (argc == 3) {
        threads = atoi(argv[2]);
    }
    if (argc > 1) {
        n = atoi(argv[1]);
    }

    printf(" PARALLEL VERSION \n");
    timeFunction(parallelFactorial, n, threads);

    printf("SEQUENTIAL VERSION \n");
    timeFunction(factorial, n, threads);

    return 0;
}

// Count the number of bits set to 1 in an integer
int countBits(unsigned long long n)
{
    int count = 0;
    while (n > 0) {
        count += n & 1;
        n >>= 1;
    }
    return count;
}

// Print the binary representation of an integer
void printBinary(unsigned long long n)
{
    if (n == 0) {
        printf("0");
        return;
    }
    // Find the most significant bit
    int bits = 0;
    unsigned long long temp = n;
    while (temp > 0) {
        bits++;
        temp >>= 1;
    }
    // Print each bit from most significant to least significant
    for (int i = bits - 1; i >= 0; i--) {
        printf("%llu", (n >> i) & 1);
    }
}

// Compute n! sequentially and return the result
// The 'threads' parameter is ignored; it exists to match the function pointer type
unsigned long long factorial(int n, int threads)
{
    (void) threads;
    unsigned long long result = 1;

    for (int i = 2; i <= n; i++) {
        result *= i;
    }

    return result;
}

// Thread function: multiply all numbers in [start, end] and
// accumulate the partial product into the shared result
void * multiplyRange(void * arg)
{
    data_t * d = (data_t *) arg;
    unsigned long long local = 1;

    for (int i = d->start; i <= d->end; i++) {
        local *= i;
    }

    pthread_mutex_lock(d->mutex);
    *(d->result) *= local;
    pthread_mutex_unlock(d->mutex);

    pthread_exit(NULL);
}

// Compute n! in parallel using 'threads' threads and return the result
unsigned long long parallelFactorial(int n, int threads)
{
    int rangeSize = n / threads;
    int remainder = n % threads;

    data_t thread_data[threads];
    pthread_t tids[threads];
    pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;

    unsigned long long resultParallel = 1;
    int status;

    for (int i = 0; i < threads; i++) {
        thread_data[i].id     = i;
        thread_data[i].start  = i * rangeSize + 1;
        thread_data[i].end    = (i + 1) * rangeSize;
        thread_data[i].result = &resultParallel;
        thread_data[i].mutex  = &mutex;

        // Assign leftover numbers to the last thread
        if (i == threads - 1) {
            thread_data[i].end += remainder;
        }

        printf("ID: %d [%d, %d]\n", thread_data[i].id,
               thread_data[i].start, thread_data[i].end);

        status = pthread_create(&tids[i], NULL, multiplyRange, &thread_data[i]);
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

    return resultParallel;
}

// Wrapper that measures wall time and CPU time of a function call
// Also prints the factorial, its binary representation, and the bit count
void timeFunction(factorial_function_t fun, int n, int threads)
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

    printf("N: %d | N!: %llu | Binary: ", n, result);
    printBinary(result);
    printf(" | Bits set to 1: %d | Time: %lf | CPU: %lf\n",
           countBits(result), elapsed_wall, elapsed_cpu);
}

// Compute elapsed seconds between two timespec values
double timespecToSeconds(struct timespec ts_begin, struct timespec ts_end)
{
    long seconds     = ts_end.tv_sec  - ts_begin.tv_sec;
    long nanoseconds = ts_end.tv_nsec - ts_begin.tv_nsec;
    return seconds + nanoseconds * 1e-9;
}