local ffi = require 'ffi'
local lfs = require 'lfs'
local zfp = ffi.load(
  lfs.currentdir() .. '/native/libzfp.so')

ffi.cdef
[[
typedef struct {
  char *fpos;
  void *base;
  unsigned short handle;
  short flags;
  short unget;
  unsigned long alloc;
  unsigned short buffincrement;
} FILE;

FILE *fopen(const char *filename, const char *mode);
int fwrite(const void *array, size_t size, size_t count, FILE *stream);
int fclose(FILE *stream);
size_t fread(void *ptr, size_t size, size_t nmemb, FILE *stream);
]]

ffi.cdef
[[
typedef unsigned char uchar;
typedef unsigned short ushort;
typedef unsigned int uint;
]]

ffi.cdef[[
typedef struct bitstream bitstream;
bitstream* stream_open(void* buffer, size_t bytes);
]]

ffi.cdef
[[
/* execution policy (for compression only) */
typedef enum {
  zfp_exec_serial = 0, /* serial execution (default) */
  zfp_exec_omp    = 1  /* OpenMP multi-threaded execution */
} zfp_exec_policy;

/* OpenMP execution parameters */
typedef struct {
  uint threads;    /* number of requested threads */
  uint chunk_size; /* number of blocks per chunk (1D only) */
} zfp_exec_params_omp;

/* execution parameters */
typedef union {
  zfp_exec_params_omp omp; /* OpenMP parameters */
} zfp_exec_params;

typedef struct {
  zfp_exec_policy policy; /* execution policy (serial, omp, ...) */
  zfp_exec_params params; /* execution parameters */
} zfp_execution;

/* compressed stream; use accessors to get/set members */
typedef struct {
  uint minbits;       /* minimum number of bits to store per block */
  uint maxbits;       /* maximum number of bits to store per block */
  uint maxprec;       /* maximum number of bit planes to store */
  int minexp;         /* minimum floating point bit plane number to store */
  bitstream* stream;  /* compressed bit stream */
  zfp_execution exec; /* execution policy and parameters */
} zfp_stream;

/* scalar type */
typedef enum {
  zfp_type_none   = 0, /* unspecified type */
  zfp_type_int32  = 1, /* 32-bit signed integer */
  zfp_type_int64  = 2, /* 64-bit signed integer */
  zfp_type_float  = 3, /* single precision floating point */
  zfp_type_double = 4  /* double precision floating point */
} zfp_type;

/* uncompressed array; use accessors to get/set members */
typedef struct {
  zfp_type type;   /* scalar type (e.g. int32, double) */
  uint nx, ny, nz; /* sizes (zero for unused dimensions) */
  int sx, sy, sz;  /* strides (zero for contiguous array a[nz][ny][nx]) */
  void* data;      /* pointer to array data */
} zfp_field;

zfp_field*       /* allocated field metadata */
zfp_field_1d(
  void* pointer, /* pointer to uncompressed scalars (may be NULL) */
  zfp_type type, /* scalar type */
  uint nx        /* number of scalars */
);

zfp_stream*         /* allocated compressed stream */
zfp_stream_open(
  bitstream* stream /* bit stream to read from and write to (may be NULL) */
);

double                /* actual error tolerance */
zfp_stream_set_accuracy(
  zfp_stream* stream, /* compressed stream */
  double tolerance    /* desired error tolerance */
);

size_t                      /* maximum number of bytes of compressed storage */
zfp_stream_maximum_size(
  const zfp_stream* stream, /* compressed stream */
  const zfp_field* field    /* array to compress */
);

zfp_stream*         /* allocated compressed stream */
zfp_stream_open(
  bitstream* stream /* bit stream to read from and write to (may be NULL) */
);

void
zfp_stream_set_bit_stream(
  zfp_stream* stream, /* compressed stream */
  bitstream* bs       /* bit stream to read from and write to */
);

size_t                   /* cumulative number of bytes of compressed storage */
zfp_compress(
  zfp_stream* stream,    /* compressed stream */
  const zfp_field* field /* field metadata */
);

size_t
zfp_stream_flush(
  zfp_stream* stream /* compressed bit stream */
);

void
zfp_stream_rewind(
  zfp_stream* stream /* compressed bit stream */
);

size_t                /* cumulative number of bytes of compressed storage */
zfp_decompress(
  zfp_stream* stream, /* compressed stream */
  zfp_field* field    /* field metadata */
);
]]

return { 
  ['zfp'] = zfp
}