--
-- euSQLite 0.4 - A SQLite wrapper
--
-- (c) 2002 Ray Smith
-- smithr@ix.net.au
--
-- converted SQLite 2.8.15 21/12/2004 C M Burch
-- converted SQLite 3.0.8 21/12/2004 C M Burch
--
-- Version 0.3 by Tone Skoda on 24th August 2005:
-- - additional wrappers were added
-- - fatal errors are automatically reported
-- - renamed my_sqlite3_* to xsqlite3_* and made them global
-- - renamed myLib to sqlite3_dll and made it global
-- - and other small additions to code
-- Version 0.4 by J-M Duro on 21th July 2021:

-- Name :       EuSQLite3 - an SQLite wrapper
-- Version :    0.3
-- Author :     Ray Smith
-- License :    None
-- Updated :    Chris Burch
-- Updated :    August 2005 Tone Skoda
-- Updated :    July 2021 J-M Duro

------------------------------------------------------------------------------

-- Euphoria object compression and decompression
--
-- Copied from database.e and modified so that it works with RAM and not with file.
-- Tone Skoda, 26. August 2005

-- public constant DEBUG = 0, EXTRA_DEBUG = 0, APP_NAME = ""

------------------------------------------------------------------------------

include std/dll.e
include std/os.e
include std/machine.e
include std/console.e
include std/math.e
include std/convert.e
include std/error.e
with warning

ifdef WINDOWS then
export atom sqlite3 = open_dll( "sqlite3.20.dll" )

elsifdef LINUX then
export atom sqlite3 = open_dll( "/usr/lib/x86_64-linux-gnu/libsqlite3.so.0" )

elsedef
error:crash( "Platform not supported" )

end ifdef

function link_c_func(atom dll, sequence name, sequence args, atom result)
ifdef WINDOWS then
  atom handle = define_c_func(dll, "+"&name, args, result)
elsifdef LINUX then
  atom handle = define_c_func(dll, name, args, result)
elsedef
  error:crash( "Platform not supported" )
end ifdef
  if handle = -1 then
    error:crash("function " & name & " not found")
  end if
  return handle
end function

function link_c_proc(atom dll, sequence name, sequence args)
ifdef WINDOWS then
  atom handle = define_c_proc(dll, "+"&name, args)
elsifdef LINUX then
  atom handle = define_c_proc(dll, name, args)
elsedef
  error:crash( "Platform not supported" )
end ifdef
  if handle = -1 then
    error:crash("procedure " & name & " not found")
  end if
  return handle
end function

public constant
  _sqlite3_bind_blob         = link_c_func( sqlite3, "sqlite3_bind_blob",         {C_POINTER, C_INT, C_POINTER, C_INT,  C_POINTER}, C_INT ),
  _sqlite3_bind_double       = link_c_func( sqlite3, "sqlite3_bind_double",       {C_POINTER, C_INT, C_DOUBLE}, C_INT ),
  _sqlite3_bind_int          = link_c_func( sqlite3, "sqlite3_bind_int",          {C_POINTER, C_INT, C_INT}, C_INT ),
  _sqlite3_bind_text         = link_c_func( sqlite3, "sqlite3_bind_text",         {C_POINTER, C_INT, C_POINTER, C_INT,  C_POINTER}, C_INT ),
  _sqlite3_changes           = link_c_func( sqlite3, "sqlite3_changes",           {C_POINTER}, C_INT ),
  _sqlite3_close             = link_c_proc( sqlite3, "sqlite3_close",             {C_POINTER}  ),
  _sqlite3_column_blob       = link_c_func( sqlite3, "sqlite3_column_blob",       {C_POINTER, C_INT}, C_POINTER ),
  _sqlite3_column_bytes      = link_c_func( sqlite3, "sqlite3_column_bytes",      {C_POINTER, C_INT}, C_POINTER ),
  _sqlite3_column_int        = link_c_func( sqlite3, "sqlite3_column_int",        {C_POINTER, C_INT}, C_INT ),
  _sqlite3_column_text       = link_c_func( sqlite3, "sqlite3_column_text",       {C_POINTER, C_INT}, C_POINTER ),
  _sqlite3_errmsg            = link_c_func( sqlite3, "sqlite3_errmsg",            {C_POINTER}, C_POINTER ),
  _sqlite3_exec              = link_c_func( sqlite3, "sqlite3_exec",              {C_POINTER, C_POINTER, C_POINTER, C_POINTER, C_POINTER}, C_INT ),
  _sqlite3_finalize          = link_c_func( sqlite3, "sqlite3_finalize",          {C_POINTER}, C_INT ),
  _sqlite3_free              = link_c_proc( sqlite3, "sqlite3_free",              {C_POINTER}  ),
  _sqlite3_free_table        = link_c_proc( sqlite3, "sqlite3_free_table",        {C_POINTER}  ),
  _sqlite3_get_table         = link_c_func( sqlite3, "sqlite3_get_table",         {C_POINTER, C_POINTER, C_POINTER,  C_INT, C_INT, C_POINTER}, C_INT ),
  _sqlite3_last_insert_rowid = link_c_func( sqlite3, "sqlite3_last_insert_rowid", {C_POINTER}, C_INT ),
  _sqlite3_libversion        = link_c_func( sqlite3, "sqlite3_libversion",        {}, C_POINTER ),
  _sqlite3_open              = link_c_func( sqlite3, "sqlite3_open",              {C_POINTER, C_POINTER}, C_INT ),
  _sqlite3_prepare           = link_c_func( sqlite3, "sqlite3_prepare",           {C_POINTER, C_POINTER, C_INT,  C_POINTER, C_POINTER}, C_INT ),
  _sqlite3_reset             = link_c_func( sqlite3, "sqlite3_reset",             {C_POINTER}, C_INT ),
  _sqlite3_step              = link_c_func( sqlite3, "sqlite3_step",              {C_POINTER}, C_INT ),
