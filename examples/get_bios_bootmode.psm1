###
#
# Lenovo Redfish examples - Get bios boot mode
# Copyright Notice:
#
# Copyright 2018 Lenovo Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.
###


###
#  Import utility libraries
###get
Import-module $PSScriptRoot\lenovo_utils.psm1

function get_bios_bootmode
{
    <#
   .Synopsis
    Cmdlet used to Get bios boot mode
   .DESCRIPTION
    Cmdlet used to Get bios boot order from BMC using Redfish API. Information will be printed to the screen. Connection information can be specified via command parameter or configuration file.
    - ip: Pass in BMC IP address
    - username: Pass in BMC username
    - password: Pass in BMC username password
    - system_id:Pass in ComputerSystem instance id(None: first instance, all: all instances)
    - config_file: Pass in configuration file path, default configuration file is config.ini
   .EXAMPLE
    get_bios_bootmode -ip 10.10.10.10 -username USERID -password PASSW0RD 
   #>
   
    param(
        [Parameter(Mandatory=$False)]
        [string]$ip="",
        [Parameter(Mandatory=$False)]
        [string]$username="",
        [Parameter(Mandatory=$False)]
        [string]$password="",
        [Parameter(Mandatory=$False)]
        [string]$system_id="None",
        [Parameter(Mandatory=$False)]
        [string]$config_file="config.ini"
        )
        

    # Get configuration info from config file
    $ht_config_ini_info = read_config -config_file $config_file
    
    # If the parameter is not specified via command line, use the setting from configuration file
    if ($ip -eq "")
    { 
        $ip = [string]($ht_config_ini_info['BmcIp'])
    }
    if ($username -eq "")
    {
        $username = [string]($ht_config_ini_info['BmcUsername'])
    }
    if ($password -eq "")
    {
        $password = [string]($ht_config_ini_info['BmcUserpassword'])
    }
    if ($system_id -eq "")
    {
        $system_id = [string]($ht_config_ini_info['SystemId'])
    }

    try
    {
        $session_key = ""
        $session_location = ""

        # Create session
        $session = create_session -ip $ip -username $username -password $password
        $session_key = $session.'X-Auth-Token'
        $session_location = $session.Location

        # Build headers with session key for authentication
        $JsonHeader = @{ 
            "X-Auth-Token" = $session_key
            "Accept" = "application/json"
        }
        
        # Get the system url collection
        $system_url_collection = @()
        $system_url_collection = get_system_urls -bmcip $ip -session $session -system_id $system_id
<#
/redfish/v1/Systems/Self
{
    "Bios": {
        "@odata.id": "/redfish/v1/Systems/Self/Bios"
    },
    "BiosVersion": "1203",
    "Boot": {
        "BootNext": null,
        "BootOptions": {
            "@odata.id": "/redfish/v1/Systems/Self/BootOptions"
        },
        "BootOrder": [
            "Boot0000"
        ],
        "BootOrderPropertySelection": "BootOrder",
        "BootSourceOverrideEnabled": "Disabled",
        "BootSourceOverrideMode": "Legacy",
        "BootSourceOverrideTarget": "None",
        "Certificates": {
            "@odata.id": "/redfish/v1/Systems/Self/Boot/Certificates"
        },
        "HttpBootUri": null,
        "UefiTargetBootSourceOverride": null
    },
}
BootSourceOverrideMode 是當前生效的開機模式，而不是「下一次覆蓋」才使用的模式。即使 BootSourceOverrideEnabled 為 Disabled，此欄位依然正確反映系統目前的 BIOS 模式

/redfish/v1/Systems/Self/BootOptions
{
    "@odata.context": "/redfish/v1/$metadata#BootOptionCollection.BootOptionCollection",
    "@odata.etag": "\"1770950790\"",
    "@odata.id": "/redfish/v1/Systems/Self/BootOptions",
    "@odata.type": "#BootOptionCollection.BootOptionCollection",
    "Description": "Collection of BootOption for this system",
    "Members": [
        {
            "@odata.id": "/redfish/v1/Systems/Self/BootOptions/0000"
        }
    ],
    "Members@odata.count": 1,
    "Name": "BootOption Collection"
}

/redfish/v1/Systems/Self/BootOptions/0000
{
    "@Redfish.Settings": {
        "@odata.type": "#Settings.v1_2_2.Settings",
        "SettingsObject": {
            "@odata.id": "/redfish/v1/Systems/Self/BootOptions/0000/SD"
        }
    },
    "@odata.context": "/redfish/v1/$metadata#BootOption.BootOption",
    "@odata.etag": "\"1770868744\"",
    "@odata.id": "/redfish/v1/Systems/Self/BootOptions/0000",
    "@odata.type": "#BootOption.v1_0_3.BootOption",
    "Alias": "Hdd",
    "BootOptionEnabled": true,
    "BootOptionReference": "Boot0000",
    "Description": "Windows Boot Manager",
    "DisplayName": "Windows Boot Manager",
    "Id": "0000",
    "Name": "Boot0000",
    "RelatedItem@odata.count": 0,
    "UefiDevicePath": "HD(1,GPT,EC9ABBB5-A4D8-4825-9CC5-50B8AC6481A5,0x800,0x64000)/\\EFI\\Microsoft\\Boot\\bootmgfw.efi"
}
#>
        # Loop all System resource instance in $system_url_collection
        foreach($system_url_string in $system_url_collection)
        {
            # Hash table of boot mode information 
            $boot_mode_dict = @{}

            # Get system resource
            $url_address_system = "https://$ip"+$system_url_string
            $response = Invoke-WebRequest -Uri $url_address_system -Headers $JsonHeader -Method Get -UseBasicParsing
            $converted_object = $response.Content | ConvertFrom-JsonWithDuplicates #ConvertFrom-Json : fixed ASUS Bug: Unable to convert the JSON string because the dictionary created from this string contains duplicate keys 'AMI' and 'Ami'.
            # Output result
            $converted_object.boot.BootSourceOverrideMode
            #TODO:
            #BootOptions                  {[@odata.id, /redfish/v1/Systems/Self/BootOptions]}  
            #Certificates                 {[@odata.id, /redfish/v1/Systems/Self/Boot/Certificates]}
        }
        
    }
    catch
    {
        # Handle http exception response
        if($_.Exception.Response)
        {
            Write-Host "Error occured, error code:" $_.Exception.Response.StatusCode.Value__
            if ($_.Exception.Response.StatusCode.Value__ -eq 401)
            {
                Write-Host "Error message: You are required to log on Web Server with valid credentials first."
            }
            elseif ($_.ErrorDetails.Message)
            {
                $response_j = $_.ErrorDetails.Message | ConvertFrom-Json | Select-Object -Expand error
                $response_j = $response_j | Select-Object -Expand '@Message.ExtendedInfo'
                Write-Host "Error message:" $response_j.Resolution
            }
            else
            {
                Write-Host "Error message:" $_.Exception.Message
                Write-Host "Please check arguments or server status."        
            }
        }
        # Handle system exception response
        elseif($_.Exception)
        {
            Write-Host "Error message:" $_.Exception.Message
            Write-Host "Please check arguments or server status."
        }
        return $False
    }
    # Delete existing session whether script exit successfully or not
    finally
    {
        if ($session_key -ne "")
        {
            delete_session -ip $ip -session $session
        }
    }
    
}
