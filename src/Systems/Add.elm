module Systems.Add where

import Bootstrap.Html exposing (..)
import Html.Shorthand exposing (..)
import Common.Http exposing (postJson, SaveResponse, saveResponse)
import Common.Errors as Errors exposing (errorsSuccessHandler)
import Html exposing (..)
import Html.Attributes exposing (class, id, href, placeholder, attribute, type', style)
import Html.Events exposing (onClick)
import Http exposing (Error(BadResponse))
import Task exposing (Task)
import Json.Decode exposing (..)
import Json.Encode as E
import Effects exposing (Effects, batch)
import Dict exposing (Dict)
import Systems.Add.Common exposing (..)
import Systems.Add.AWS as AWS exposing (..)
import Systems.Add.Physical as Physical exposing (..)
import Systems.Add.Openstack as Openstack exposing (..)
import Systems.Add.GCE as GCE exposing (..)
import Systems.Add.Digital as Digital exposing (..)
import Systems.Add.General as General exposing (..)
import Systems.Add.Encoders exposing (..)
import Jobs.Common as Jobs exposing (runJob, JobResponse)
import String exposing (toLower)
import Maybe exposing (withDefault)
import Common.Utils exposing (none)
import Systems.Add.Persistency exposing (persistModel)
import Systems.Model.Common exposing (System, Machine, emptyMachine)
import Common.Wizard as Wizard
import Common.Components exposing (asList, panelContents, panel, dialogPanel, error, notImplemented)

type Stage = 
  General 
    | Error
    | Proxmox
    | AWS
    | Openstack
    | GCE
    | Digital
    | Physical

type alias Model = 
  { stage : Stage
  , awsModel : AWS.Model
  , gceModel : GCE.Model
  , physicalModel : Physical.Model
  , digitalModel : Digital.Model
  , openstackModel : Openstack.Model
  , general : General.Model
  , hasNext : Bool
  , saveErrors : Errors.Model
  }

type Action = 
  Next
  | SaveSystem
  | SaveTemplate
  | Create
  | Stage
  | Back
  | NoOp
  | AWSView AWS.Action
  | GCEView GCE.Action
  | PhysicalView Physical.Action
  | DigitalView Digital.Action
  | OpenstackView Openstack.Action
  | GeneralView General.Action
  | ErrorsView Errors.Action
  | Saved Action (Result Http.Error SaveResponse)
  | JobLaunched (Result Http.Error JobResponse)

init : (Model, Effects Action)
init =
  let 
    (aws, _) = AWS.init 
    (openstack, _) = Openstack.init 
    (gce, _) = GCE.init 
    (physical, _) = Physical.init 
    (digital, _) = Digital.init 
    (errors, _) = Errors.init
    (general, effects) = General.init 
  in 
   (Model General aws gce physical digital openstack general True errors, Effects.map GeneralView effects)


setSaved : Action -> Model -> SaveResponse -> (Model, Effects Action)
setSaved next model {id} =
  (model, runJob (toString id) (toLower (toString next)) JobLaunched)

back hasPrev model =
   let
     newModel = { model |  hasNext = True}
   in
     if hasPrev then
       newModel 
     else 
       {newModel | stage = General}

getBack ({awsModel, gceModel, digitalModel, openstackModel, physicalModel} as model) hyp = 
  let
   backs = Dict.fromList [
      ("aws", (back (Wizard.hasPrev awsModel) {model | stage = AWS , awsModel = (AWS.back awsModel)}))
    , ("gce", (back (Wizard.hasPrev gceModel) {model | stage = GCE , gceModel = (GCE.back gceModel)}))
    , ("openstack", (back (Wizard.hasPrev openstackModel) {model | stage = Openstack , openstackModel = (Openstack.back openstackModel)}))
    , ("digital-ocean", (back (Wizard.hasPrev digitalModel) {model | stage = Digital, digitalModel = Digital.back digitalModel}))
    , ("physical", (back (Wizard.hasPrev physicalModel) {model | stage = Physical, physicalModel = (Physical.back physicalModel)}))
   ]
  in
   withDefault model (Dict.get hyp backs)

machineFrom : String -> Model -> Machine
machineFrom stage {awsModel, gceModel, digitalModel, openstackModel, physicalModel} =
  let 
    machines =  Dict.fromList [
            ("aws", awsModel.machine)
          , ("gce", gceModel.machine)
          , ("openstack", openstackModel.machine)
          , ("digital", digitalModel.machine)
          , ("physical", physicalModel.machine)
      ]
  in
    withDefault emptyMachine (Dict.get (String.toLower stage) machines)

  
intoSystem : Model -> System
intoSystem ({general, awsModel, gceModel, digitalModel, openstackModel, physicalModel, stage} as model) = 
  let
    {admin, type'} =  general
    baseSystem = System admin.owner admin.environment type' (machineFrom (toString stage) model)
  in 
    baseSystem (Just awsModel.aws) (Just gceModel.gce) (Just digitalModel.digital) (Just openstackModel.openstack) (Just physicalModel.physical)
  
update : Action ->  Model-> (Model , Effects Action)
update action ({general, awsModel, gceModel, digitalModel, openstackModel, physicalModel, stage} as model) =
  case action of
    Next -> 
      let 
        {admin} = general
        current = withDefault Dict.empty (Dict.get admin.environment admin.rawEnvironments)
      in
        case general.hypervisor of
          "aws" -> 
            let
              newAws = AWS.next awsModel current 
            in
              none { model | stage = AWS, awsModel = newAws , hasNext = Wizard.hasNext newAws}

          "gce" -> 
             let
               newGce = GCE.next gceModel current 
             in
               none { model | stage = GCE, gceModel = newGce , hasNext = Wizard.hasNext newGce}

          "digital-ocean" -> 
            let
               newDigital = Digital.next digitalModel current 
            in
              none { model | stage = Digital , digitalModel = newDigital , hasNext = Wizard.hasNext newDigital}


          "physical" -> 
            let
              newPhysical = Physical.next physicalModel current 
            in
              none { model | stage = Physical , physicalModel = newPhysical , hasNext = Wizard.hasNext newPhysical}

          "openstack" -> 
            let
              newOpenstack = Openstack.next openstackModel current 
            in
              none { model | stage = Openstack , openstackModel = newOpenstack , hasNext = Wizard.hasNext newOpenstack}

          _ -> 
            (model, Effects.none)

    Back -> 
     none (getBack model general.hypervisor)

    AWSView action -> 
      let
        newAws = AWS.update action awsModel 
      in
        none { model | awsModel = newAws }

    GCEView action -> 
      let
        newGce= GCE.update action gceModel
      in
        none { model | gceModel = newGce }

    DigitalView action -> 
      let
        newDigital= Digital.update action digitalModel
      in
        none { model | digitalModel = newDigital }

    PhysicalView action -> 
      let
        newPhysical= Physical.update action physicalModel
      in
        none { model | physicalModel = newPhysical }

    OpenstackView action -> 
      let
        newOpenstack = Openstack.update action openstackModel
      in
        none { model | openstackModel = newOpenstack }

    GeneralView action -> 
      let
        newGeneral= General.update action general
      in
        none { model | general = newGeneral }

    Stage -> 
       (model, persistModel (saveSystem Stage) (intoSystem model) (toString stage))

    SaveSystem -> 
       (model, persistModel (saveSystem NoOp) (intoSystem model) (toString stage))

    Create -> 
      (model, persistModel (saveSystem Create) (intoSystem model) (toString stage))

    SaveTemplate -> 
      none model

    Saved next result -> 
      let
        ({saveErrors} as newModel, effects) = errorsSuccessHandler result model (setSaved next model) NoOp
      in
       if Errors.hasErrors saveErrors then
          ({newModel | stage = Error} , effects)
       else
          (model, effects)

    _ -> (model, Effects.none)

currentView : Signal.Address Action -> Model -> Html
currentView address ({awsModel, gceModel, digitalModel, physicalModel, openstackModel, saveErrors, general} as model)=
  case model.stage of 
    General -> 
      (General.view (Signal.forwardTo address GeneralView) general)

    AWS -> 
      (AWS.view (Signal.forwardTo address AWSView) awsModel)

    GCE -> 
      (GCE.view (Signal.forwardTo address GCEView) gceModel)

    Digital -> 
      (Digital.view (Signal.forwardTo address DigitalView) digitalModel)

    Physical -> 
      (Physical.view (Signal.forwardTo address PhysicalView) physicalModel)

    Openstack -> 
      (Openstack.view (Signal.forwardTo address OpenstackView) openstackModel)

    _ -> 
      notImplemented

saveDropdown : Signal.Address Action -> Html 
saveDropdown address =
  ul [class "dropdown-menu"] [
    li [] [a [class "SaveSystem", href "#", onClick address SaveSystem ] [text "Save system"]]
  , li [] [a [class "SaveTemplate", href "#", onClick address SaveTemplate ] [text "Save as template"]]
  , li [] [a [class "Create", href "#", onClick address Create ] [text "Create System"]]
  ]
    
buttons : Signal.Address Action -> Model -> List Html
buttons address ({hasNext} as model) =
  let
    margin = style [("margin-left", "30%")]
    click = onClick address
  in 
    [ 
      button [id "Back", class "btn btn-primary", margin, click Back] [text "<< Back"]
    , if hasNext then
       div [class "btn-group", margin]
           [button [id "Next", class "btn btn-primary", click Next] [text "Next >>"]]
      else
        div [class "btn-group", margin]
         [  button [type' "button", class "btn btn-primary", click Stage] [text "Stage"]
         ,  button [class "btn btn-primary dropdown-toggle"
                   , attribute "data-toggle" "dropdown"
                   , attribute "aria-haspopup" "true"
                   , attribute "aria-expanded" "false"] 
             [ span [class "caret"] [] , span [class "sr-only"] [] ]
          , saveDropdown address
        ]
  ]
       

errorsView address {saveErrors} = 
   let
     body = (Errors.view (Signal.forwardTo address ErrorsView) saveErrors)
   in
     dialogPanel "danger" (error "Failed to save system") (panel (panelContents body))


view : Signal.Address Action -> Model -> List Html
view address ({stage} as model) =
 [ row_ [
     (if stage /= Error then
        div [class "col-md-offset-2 col-md-8"] [
          (panel (currentView address model))
        ]
       else
         div [] (errorsView address model))
   ]
 , row_ (buttons address model)
 ]

-- Effects

saveSystem : Action -> String -> Effects Action
saveSystem next json  = 
  postJson (Http.string json) saveResponse "/systems"  
    |> Task.toResult
    |> Task.map (Saved next)
    |> Effects.task


