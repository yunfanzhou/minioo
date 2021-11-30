(* File miniooAbstractSyntax.ml *)

type ast =
  Ident of string  (**check the delcaration*)
  | Field of string 
  | Num of int
  | Diff of ast * ast 
  | Null 
  | Loc of ast * ast
  
  | Proc of string * ast
  | Decl of string * ast
  
  | NewAssign of ast * ast
  | Assign of string * ast
  | FieldAssign of ast * ast * ast 
  
  | Seq of ast * ast
  | Skip
  | If of ast * ast * ast
  | While of ast * ast
  | Malloc of ast
  | RecProcCall of ast * ast 
  | Atom of ast
  | Parallel of ast * ast 
  | Empty

  | True 
  | False
  | Equal of ast * ast 
  | LessT of ast * ast 

  | Block of ast

and ptr_decl = 
  Ptr of ast
  | Void
;; 

(* syntax and semantics *)

type boolean = 
  BoolT 
  |BoolF 
  |BoolErr 
;;

type obj = 
  Obj of int
and location = 
  Locat of obj
;;

type stack = (ast * location) list
;;

type closure = 
  Clo of ast * ast * stack
;;

type tva = 
  TvaError 
  | TvaField of ast
  | TvaInt of int
  | TvaLoc of location
  | TvaClo of closure
  | TvaNull 
;;
  
type heapentry =  
  Entry of (ast * tva) list 
and heap = heapentry list 
;;

type configuration = 
  Conf of ast * stack * heap
;;