$

sequence Bytes -- read from here instead from file
integer Byte_pos -- instead of file position

-- Compressed format of Euphoria objects on disk
--
-- First byte:
--          0..248    -- immediate small integer, -9 to 239
          -- since small negative integers -9..-1 might be common
constant
  I2B = 249,   -- 2-byte signed integer follows
  I3B = 250,   -- 3-byte signed integer follows
  I4B = 251,   -- 4-byte signed integer follows
  F4B = 252,   -- 4-byte f.p. number follows
  F8B = 253,   -- 8-byte f.p. number follows
  S1B = 254,   -- sequence, 1-byte length follows, then elements
  S4B = 255    -- sequence, 4-byte length follows, then elements

constant
  MIN1B = -9,
  MAX1B = 239,
  MIN2B = -power(2, 15),
  MAX2B =  power(2, 15)-1,
  MIN3B = -power(2, 23),
  MAX3B =  power(2, 23)-1,
  MIN4B = -power(2, 31)

-- emulation of getc(); this one reads from sequence and not from file.
-- this helps for easier translation of decompress_() to read from sequence and not from file.
-- i didn't need to modify decompress_() except change getc() to getc_() and
-- get4() to get4_()
function getc_ ()
  integer c = Bytes [Byte_pos]
  Byte_pos += 1
  return c
end function

atom mem0 = allocate(4)
atom mem1 = mem0 + 1
atom mem2 = mem0 + 2
atom mem3 = mem0 + 3

-- emulation of get4()
-- read 4-byte value at current position in sequence
function get4_()
  poke(mem0, getc_())
  poke(mem1, getc_())
  poke(mem2, getc_())
  poke(mem3, getc_())
  return peek4u(mem0)
end function

function decompress_(integer c)
  sequence s
  integer len

  if c = 0 then
    c = getc_()
    if c < I2B then
      return c + MIN1B
    end if
  end if

  if c = I2B then
    return getc_() + #100 * getc_() + MIN2B
  elsif c = I3B then
    return getc_() + #100 * getc_() + #10000 * getc_() + MIN3B
  elsif c = I4B then
    return get4_() + MIN4B
  elsif c = F4B then
    return float32_to_atom({getc_(), getc_(), getc_(), getc_()})
  elsif c = F8B then
    return float64_to_atom({getc_(), getc_(), getc_(), getc_(), getc_(), getc_(),  getc_(), getc_()})
  else
    -- sequence
    if c = S1B then
      len = getc_()
    else
      len = get4_()
    end if
    s = repeat(0, len)
    for i = 1 to len do
      -- in-line small integer for greater speed on strings
      c = getc_()
      if c < I2B then
        s[i] = c + MIN1B
      else
        s[i] = decompress_(c)
      end if
    end for
    return s
  end if
end function

-- decompress a sequence of bytes which should represent
-- a Euphoria object, and return it
public function decompress (sequence bytes)
  Bytes = bytes
  Byte_pos = 1
  return decompress_ (0)
