open GapiUtils.Infix
module Fun = GapiFun

let build_client_login_auth test_config =
  let get = Config.get test_config in
  ( GapiConfig.ClientLogin
      { GapiConfig.username = get "cl_user"; password = get "cl_pass" },
    GapiConversation.Session.ClientLogin (get "cl_token") )

let build_oauth1_auth test_config =
  let get = Config.get test_config in
  ( GapiConfig.OAuth1
      {
        GapiConfig.signature_method = GapiCore.SignatureMethod.HMAC_SHA1;
        consumer_key = get "oa1_cons_key";
        consumer_secret = get "oa1_cons_secret";
      },
    GapiConversation.Session.OAuth1
      {
        GapiConversation.Session.token = get "oa1_token";
        secret = get "oa1_secret";
      } )

let build_oauth2_auth test_config =
  let get = Config.get test_config in
  ( GapiConfig.OAuth2
      {
        GapiConfig.client_id = get "oa2_id";
        client_secret = get "oa2_secret";
        refresh_access_token = None;
      },
    GapiConversation.Session.OAuth2
      {
        GapiConversation.Session.oauth2_token = get "oa2_token";
        refresh_token = get "oa2_refresh";
      } )

let build_oauth2_service_account_auth test_config =
  let get = Config.get test_config in
  let service_account_credentials_path =
    "../../config/service-account-key.json"
  in
  let service_account_credentials_json =
    let in_ch = open_in service_account_credentials_path in
    let b = Buffer.create 512 in
    ( try
        while true do
          Buffer.add_string b (input_line in_ch)
        done
      with End_of_file -> () );
    close_in in_ch;
    Buffer.contents b
  in
  let scopes =
    let scopes_string = get "oa2_scopes" in
    let rec loop s accu =
      if String.contains s ' ' then
        let space_index = String.index s ' ' in
        let scope = String.sub s 0 space_index in
        let s' =
          String.sub s (space_index + 1) (String.length s - space_index - 1)
        in
        loop s' (scope :: accu)
      else s :: accu
    in
    loop scopes_string [] |> List.rev
  in
  let user_to_impersonate =
    match get "oa2_user_to_impersonate" with "" -> None | u -> Some u
  in
  ( GapiConfig.OAuth2ServiceAccount
      {
        GapiConfig.service_account_credentials_json;
        scopes;
        user_to_impersonate;
        refresh_service_account_access_token = None;
      },
    GapiConversation.Session.OAuth2
      {
        GapiConversation.Session.oauth2_token = get "oa2_token";
        refresh_token = "";
      } )

let build_oauth2_devices_auth test_config =
  let get = Config.get test_config in
  ( GapiConfig.OAuth2
      {
        GapiConfig.client_id = get "oa2_devices_id";
        client_secret = get "oa2_devices_secret";
        refresh_access_token = None;
      },
    GapiConversation.Session.OAuth2
      {
        GapiConversation.Session.oauth2_token = get "oa2_token";
        refresh_token = get "oa2_refresh";
      } )

let build_no_auth _ = (GapiConfig.NoAuth, GapiConversation.Session.NoAuth)

let build_config debug_flag auth_config =
  let base_config =
    if debug_flag then GapiConfig.default_debug else GapiConfig.default
  in
  { base_config with GapiConfig.auth = auth_config }

let get_debug_flag test_config =
  try
    let value = Config.get test_config "debug" in
    bool_of_string value
  with Not_found -> false

let string_of_json_data_model tree =
  let join _ = String.concat "," in
  GapiCore.AnnotatedTree.fold
    (fun m xs ->
      match m.GapiJson.data_type with
      | GapiJson.Object ->
          Printf.sprintf "%a{%a}"
            (fun _ n -> if n <> "" then "\"" ^ n ^ "\":" else "")
            m.GapiJson.name join xs
      | GapiJson.Array -> Printf.sprintf "\"%s\":[%a]" m.GapiJson.name join xs
      | _ -> assert false)
    (fun m value ->
      let s = Yojson.Safe.to_string value in
      if m.GapiJson.name <> "" then Printf.sprintf "\"%s\":%s" m.GapiJson.name s
      else s)
    tree

let do_request config auth_session interact handle_exception =
  let state = GapiCurl.global_init () in
  let rec try_request () =
    try
      GapiConversation.with_session ~auth_context:auth_session config state
        interact
    with
    | Failure message as e ->
        if
          Str.string_match
            (Str.regexp_string "CURL_OPERATION_TIMEOUTED")
            message 0
        then try_request ()
        else handle_exception e
    | GapiService.ServiceError (_, e) ->
        let e' =
          Failure
            ( e |> GapiError.RequestError.to_data_model
            |> string_of_json_data_model )
        in
        handle_exception e'
    | e -> handle_exception e
  in
  try try_request () with e -> raise e

let test_request ?configfile ?(handle_exception = raise) build_auth interact =
  let test_config = Config.parse ?filename:configfile () in
  let auth_conf, auth_session = build_auth test_config in
  let debug_flag = get_debug_flag test_config in
  let config = build_config debug_flag auth_conf in
  do_request config auth_session interact handle_exception

let test_request_noauth ?configfile ?(handle_exception = raise) interact =
  let test_config = Config.parse ?filename:configfile () in
  let debug_flag = get_debug_flag test_config in
  let config = build_config debug_flag GapiConfig.NoAuth in
  do_request config GapiConversation.Session.NoAuth (interact test_config)
    handle_exception

let print_exception e =
  print_endline (Printexc.to_string e);
  Printexc.print_backtrace stdout

(* We should add a delay to let Google persist the new entry, after a write
 * operation, otherwise DELETE will return a 503 HTTP error (Service
 * Unavailable) *)
let delay ?(seconds = 5) () = Unix.sleep seconds

let assert_false msg b = OUnit.assert_bool msg (not b)

let assert_not_empty msg s = OUnit.assert_bool msg (s <> "")

let assert_equal_file file_name s =
  let ic = open_in file_name in
  let buffer = Buffer.create 512 in
  let file_content =
    try
      while true do
        let s = input_line ic in
        Buffer.add_string buffer s
      done;
      assert false
    with End_of_file -> Buffer.contents buffer
  in
  OUnit.assert_equal ~printer:Fun.id file_content s

let assert_exists msg pred xs = OUnit.assert_bool msg (List.exists pred xs)

let assert_not_exists msg pred xs =
  OUnit.assert_bool msg (not (List.exists pred xs))

let id x = x

let string_to_hex s =
  let b = Buffer.create (String.length s * 2) in
  String.iter
    (fun c -> Buffer.add_string b (Printf.sprintf "%2.2x" (Char.code c)))
    s;
  Buffer.contents b
