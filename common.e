namespace common

ifdef PHIX then
elsedef 
  include std/types.e
  include std/dll.e
  include std/filesys.e
  include std/os.e
  include std/math.e
  include std/error.e
  include std/io.e
  include std/graphics.e
  include std/console.e
  include std/sequence.e
  include std/text.e
  include std/search.e
  include std/wildcard.e
  include std/convert.e
  include std/pretty.e
  include std/pipeio.e as pipe
ifdef WINDOWS then
  include std/win32/msgbox.e
end ifdef 
  include euphoria/info.e
end ifdef 

public integer eu_version = 0

public constant
  EU_4_1_LNX_64 = 1, EU_4_1_LNX_32 = 2, EU_4_0_LNX = 3, PHIX_LNX_64 = 4, PHIX_LNX_32 = 5,
  EU_4_1_WIN_64 = 6, EU_4_1_WIN_32 = 7, EU_4_0_WIN = 8, PHIX_WIN_64 = 9, PHIX_WIN_32 = 10

public constant
  NOTSET = 0, CRITICAL = 1, ERROR = 2, WARNING = 3, INFO = 4, DEBUG = 5

global integer f_debug = 1    -- debug file
global integer debug_level = WARNING  -- if set, log_puts and log_printf will write to debug file
global integer debug_time_stamp = 0   -- if set, log_puts and log_printf will add a time stamp

sequence cmd = command_line()
public sequence ExecDir = pathname(cmd[2]) & SLASH  -- directory where the program is located

public sequence InitialDir
ifdef PHIX then
  InitialDir = current_dir() & SLASH
elsedef 
  InitialDir = init_curdir()
end ifdef 

-- puts(1, "InitialDir: " & InitialDir & "\n")

public object void = 0  -- Dummy object used when function return value is unused

public constant
  ON = 1, OFF = 0, SUCCESS = 1, FAIL = 0

public constant CONTINUE_WALKING=0, STOP_WALKING=1, STOP_DEEPENING=2

--------------------------------------------------------------------------------

public procedure log_puts(sequence msg="", integer level=debug_level,
                          integer time_stamp=debug_time_stamp, integer pfx=1)
  --printf(1, "log_puts(msg='%s', level=%d, time_stamp=%d)\n", {show_printable(msg), level, time_stamp})
  sequence dt = date()
  sequence prefix = ""
  if (f_debug = 0) or (level = NOTSET) then return end if
  if (level < debug_level) or length(msg) = 0 then return end if
  if time_stamp then
    prefix = sprintf("[%d-%02d-%02d %02d:%02d:%02d] ",
                     {dt[1]+1900, dt[2], dt[3], dt[4], dt[5], dt[6]})
  end if
  if pfx then
    switch level do
      case DEBUG then
        prefix &= "[DEBUG] "
      case INFO then
        prefix &= "[INFO] "
      case WARNING then
        prefix &= "[WARNING] "
      case ERROR then
        prefix &= "[ERROR] "
      case CRITICAL then
        prefix &= "[CRITICAL] "
    end switch
  end if
  puts(f_debug, prefix & msg)
  flush(f_debug)
end procedure

--------------------------------------------------------------------------------

public procedure log_printf(sequence format, object value, integer level=debug_level,
                            integer time_stamp=debug_time_stamp, integer pfx=1)
  sequence msg = sprintf(format, value)
  log_puts(msg, level, time_stamp, pfx)
end procedure

--------------------------------------------------------------------------------

public procedure error_message(sequence msg, atom quit)
  log_puts(msg, ERROR)
ifdef WINDOWS then
  void = message_box(msg, "Error", MB_ICONERROR+MB_OK+MB_APPLMODAL+MB_SETFOREGROUND)
elsifdef LINUX then
  puts(2, "Error: " & msg & "\n")
end ifdef
  if quit then
    if f_debug then close(f_debug) end if
    abort(1)
  end if
end procedure

------------------------------------------------------------------------------

