module Users.Session where

import Json.Decode as Json exposing (..)
import Http exposing (Error(BadResponse))
import Effects exposing (Effects)
import Task

type alias Session = 
  {
    envs : List String,
    identity : String, 
    operations : List String,
    roles : List String,
    username : String
  }

emptySession : Session
emptySession  =
  (Session [] "" [] [] "")

session : Decoder Session
session  =
  object5 Session 
    ("envs" := list string)
    ("identity" := string )
    ("operations" := list string )
    ("roles" := list string )
    ("username" := string )


getSession action = 
  Http.get session "/sessions" 
    |> Task.toResult
    |> Task.map action
    |> Effects.task

logout action =
    Http.getString "/logout" 
      |> Task.toResult
      |> Task.map action
      |> Effects.task


