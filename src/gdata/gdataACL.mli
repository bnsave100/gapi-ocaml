val ns_gAcl : string

module Scope :
sig
  type t = {
    stype : string;
    value : string
  }

  val empty : t

  val of_xml_data_model : t -> GdataCore.xml_data_model -> t

  val to_xml_data_model : t -> GdataCore.xml_data_model list

end

type acl_role = string

type calendar_aclEntry = {
  ae_etag : string;
  ae_kind : string;
  ae_authors : GdataAtom.Author.t list;
  ae_categories : GdataAtom.Category.t list;
  ae_contributors : GdataAtom.Contributor.t list;
  ae_id : GdataAtom.atom_id;
  ae_content : GdataAtom.Content.t;
  ae_published : GdataAtom.atom_published;
  ae_updated : GdataAtom.atom_updated;
  ae_edited : GdataAtom.app_edited;
  ae_links : GdataAtom.Link.t list;
  ae_title : GdataAtom.Title.t;
  ae_scope : Scope.t;
  ae_role : acl_role
}

val empty_entry : calendar_aclEntry

val parse_acl_entry : GdataCore.xml_data_model -> calendar_aclEntry

val acl_entry_to_data_model : calendar_aclEntry -> GdataCore.xml_data_model

module Entry :
sig
  type t = calendar_aclEntry

  val empty : t

  val to_xml_data_model : t -> GdataCore.xml_data_model list

  val of_xml_data_model : t -> GdataCore.xml_data_model -> t

end

module Feed :
sig
  include GdataAtom.FEED
    with type entry_t = Entry.t
      and type link_t = GdataAtom.Link.t

end

module Rel :
sig
  type t =
    [ `Acl
    | GdataAtom.Rel.t ]

  val to_string : [> t] -> string

end

val find_url : Rel.t -> GdataAtom.Link.t list -> string

val get_acl_prefix : string -> string