end function

-- return the compressed representation of a Euphoria object
-- as a sequence of bytes
public function compress(object x)
  sequence x4, s

  if integer(x) then
    if x >= MIN1B and x <= MAX1B then
      return {x - MIN1B}
    elsif x >= MIN2B and x <= MAX2B then
      x -= MIN2B
      return {I2B, and_bits(x, #FF), floor(x / #100)}
    elsif x >= MIN3B and x <= MAX3B then
      x -= MIN3B
      return {I3B, and_bits(x, #FF), and_bits(floor(x / #100), #FF), floor(x / #10000)}
    else
      return I4B & int_to_bytes(x-MIN4B)
    end if

  elsif atom(x) then
    -- floating point
    x4 = atom_to_float32(x)
    if x = float32_to_atom(x4) then
      -- can represent as 4-byte float
      return F4B & x4
    else
      return F8B & atom_to_float64(x)
    end if

  else
    -- sequence
    if length(x) <= 255 then
      s = {S1B, length(x)}
    else
      s = S4B & int_to_bytes(length(x))
    end if
    for i = 1 to length(x) do
      s &= compress(x[i])
    end for
    return s
  end if
end function

------------------------------------------------------------------------------

global constant
  SQLITE_OK           =   0,   -- Successful result
  SQLITE_ERROR        =   1,   -- SQL error or missing database
  SQLITE_INTERNAL     =   2,   -- An internal logic error in SQLite
  SQLITE_PERM         =   3,   -- Access permission denied
  SQLITE_ABORT        =   4,   -- Callback routine requested an abort
  SQLITE_BUSY         =   5,   -- The database file is locked
  SQLITE_LOCKED       =   6,   -- A table in the database is locked
  SQLITE_NOMEM        =   7,   -- A malloc() failed
  SQLITE_READONLY     =   8,   -- Attempt to write a readonly database
  SQLITE_INTERRUPT    =   9,   -- Operation terminated by sqlite3_interrupt()
  SQLITE_IOERR        =  10,   -- Some kind of disk I/O error occurred
  SQLITE_CORRUPT      =  11,   -- The database disk image is malformed
  SQLITE_NOTFOUND     =  12,   -- (Internal Only) Table or record not found
  SQLITE_FULL         =  13,   -- Insertion failed because database is full
  SQLITE_CANTOPEN     =  14,   -- Unable to open the database file
  SQLITE_PROTOCOL     =  15,   -- Database lock protocol error
  SQLITE_EMPTY        =  16,   -- (Internal Only) Database table is empty
  SQLITE_SCHEMA       =  17,   -- The database schema changed
  SQLITE_TOOBIG       =  18,   -- Too much data for one row of a table
  SQLITE_CONSTRAINT   =  19,   -- Abort due to constraint violation
  SQLITE_MISMATCH     =  20,   -- Data type mismatch
  SQLITE_MISUSE       =  21,   -- Library used incorrectly
  SQLITE_NOLFS        =  22,   -- Uses OS features not supported on host
  SQLITE_AUTH         =  23,   -- Authorization denied
  SQLITE_ROW          = 100,   -- sqlite3_step() has another row ready
  SQLITE_DONE         = 101,   -- sqlite3_step() has finished executing

  SQLITE_STATIC       =   0,
  SQLITE_TRANSIENT    =  -1

--*************************************************
-- Globals
--*************************************************

public integer sqlite3_last_err_no = SQLITE_OK
public sequence sqlite3_last_err_desc = ""

public integer SQLITE_MAX_FIELD_LENGTH   = 32768  -- the maximum length of an individual column returned from exec and get_table
public integer SQLITE_MAX_ERR_LENGTH     =   128  -- the maximum length of error messages
public integer SQLITE_MAX_VERSION_LENGTH =    64  -- the maximum length of the version string

-------------------------------------------------------------------------------------

public function sqlite3_errmsg(atom db)
  atom message_addr = c_func(_sqlite3_errmsg, {db})
  sequence message = peek_string(message_addr)
  return message
end function

-------------------------------------------------------------------------------------

-- default fatal error handler - you can override this
procedure default_fatal(atom db, sequence on_command)
  error:crash("Fatal SQLite Error: " & sqlite3_last_err_desc &
              "\nWhen Executing: " & on_command &
              sprintf("\nError %d: %s\n\n", {sqlite3_last_err_no, sqlite3_errmsg(db)}))
end procedure

-- exception handler
public integer sqlite3_fatal_id = routine_id("default_fatal") -- you can set it to your own handler

-------------------------------------------------------------------------------------

public procedure sqlite3_close(atom db)
  c_proc(_sqlite3_close, {db})
end procedure

-------------------------------------------------------------------------------------

procedure fatal(atom db, sequence on_command)
  if db > 0 then sqlite3_close(db) end if
  call_proc(sqlite3_fatal_id, {db, on_command})
end procedure

-------------------------------------------------------------------------------------

-- Frees memory allocated from mprintf() or vmprintf().</digest>
-- Used internally by sqlite
public procedure sqlite3_free (atom addr)
  c_proc(_sqlite3_free, {addr})
end procedure

-------------------------------------------------------------------------------------

public function sqlite3_open(sequence filename)
  atom filename_addr = allocate_string(filename)  --put the filename into memory
  atom db_addr = allocate(4)                      --allocate memory for the db handle

  atom err_no = c_func(_sqlite3_open, {filename_addr, db_addr})
  atom db = peek4u(db_addr)
  sqlite3_last_err_no = err_no
  if err_no != SQLITE_OK then
    sqlite3_last_err_desc = sqlite3_errmsg(db)
    fatal(db, "sqlite3_open()")
  else
    sqlite3_last_err_desc = ""
  end if
  return db
end function

-------------------------------------------------------------------------------------

-- might need this one day
-----------------------------
-- sqlite3_exec_callback
-----------------------------
--procedure sqlite3_exec_callback(atom null_addr, integer cols, atom data_ptr,
--                              atom col_name_ptr)
--
--
--   return 0
--end function

-- returns SQLITE_OK, SQLITE_ABORT or SQLITE_BUSY
public function sqlite3_exec(atom db, sequence cmd)
  atom err_ptr_addr = allocate(4)
  poke4(err_ptr_addr, 0)
  atom cmd_addr = allocate_string(cmd)
  integer ret = c_func(_sqlite3_exec,{db, cmd_addr, NULL, NULL, err_ptr_addr})
-- if using a callback TODO
-- ret = c_func(_sqlite3_exec,{db, cmd_addr,
--                 call_back(routine_id(sqlite3_exec_callback)), NULL, err_ptr_addr})
  free(cmd_addr)
  sqlite3_last_err_no = SQLITE_OK
  sqlite3_last_err_desc = ""
  if ret != SQLITE_OK then
    sqlite3_last_err_no = ret
    atom err_addr = peek4u(err_ptr_addr)
    if err_addr > 0 then
      sqlite3_last_err_desc = peek_string(err_addr)  --, SQLITE_MAX_ERR_LENGTH)
      sqlite3_free(err_addr)
    end if
    if not find (ret, {SQLITE_ABORT, SQLITE_BUSY}) then
      fatal (db, "sqlite3_exec(\"" & cmd & "\"")
    end if
  end if
   return ret
end function

-------------------------------------------------------------------------------------

public procedure sqlite3_free_table(atom data_addr)
  c_proc(_sqlite3_free_table, {data_addr})
end procedure

-------------------------------------------------------------------------------------

public function sqlite3_get_table(atom db, sequence cmd)
  atom cmd_addr = allocate_string(cmd)
  atom col_addr = allocate(4)
  atom row_addr = allocate(4)
  atom err_ptr_addr = allocate(4)
  poke4(err_ptr_addr, 0)
  atom data_ptr_addr = allocate(4)

  integer ret = c_func(_sqlite3_get_table, {db, cmd_addr, data_ptr_addr, row_addr,
                       col_addr, err_ptr_addr})
  sqlite3_last_err_no = SQLITE_OK
  sqlite3_last_err_desc = ""
  if ret != SQLITE_OK then
    sqlite3_last_err_no = ret
    atom err_addr = peek4u(err_ptr_addr)
    if err_addr > 0 then
      sqlite3_last_err_desc = peek_string(err_addr)  --, SQLITE_MAX_ERR_LENGTH)
      sqlite3_free(err_addr)
    end if
    if not find (ret, {SQLITE_ABORT, SQLITE_BUSY}) then
      fatal (db, "sqlite3_get_table(\"" & cmd & "\"")
    end if
  end if

  integer col = peek4u(col_addr)
  integer row = peek4u(row_addr)
  atom data_addr = peek4u(data_ptr_addr)

  free(cmd_addr)
  free(col_addr)
  free(row_addr)
  free(err_ptr_addr)
  free(data_ptr_addr)

  sequence data = {}
  if row > 0 then
    atom tmp_ptr_addr = data_addr
    for r = 0 to row do
      sequence tmp_row = {}
      sequence tmp_field = {}
      for c = 1 to col do
        atom field_addr = peek4u(tmp_ptr_addr)
        if field_addr != 0 then
          tmp_field = peek_string(field_addr)  --, SQLITE_MAX_FIELD_LENGTH)
        else
          tmp_field = {}
        end if
        -- tmp_field = peek_string(peek4u(tmp_ptr_addr))  --, SQLITE_MAX_FIELD_LENGTH)
        tmp_ptr_addr += 4
        tmp_row = append(tmp_row, tmp_field)
      end for
      data = append(data, tmp_row)
    end for
  end if
  sqlite3_free_table(data_addr)
  return data
