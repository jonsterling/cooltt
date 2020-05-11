open CoolBasis

type level = [`Info | `Error | `Warn]

type location = LexingUtil.span option

val pp_message
  : loc:location
  -> lvl:level
  -> 'a Pp.printer
  -> Format.formatter
  -> 'a
  -> unit