public function hexify(sequence data)
  integer lg = length(data)
  sequence binary = ""
  for i = 1 to lg do
    if data[i] < 0 then data[i] += #100 end if
    binary &= sprintf(" %02x", data[i])
  end for
  return binary[2..$]
end function

------------------------------------------------------------------------------

-- dumps a sequence in hex form to the specified output</digest>
-- example:
-- hex_dump("0123456789ABCDEF"&0&1&2&3&4)
-- Address   0  1  2  3  4  5  6  7  8   9  A  B  C  D  E  F  |  0123456789ABCDEF
-- ------------------------------------------------------------------------------
-- 000000:  30 31 32 33 34 35 36 37 38  39 41 42 43 44 45 46  |  0123456789ABCDEF
-- 000010:  00 01 02 03 04                                    |  .....
public procedure hexDump(sequence data, integer offset=0, integer level=debug_level)
  sequence address, binary, ascii
  integer lg = length(data)
  integer start = floor(offset/16)*16
  integer stop = ceil((offset+lg)/16)*16
  -- printf(1, "start = %06x, stop = %06x\n", {start, stop})

  if (f_debug = 0) or (level = NOTSET) then return end if
  if (level < debug_level) or (lg = 0) then return end if
  puts(f_debug, "\nAddress   0  1  2  3  4  5  6  7   8  9  A  B  C  D  E  F  |  0123456789ABCDEF\n")
  puts(f_debug, repeat('-', 78) & "\n")
  address = sprintf("%06x: ", start)
  binary = ""
  ascii  = "  |  "
  for i = start to stop-1 do
    if (i < offset) or (i >= offset + lg) then
      binary &= "   "
      ascii &= " "
    else
      integer char = data[i-offset+1]
      if char < 0 then char += #100 end if
      binary &= sprintf(" %02x", char)
      if (char > 31) and (char < 127) then
        ascii &= char
      else
        ascii &= "."
      end if
    end if
    if length(binary) = 24 then
      binary &= " "
    end if
    if (remainder(i, 16) = 15) then
      puts(f_debug, address&binary&ascii&"\n")
      address = sprintf("%06x: ", floor((i+1)/16)*16)
      binary = ""
      ascii  = "  |  "
    end if
  end for
  lg = length(binary)
  if lg then
    puts(f_debug, address&sprintf("%-49s", {binary})&ascii&"\n")
  end if
  puts(f_debug, "\n")
  flush(f_debug)
end procedure

--------------------------------------------------------------------------------

public function get_key_index(object what, sequence where, sequence key)
  for i = 1 to length(where) do
    if equal(key, where[i][1]) and equal(what, where[i][2])then
      return i
    end if
  end for
  return 0
end function

--------------------------------------------------------------------------------

public function get_all_keys(object what, sequence where, sequence key)
  sequence result = {}
  for i = 1 to length(where) do
    if equal(key, where[i][1]) and equal(what, where[i][2])then
      result = append(result, i)
    end if
  end for
  return result
end function

--------------------------------------------------------------------------------

-- lightweight alternative to vlookup
public function get_key_value(object key, sequence list, object def)
-- extracts an option value from a list of {key, value} list
  for i = 1 to length(list) do
    if equal(key, list[i][1]) then
      return list[i][2]
    end if
  end for
  return def
end function

--------------------------------------------------------------------------------

-- executes a command on the system
public function exec_command(sequence cmd)
  sequence s = ""
  object z = pipe:create()
  object p = pipe:exec(cmd, z)
  if atom(p) then
    error_message(sprintf("Failed to exec() with error %x", pipe:error_no()), 0)
    pipe:kill(p)
    return -1
  end if
  object c = pipe:read(p[pipe:STDOUT], 256)
  while sequence(c) and length(c) do
    s &= c
    if atom(c) then
      error_message(sprintf("Failed on read with error %x", pipe:error_no()), 0)
      pipe:kill(p)
      return -1
    end if
    c = pipe:read(p[pipe:STDOUT], 256)
  end while
  --Close pipes and make sure process is terminated
  pipe:kill(p)
  return s
