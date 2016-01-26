module Systems.Add.Encoders where

import Json.Encode as E exposing (..)
import Systems.Model.Common exposing (..)

import Systems.Model.AWS as AWS exposing (AWS, emptyVpc, emptyAws)
import Systems.Model.Openstack as Openstack exposing (Openstack, OpenstackDefaults, emptyOpenstack, emptyOpenstackDefaults)
import Systems.Model.GCE exposing (GCE, emptyGce)
import Systems.Model.Digital exposing (Digital, emptyDigital)
import Systems.Model.Physical exposing (Physical, emptyPhysical)

import Systems.Add.AWS exposing (ebsTypes)
import Dict exposing (Dict)
import Maybe exposing (withDefault)
import Common.Utils exposing (defaultEmpty)
import String

awsVolumeEncoder : AWS.Volume -> Value
awsVolumeEncoder volume =
  object [
      ("volume-type", maybeString (Dict.get volume.type' ebsTypes))
    , ("size", int volume.size)
    , ("iops", int (withDefault 0 volume.iops))
    , ("device", string volume.device)
    , ("clear", bool volume.clear)
  ]


blockEncoder : AWS.Block -> Value
blockEncoder block =
  object [
      ("volume", string block.volume)
    , ("device", string block.device)
  ]

vpcEncoder : AWS.VPC -> Value
vpcEncoder ({vpcId} as vpc) =
  if String.isEmpty vpcId then
    null
  else
    object [
        ("subnet-id", string vpc.subnetId)
      , ("vpc-id", string vpc.vpcId)
      , ("assign-public", bool vpc.assignPublic)
    ]

awsEncoder : AWS -> Value
awsEncoder aws =
  object [
      ("key-name", string aws.keyName)
    , ("endpoint", string aws.endpoint)
    , ("instance-type", string aws.instanceType)
    , ("ebs-optimized", bool (withDefault False aws.ebsOptimized))
    , ("availability-zone", maybeString aws.availabilityZone)
    , ("security-groups", list (List.map string (defaultEmpty aws.securityGroups)))
    , ("vpc", vpcEncoder (withDefault emptyVpc aws.vpc))
    , ("block-devices", list (List.map blockEncoder (defaultEmpty aws.blockDevices)))
    , ("volumes", list (List.map awsVolumeEncoder (defaultEmpty aws.volumes)))
  ]

gceEncoder : GCE -> Value
gceEncoder gce =
  object [
      ("machine-type", string gce.machineType)
    , ("zone", string gce.zone)
    , ("tags", list (List.map string (defaultEmpty gce.tags)))
    , ("project-id", string gce.projectId)
  ]

digitalEncoder : Digital -> Value
digitalEncoder digital =
  object [
      ("size", string digital.size)
    , ("region", string digital.region)
    , ("private-networking", bool digital.privateNetworking)
  ]

optional : (a -> Value) -> Maybe a -> Value
optional enc value =
  case value of
    Just v -> 
      enc v
    Nothing -> 
       null

physicalEncoder : Physical -> Value
physicalEncoder physical =
  object [
      ("mac", optional string physical.mac)
    , ("broadcast", optional string physical.broadcast)
  ]


openstackVolumeEncoder : Openstack.Volume -> Value
openstackVolumeEncoder volume =
  object [
      ("device", string volume.device)
    , ("size", int volume.size)
    , ("clear", bool volume.clear)
  ]


maybeString optional = 
  case optional of 
    Just value -> 
      (string value)
    Nothing -> 
      null

openstackEncoder : Openstack -> Value
openstackEncoder openstack =
  object [
      ("flavor", string openstack.flavor)
    , ("tenant", string openstack.tenant)
    , ("floating-ip", maybeString openstack.floatingIp)
    , ("floating-ip-pool", maybeString openstack.floatingIpPool)
    , ("key-name", string openstack.keyName)
    , ("security-groups", list (List.map string (defaultEmpty openstack.securityGroups)))
    , ("networks", list (List.map string openstack.networks))
    , ("volumes", list (List.map openstackVolumeEncoder (defaultEmpty openstack.volumes)))
  ]

machineEncoder : Machine -> Value
machineEncoder machine =
  object [
      ("domain", string machine.domain)
    , ("hostname", string machine.hostname)
    , ("ip", optional string machine.ip)
    , ("os", string machine.os)
    , ("user", string machine.user)
  ]

encoderOf {openstack, physical, aws, digital, gce} stage =
  case stage of 
    "AWS" -> 
       ("aws", awsEncoder (withDefault emptyAws aws))

    "GCE" -> 
       ("gce" , gceEncoder (withDefault emptyGce gce))

    "Digital" -> 
       ("digital-ocean" , digitalEncoder (withDefault emptyDigital digital))
   
    "Physical" -> 
       ("physical" , physicalEncoder (withDefault emptyPhysical physical))

    "Openstack" -> 
      ("openstack" , openstackEncoder (withDefault emptyOpenstack openstack))

    _ -> 

     ("",null)

encode: System -> String -> Value
encode ({owner, env, type', machine} as system) stage =
 object [
    ("type" , string type')
  , ("owner" , string owner)
  , ("env" , string env)
  , (encoderOf system stage)
  , ("machine" , machineEncoder machine)
 ] 


