module Systems.View where

import Effects exposing (Effects)
import Systems.Model.Common exposing (System, Machine, emptySystem)
import Systems.Model.AWS exposing (emptyAws)
import Common.Http exposing (getJson)

-- Effects
import Task
import Http exposing (Error(BadResponse))
import Systems.Decoders exposing (systemDecoder)
import Common.Errors exposing (successHandler)

-- View
import Common.Components exposing (fixedPanel, asList, notImplemented)
import Html exposing (..)
import Systems.View.AWS  as AWSView
import Systems.View.KVM as KVMView
import Systems.View.Openstack as OpenstackView
import Systems.View.GCE as GCEView
import Systems.View.Digital as DigitalView

import Maybe exposing (withDefault)

-- Model 
type alias Model = 
  {
    system : System
   }

init : (Model , Effects Action)
init =
  (Model emptySystem, Effects.none)

-- Update
type Action = 
  ViewSystem String
    | SetSystem (Result Http.Error System)
    | NoOp

setSystem : Model -> System -> (Model , Effects Action)
setSystem model system =
  ({model | system = system}, Effects.none)

update : Action ->  Model-> (Model , Effects Action)
update action model =
  case action of
    ViewSystem id -> 
      (model, getSystem id)

    SetSystem result -> 
      successHandler result model (setSystem model) NoOp
      
    NoOp -> 
      (model, Effects.none)
      
-- View

toHtml ({system} as model) f prop= 
  case prop of
    Just value -> 
       asList (fixedPanel (div [] (f (value, system.machine))))
    Nothing -> 
       []

view : Signal.Address Action -> Model -> List Html
view address ({system} as model) =
    let
      options = [ toHtml  model AWSView.summarize system.aws
                , toHtml  model GCEView.summarize system.gce
                , toHtml  model OpenstackView.summarize system.openstack
                , toHtml  model KVMView.summarize system.kvm
                , toHtml  model DigitalView.summarize system.digital]
    in 
      withDefault (asList notImplemented) (List.head (List.filter (not << List.isEmpty) options))

-- Effects

getSystem : String -> Effects Action
getSystem id = 
  getJson systemDecoder ("/systems/" ++ id)
    |> Task.toResult
    |> Task.map SetSystem
    |> Effects.task