end function

--------------------------------------------------------------------------------

constant EU_VERSION_NAME = {
  "EU_4_1_LNX_64", "EU_4_1_LNX_32", "EU_4_0_LNX", "PHIX_LNX_64", "PHIX_LNX_32",
  "EU_4_1_WIN_64", "EU_4_1_WIN_32", "EU_4_0_WIN", "PHIX_WIN_64", "PHIX_WIN_32"
}

public function eu_version_name()
  return EU_VERSION_NAME[eu_version]
end function

--------------------------------------------------------------------------------

public function is_string(object x)
-- checks if a sequence represents a string
  if not sequence(x) then return 0 end if
  if length(x) = 0 then return 1 end if
  for i = 1 to length(x) do
    if sequence(x[i]) then
      return 0
    elsif x[i] > 254 then
      return 0
    elsif (x[i] < 32) and not find(x[i], {9, 10, 13}) then
      return 0
    end if
  end for
  return 1
end function

--------------------------------------------------------------------------------

public function is_number(sequence s)
  return atom(to_number(s, -1))
end function

--------------------------------------------------------------------------------

public function show_printable(object s, integer highest=127)
-- returns only printable characters of a sequence
-- non printable characters are replace by a dot
  if atom(s) then s = {s} end if
  sequence res = ""
  for i = 1 to length(s) do
    if sequence(s[i]) then
        res &= "{}"
    elsif integer(s[i]) then
      if (s[i] > 31) and (s[i] < highest) then
        res &= s[i]
      elsif s[i] = 8 then
        res &= "[bksp]"
      elsif s[i] = 9 then
        res &= "[tab]"
      elsif s[i] = 10 then
        res &= "[lf]"
      elsif s[i] = 11 then
        res &= "[vtab]"
      elsif s[i] = 12 then
        res &= "[ff]"
      elsif s[i] = 13 then
        res &= "[cr]"
      else
        res &= "."
      end if
    else
      res &= "."
    end if
  end for
  return res
end function

--------------------------------------------------------------------------------

public function object_dump(object x, integer max_level=3, integer level=0)
  integer subSequence
  sequence s

--  analyze_object(x, "x")
  s = ""
  if integer(x) then
    s = pretty_sprint(x, {1})  --sprintf("%d'%s'", {x, show_printable({x}, 254)})
  elsif atom(x) then
    if (x >= 0) and (x = floor(x)) then
      s = sprintf("%.0f", {x})
    elsif (x < 0) and (x = floor(x+1)) then
      s = sprintf("%.0f", {x})
    else
      s = sprintf("%f", {x})
    end if
  elsif is_string(x) then
    if length(x) = 0 then
      s = "''"
    else
      s = pretty_sprint(x, {2})  --sprintf("'%s'", {show_printable(x, 254)})
    end if
  else
    if level > max_level then return "..." end if
    subSequence = 0
    for i=1 to length(x) do
      if sequence(x[i]) then
        subSequence = 1
        exit
      end if
    end for
    if subSequence = 0 then
      --if is_string(x) then
      --  s = pretty_sprint(x, {2})  --sprintf("'%s'", {show_printable(x, 254)})
      --else
        s = pretty_sprint(x, {1})  --sprintf("%s", {sprint(x)})
      --end if
    elsif length(x) then
      s = "{" & object_dump(x[1], max_level, level+1)
      if length(x) > 1 then
        for i=2 to length(x) do
          s &= ", " & object_dump(x[i], max_level, level+1)
        end for
      end if
      s &= "}"
    end if
  end if
  return s
end function

--------------------------------------------------------------------------------

public procedure analyze_object(object x, sequence Name, integer dbg_lvl=debug_level,
                                integer time_stamp=debug_time_stamp, integer pfx=1,
                                sequence path={}, integer level=0, sequence prefix="")