(* ################## stack operations ####################*)
(* push to stack at Decl and Proc *)
(* s is string, t is the Decl/Proc ast, l is location correpsonds to heap, st is the sack*)
(* string -> ast -> int -> stack -> stack  *)
(** second thought, bad decision, now make parameter be the more general ast_s, so stack can also store fields*)
(** ast -> int -> stack -> stack *)
let push_stack ast_s l st = 
  (match ast_s with 
    Ident(s) -> (ast_s, Locat(Obj(l))) :: st
    |_ -> failwith "the push is not Ident"
  )
;;

(* stack -> stack *)
let pop_stack st =
  match st with 
  [] -> failwith "pop on empty stack"
  |h::t -> t 
;;

(* search the stack st for variable ast_s and return the location corresponding to ast_s for heap val storation *) 
(* ast_s here can only be Ident(s, ptr) *)
(* ast -> stack -> location *) 
let get_loc_from_stack ast_s st =
  if List.mem_assoc ast_s st then List.assoc ast_s st
  else failwith "the varible is not stored on stack"
;;

(* location -> int *)
let get_integer_from_loc l =
  match l with 
  Locat(t) -> 
    match t with 
    Obj(i) -> i
  |_ -> failwith "not a location"

(* ################### refactoring heap ############################## *)

(* the bricks I need *)
(* heapentry -> (ast * tav ref) list *)
let get_list_from_heapentry hpent = 
  match hpent with
  Entry(ast_tvaref_list) -> ast_tvaref_list
  |_ -> failwith "it's not a heapentry"
;;

(* ast is Ident/Field, l is int *) 
(* ast -> int -> heap -> tva *)
let get_val_from_heap ast l hp = 
  Printf.printf " the stack index is %8d \n" l;
  if l >= List.length hp then (print_string " location l exceeded the size of heap in get_val_from_heap"; TvaError)
  else 
    let hpentrylist = get_list_from_heapentry (List.nth hp l) in
      if List.mem_assoc ast hpentrylist then (List.assoc ast hpentrylist)
      else failwith "ast is not declared";
  ;;

(* happens only at decl/proc when new var is created. append the new (ast * tva ref) association pair in heap *)
(* ast -> tva -> heap -> heap *)
let append_new_var ast v hp =
  (print_string "pre check\n");
  (print_string "passed check\n");
  hp @[Entry([(ast, v)])];
;;
(* this is when ast doesn't exist in heap yet *)
(* ast -> int -> tva -> heap -> heap *)
let rec set_val_in_heap ast l v hp =
  if l > List.length hp then failwith "location l exceeded the size of heap in set_val_in_heap"
  else 
    match hp with 
      h::t -> if l = 0 then 
                let hpentrylist = get_list_from_heapentry h in  
                  Entry((ast, v)::hpentrylist)::t
              else h::set_val_in_heap ast (l-1) v t
      |[] -> append_new_var ast v hp
;;

(* this is when ast already exist in heap and we want to change the value to cuurent v *)
(* first disassociate the old (ast, ref tva), then call insert *)
(* ast -> int -> tva -> heap -> heap *)
let rec change_val_in_heap ast l v hp =
  if l >= List.length hp then failwith "location l exceeded the size of heap in change_val_in_heap"
  else 
    match hp with  
      [] -> failwith "would fail here but still this is when we get a empty hp in change val"
      |h::t ->  if l = 0 then 
                  let hpentrylist = get_list_from_heapentry h in  
                    if List.mem_assoc ast hpentrylist then 
                      Entry((ast, v)::List.remove_assoc ast hpentrylist)::t
                    else failwith "ast has not existed in the heap before "
                else h::change_val_in_heap ast (l-1) v t

;;


(* ################### heap ends ############################## *)

  (*1. since malloc should have happened in previous cmds, eval of ast_v should return location. Check this, if not fail
    2. given 1. did not error we eval ast_f. And this should give TvaField(Field). If not fail
    (after this point all happen in get_val_from_heap) 
    3. given 1.2. succeeded use loc got in 1. check in heap with this loc use get_val_from_heap ast_f l hp, (use List.mem_assoc hp[loc] Field). 
        the returned val of get_val_from_heap will either be 
        (TvaNull, meaning field has not existed yet, or TvaErr (unclear why it would be but we shall fail if so), or everything else doesn't matter)
    If exist update the value to v, 
      if doesn't exit, we need to push this Field into that hp[loc] and set value to TvaNull at this point 
    4. the provious steps have made sure the field exists. now call change_val_in_heap with  *)
(* ast -> stack -> hp -> tva *)
let rec eval ast_s st hp = 
  match ast_s with 
  Num(i) -> TvaInt(i)
  |Field(s) -> TvaField(ast_s)
  |Ident(s) ->
                  let loc = get_loc_from_stack ast_s st in 
                  let l = get_integer_from_loc loc in
                    get_val_from_heap ast_s l hp 
  
  
  |Loc(e1, e2) -> (print_string "at eval of loc e1.e2 \n");
                  let le1 = eval e1 st hp in 
                  let fe2 = eval e2 st hp in
                    (match le1, fe2 with 
                      TvaLoc(loc), _ -> (print_string "e1 is evaled to tvaloc \n");
                                        let l = get_integer_from_loc loc in 
                                        
                                        (match fe2 with 
                                            TvaField(ast_f) ->  (print_string "e2 is evaled to tvafield \n");
                                                                 get_val_from_heap ast_f l hp                       
                                            |_ -> failwith "e2 in e1.e2 has to be field"; 
                                        )                 
                      |_, _ -> failwith "there weren't malloc for variable before this";
                    )
  |Diff(e1, e2) -> (match e1, e2 with 
                      Num(i1), Num(i2) -> TvaInt(i1-i2)
                      |_, _ -> failwith "e1-e2 eval failure"
                    )
  |Proc(s, c) -> TvaClo(Clo(Ident(s), c, st))

  |Null -> print_string "ast_s at eval is Null"; TvaError

  |_ -> TvaError
;;

(* ast -> stack -> heap -> boolean *)
let rec bool_eval ast_s st hp =
  match ast_s with
  True -> BoolT
  |False -> BoolF
  |Equal(e1, e2) -> let v1 = eval e1 st hp in
                    let v2 = eval e2 st hp in
                      (match v1, v2 with 
                        TvaInt(i1), TvaInt(i2) -> if i1 = i2 then BoolT else BoolF
                        |TvaLoc(l1), TvaLoc(l2) -> (match l1, l2 with 
                                                    Locat(obj1), Locat(obj2) -> (match obj1, obj2 with 
                                                                                  Obj(i1), Obj(i2) -> if i1 = i2 then BoolT else BoolF
                                                                                )
                                                    )
                        |TvaClo(clo1), TvaClo(clo2) -> if clo1 = clo2 then BoolT else BoolF
                        |_, _ -> BoolErr
                      )
  |LessT(e1, e2) -> let v1 = eval e1 st hp in
                    let v2 = eval e2 st hp in
                      (match v1, v2 with 
                        TvaInt(i1), TvaInt(i2) -> if i1 < i2 then BoolT else BoolF
                        |_, _ -> BoolErr
                      )
  |_ -> BoolErr
;;

(* ################################## printing method ####################################### *)
let print_stack st = 
  (print_string "******* start of stack ***** \n");
  let rec print_stack_rec st = 
    (match st with 
      [] -> (print_string "******* end of stack ***** \n")
      |h::t -> (match h with 
                Ident(s), Locat(Obj(l)) -> (Printf.printf "the stack at %d is %8s \n" l s); print_stack_rec t
                |_-> print_string "wrong stack "
                )
    )
  in print_stack_rec st
;;

let rec print_hpentry hpentry = 
  (match hpentry with 
    [] -> (print_string "     &&&&& end of heapentry &&&& \n");
    |h::t -> (match h with 
              Ident(s), r -> (match r with 
                            TvaInt(i) ->(Printf.printf "the ident is %s and the value is TvaInt %d \n" s i); 
                                          print_hpentry t
                            |TvaClo(Clo(x, c, st)) -> (Printf.printf "the ident is %s and the value is TvaClo \n" s); 
                                                        (print_string ("        the stack at closure is \n"));print_stack st;
                                          print_hpentry t
                            |TvaLoc(loc) -> let l = get_integer_from_loc loc in
                                            (Printf.printf "the ident is %s and the value is Tvaloc %d \n" s l);     
                                          print_hpentry t  
                            |_ -> (print_string ("the ident is " ^s));(print_string (" and the value in not value  or closure\n"));
                                          print_hpentry t
                            )
              |Field(f), r -> (match r with 
                              TvaInt(i) ->(Printf.printf "the field is %s and the value is TvaInt %d \n" f i); 
                                            print_hpentry t
                              |TvaClo(Clo(x, c, st)) -> (Printf.printf "the field is %s and the value is TvaClo \n" f); 
                                                          (print_string ("        the stack at closure is \n"));print_stack st;
                                            print_hpentry t
                              |TvaLoc(loc) -> let l = get_integer_from_loc loc in
                                              (Printf.printf "the field is %s and the value is Tvaloc %d \n" f l);     
                                            print_hpentry t  
                              |_ -> (print_string ("the field is " ^f));(print_string (" and the value in not value  or closure\n"));
                                            print_hpentry t
                              )
              |_,_ -> print_string "the pair in heapentry is not ident or field";
                      print_hpentry t;
              )
  )
;;
let print_hp hp = 
  (print_string "&&&&&&&&&&& start of heap &&&&&&&&&& \n");
  let rec print_hp_rec hp = 
    match hp with
      [] -> (print_string "&&&&&&&&&&& end of heap &&&&&&&&&& \n");(print_string "heap is printed\n")
      |h::t -> let hpentrylist = get_list_from_heapentry h in 
                  (print_string "     &&&&& start of heapentry &&&& \n");
                  print_hpentry hpentrylist; 
                  print_hp_rec t;    
  in print_hp_rec hp         
;;


(* ################################## iterator ####################################### *)
let rec ptr_cmd t st hp= 
  match t with 
    Empty -> Conf (Empty, st, hp)  (* I need to stop execution here? How? And do I need to poop st here? *)(** at the end of the execution there is an empty stack*)

    (* |Proc (s, c) ->  let l = List.length hp in
                     (* let ast_s = link_var s t in  *)
                      Conf(Block(c), (push_stack (Ident(s)) l st), (append_new_var (Ident(s)) TvaNull hp));  *)
                  
    |Decl (s, c) -> let l = List.length hp in 
                    (* let ast_s = link_var s t in  *)
                    let st' = (push_stack (Ident(s)) l st) in 
                    let hp' = (append_new_var (Ident(s)) TvaNull hp) in 
                      Conf(Block(c), st', hp'); 
                  
    |Seq (c1, c2) -> let Conf(c1', st', hp') = ptr_cmd c1 st hp in
                      (match c1' with 
                        Empty -> Conf(c2, st', hp')
                        |_ -> Conf(Seq(c1', c2), st', hp')
                      )
    |Block (c) -> (match c with 
                    Empty -> Conf (Empty, pop_stack st, hp) 

                    |_ -> let Conf(c', st', hp') = ptr_cmd c st hp in 
                            (print_string "i am in the block");
                            print_newline();
                            print_stack st';
                            print_newline();
                            print_hp hp';
                            print_newline();
                            Conf(Block c', st', hp')
                  )     
    (* we need to be clear only variable can have field, thus in Loc(e1, e2) e1 can only be Ident and e2 be field *)
    
    |NewAssign(e1, e2) -> let v = eval e2 st hp in  (* eval of e2 shuold have and return a Tva value , check this if not error out *)
                            (match e1 with 
                              Ident(s) -> 
                                            let loc = get_loc_from_stack e1 st in 
                                            let l = get_integer_from_loc loc in
                                              Conf(Empty, st, change_val_in_heap e1 l v hp) (*retrun the Empty, st, hp(modified)*)
                                          
                              (* we call eval on Loc
                              in eval of Loc(ast_v, ast_f) are restriced to: ast_v can only be Ident and ast_f be Field that's not true e2 can be other Tva val 
                              and in eval of Loc a few things should happen (see commet at eval for details):*)
                              
                              |Loc(ast_v, ast_f) -> let val_loc = eval e1 st hp in 
                                                      (match val_loc with 
                                                        TvaError -> let tvaloc = eval ast_v st hp in
                                                                    (match tvaloc with 
                                                                      TvaLoc(loc) -> let l = get_integer_from_loc loc in 
                                                                                      Conf(Empty, st, set_val_in_heap ast_f l v hp) (* we now create the field at the location and set that value to v*)
                                                                      |_ -> failwith "not a location in e1.e2"
                                                                    )
                                                        (** if that field already exists in heap then just change the field *)
                                                        |_ -> let tvaloc = eval ast_v st hp in
                                                                (match tvaloc with 
                                                                  TvaLoc(loc) -> let l = get_integer_from_loc loc in 
                                                                                  Conf(Empty, st, change_val_in_heap ast_f l v hp)(* we now create the field at the location and set that value to v*)
                                                                  |_ -> failwith "not a location in e1.e2"
                                                                )
                                                      )
                              |_ -> failwith "assign only takes Ident or Loc, a third type is caught here"
                            )
    (*i kind of decided that malloc can only be called on ident *)
    (* this is for sure bugged, I need to set the field that malloced to be null or find out how the field will be evaluated in e1.e2 sort of setting *)
    (* currently e1.e2 assumes e2 evaluated to TvaField, meaning e2 has already existed in the heap *)
    (* so when does e2 get to be initiated on the heap? *)
    |Malloc(ast_s) ->(match ast_s with 
                          Ident(s) -> let loc = get_loc_from_stack ast_s st in
                                      let l = get_integer_from_loc loc in
                                      let malloc_s_val = get_val_from_heap ast_s l hp in
                                      (match malloc_s_val with
                                        TvaLoc(newloc) -> Conf(Empty, st, hp)
                                        (* meaning this var x has fields before, then do nothing  *)
                                        |_ -> let newl = List.length hp in 
                                              let newloc = TvaLoc(Locat(Obj(newl))) in
                                              let hp_change_var = change_val_in_heap ast_s l newloc hp in 
                                                (Printf.printf "  malloc has changed heap at %d \n" l);
                                                Conf (Empty, st, hp_change_var)
                                        (* meaning this is the first time malloc *)
                                      )
                          |_ -> failwith "malloc should happen on Ident(s)"
                        )
    |RecProcCall(e1, e2) -> let v = eval e1 st hp in 
                              (match v with 
                                TvaClo(clo1) -> (match clo1 with 
                                                  Clo(ast_s, c, st') -> 
                                                                        let recv = eval e2 st hp in
                                                                          (match recv with 
                                                                          TvaError -> failwith "recursive call e2 errored at eval"
                                                                          |_ -> print_hp hp; 
                                                                                print_newline(); 
                                                                                print_stack st';
                                                                                (print_string "this is st'"); print_newline();
                                                                                let l = List.length hp in
                                                                                (print_string ("counter l at thiis point is \n"^string_of_int l));
                                                                                let st'' = push_stack ast_s l st' in
                                                                                let hp' = set_val_in_heap ast_s l recv hp in 
                                                                                
                                                                                  print_stack st'';
                                                                                  print_string "this is st''";
                                                                                  print_hp hp';Conf(Block c, st'', hp') 
                                                                          )                         
                                                  |_ -> failwith "recursive call closure not valid"
                                                )
                                |_ -> failwith "recursive call on not a closure"
                              )
    
    
    |Atom(c) -> let Conf(t', st', hp') = ptr_cmd c st hp in 
                  (match t' with (* fishy recurssion *)
                    Empty -> Conf(Empty, st', hp')
                    |_ -> ptr_cmd (Atom(t')) st' hp'
                  )
    |Parallel(c1, c2) -> let i = Random.int 2 in 
                          if i = 0 then let Conf(t', st', hp') = ptr_cmd c1 st hp in 
                            (match t' with
                              |Empty -> Conf(c2, st', hp')
                              |_ -> Conf(Parallel(t', c2), st', hp')
                            )
                          else let Conf(t', st', hp') = ptr_cmd c2 st hp in 
                            (match t' with
                              |Empty -> Conf(c1, st', hp')
                              |_ ->Conf(Parallel(c1, t'), st', hp')
                            )

    |Skip -> Conf(Empty, st, hp)

    |If(condition, c1, c2) -> let b = bool_eval condition st hp in
                                (match b with
                                  BoolT -> Conf(c1, st, hp)
                                  |BoolF -> Conf(c2, st, hp)
                                  |_ -> failwith "If condition evaluation error"
                                )
    |While(condition, c) -> let b = bool_eval condition st hp in
                                (match b with 
                                  BoolT -> Conf(c, st, hp)
                                  |BoolF -> Conf(Empty, st, hp)
                                  |_ -> failwith "While condition evaluation error"
                                )
    |_ -> failwith "just to catch impossible failure in ptr_cmd";;
  
(* the type was incompatible thus invented the ast type to unite the cmdAST and exprAST type *)
(* should I initiate heap here so the function is a trace function *)
(* ast -> int -> stack -> heap -> configuration *)
let rec trace t st hp = 
  (match t with 
    Empty -> failwith "empty is not a program"
    |_ -> let Conf(t', st', hp') = ptr_cmd t st hp in
            (match t' with 
            Empty -> 
                    print_string "the heap is \n ";
                    print_newline();
                    print_hp hp';
                    print_newline();
                    print_stack st';
                     Conf(Empty, st', hp') 

            |_ -> trace t' st' hp'
            )
  )
;;

let rec print_ast ast = 
  (match ast with 

    Num (i) -> print_string (string_of_int i) ;
    |Decl (s, cmdast) -> print_string ("Declaration:"^s) ;print_newline();
                         print_string ("Command List:") ;print_newline();
                         print_ast cmdast; print_newline()
    |NewAssign (ast_s, exprast) -> 
                            match ast_s with 
                              Ident(s) ->
                                print_string ("Assign: "^s) ;print_newline();
                                print_string (" = ") ;print_newline();
                                print_ast exprast; print_newline()
    | _  -> failwith "print_ast"
  ) 
;;

