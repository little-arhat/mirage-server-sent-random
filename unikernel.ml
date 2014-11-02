open Lwt

module Main (C: V1_LWT.CONSOLE)
            (FS: V1_LWT.KV_RO)
            (H: Cohttp_lwt.Server) = struct

  let not_allowed = H.respond_error ~status:`Method_not_allowed
                                           ~body:"Method not supported\n" ()
  let not_found path =  H.respond_error ~status:`Not_found
                                        ~body:(Printf.sprintf "Not found '%s'\n" path) ()

  let from_fs_to_stream fs name =
    FS.size fs name >>= fun res ->
    match res with
    | `Error (FS.Unknown_key _) -> return (`Not_found name)
    | `Ok size ->
       FS.read fs name 0 (Int64.to_int size) >>= fun res ->
       match res with
       | `Error (FS.Unknown_key _) -> return (`Read_error name)
       | `Ok bufs -> return (`Ok (size,
                                  Lwt_stream.map Cstruct.to_string
                                                 (Lwt_stream.of_list bufs)))

  let handle_static request fs path =
    match H.Request.meth request with
    | `GET -> lwt read_res = from_fs_to_stream fs path in
              match read_res with
              | `Not_found p -> not_found p
              | `Read_error p -> H.respond_error ~status:`Internal_server_error
                                                 ~body:"Could not read requested page" ()
              | `Ok (size, stream) ->
                  let headers = Cohttp.Header.init_with "Content-Length"
                                                        (Int64.to_string size) in
                  let encoding = Cohttp.Transfer.Fixed size in
                  let res = H.Response.make ~status:`OK ~encoding ~headers () in
                  return (res, Cohttp_lwt_body.of_stream stream)
    | _ -> not_allowed

  let sse_headers = Cohttp.Header.of_list [("Cache-Control", "no-cache");
                                           ("Content-Type", "text/event-stream")]

  let generate_events conn_id = fun () ->
    Lwt_unix.sleep 5.0 >>= fun () ->
    return (Int64.to_string (Random.int64 Int64.max_int)) >>= fun (rnd) ->
    return (Printf.sprintf "data: %s\n\n" rnd) >>= fun (data) ->
    return (Some data)

  let new_event_stream conn_id =
    let stream = Lwt_stream.from (generate_events conn_id) in
    Cohttp_lwt_body.of_stream stream

  let handle_events request conn_id =
    match H.Request.meth request with
    | `GET -> let res = H.Response.make ~status:`OK
                                        ~encoding:(Cohttp.Transfer.Chunked)
                                        ~headers:sse_headers () in
              return (res, new_event_stream conn_id)
    | _ -> not_allowed

  let start c fs http =
    let () = Random.self_init () in
    let () = Log.write := C.log_s c in

    let callback (_io_conn, http_conn) request body =
      let uri = Cohttp.Request.(request.uri) in
      let _:(unit C.io) = Log.info "Got request to: %s" (Uri.path_and_query uri) in
      try_lwt
        match Uri.path uri with
        | "/" -> handle_static request fs "index.html"
        | "/events" -> let conn_id = Cohttp.Connection.to_string http_conn in
                       handle_events request conn_id
        | path -> handle_static request fs path
      with ex ->
          Log.warn "error handling HTTP request: %s\n%s"
            (Printexc.to_string ex)
            (Printexc.get_backtrace ()) >>= fun () ->
          raise ex in

    let conn_closed (_io_conn, http_conn) () =
      let conn_id = Cohttp.Connection.to_string http_conn in
      Log.info "connection %s closed" conn_id |> ignore in

    http { H.
           callback;
           conn_closed
      }
end
