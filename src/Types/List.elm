module Types.List where

import Html exposing (..)
import Effects exposing (Effects)
import Dict exposing (Dict)
import Common.Http exposing (getJson)

import Types.Model exposing (..)
import Pager exposing (..)
import Table

import Bootstrap.Html exposing (..)
import Json.Decode as Json exposing (..)
import Html.Attributes exposing (type', class, id, style, attribute)
import Http exposing (Error(BadResponse))
import Effects exposing (Effects)
import Task
import Maybe exposing (withDefault)
import Common.Errors exposing (successHandler)
import Types.Model as Model exposing (Type)
import Common.Utils exposing (none)
import Debug

type alias Model = 
  { types : List Type
  , table : Table.Model Type
  , pager : Pager.Model
  } 

typeRow : String -> Type -> List Html
typeRow id {type', description } = 
    [ td [] [ text type' ]
    , td [] [ text "Puppet standalone"]
    , td [] [ text (withDefault "" description)]
    ]

init : (Model , Effects Action)
init =
  let 
    table = Table.init "typesListing" True ["Name", "Provisioner", "Description"] typeRow "Types"
  in 
    (Model [] table Pager.init , getTypes SetTypes)

type Action = 
  LoadPage (Table.Action Type)
    | GotoPage Pager.Action
    | SetTypes (Result Http.Error (List Type))
    | NoOp

setTypes: Model -> List Type -> (Model , Effects Action)
setTypes ({pager, table} as model) types = 
  let
    total = List.length types
    typePairs = List.map (\ ({type'} as item) -> (type', item)) types
    newPager = (Pager.update (Pager.UpdateTotal (Basics.toFloat total)) pager)
    newTable = (Table.update (Table.UpdateRows typePairs) table)
  in
    none { model | types = types, pager = newPager, table = newTable }


update : Action ->  Model-> (Model , Effects Action)
update action model =
  case action of
    SetTypes result ->
      successHandler result model (setTypes model) NoOp
     
    _ -> 
      none model

view : Signal.Address Action -> Model -> List Html
view address ({types, pager, table} as model) =
  [ div [class ""] [
    row_ [
      div [class "col-md-offset-1 col-md-10"] [
        panelDefault_ (Table.view (Signal.forwardTo address LoadPage) table)
      ]
    ],
   row_ [(Pager.view (Signal.forwardTo address GotoPage) pager)]
  ]]
  

-- Decoding

typesList : Decoder (List Type)
typesList =
   at ["types"] (list Model.type')

-- Effects
getTypes action = 
  getJson typesList "/types" 
    |> Task.toResult
    |> Task.map action
    |> Effects.task


