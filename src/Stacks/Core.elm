module Stacks.Core where

import Effects exposing (Effects)
import Html exposing (..)
import Stacks.Add as Add
import Nav.Common exposing (Active(Jobs), Section(Stats, Launch, Add, List, View))
import Common.Components exposing (asList, notImplemented)
import Debug

type alias Model = 
  {
    add : Add.Model 
  , navChange : Maybe (Active, Section)
  }
 
init : (Model , Effects Action)
init =
  let
    (add, addEffects) = Add.init
    effects = [
      Effects.map StacksAdd addEffects
    ]
  in
   (Model add Nothing, Effects.batch effects)

-- Update 

type Action = 
  NoOp
    | StacksAdd Add.Action

update : Action ->  Model-> (Model , Effects Action)
update action ({add} as model) =
  case action of 
    StacksAdd addAction -> 
      let
        (newAdd, effects) = Add.update addAction add
      in
        ({model | add = newAdd}, Effects.map StacksAdd effects)
    
    _ -> 
      (model, Effects.none)

-- View

view : Signal.Address Action -> Model -> Section -> List Html
view address model section =
  case section of
    Add ->
      asList (Add.view (Signal.forwardTo address StacksAdd) model.add)

    _ -> 
      asList notImplemented


loadTemplates ({add} as model) =
  let
   (newAdd, effects) = Add.update Add.LoadTemplates add
  in
   ({model | add = newAdd }, Effects.map StacksAdd effects)

