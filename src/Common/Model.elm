module Common.Model where

import Json.Decode as Json exposing (..)
import Dict exposing (Dict)
import String

type Options = 
  BoolOption Bool 
    | StringOption String
    | IntOption Int
    | DictOption (Dict String Options)

valueOf option = 
  case option of 
    BoolOption bool -> 
      (String.toLower (toString bool))

    StringOption str -> 
      str

    IntOption int -> 
      (toString int)

    DictOption dict -> 
      (toString dict)
      



dictOption' : () -> Decoder Options
dictOption' _ =
  Json.succeed ()
     `Json.andThen`
         (option  >> Json.dict >> Json.map DictOption)

option _ = 
  (oneOf [map BoolOption bool, map StringOption string, map IntOption int,  (dictOption' ())])


