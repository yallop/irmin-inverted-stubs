let (>>=), return = Lwt.((>>=), return)

module InMemory (* : Irmin.BC *)
  = Irmin.Make
    (Irmin_mem.AO)(Irmin_mem.RW)(Irmin.Contents.String)
    (Irmin.Ref.String)(Irmin.Hash.SHA1)

type store = InMemory.t
type key = string list

let create_repository : unit -> InMemory.Repo.t Lwt.t =
  fun () -> InMemory.Repo.create (Irmin_mem.config ())

let repository_master : InMemory.Repo.t -> store Lwt.t =
  fun repo ->
    InMemory.master Irmin.Task.none repo >>= fun g ->
    return (g ())

let update : store -> key -> string -> unit Lwt.t =
  InMemory.update

let read : store -> key -> string option Lwt.t =
  InMemory.read

let store_history : ?depth:int -> store -> InMemory.History.t Lwt.t =
  fun ?depth store -> InMemory.history ?depth store

let walk_history :
  InMemory.History.t -> (string -> int64) -> unit Lwt.t =
  fun h f ->
    let module M = struct exception Stop end in
    let handle_vertex v =
      if f (Irmin.Hash.SHA1.to_hum v) = 0L then raise M.Stop
    in
    match InMemory.History.iter_vertex handle_vertex h with
      () -> Lwt.return ()
    | exception M.Stop -> Lwt.return ()

open Ctypes
(* External types *)
let repository : [`repository] structure typ =
  structure "irmin_repository"

let store : [`store] structure typ =
  structure "irmin_store"

let history : [`history] structure typ =
  structure "irmin_history"

let walk_action : int64 typ =
  typedef int64_t "irmin_walk_action_t"

module type TYPED_ROOT =
sig
  type t
  type ctyp
  val create : t -> ctyp ptr
  val get : ctyp ptr -> t
  val set : ctyp ptr -> t -> unit
  val release : ctyp ptr -> unit
end

module Typed_root(X: sig type t type ctyp val ctyp : ctyp typ end) :
  TYPED_ROOT with type t = X.t and type ctyp = X.ctyp =
struct
  include X
  let of_ctyp = Ctypes.coerce (ptr ctyp) (ptr void)
  let to_ctyp = Ctypes.coerce (ptr void) (ptr ctyp)
  let create v = to_ctyp (Root.create v)
  let get p = Root.get (of_ctyp p)
  let set p v = Root.set (of_ctyp p) v
  let release p = Root.release (of_ctyp p)
end

type ('t, 'ctyp) typed_root = 
  (module TYPED_ROOT with type t = 't and type ctyp = 'ctyp)

let typed_root (type ctyp') (type t') (ctyp : ctyp' typ)
  : (t', ctyp') typed_root =
  (module Typed_root
       (struct type t = t' type ctyp = ctyp' let ctyp = ctyp end))

module Repository_root = (val (typed_root repository
                               : (InMemory.Repo.t,_) typed_root))
module Store_root = (val (typed_root store
                          : (InMemory.t,_) typed_root))
module History_root = (val (typed_root history
                            : (InMemory.History.t,_) typed_root))

module Stubs(I : Cstubs_inverted.INTERNAL) =
struct
  let () = I.structure repository
  let () = I.typedef repository "irmin_repository_t"
  let () = I.structure store
  let () = I.typedef store "irmin_store_t"

  (** Repositories *)
  let () = I.internal "irmin_repository_create"
      (void @-> returning (ptr repository))
      (fun () -> 
         Repository_root.create @@
         Lwt_unix.run @@
         create_repository ())

  let () = I.internal "irmin_repository_destroy"
      (ptr repository @-> returning void)
      Repository_root.release

  let () = I.internal "irmin_repository_master_store"
      (ptr repository @-> returning (ptr store))
      (fun p ->
         Store_root.create @@
         Lwt_unix.run @@
         repository_master @@
         Repository_root.get p)

  (** Stores *)
  let () = I.internal "irmin_store_destroy"
      (ptr store @-> returning void)
      Store_root.release

  let () = I.internal "irmin_store_append"
      (ptr store @-> string @-> string @-> returning void)
      (fun p k v ->
         Lwt_unix.run @@
         update (Store_root.get p) [k] v)

  let () = I.internal "irmin_store_read"
      (ptr store @-> string @-> returning string_opt)
      (fun p k ->
         Lwt_unix.run @@
         read (Store_root.get p) [k])

  let () = I.internal "irmin_store_history"
      (ptr store @-> returning (ptr history))
      (fun p ->
         History_root.create @@
         Lwt_unix.run @@
         store_history @@
         Store_root.get p)

  (** Histories *)
  let () = I.internal "irmin_history_destroy"
      (ptr history @-> returning void)
      History_root.release

  let () = I.internal "irmin_history_walk"
      (ptr history @->
       (* TODO: we shouldn't need Foreign just for this. *)
       (Foreign.funptr (string @-> returning walk_action)) @->
       returning void)
      (fun h f ->
         Lwt_unix.run (walk_history (History_root.get h) f))
end
