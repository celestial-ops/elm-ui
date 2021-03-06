module Common.FormWizard where

import Effects exposing (Effects)
import Html exposing (..)
import Common.Utils exposing (withDefaultProp, defaultEmpty)
import Maybe exposing (withDefault)
import Debug
import Dict exposing (Dict)
import Common.Utils exposing (none)
import Form exposing (Form)
import Form.Validate as Validate exposing (..)
import Form.Input as Input


type alias Step s f = 
  {
    form : Form () f
  , value : s
  }

type alias Model s f = 
  {
    step : Maybe (Step s f)
  , prev : List (Step s f)
  , next : List (Step s f)
  }
 
init first steps =
   Model (Just first) [] steps 

-- Update 

type Action = 
  Next 
    | FormAction Form.Action
    | Back
    | NoOp

noErrors ({step} as model) = 
  case step of 
    Just {form} ->
      (List.isEmpty (Form.getErrors form))

    Nothing -> 
      True

append step target = 
  case step of 
    Just s -> 
      List.append target [s]

    Nothing -> 
      target

prepend step target =
  case step of 
    Just s -> 
      List.append [s] target 

    Nothing -> 
      target


update : Action -> Model s f -> Model s f
update action ({next, prev, step} as model)  =
  case action of 
    Next -> 
      let
        nextStep = (List.head next)
        nextSteps = defaultEmpty (List.tail next)
        prevSteps = append step prev
        -- newModel = update (FormAction Form.Validate) model
      in
        if noErrors model then
           { model | step = nextStep, next = nextSteps, prev = prevSteps}
        else 
           model

    Back -> 
      let
        prevStep = List.head (List.reverse prev)
        prevSteps = List.take ((List.length prev) - 1) prev
        nextSteps = prepend step next
        -- newModel = update (FormAction Form.Validate) model
      in
        if (noErrors model && prevStep /= Nothing) then
          {model | step = prevStep, next = nextSteps, prev = prevSteps}
        else 
          model

    FormAction formAction ->
      case step of 
        Just ({form} as currStep) -> 
         let 
           newForm = Form.update formAction form
           newStep = { currStep | form = newForm }
         in
           { model | step = Just newStep }

        Nothing -> 
          model


    _  -> 
      model

hasNext {wizard} =
  not (List.isEmpty wizard.next)

hasPrev {wizard}  =
  not (List.isEmpty wizard.prev)

notDone {wizard} = 
  wizard.step /= Nothing 
