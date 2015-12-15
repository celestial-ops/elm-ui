module Systems.View.AWS where

import Html exposing (..)
import Common.Utils exposing (partition)
import Html.Attributes exposing (class, id, for, rows, placeholder, attribute, type', style)
import Systems.Model.Common exposing (Machine, AWS)
import Bootstrap.Html exposing (..)
import Maybe exposing (withDefault)
import Common.Components exposing (panelContents)
import Effects exposing (Effects, Never, map)
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
overviewSection : String -> List String -> List String ->  List Html
overviewSection title headers values =
   [ text title
   , ul [style [("list-style-type", "none")]] 
       (List.map2 (\ title value -> li [] [(text (title ++ ": "++ value))] ) headers values)
   ]

tablizedRow: List (a -> String) -> a -> Html
tablizedRow props v = 
   tr [] (List.map (\prop -> td [] [text (prop v)]) props) 

tablizedSection : String -> List String -> List a -> List (a -> String) -> List Html
tablizedSection title headers rows props =
  if (not (List.isEmpty rows)) then
      [ text title
      , table [class "table", id title]
         [thead []
            [ tr [] (List.map (\k -> (th [] [text k])) headers)]
            , tbody [] (List.map (\value -> (tablizedRow props value)) rows)
         ]
      ]
  else 
    []

optionalSection : String -> List String -> List String -> Bool -> List Html
optionalSection title headers values pred =
  if pred then
    overviewSection title headers values
  else
    []

summaryPanel : List Html -> List Html
summaryPanel contents =
  [ div [class "panel col-md-4 col-md-offset-1"] [
      div  [class "panel-body"] contents
    ] 
  ]
  
summarySections : (AWS, Machine) -> List (List Html)
summarySections ((aws, machine) as model)=
   List.filter (not << List.isEmpty) [ 
     overviewSection "Instance"
       ["type", "os", "endpoint", "availability zone"]
       [aws.instanceType, machine.os, aws.endpoint, withDefault "" aws.availabilityZone]
   , overviewSection "Security"
       ["user", "keypair", "security groups" ]
       [ machine.user, aws.keyName, (String.join " " aws.securityGroups)]
   , overviewSection "DNS"
       ["hostname", "domain", "ip" ]
       [ machine.hostname, machine.domain, withDefault "" machine.ip]
   , optionalSection "VPC" 
       ["VPC id", "Subnet id", "Assign IP"]
       [aws.vpc.vpcId, aws.vpc.subnetId, (toString aws.vpc.assignPublic)]
       (not (String.isEmpty aws.vpc.vpcId))
   , tablizedSection "EBS volumes" 
       ["device", "size", "type", "clear"] aws.volumes
       [.device, (toString << .size), .type', (toString << .clear)]
   , tablizedSection "Instance store blocks" 
       ["device", "volume"] aws.blockDevices
       [.device, .volume]

   ]

summarize: (AWS, Machine) -> List Html
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
  div []
    (panelContents "System" (div [] []))