end function

-------------------------------------------------------------------------------------

public function sqlite3_changes( atom db )
  return c_func( _sqlite3_changes, {db} )
end function

-------------------------------------------------------------------------------------

public function sqlite3_libversion()
  atom addr = c_func(_sqlite3_libversion, {})
  return peek_string(addr)  -- , SQLITE_MAX_VERSION_LENGTH)
end function

-------------------------------------------------------------------------------------

public function sqlite3_prepare(atom db, sequence cmd)
  atom cmd_addr = allocate_string(cmd)
  atom stmt_ptr_addr = allocate (4)
  integer ret = c_func(_sqlite3_prepare,{db, cmd_addr, length (cmd), stmt_ptr_addr, 0})
  sqlite3_last_err_no = ret
  sqlite3_last_err_desc = ""
  if ret != SQLITE_OK then
    sqlite3_last_err_no = ret
    sqlite3_last_err_desc = sqlite3_errmsg (db)
    fatal (db, "sqlite3_prepare(\"" & cmd & "\")")
  end if
  atom stmt_addr = peek4u (stmt_ptr_addr)
  free(cmd_addr)
  free (stmt_ptr_addr)
  return stmt_addr
end function

-------------------------------------------------------------------------------------

-- Returns SQLITE_DONE, SQLITE_ROW, SQLITE_BUSY,
-- SQLITE_ERROR or SQLITE_MISUSE, see http://sqlite.org/capi3ref.html#sqlite3_step
-- SQLITE_ROW is returned if there were any row(s) found
-- and are ready to be read with sqlite3_column_* functions.
-- SQLITE_DONE is returned if there was no row found.
public function  sqlite3_step(atom db, atom stmt)
  integer ret = c_func(_sqlite3_step, {stmt})
  sqlite3_last_err_no = ret
  sqlite3_last_err_desc = ""
  if ret = SQLITE_DONE or ret = SQLITE_ROW or ret = SQLITE_BUSY then
    -- do nothing
  elsif ret = SQLITE_ERROR or ret = SQLITE_MISUSE then
    sqlite3_last_err_desc = sqlite3_errmsg (db)
    fatal (db, "sqlite3_step()")
  end if
  return ret
