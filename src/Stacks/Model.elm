module Stacks.Model where

type alias System = 
  {
    count : Int
  , template : String 
  }

type alias Stack = 
  {
    name : String 
  , description : String
  , systems : List System  
  }
 

emptyStack : Stack
emptyStack  =
  Stack "" "" []

