-- by cucumber / gonzalezjo

local lfs = require 'lfs'
local ffi = require 'ffi'
local lib = require 'lib'

local ERROR_TOLERANCE = 1e-5
local WRITE_EVERYTHING = true
local REUSE_ARRAYS = true
local DEBUG_MODE = true 
local UNCOMPRESSED_DIRECTORY = lfs.currentdir() .. '/uncompressed'
local ARRAY_DIRECTORY = lfs.currentdir() .. '/arrays'
local COMPRESSED_DIRECTORY = lfs.currentdir() .. '/compressed'
local DECOMPRESSED_DIRECTORY = lfs.currentdir() .. '/decompressed'
local RECONVERTED_DIRECTORY = lfs.currentdir() .. '/reconverted'
local DATA_TYPE = 'float'
local SKIPPABLE_FILES = {
  ['256_20_random_10000']    = true, 
  ['64_6_developed_9154']    = false, 
  ['192_15_developed_449']   = true, 
  ['256_20_developed_10002'] = true
}

local dload, dstore, dprint
do 
  local lookup = {}

  function dload(k)
    return lookup[k]
  end

  function dstore(k, v)
    lookup[k] = v
  end


  function dprint(...)
    if DEBUG_MODE then 
      print(...)
    end
  end
end

local function cachedarray(name)
  local inpath = string.format('%s/%s', ARRAY_DIRECTORY, name)
  local infile = io.open(inpath, 'rb')
  local contents = infile and infile:read('*a') or ''

  if #contents ~= 0 then 
    local elements = #contents / ffi.sizeof(DATA_TYPE)
    local array = ffi.new(DATA_TYPE .. '[?]', elements)

    infile:seek('set')

    local status = ffi.C.fread(
      array, 
      ffi.sizeof(DATA_TYPE),
      elements,
      infile) 

    return array
  end
end

local function toarray(name) 
  dprint('In toarray for: ' .. name)

  local numbers, array

  if REUSE_ARRAYS then 
    local cached = cachedarray(name)
    if cached then 
      dprint('Reused cached array for ' .. name)
      return cached
    else 
      dprint('Failed to find cached array.')
    end
  end

  do -- Initialize number list
    local inpath = ('%s/%s'):format(UNCOMPRESSED_DIRECTORY, name)
    local infile = io.open(inpath, 'rb')
    numbers = {}

    local number = infile:read('*n')
    while number do 
      table.insert(numbers, number) 
      number = infile:read('*n')
    end

    if DEBUG_MODE then 
      infile:seek('set')
      dload(name).bytes = #infile:read('*all')
    end

    infile:close()
  end

  do -- Initialize ARRAY array
    array = ffi.new(DATA_TYPE .. '[?]', #numbers)

    for i, number in ipairs(numbers) do 
      array[i - 1] = number
    end
  end

  if WRITE_EVERYTHING then 
    local outpath = string.format('%s/%s', ARRAY_DIRECTORY, name)
    local outfile = assert(io.open(outpath, 'wb'))

    ffi.C.fwrite(
      array, 
      ffi.sizeof(DATA_TYPE), 
      #numbers, 
      outfile)

    outfile:close()
  end

  dprint('Total numbers: ' .. #numbers)
  dprint('Exiting toarray for: ' .. name)

  return array
end

local function compress(array, name)
  local zfp = lib.zfp
  local elements   = ffi.sizeof(array) / ffi.sizeof(DATA_TYPE)

  local zfp_type   = zfp.zfp_type_float
  local zfp_field  = zfp.zfp_field_1d(array, zfp_type, elements)
  local zfp_stream = zfp.zfp_stream_open(nil)

  zfp.zfp_stream_set_accuracy(zfp_stream, ERROR_TOLERANCE)

  local buffer, bitstream 
  do 
    local size = zfp.zfp_stream_maximum_size(
      zfp_stream, 
      zfp_field)

    buffer = ffi.new('uchar[?]', size)
    bitstream = zfp.stream_open(buffer, size)
    zfp.zfp_stream_set_bit_stream(zfp_stream, bitstream)
  end

  local compressed
  do 
    local size = zfp.zfp_compress(zfp_stream, zfp_field)
    zfp.zfp_stream_flush(zfp_stream)
    compressed = ffi.new('uchar[?]', size)
    ffi.copy(compressed, buffer, size)
  end

  if WRITE_EVERYTHING then
    local outpath = ('%s/%s'):format(COMPRESSED_DIRECTORY, name)
    local outfile = io.open(outpath, 'wb')

    ffi.C.fwrite(
      compressed,
      ffi.sizeof('uchar'),
      ffi.sizeof(compressed) / ffi.sizeof('uchar'),
      outfile)

    outfile:close()
  end

  dload(name).zfp_stream = zfp_stream 
  dload(name).zfp_field = zfp_field 

  return compressed
end

local function decompress(array, name)
  local zfp = lib.zfp

  zfp.zfp_stream_rewind(dload(name).zfp_stream)
  
  local size = zfp.zfp_decompress(
    dload(name).zfp_stream, 
    dload(name).zfp_field) -- can replace w/header reading/writing

  if WRITE_EVERYTHING then
    local outpath = ('%s/%s'):format(DECOMPRESSED_DIRECTORY, name)
    local outfile = io.open(outpath, 'wb')

    ffi.C.fwrite(
      array,
      ffi.sizeof('uint8_t'),
      size,
      outfile)

    outfile:close()
  end

  local floats = ffi.new(DATA_TYPE .. '[?]', 
    size / ffi.sizeof(DATA_TYPE))

  ffi.copy(floats, array, size)

  return floats 
end

local function reconvert(array, name)
  -- not really sure how to approach this. metadata header i guess?
end

local function test()
  for name in lfs.dir(UNCOMPRESSED_DIRECTORY) do 
    if not name:match('^%.') and not SKIPPABLE_FILES[name] then 
      dstore(name, {})
      local array = toarray(name)
      local compressed = compress(array, name)
      local decompressed = decompress(compressed, name)
      reconvert(decompressed, name)
      dprint('Finished test for: ' .. name)
    end
  end
end

local function main()
  assert(DATA_TYPE == 'float', 
    'Application does not currently support the selected data type.') 

  test()
end

main()