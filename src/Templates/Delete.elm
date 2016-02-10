module Templates.Delete where

import Effects exposing (Effects)
import Common.Utils exposing (none)
import Html exposing (..)
import Task
import Json.Decode exposing (..)
import Http exposing (Error(BadResponse))
import Common.Components exposing (dangerCallout)
import Common.Redirect exposing (failHandler)
import Common.Http exposing (delete)
import Maybe exposing (withDefault)

type alias Model = 
  {
    name : String
  , error : String
  }
 
init : (Model , Effects Action)
init =
  none (Model "" "")

-- Update 

type Action = 
  NoOp
  | Cancel
  | Delete
  | Done
  | Deleted (Result Http.Error DeleteResponse)
  | Error String

update : Action ->  Model-> (Model , Effects Action)
update action ({name} as model) =
  case action of 
    Deleted result -> 
      failHandler result model (\{message} -> none { model | error = withDefault "Failed to delete template" message }) NoOp
       
    Delete -> 
      (model, deleteTemplate name)

    _ -> 
      none model

-- View
deleteMessage : String -> List Html
deleteMessage name =
  [
     h4 [] [ text "Notice!" ]
  ,  span [] [
          text "Template " 
        , strong [] [text name] 
        , text " will be deleted! "
     ]
 ]
errorMessage : String -> List Html
errorMessage message=
  [
    h4 [] [ text "Error!" ]
  , span [] [ text message ]
  ]

deleteView address {name} =
   dangerCallout address (deleteMessage name) (div [] []) Cancel Delete

view : Signal.Address Action -> Model -> List Html
view address ({error} as model) =
  if error /= "" then
    dangerCallout address (errorMessage error) (div [] []) Cancel Done
  else
    deleteView address model  

type alias DeleteResponse = 
  { message : String } 

deleteResponse : Decoder DeleteResponse
deleteResponse = 
  object1 DeleteResponse
    ("message" := string) 

deleteTemplate : String -> Effects Action
deleteTemplate  name = 
  delete deleteResponse ("/templates/" ++ name)
    |> Task.toResult
    |> Task.map Deleted
    |> Effects.task

succeeded action {error} = 
  if action == (Deleted (Result.Ok { message = "Template deleted"} )) then
    True
  else
    False