end function

-------------------------------------------------------------------------------------

public procedure sqlite3_reset(atom db, atom stmt)
  integer ret = c_func(_sqlite3_reset, {stmt})
  sqlite3_last_err_no = ret
  sqlite3_last_err_desc = ""
  if ret != SQLITE_OK then
    sqlite3_last_err_desc = sqlite3_errmsg (db)
    fatal (db, "sqlite3_reset()")
  end if
end procedure

-------------------------------------------------------------------------------------

-- can return SQLITE_ABORT, see http://sqlite.org/capi3ref.html#sqlite3_finalize
public function sqlite3_finalize(atom db, atom stmt)
  integer ret = c_func(_sqlite3_finalize, {stmt})
  sqlite3_last_err_no = ret
  sqlite3_last_err_desc = ""
  if ret != SQLITE_OK then
    sqlite3_last_err_desc = sqlite3_errmsg (db)
    if ret != SQLITE_ABORT then
      fatal (db, "sqlite3_finalize()")
    end if
  end if
  return ret
end function

-------------------------------------------------------------------------------------

public procedure sqlite3_bind_int(atom db, atom stmt, integer param_index, integer val)
  integer ret = c_func(_sqlite3_bind_int,{stmt, param_index, val})
  sqlite3_last_err_no = ret
  sqlite3_last_err_desc = ""
  if ret != SQLITE_OK then
    sqlite3_last_err_desc = sqlite3_errmsg (db)
    fatal (db, "sqlite3_bind_int()")
  end if
