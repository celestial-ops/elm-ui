module Users.Core exposing (..)

import Html exposing (..)
import Html
import Common.Utils exposing (none)
import Common.Components exposing (notImplemented, asList)


type alias Model =
    { list : List.Model
    , add : Add.Model
    , navChange : Maybe String
    }


init : ( Model, Cmd Msg )
init =
    let
        ( list, listMsgs ) =
            List.init

        ( add, addMsgs ) =
            Add.init

        msgs =
            [ Cmd.map Listing listMsgs
            , Cmd.map Adding addMsgs
            ]
    in
        ( Model list add Nothing, Cmd.batch msgs )



-- Update


type Msg
    = NoOp


navigate : Msg -> ( Model, Cmd Msg ) -> ( Model, Cmd Msg )
navigate msg (( { list } as model, msgs ) as result) =
    case msg of
        MenuClick ( job, name ) ->
            case job of
                "edit" ->
                    ( { model | navChange = Just ("/users/edit/" ++ name) }, msgs )

                "clear" ->
                    ( { model | navChange = Just ("/users/delete/" ++ name) }, msgs )

                _ ->
                    none model

        _ ->
            none model


route : Msg -> Model -> ( Model, Cmd Msg )
route msg ({ list, add } as model) =
    case msg of
        Listing listing ->
            let
                ( newList, msgs ) =
                    List.update listing list
            in
                ( { model | list = newList }, Cmd.map Listing msgs )

        Adding adding ->
            let
                ( newAdd, msgs ) =
                    Add.update adding add
            in
                ( { model | add = newAdd }, Cmd.map Adding msgs )

        _ ->
            none model


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    navigate msg (route msg model)



-- View


view : Model -> Route -> Html Msg
view ({ list, add } as model) section =
    case section of
        Routing.List ->
            Html.map Listing (List.view list)

        Routing.Add ->
            Html.map Adding (Add.view add)

        _ ->
            notImplemented