-- prints a sequence structure in a human readable way
  sequence offset = "  "
  if level=0 then
    offset = ""
    log_printf("%s =", {Name}, dbg_lvl, time_stamp, pfx)
  end if
  for i = 1 to level-1 do offset &= ".  " end for
  sequence s = ""
  if atom(x) then
    log_printf("%s%s %s\n", {offset, prefix, pretty_sprint(x, {1})}, dbg_lvl, 0, 0)
  else
    integer subSequence = 0
    for i=1 to length(x) do
      if sequence(x[i]) then
        subSequence = 1
        exit
      end if
    end for
    if subSequence = 0 then
      if is_string(x) then
        if length(x) = 0 then
          s = "''"
        else
          s = pretty_sprint(x, {2})
        end if
      else
        s = pretty_sprint(x, {1})
      end if
      log_printf("%s%s %s\n", {offset, prefix, s}, dbg_lvl, 0, 0)
    else
      if length(s) = 0 then
        log_puts(offset&prefix&"\n", dbg_lvl, 0, 0)
      end if
      for i=1 to length(x) do
        prefix = sprintf("[%d]", i)
        analyze_object(x[i], Name, dbg_lvl, 0, 0, path&i, level+1, prefix)
      end for
    end if
  end if
end procedure

--------------------------------------------------------------------------------

public function path_exists(object structure, sequence targetPath,
                     sequence currentPath={})
  if equal(currentPath, targetPath) then
    return 1
  else
    integer digit = targetPath[length(currentPath)+1]
    if digit <= length(structure) then
      return path_exists(structure[digit], targetPath, currentPath&digit)
    else
      return 0
    end if
  end if
end function

--------------------------------------------------------------------------------

function get_nested(object structure, sequence targetPath, object def=0,
                    sequence currentPath={})
  if equal(currentPath, targetPath) then
    return structure
  else
    integer digit = targetPath[length(currentPath)+1]
    if digit <= length(structure) then
      return get_nested(structure[digit], targetPath, def, currentPath&digit)
    else
      return def
    end if
  end if
end function

--------------------------------------------------------------------------------

function set_nested(object structure, sequence targetPath, object x,
                    sequence currentPath={})
  integer digit = targetPath[length(currentPath)+1]
  for i = 1 to digit do
    if i > length(structure) then
      structure = append(structure, {})
    end if
    if i = digit then
      if equal(currentPath&{i}, targetPath) then
        structure[i] = x
      else
        structure[i] = set_nested(structure[i], targetPath, x, currentPath&i)
      end if
    end if
  end for
  return structure
end function

--------------------------------------------------------------------------------

function remove_nested(object structure, sequence targetPath,
                       sequence currentPath={})
  integer digit = targetPath[length(currentPath)+1]
  if digit <= length(structure) then
    if equal(currentPath&{digit}, targetPath) then
      structure = remove(structure, digit)
    else
      structure[digit] = remove_nested(structure[digit], targetPath,
                                       currentPath&digit)
    end if
  end if
  return structure
end function

--------------------------------------------------------------------------------

public function nested_set(object structure, sequence targetPath, object x)
  if length(targetPath) = 0 then
    crash_message("Target path cannot be empty!\n")
  end if
  return set_nested(structure, targetPath, x)
end function

--------------------------------------------------------------------------------

public function nested_get(object structure, sequence targetPath, object def=0)
  if length(targetPath) = 0 then
    crash_message("Target path cannot be empty!\n")
  end if
  return get_nested(structure, targetPath, def)
end function

--------------------------------------------------------------------------------

public function nested_remove(object structure, sequence targetPath)
  if length(targetPath) = 0 then
    crash_message("Target path cannot be empty!\n")
  end if
  return remove_nested(structure, targetPath)
end function

------------------------------------------------------------------------------

public function is_quoted(sequence str, object quotes='"')
  if (length(str) > 1) then
    if atom(quotes) then
      if (str[1]=quotes) and (str[$]=quotes) then
        return 1
      end if
    else
      if (length(quotes) = 2) and (str[1]=quotes[1]) and (str[$]=quotes[2]) then
        return 1
      end if
    end if
  end if
  return 0
