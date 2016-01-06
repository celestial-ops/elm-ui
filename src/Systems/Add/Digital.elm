module Systems.Add.Digital where

import Bootstrap.Html exposing (..)
import Html.Shorthand exposing (..)
import Html exposing (..)
import Html.Attributes exposing (class, id, for, rows, placeholder, attribute, type', style)
import Html.Events exposing (onClick)
import Systems.Add.Common exposing (..)
import Systems.View.GCE exposing (summarize)
import Systems.Add.Validations exposing (..)
import Environments.List as ENV exposing (Environment, Template, Hypervisor(OSTemplates))
import Dict as Dict exposing (Dict)
import Systems.Model.Common exposing (Machine, emptyMachine)
import Systems.Model.Digital exposing (..)
import Effects exposing (Effects, batch)
import Common.Components exposing (panelContents)
import Common.Utils exposing (withDefaultProp, defaultEmpty)
import String
import Maybe exposing (withDefault)
import Debug

-- Model 

type alias Model = 
  { step : Step
  , prev : List Step
  , next : List Step
  , digital : Digital
  , machine : Machine
  , environment : Environment
  , errors : Dict String (List Error)
  }

init : (Model , Effects Action)
init =
  let 
    steps = [ Instance, Summary ]
  in 
  (Model Zero [] steps (emptyDigital) (emptyMachine) Dict.empty Dict.empty, Effects.none)

type Action = 
  Next 
  | Back 
  | Update Environment
  | SelectSize String
  | SelectOS String
  | PrivateNetworking
  | SelectRegion String
  | UserInput String
  | HostnameInput String
  | DomainInput String

type Step = 
  Zero
  | Instance
  | Networking
  | Summary

-- Update

setDigital : (Digital -> Digital) -> Model -> Model
setDigital f ({digital, errors} as model) =
  let
    newGce = f digital
  in
   { model | digital = newGce }

setMachine: (Machine-> Machine) -> Model -> Model
setMachine f ({machine} as model) =
  let
    newMachine = f machine
  in
   { model | machine = newMachine }

validationOf : String -> List (a -> Error) -> (Model -> a) -> Model -> Model
validationOf key validations value ({errors} as model) =
   let
     res = List.filter (\error -> error /= None) (List.map (\validation -> (validation (value model))) validations)
     newErrors = Dict.update key (\_ -> Just res) errors
   in
     {model | errors = newErrors}

 
stringValidations = Dict.fromList [
    vpair Instance [
        ("Hostname", validationOf "Hostname" [notEmpty] (\({machine} as model) -> machine.hostname))
      , ("Domain", validationOf "Domain" [notEmpty] (\({machine} as model) -> machine.domain))
      , ("User", validationOf "User" [notEmpty] (\({machine} as model) -> machine.user))
    ]
 ]

validate : Step -> String -> Dict String (Dict String (Model -> Model)) -> (Model -> Model)
validate step key validations =
  let
    stepValidations =  withDefault Dict.empty (Dict.get (toString step) validations)
  in
    withDefault identity (Dict.get key stepValidations)


validateAll : Step -> Model -> Model
validateAll step model =
  let
    stepValues = (List.map (\vs -> withDefault Dict.empty (Dict.get (toString step) vs)) [stringValidations])
  in
    List.foldl (\v m -> (v m)) model (List.concat (List.map Dict.values stepValues))

notAny:  Dict String (List Error) -> Bool
notAny errors =
  List.isEmpty (List.filter (\e -> not (List.isEmpty e)) (Dict.values errors))

update : Action -> Model-> Model
update action ({next, prev, step, digital, machine} as model) =
  case action of
    Next -> 
      let
        nextStep = withDefault Instance (List.head next)
        nextSteps = defaultEmpty (List.tail next)
        prevSteps = if step /= Zero then List.append prev [step] else prev
        ({errors} as newModel) = (validateAll step model)
      in
        if notAny errors then
          {newModel | step = nextStep, next = nextSteps, prev = prevSteps}
        else 
          newModel

    Back -> 
      let
        prevStep = withDefault Zero (List.head (List.reverse prev))
        prevSteps = List.take ((List.length prev) - 1) prev
        nextSteps = if step /= Zero then List.append [step] next else next
        ({errors} as newModel) = (validateAll step model)
      in
        if notAny errors then
          {model | step = prevStep, next = nextSteps, prev = prevSteps}
        else 
          model

    Update environment -> 
        let
           newModel = { model | environment = environment }
        in 
          case List.head (Dict.keys (getOses newModel)) of
             Just os -> 
               if (String.isEmpty machine.os) then
                 { newModel | machine = {machine | os = os }}
               else 
                 newModel
             Nothing -> 
               newModel

    SelectSize size -> 
      setDigital (\digital-> {digital| size = size }) model

    SelectOS newOS -> 
      setMachine (\machine -> {machine | os = newOS }) model

    SelectRegion region -> 
      setDigital (\digital-> {digital | region = region }) model 

    UserInput user -> 
       model 
        |> setMachine (\machine -> {machine | user = user })
        |> validate step "User" stringValidations

    HostnameInput host -> 
      model 
        |> setMachine (\machine -> {machine | hostname = host })
        |> validate step "Hostname" stringValidations
         
    DomainInput domain -> 
      model 
        |> setMachine (\machine -> {machine | domain = domain})
        |> validate step "Domain" stringValidations

    PrivateNetworking -> 
       setDigital (\digital -> {digital | privateNetworking = (not (digital.privateNetworking))}) model



hasNext : Model -> Bool
hasNext model =
  not (List.isEmpty model.next)

hasPrev : Model -> Bool
hasPrev model =
  not (List.isEmpty model.prev)

getOses : Model -> Dict String Template
getOses model =
  let 
    hypervisor = withDefault (OSTemplates Dict.empty) (Dict.get "digital" model.environment)
  in 
    case hypervisor of
      OSTemplates oses -> 
        oses
      _ -> 
        Dict.empty

instance : Signal.Address Action -> Model -> List Html
instance address ({digital, machine, errors} as model) =
  let
    check = withErrors errors
    region = withDefault "" (List.head regions)
  in
    [div [class "form-horizontal", attribute "onkeypress" "return event.keyCode != 13;" ] 
       [ 
         legend [] [text "Properties"]
       , group' "Size" (selector address SelectSize sizes digital.size)
       , group' "OS" (selector address SelectOS (Dict.keys (getOses model)) machine.os)
       , group' "Region" (selector address SelectRegion regions digital.region)
       , legend [] [text "Security"]
       , check "User" (inputText address UserInput "" model.machine.user) 
       , group' "Private Networking" (checkbox address PrivateNetworking digital.privateNetworking)
       ]
    ]

withErrors : Dict String (List Error) -> String ->  Html -> Html
withErrors errors key widget =
  group key widget (defaultEmpty  (Dict.get key errors))


stepView :  Signal.Address Action -> Model -> List Html
stepView address ({digital, machine} as model) =
  case model.step of
    Instance -> 
      instance address model 

    Summary -> 
      [div  [] [ ]]
      -- summarize (digital, machine)

    _ -> 
      Debug.log (toString model.step) [div [] []]


view : Signal.Address Action -> Model -> List Html
view address ({step} as model)=
  panelContents (toString step) (Html.form [] (stepView address model))
