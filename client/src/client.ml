
module Html = Dom_html

(* var CommentBox = React.createClass({displayName: 'CommentBox', *)
(*   render: function() { *)
(*     return ( *)
(*       React.createElement('div', {className: "commentBox"}, *)
(*         "Hello, world! I am a CommentBox." *)
(*       ) *)
(*     ); *)
(*   } *)
(* }); *)
(* React.render( *)
(*   React.createElement(CommentBox, null), *)
(*   document.getElementById('content') *)
(* ); *)

(* let react s = Js.Unsafe.fun_call *)
(*   (Unsafe.variable "React") [|Unsafe.inject (Js.string s)|] *)

let on_message event =
  let div = Dom_html.getElementById "main-area" in
  let data = event##data in
  let () = Firebug.console##log_2(Js.string "Got event: ", data) in
  let _ = div##innerHTML <- data in
  Js._false


let start _:(bool Js.t) =
  let evs = jsnew EventSource.eventSource (Js.string "/events") in
  let _ = evs##onmessage <- (Dom.handler on_message) in
  Js._false

let () =
  Html.window##onload <- Dom.handler start