end function

---------------------------------------------------------------------------------

-- remove leading and trailing spaces of a line
-- replace tabs with spaces and replace subsequent spaces by one only
public function trim_spaces(sequence s)
  sequence result
  integer lg

  result = ""
  s = trim(s)
  lg = length(s)
  if lg = 0 then return "" end if
  if s[1] = '\t' then s[1] = " " end if
  if s[1] != ' ' then result &= {s[1]} end if
  if lg > 1 then
    for i = 2 to lg do
      if s[i] = '\t' then s[i] = ' ' end if
      if s[i] != ' ' then
        result &= {s[i]}
      else
        if s[i-1] != ' ' then result &= {s[i]} end if
      end if
    end for
  end if
  return result
end function

------------------------------------------------------------------------------

-- find staring and ending line of a section in an INI file
function find_ini_section(sequence sec, sequence lines)
  integer from = 0, upto = 0
  if begins({#EF,#BB,#BF}, lines[1]) then  -- UTF-8 BOM
    lines[1] = remove(lines[1], 1, 3)
  end if
  integer ok = 0
  for i = 1 to length( lines ) do
    if length(lines[i]) then
      -- check section
      if lines[i][1] = '[' then
        if from > 0 then upto = i - 1 end if
        integer p = find(']', lines[i])
        if p = 0 then
          log_puts("Missing closing bracket: exiting", ERROR)
          return 0
        end if
        if equal(lines[i][2..p-1], sec) then from = i end if
      end if
    end if
  end for
  if from and not upto then
    upto = length(lines)
  end if
  return {from, upto}
end function

------------------------------------------------------------------------------

-- read a parameter value in an INI file
public function read_ini(sequence fname, sequence sec, sequence name,
                         sequence default)
  log_printf("read_ini(%s, %s, %s, %s)\n", {fname, sec, name, default})
  integer from = 0, upto = 0
  if not file_exists(fname) then return 0 end if
  sequence lines = read_lines(fname)
  object section = find_ini_section(sec, lines)
  if atom(section) then return 0 end if
  {from, upto} = section
  for i = from to upto do
    if length(lines[i]) then
      -- read params
      lines[i] = trim_head(lines[i])
      if (length(lines[i]) > 0) and not begins(";", lines[i]) then
        sequence params = split(lines[i], '=')
        if equal(name, trim(params[1])) then  -- param matches
          return trim(params[2])
        end if
      end if
    end if
  end for
  return default
end function

------------------------------------------------------------------------------

-- write an parameter in an INI file
public procedure write_ini(sequence fname, sequence sec, sequence name,
                    sequence Value)
  log_printf("write_ini(%s, %s, %s, %s)\n", {fname, sec, name, Value})
  integer from = 0, upto = 0
  sequence lines = {}, BOM = ""
  if file_exists(fname) then
    lines = read_lines(fname)
    if begins({#EF,#BB,#BF}, lines[1]) then  -- UTF-8 BOM
      BOM = {#EF,#BB,#BF}
      lines[1] = remove(lines[1], 1, 3)
    end if
  end if
  object section = find_ini_section(sec, lines)
  if atom(section) then
    lines = append(lines, "\n[" & sec & "]")
    lines = append(lines, name & "=" & Value)
  else
    {from, upto} = section
    integer existing = 0
    for i = from to upto do
      if length(lines[i]) then
        -- read params
        lines[i] = trim_head(lines[i])
        if (length(lines[i]) > 0) and not begins(";", lines[i]) then
          sequence params = split(lines[i], '=')
          if equal(name, trim(params[1])) then  -- param matches
            lines[i] = name & "=" & Value
            existing = 1
            exit
          end if
        end if
      end if
    end for
    if not existing then
      if upto < length(lines) then
        lines = insert(lines, upto, name & "=" & Value)
      else    
        lines = append(lines, name & "=" & Value)
      end if
    end if
  end if
  write_lines(fname,  lines)
end procedure

--------------------------------------------------------------------------------

public function replace_all(sequence s, sequence old, sequence new)
  integer lg = length(old)
  integer index = match(old, s, 1)
  while index != 0 do
    s = replace(s, new, index, index+lg-1)
    index = match(old, s, index+lg)
  end while
  return s
end function

--------------------------------------------------------------------------------

public function unescape(sequence str)
  sequence result = ""
  if length(str) = 0 then
    return result
  end if
  integer i = 1
  while i < length(str) do
    if equal(str[i..i+1], "\\n") then
      result &= "\n"
      i += 1
    elsif equal(str[i..i+1], "\\r") then
      result &= "\r"
      i += 1
    elsif equal(str[i..i+1], "\\t") then
      result &= "\t"
      i += 1
    elsif not find(str[i..i+1], {"\\\"", "\\'", "\\\\"}) then
      result &= str[i]
    end if
    i += 1
  end while
  if i <= length(str) then result &= str[i] end if
  return result
end function

--------------------------------------------------------------------------------

public function split_string(sequence str, object sep=" ", integer as_is=0,
                             integer keep=0)
  sequence t

  sequence result = {}
  integer slen = length(str)
  if slen = 0 then return result end if
  if atom(sep) then sep = {sep} end if

  sequence s = {}
  integer isWithin = 0      -- if 1, index is within double quotes
  integer lg = length(sep)
  integer i = 1
  while i <= slen do
    if (str[i] = '"') and not find('"', sep) then
      s = s & str[i]
      if (i = 1) or (str[i-1] != '\\') then
        if isWithin = 0 then
          isWithin = 1
        else
          isWithin = 0
        end if
      end if
    elsif as_is = 0 then
      if isWithin = 0 and find(str[i], sep) then
        t = trim(s)
        -- if length(t) then result = append(result, t) end if
        result = append(result, t)
        if keep then result = append(result, str[i]) end if
        s = {}
      else
        s = s & str[i]
      end if
    elsif as_is = 1 then
      if (isWithin = 0) and (i < slen-lg) and (match(sep, str[i..$])=1) then
        t = trim(s)
        -- if length(t) then result = append(result, t) end if
        result = append(result, t)
        i += lg-1
        if keep then result = append(result, sep) end if
        s = {}
      else
        s = s & str[i]
      end if
    end if
    i += 1
  end while
  t = trim(s)
  if length(t) then result = append(result, t) end if
  return result
end function

--------------------------------------------------------------------------------

public function append_if_new(sequence s, object o)
  if find(o, s) then
    return s
  else
    return append(s, o)
  end if
end function

--------------------------------------------------------------------------------

-- processes specific structure elements
-- valid_rtn, if used, identifies elements to be processed (defaults to all structure items)
-- walk_rtn defines actions to be done on selected structure elements
-- child_field iedntifies which field of a selected element leads to sub-items
-- paths is the path to the root element
-- params defines parameters to be transmitted to walk_rtn (as can be an eventual depth criteria)
-- result is the result of all processings to the structure
public function walk_sequence(object x, integer walk_rtn, integer valid_rtn=0,
                              integer child_field, sequence path={},
                              sequence params={}, sequence result={})
  integer  n = 0, p = 0
  
  if atom(x) then
    return {CONTINUE_WALKING, result}
  else
    if not valid_rtn or call_func(valid_rtn, {x}) then
      {n, result} = call_func(walk_rtn, {x, path, params, result})
      -- printf(f_debug, "path = %s, n = %d\n", {sprint(path), n})
      switch n do
        case CONTINUE_WALKING then
          {p, result} = walk_sequence(x[child_field], walk_rtn, valid_rtn,
                                      child_field, path & {child_field},
                                      params, result)
            if p then return {p, result} end if
        case STOP_WALKING then
          return {STOP_WALKING, result}
        case STOP_DEEPENING then
          -- do nothing
      end switch
    else
      for i=1 to length(x) do
        {p, result} = walk_sequence(x[i], walk_rtn, valid_rtn, child_field,
                                    path & {i}, params, result)
        if p then return {p, result} end if
      end for
    end if
  end if
  -- puts(f_debug, result & "\n")
  return {CONTINUE_WALKING, result}
end function

--------------------------------------------------------------------------------

public function csv_to_sequence(sequence str, integer sep=';')
  sequence splitted = split_string(str, sep)
  for i = 1 to length(splitted) do
    if is_number(splitted[i]) then
      splitted[i] = to_number(splitted[i])
    elsif is_string(splitted[i]) then
      splitted[i] = dequote(splitted[i])
    end if
  end for
  return splitted
end function

--------------------------------------------------------------------------------

public function sequence_to_csv(sequence s, integer sep=';')
  for i = 1 to length(s) do
    if atom(s[i]) then
      s[i] = to_string(s[i])
    elsif is_string(s[i]) then
      s[i] = quote(s[i], {})
    end if
  end for
  return join(s, sep)
end function

------------------------------------------------------------------------------

public function read_csv(sequence fname, integer header=0, integer sep=';')
  sequence lines = {}
  object content = read_lines(fname)
  if atom(content) then
    error_message("Cannot open " & fname & "!", 1)
  end if
  integer start = 1
  if header then
    if length(content) = 0 then
      error_message(fname & " has no header!", 1)
    end if
    lines = append(lines, split_string(content[1], sep))
    start = 2
  end if
  for i = start to length(content) do
    sequence line = trim(content[i])
    if length(line) > 0 then
      lines = append(lines, csv_to_sequence(line, sep) )
    end if
  end for
  return lines
end function

------------------------------------------------------------------------------

public procedure write_csv(sequence fname, sequence lines,
                           integer header=0, integer sep=';')
  integer start=1
  sequence content = {}
  if header then
    if length(lines[1]) = 0 then
      error_message("Missing header!", 1)
    end if
    content = append(content, join(lines[1], sep))
    start = 2
  end if
  for i = start to length(lines) do
    content = append(content, sequence_to_csv(lines[i], sep))
  end for
  if write_lines(fname, content) < 0 then
    error_message("Cannot write " & fname & "!", 1)
  end if
end procedure

------------------------------------------------------------------------------

public procedure append_csv(sequence fname, sequence lines, integer sep=';')
  sequence content = {}
  for i = 1 to length(lines) do
    content = append(content, sequence_to_csv(lines[i], sep))
  end for
  if append_lines(fname, content) < 0 then
    error_message("Cannot append to " & fname & "!", 1)
  end if
end procedure

--------------------------------------------------------------------------------

crash_file(InitialDir & SLASH & "ex.err")

ifdef BITS64 then  
  ifdef PHIX then
    ifdef WINDOWS then
      eu_version = PHIX_WIN_64
    elsifdef LINUX then
      eu_version = PHIX_LNX_64
    end ifdef
  elsedef
    ifdef WINDOWS then
      eu_version = EU_4_1_WIN_64
    elsifdef LINUX then
      eu_version = EU_4_1_LNX_64
    end ifdef
  end ifdef
elsedef  
  ifdef PHIX then
    ifdef WINDOWS then
      eu_version = PHIX_WIN_32
    elsifdef LINUX then
      eu_version = PHIX_LNX_32
    end ifdef
  elsedef
    ifdef WINDOWS then
      ifdef EU4_0 then
        eu_version = EU_4_0_WIN
      elsifdef EU4_1 then
        eu_version = EU_4_1_WIN_32
      end ifdef
    elsifdef LINUX then
      ifdef EU4_0 then
        eu_version = EU_4_0_LNX
      elsifdef EU4_1 then
        eu_version = EU_4_1_LNX_32
      end ifdef
    end ifdef
  end ifdef
end ifdef
