module Op :
sig
  val ( |> ) : 'a -> ('a -> 'b) -> 'b

  val ( <<< ) : ('a -> 'b) -> ('c -> 'a) -> 'c -> 'b

  val ( >>> ) : ('a -> 'b) -> ('b -> 'c) -> 'a -> 'c

end

val is_weak_etag : string -> bool

val etag_option : string -> string option

val merge_query_string : (string * string) list -> string -> string

val add_id_to_url : string -> string -> string