end procedure

-------------------------------------------------------------------------------------

public procedure sqlite3_bind_double(atom db, atom stmt, integer param_index, atom val)
  integer ret = c_func(_sqlite3_bind_double,{stmt, param_index, val})
  sqlite3_last_err_no = ret
  sqlite3_last_err_desc = ""
  if ret != SQLITE_OK then
    sqlite3_last_err_desc = sqlite3_errmsg (db)
    fatal (db, "sqlite3_bind_double()")
  end if
end procedure

-------------------------------------------------------------------------------------

public procedure sqlite3_bind_text(atom db, atom stmt, integer param_index, sequence val)
  atom val_addr = allocate_string (val)
  integer ret = c_func(_sqlite3_bind_text,{stmt, param_index, val_addr,
                       length (val), SQLITE_TRANSIENT})
      -- SQLITE_STATIC})
      -- call_back (routine_id ("my_free"))}) -- this is very slow, i don't know why
  -- free (val_addr)
  sqlite3_last_err_no = ret
  sqlite3_last_err_desc = ""
  if ret != SQLITE_OK then
    sqlite3_last_err_desc = sqlite3_errmsg (db)
    fatal (db, "sqlite3_bind_text()")
  end if
end procedure

-------------------------------------------------------------------------------------

-- it compresses Euphoria object on the same way as EDS
public procedure sqlite3_bind_blob(atom db, atom stmt, integer param_index, object val)
  sequence val_string = compress(val)
  atom val_addr = allocate (length (val_string))
  poke (val_addr, val_string)
  integer ret = c_func(_sqlite3_bind_blob,{stmt, param_index, val_addr,
                       length (val_string), SQLITE_TRANSIENT})
      -- SQLITE_STATIC})
      -- call_back (routine_id ("my_free"))}) -- this is very slow, i don't know why
  -- free (val_addr)
  sqlite3_last_err_no = ret
  sqlite3_last_err_desc = ""
  if ret != SQLITE_OK then
    sqlite3_last_err_desc = sqlite3_errmsg (db)
    fatal (db, "sqlite3_bind_blob()")
  end if
end procedure

-------------------------------------------------------------------------------------

-- column_num is 1-based
public function sqlite3_column_int(atom db, atom stmt, integer column_num)
  return c_func(_sqlite3_column_int,{stmt, column_num - 1})
end function

-------------------------------------------------------------------------------------

-- column_num is 1-based
public function sqlite3_column_bytes(atom db, atom stmt, integer column_num)
  return c_func(_sqlite3_column_bytes, {stmt, column_num - 1})
end function

-------------------------------------------------------------------------------------

-- column_num is 1-based
public function sqlite3_column_text(atom db, atom stmt, integer column_num)
  atom addr = c_func(_sqlite3_column_text, {stmt, column_num - 1})
  if addr then
    atom nBytes = c_func(_sqlite3_column_bytes, {stmt, column_num - 1})
    return peek ({addr, nBytes})
  else
    fatal(db, "sqlite3_column_text(): can't get text")
    return ""
  end if
end function

-------------------------------------------------------------------------------------

-- column_num is 1-based
public function sqlite3_column_blob(atom db, atom stmt, integer column_num)
  atom addr = c_func(_sqlite3_column_blob, {stmt, column_num - 1})
  if addr then
    atom nBytes = c_func(_sqlite3_column_bytes, {stmt, column_num - 1})
    sequence val_string = peek ({addr, nBytes})
    return decompress (val_string)
  else
    fatal(db, "sqlite3_column_blob(): can't get data")
    return -1
  end if
end function

-------------------------------------------------------------------------------------

-- gets the last inserted row_id from open database db
-- remember, to get the last inserted row, need to  work on an open database,
-- where the data has just been inserted
public function sqlite3_last_insert_rowid(atom db)
  atom row_id = c_func(_sqlite3_last_insert_rowid, {db})
  return row_id
end function

--------------------------------------------------------------------------------

public function exec_sql_command(atom sql_db, sequence cmd)
  sequence data = sqlite3_get_table(sql_db, cmd)
  if sqlite3_last_err_no != SQLITE_OK then
    sequence msg = sprintf("Command: %s\nError %d: %s\n", {cmd, sqlite3_last_err_no, sqlite3_last_err_desc})
    puts(2, msg & "\n")
  end if
  return data
end function
