module Systems.View.Digital where

import Html exposing (..)
import Common.Utils exposing (partition, withDefaultProp)
import Html.Attributes exposing (class, id, for, rows, placeholder, attribute, type', style)
import Systems.Model.Common exposing (Machine)
import Systems.Model.Digital exposing (Digital)
import Bootstrap.Html exposing (..)
import Maybe exposing (withDefault)
import Common.Components exposing (fixedPanel)
import Effects exposing (Effects, Never, map)
import Common.Summary exposing (..)
import String

-- Model 
type alias Model = 
  {
   id : Int
  }

init : (Model , Effects Action)
init =
  (Model 0 , Effects.none)
  
-- Update
type Action = 
  NoOp

-- View
   
summarySections : (Digital, Machine) -> List (List Html)
summarySections ((digital, machine) as model) =
   [ 
     overviewSection "Instance" ["size", "os", "region"] 
       [digital.size, machine.os, digital.region]
   , overviewSection "Security" ["user"] [ machine.user]
   , overviewSection "Networking" ["hostname", "domain", "private networking" ] 
      [ machine.hostname, machine.domain, (toString digital.privateNetworking)]
   ]

summarize: (Digital, Machine) -> List Html
summarize model =
  [div [] [ h4 [] [(text "System overview")] 
          , div [style [("line-height", "1.8"),("list-style-type", "none") ]] 
             (summarySections model |> List.map summaryPanel
                                    |> partition 2 
                                    |> (List.map List.concat) 
                                    |> (List.map row_))
          ]
  ]


view : Signal.Address Action -> Model -> Html
view address model =
    fixedPanel (div [] [])


