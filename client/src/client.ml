
module Html = Dom_html

let start _:(bool Js.t) = Js._false

let () =
  Html.window##onload <- Html.handler start
