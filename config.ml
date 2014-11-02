open Mirage

let net =
  match get_mode () with
  | `Xen -> `Direct
  | `Unix ->
      try match Sys.getenv "NET" with
        | "direct" -> `Direct
        | "socket" -> `Socket
        | _        -> `Direct
      with Not_found -> `Socket

let stack console =
  match net with
  | `Direct -> direct_stackv4_with_dhcp console tap0
  | `Socket -> socket_stackv4 console [Ipaddr.V4.any]

let port =
  try match Sys.getenv "PORT" with
    | "" -> 8080
    | s  -> int_of_string s
  with Not_found -> 8080

let server =
  http_server (`TCP (`Port port)) (conduit_direct (stack default_console))

let fs_mode =
  try match String.lowercase (Unix.getenv "FS") with
    | "fat" -> `Fat
    | _     -> `Crunch
  with Not_found ->
    `Crunch

let fat_ro dir =
  kv_ro_of_fs (fat_of_files ~dir ())

let fs =
  match fs_mode, get_mode () with
  | `Fat, _    -> fat_ro "../files"
  | `Crunch, `Xen -> crunch "../files"
  | `Crunch, `Unix -> direct_kv_ro "../files"


let main = foreign
  "Unikernel.Main" (console @-> kv_ro @-> http @-> job)

let () =
  register "ssr" [
    main $ default_console $ fs $ server
  ]
