include std/datetime.e
include std/console.e
include ../common.e
include ../eusqlite3.e

constant
  CUSTOMER = 1, MGMT_IP = 2, USERNAME = 3, PASSWORD = 4, MODEL = 5,
  BOOT = 6, ONEOS = 7, LAST_UPDATE = 8, STATUS = 9, LAST_CHECK = 10

--------------------------------------------------------------------------------

  sequence s
  atom sql_db
  sequence deviceList = {}

  f_debug = open(InitialDir & "debug.log", "w")
  debug_level = DEBUG
  debug_time_stamp = 0

  sql_db = sqlite3_open(InitialDir & "provisioning.sqlite")
  if sql_db <= 0 then
    error_message("Couldn't open SQLite database\n", 1)
  end if
  printf(f_debug, "sql_db = %d\n", {sql_db})
  
  deviceList = sqlite3_get_table(sql_db, "SELECT * FROM devices;")
  analyze_object(deviceList, "deviceList", DEBUG)

  sequence cmd = sprintf("UPDATE \"devices\" SET \"%s\" = \"%s\" WHERE \"rowid\" = %d;",
                         {"Last_update", datetime:format(now(), "%Y-%m-%d %H:%M:%S"), 2})
  void = exec_sql_command(sql_db, cmd)

  deviceList = sqlite3_get_table(sql_db, "SELECT * FROM devices;")
  analyze_object(deviceList, "deviceList", DEBUG)

  sqlite3_close(sql_db)
  close(f_debug)

  maybe_any_key()
  
