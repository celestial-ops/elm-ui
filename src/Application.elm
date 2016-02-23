module Application where

import Html exposing (..)
import Effects exposing (Effects, Never, batch, map)

import Html.Attributes exposing (type', class, id, href, attribute, height, width, alt, src)
import Systems.Core as Systems 
import Stacks.Core as Stacks 
import Jobs.List exposing (Action(Polling))
import Jobs.Stats
import Common.Utils exposing (none)
import Types.Core as Types
import Templates.Core as Templates
import Nav.Side as NavSide exposing (Active(Stacks, Types, Systems, Jobs, Templates), Section(Stats, Launch, Add, List, View))
import Nav.Header as NavHeader

import Bootstrap.Html exposing (..)
import Debug

init : (Model, Effects Action)
init =
  let 
    (jobsList, jobsListAction) = Jobs.List.init
    (jobsStat, jobsStatAction) = Jobs.Stats.init
    (navHeaderModel, navHeaderAction) = NavHeader.init
    (types, typesAction) = Types.init
    (templates, templatesAction) = Templates.init
    (systems, systemsAction) = Systems.init
    (stacks, stacksAction) = Stacks.init
    effects = [ 
                Effects.map TemplatesAction templatesAction
              , Effects.map TypesAction typesAction
              , Effects.map SystemsAction systemsAction
              , Effects.map StacksAction stacksAction
              , Effects.map NavHeaderAction navHeaderAction
              , Effects.map JobsList jobsListAction
              , Effects.map JobsStats jobsStatAction
              ]
  in
    (Model systems stacks jobsList jobsStat types templates NavSide.init navHeaderModel, Effects.batch effects) 

type alias Model = 
  { 
    systems : Systems.Model
  , stacks : Stacks.Model
  , jobsList : Jobs.List.Model
  , jobsStats : Jobs.Stats.Model
  , types : Types.Model
  , templates : Templates.Model
  , navSide : NavSide.Model 
  , navHeader : NavHeader.Model 
  }


type Action = 
  SystemsAction Systems.Action
    | StacksAction Stacks.Action
    | JobsList Jobs.List.Action
    | JobsStats Jobs.Stats.Action
    | NavSideAction NavSide.Action
    | NavHeaderAction NavHeader.Action
    | TypesAction Types.Action
    | TemplatesAction Templates.Action
    | NoOp

-- Navigation changes
jobListing : Model -> (Model , Effects Action)
jobListing ({navSide} as model) = 
  let
    (newJobs, effects) = Jobs.List.init
  in 
    ({model | jobsList = newJobs}, Effects.map JobsList effects)

goto : Active -> Section -> (Model, Effects Action) -> (Model, Effects Action)
goto active section (({navSide} as model), effects)  =
  ({model | navSide = NavSide.update (NavSide.Goto active section) navSide}, effects)

navigate : Action -> (Model , Effects Action) -> (Model , Effects Action)
navigate action ({systems, templates, stacks} as model , effects) =
  case action of
    SystemsAction action -> 
      case systems.navChange  of
         Just (Jobs, List) -> 
           let
             (withJobs, jobEffects) = (jobListing model)
           in
             goto Jobs List (withJobs, jobEffects)
 
         Just (Systems, section) -> 
            goto Systems section (model , effects)

         Just (Templates, section) -> 
            let
               (hyp, system) = (Systems.addedSystem systems)
               add = (Templates.add hyp system)
               (newTemplates, effects) = Templates.update add model.templates 
            in
              goto Templates section ({model | templates = newTemplates}, Effects.map TemplatesAction effects)
         _ -> 
            (model, effects) 

    TemplatesAction action -> 
        case templates.navChange of
          Just (active, dest) -> 
            goto active dest (model, effects)

          _ -> 
            (model, effects) 

    NavSideAction navAction -> 
      case navAction of 
        NavSide.Goto Stacks Add -> 
          let
            (newStacks, effects) = Stacks.loadTemplates stacks
          in
            ({ model | stacks = newStacks }, Effects.map StacksAction effects)

        _ -> 
         (model, effects)

    _ -> 
      (model, effects)


route : Action ->  Model -> (Model , Effects Action)
route action ({navSide, types, jobsList, jobsStats, systems, templates, stacks} as model) =
  case action of 
    JobsList jobAction -> 
      if jobAction == Polling && navSide.active /= Jobs then
        (model, Effects.none)
      else
        let 
          (newJobList, effects) = Jobs.List.update jobAction jobsList 
        in
          ({model | jobsList = newJobList}, Effects.map JobsList effects) 

    JobsStats jobAction -> 
      let 
        (newJobsStats, effects) = Jobs.Stats.update jobAction jobsStats
      in
        ({model | jobsStats= newJobsStats }, Effects.map JobsStats effects) 

    NavSideAction navAction -> 
      let 
        newNavSide = NavSide.update navAction model.navSide
        (newModel, effects) = init
      in
        ({ newModel | navSide = newNavSide }, effects)

    NavHeaderAction navAction -> 
      let 
        (newNavHeader, effects) = NavHeader.update navAction model.navHeader
      in
        ({ model | navHeader = newNavHeader}, Effects.map NavHeaderAction effects)

    TypesAction action -> 
      let 
       (newTypes, effects) = Types.update action types
      in
       ({ model | types = newTypes}, Effects.map TypesAction effects) 

    StacksAction action -> 
      let 
       (newStacks, effects) = Stacks.update action stacks
      in
       ({ model | stacks = newStacks}, Effects.map StacksAction effects) 

    TemplatesAction action -> 
      let 
        (newTemplates, effects) = Templates.update action templates
      in
        ({ model | templates = newTemplates} , Effects.map TemplatesAction effects)

    SystemsAction action -> 
      let 
        (newSystems, effects) = Systems.update action systems
      in
        ({ model | systems = newSystems}, Effects.map SystemsAction effects)

    _ -> 
        none model


update : Action ->  Model -> (Model , Effects Action)
update action model = 
   navigate action (route action model)

activeView : Signal.Address Action -> Model -> List Html
activeView address ({jobsList, jobsStats} as model) =
  case model.navSide.active of
    Systems -> 
      Systems.view (Signal.forwardTo address SystemsAction) model.systems model.navSide.section 

    Types -> 
      Types.view (Signal.forwardTo address TypesAction) model.types model.navSide.section

    Templates -> 
      Templates.view (Signal.forwardTo address TemplatesAction) model.templates model.navSide.section
    
    Jobs -> 
      case model.navSide.section of
        List ->
          Jobs.List.view (Signal.forwardTo address JobsList) jobsList

        Stats ->
          Jobs.Stats.view (Signal.forwardTo address JobsStats) jobsStats

        _ ->
           []

    Stacks -> 
       Stacks.view (Signal.forwardTo address StacksAction) model.stacks model.navSide.section 

view : Signal.Address Action -> Model -> Html
view address model = 
  div [ class "wrapper" ] 
    (List.append
       (List.append 
         (NavHeader.view (Signal.forwardTo address NavHeaderAction) model.navHeader) 
         (NavSide.view (Signal.forwardTo address NavSideAction) model.navSide))
       [div [class "content-wrapper"]
         [section [class "content"] (activeView address model)]])

