module Types.Persistency where

import Types.Model exposing (Type, Options(BoolOption, StringOption)) 
import Effects exposing (Effects)
import Json.Encode as E exposing (..)
import Maybe exposing (withDefault)
import Dict exposing (Dict)


moduleEncoder {name, src, options}  = 
  object [
    ("name", string name)
  , ("src", string src)
  ]

option o = 
  case o of
    BoolOption value -> 
       bool value

    StringOption value -> 
       string value

class c = 
  dictEncoder option c 

puppetEncoder {module', args, classes} = 
  object [
    ("module", moduleEncoder module')
  , ("args", list (List.map string args))
  , ("classes", dictEncoder class classes)
  ]

dictEncoder enc dict = 
   Dict.toList dict 
     |> List.map (\(k,v) -> (k, enc v)) 
     |> object 


encode: Type -> Value
encode ({type', description, puppetStd}) =
 object [
    ("type" , string type')
  , ("description" , string (withDefault "" description))
  , ("puppet-std", dictEncoder puppetEncoder puppetStd)
 ] 


persistModel : (String -> Effects a) -> Value -> Effects a
persistModel f value =
    (f (E.encode 0 value))

persistType f type' = 
  persistModel f (encode type')

