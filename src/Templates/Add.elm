module Templates.Add where

import Html.Shorthand exposing (..)
import Bootstrap.Html exposing (..)
import Common.Http exposing (postJson)
import Common.Redirect as Redirect exposing (resultHandler, successHandler)
import Html exposing (..)
import Html.Attributes exposing (class, id, href, placeholder, attribute, type', style)
import Html.Events exposing (onClick)
import Http exposing (Error(BadResponse))
import Task exposing (Task)
import Json.Decode exposing (..)
import Json.Encode as E
import Effects exposing (Effects, batch)
import Dict exposing (Dict)
import Systems.Model.Common exposing (System)
import String exposing (toLower)
import Maybe exposing (withDefault)
import Common.Utils exposing (none)
import Templates.Persistency exposing (persistModel, encodeDefaults)
import Common.Components exposing (panelContents)
import Systems.Add.Common exposing (..)
import Common.Editor exposing (loadEditor, getEditor)
import Systems.Add.Errors as Errors exposing (..)
import Templates.Model.Common exposing (decodeDefaults, emptyDefaults, emptyTemplate, Template)
import Debug


type alias Model = 
  {
    template : Template
  , stage : String
  , editDefaults : Bool
  , saveErrors : Errors.Model
  }

type Stage = 
  Template
    | Error


type Action = 
  SaveTemplate
  | NoOp
  | Cancel
  | LoadEditor
  | SetDefaults String
  | TemplateSaved (Result Http.Error SaveResponse)
  | SetSystem System
  | NameInput String
  | DefaultsInput String

init =
  let
    (errorsModel, _ ) = Errors.init
  in
    none (Model emptyTemplate "" False errorsModel)   

setErrors : Model -> Redirect.Errors -> (Model, Effects Action)
setErrors ({saveErrors} as model) es =
  let
    newErrors = {saveErrors | errors = es}  
  in 
    ({model | saveErrors = newErrors}, Effects.none)

intoTemplate ({template} as model) {openstack, physical, aws, digital, gce} = 
    let 
      newTemplate = {template | openstack = openstack, physical = physical, aws = aws, digital = digital, gce = gce} 
    in 
      {model | template = newTemplate}

update : Action ->  Model-> (Model , Effects Action)
update action ({template, stage, editDefaults} as model) =
  case action of
    SaveTemplate -> 
      if editDefaults == False then
        (model, persistModel saveTemplate template stage)
      else
        (model, getEditor NoOp)

    SetSystem system -> 
      none (intoTemplate model system)

    LoadEditor -> 
      ({ model | editDefaults = not editDefaults}, loadEditor NoOp (encodeDefaults emptyDefaults stage))
    
    NameInput name -> 
      let 
        newTemplate = { template | name = name }
      in 
        none { model | template = newTemplate} 

    SetDefaults json -> 
       let 
         newTemplate = { template | defaults = Just (decodeDefaults json) }
       in 
         ({ model | template = newTemplate}, persistModel saveTemplate template stage)
    
    TemplateSaved result -> 
      Debug.log (toString result) (none model)

    _ -> 
      (model, Effects.none)

    
buttons : Signal.Address Action -> Model -> List Html
buttons address model =
  let
    margin = style [("margin-left", "30%")]
    click = onClick address
  in 
   [ 
      button [id "Cancel", class "btn btn-primary", margin, click Cancel] [text "Cancel"]
    , button [id "Save", class "btn btn-primary", margin, click SaveTemplate] [text "Save"]
   ]
 
view : Signal.Address Action -> Model -> List Html
view address ({template, editDefaults} as model) =
 [ row_ [
     div [class "col-md-offset-2 col-md-8"] [
       div [class "panel panel-default"]
         (panelContents "New Template" 
           (Html.form [] [
             div [class "form-horizontal", attribute "onkeypress" "return event.keyCode != 13;" ] [
                  group' "Name" (inputText address NameInput " "  template.name)
                , group' "Edit defaults" (checkbox address LoadEditor editDefaults)
                , div [id "jsoneditor", style [("width", "550px"), ("height", "400px"), ("margin-left", "25%")]] []
                ]
                 
           ]))
     ]
   ]
 , row_ (buttons address model)
 ]

-- Effects

type alias SaveResponse = 
  { message : String , id : Int } 

saveResponse : Decoder SaveResponse
saveResponse = 
  object2 SaveResponse
    ("message" := string) 
    ("id" := int)

saveTemplate: String -> Effects Action
saveTemplate json = 
  postJson (Http.string json) saveResponse "/templates"  
    |> Task.toResult
    |> Task.map TemplateSaved
    |> Effects.task


