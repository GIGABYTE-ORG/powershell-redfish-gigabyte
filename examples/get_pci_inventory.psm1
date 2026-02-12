###
#
# Lenovo Redfish examples - Get the network information
#
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
###
Import-module $PSScriptRoot\lenovo_utils.psm1

function get_pci_inventory
{
    <#
   .Synopsis
    Cmdlet used to get pci inventory
   .DESCRIPTION
    Cmdlet used to get pci inventory from BMC using Redfish API. Connection information can be specified via command parameter or configuration file.
    - ip: Pass in BMC IP address
    - username: Pass in BMC username
    - password: Pass in BMC username password
    - system_id:Pass in ComputerSystem instance id(None: first instance, all: all instances)
    - config_file: Pass in configuration file path, default configuration file is config.ini
   .EXAMPLE
    get_pci_inventory -ip 10.10.10.10 -username USERID -password PASSW0RD
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

        # Build headers with sesison key for authentication
        $JsonHeader = @{ 
            "X-Auth-Token" = $session_key
            "Accept" = "application/json"
        }
        
        # Get the chassis url
        $base_url = "https://$ip/redfish/v1/"
        $response = Invoke-WebRequest -Uri $base_url -Headers $JsonHeader -Method Get -UseBasicParsing
        $converted_object = $response.Content | ConvertFrom-Json
        $chassis_url = $converted_object.Chassis."@odata.id"

        #Get chassis list 
        $chassis_url_collection = @()
        $chassis_url_string = "https://$ip"+ $chassis_url
        $response = Invoke-WebRequest -Uri $chassis_url_string -Headers $JsonHeader -Method Get -UseBasicParsing
        $converted_object = $response.Content | ConvertFrom-Json

        foreach($i in $converted_object.Members)
        {
               $tmp_chassis_url_string = "https://$ip" + $i."@odata.id"
               $chassis_url_collection += $tmp_chassis_url_string
        }
        $pci_details = @()
        # Loop all System resource instance in $chassis_url_collection
       foreach($chassis_url_string in $chassis_url_collection)
        {
            # Get system resource
            $response = Invoke-WebRequest -Uri $chassis_url_string -Headers $JsonHeader -Method Get -UseBasicParsing
            $converted_object = $response.Content | ConvertFrom-Json
            $hash_table = @{}
            $converted_object.psobject.properties | Foreach { $hash_table[$_.Name] = $_.Value }
            if ($hash_table.Keys -notcontains "PCIeDevices") {
                break
            }

            $pci_devices_url = $converted_object.PCIeDevices."@odata.id"
                
            do {
                # Get PCIeDevices resource 
                $pci_devices_url = "https://$ip" + $pci_devices_url
                #$pci_devices_url #https://10.1.9.129/redfish/v1/Chassis/Self/PCIeDevices
                $response = Invoke-WebRequest -Uri $pci_devices_url -Headers $JsonHeader -Method Get -UseBasicParsing
                $converted_pci_object = $response.Content | ConvertFrom-Json
                #$converted_pci_object
                $hash_table2 = @{}
                $converted_pci_object.psobject.properties | Foreach { $hash_table2[$_.Name] = $_.Value }
                $hash_table2
                
<#
{
    "@odata.context": "/redfish/v1/$metadata#PCIeDeviceCollection.PCIeDeviceCollection",
    "@odata.etag": "\"1770678847\"",
    "@odata.id": "/redfish/v1/Chassis/Self/PCIeDevices",
    "@odata.type": "#PCIeDeviceCollection.PCIeDeviceCollection",
    "Description": "The Collection of PCIeDevices",
    "Members": [
        {
            "@odata.id": "/redfish/v1/Chassis/Self/PCIeDevices/00_D4_00"
        },
        {
            "@odata.id": "/redfish/v1/Chassis/Self/PCIeDevices/00_D5_00"
        },
        {
            "@odata.id": "/redfish/v1/Chassis/Self/PCIeDevices/00_D6_00"
        },
        {
            "@odata.id": "/redfish/v1/Chassis/Self/PCIeDevices/00_E0_00"
        },
        {
            "@odata.id": "/redfish/v1/Chassis/Self/PCIeDevices/00_E0_01"
        },
        {
            "@odata.id": "/redfish/v1/Chassis/Self/PCIeDevices/00_E0_02"
        },
        {
            "@odata.id": "/redfish/v1/Chassis/Self/PCIeDevices/00_F0_00"
        },
        {
            "@odata.id": "/redfish/v1/Chassis/Self/PCIeDevices/00_F0_01"
        },
        {
            "@odata.id": "/redfish/v1/Chassis/Self/PCIeDevices/00_F0_02"
        },
        {
            "@odata.id": "/redfish/v1/Chassis/Self/PCIeDevices/00_F0_03"
        },
        {
            "@odata.id": "/redfish/v1/Chassis/Self/PCIeDevices/00_F0_04"
        },
        {
            "@odata.id": "/redfish/v1/Chassis/Self/PCIeDevices/00_F0_05"
        },
        {
            "@odata.id": "/redfish/v1/Chassis/Self/PCIeDevices/00_F0_07"
        },
        {
            "@odata.id": "/redfish/v1/Chassis/Self/PCIeDevices/00_F1_00"
        }
    ],
    "Members@odata.count": 64,
    "Members@odata.nextLink": "/redfish/v1/Chassis/Self/PCIeDevices?$skip=50",
    "Name": "PCIeDevice Collection"
}
#>

                # Get pci count
                $pci_x_count =$converted_pci_object."Members@odata.count"
                # Loop all pci resource instance in EthernetInterfaces resource
                #for($i = 0;$i -lt $pci_x_count;$i ++)
                foreach($pcidevice_object in $converted_pci_object.Members)
                {
                    $ht_pcifunction = @{}
                    # Get pci resource
                    $pci_device_x_url ="https://$ip" +  $pcidevice_object."@odata.id"
                    #$pci_device_x_url #/redfish/v1/Chassis/Self/PCIeDevices/00_01_00
 <#
{
    "@odata.context": "/redfish/v1/$metadata#PCIeDevice.PCIeDevice",
    "@odata.etag": "W/\"1739219977\"",
    "@odata.id": "/redfish/v1/Chassis/Self/PCIeDevices/00_01_00",
    "@odata.type": "#PCIeDevice.v1_9_0.PCIeDevice",
    "Description": "Network Device",
    "Id": "00_01_00",
    "Links": {
        "PCIeFunctions": [
            {
                "@odata.id": "/redfish/v1/Chassis/Self/PCIeDevices/00_01_00/PCIeFunctions/00_01_00_00"
            }
        ],
        "PCIeFunctions@odata.count": 1
    },
    "Manufacturer": "Intel Corporation",
    "Model": "Wireless 7260",
    "Name": "Wireless 7260",
    "PCIeInterface": {
        "LanesInUse": 1,
        "MaxLanes": 1,
        "MaxPCIeType": "Gen1",
        "PCIeType": "Gen1"
    },
    "Slot": {
        "Lanes": 16,
        "PCIeType": "Gen5"
    },
    "Status": {
        "Health": "OK",
        "State": "Enabled"
    }
}
#>
                    $response_pci_x_device = Invoke-WebRequest -Uri $pci_device_x_url -Headers $JsonHeader -Method Get -UseBasicParsing 
                    $converted_pci_x_object = $response_pci_x_device.Content | ConvertFrom-Json
<#
{
    "@odata.context": "/redfish/v1/$metadata#PCIeDevice.PCIeDevice",
    "@odata.etag": "\"1770669948\"",
    "@odata.id": "/redfish/v1/Chassis/Self/PCIeDevices/00_D4_00",
    "@odata.type": "#PCIeDevice.v1_4_0.PCIeDevice",
    "DeviceType": "SingleFunction",
    "Id": "00_D4_00",
    "Name": "00_D4_00",
    "PCIeFunctions": {
        "@odata.id": "/redfish/v1/Chassis/Self/PCIeDevices/00_D4_00/PCIeFunctions"
    },
    "Status": {
        "Health": "OK",
        "State": "Enabled"
    }
}
#>

                    $hash_table = @{}
                    $converted_pci_x_object.psobject.properties | Foreach { $hash_table[$_.Name] = $_.Value } 
                    foreach ($key in $hash_table.Keys) 
                    {
                
                        if('Description','@odata.context','@odata.id','@odata.type','@odata.etag', 'Links','PCIeFunctions' -notcontains $key)
                        {
                
                            $ht_pcifunction[$key] = $hash_table.$key
                        }
                    }
                    $ht_pcifunction['PCIeDevice']=$hash_table.Id
                    


                    $pci_function_url ="https://$ip" +  $converted_pci_x_object.PCIeFunctions."@odata.id"
                    #$pci_function_url #/redfish/v1/Chassis/Self/PCIeDevices/00_01_00/PCIeFunctions
                    $response_pcifun_x_device = Invoke-WebRequest -Uri $pci_function_url -Headers $JsonHeader -Method Get -UseBasicParsing 
                    $converted_pcifun_x_object = $response_pcifun_x_device.Content | ConvertFrom-Json
<#
{
    "@odata.context": "/redfish/v1/$metadata#PCIeFunctionCollection.PCIeFunctionCollection",
    "@odata.etag": "\"1770679715\"",
    "@odata.id": "/redfish/v1/Chassis/Self/PCIeDevices/00_D4_00/PCIeFunctions",
    "@odata.type": "#PCIeFunctionCollection.PCIeFunctionCollection",
    "Description": "The Collection of PCIeFunctions",
    "Members": [
        {
            "@odata.id": "/redfish/v1/Chassis/Self/PCIeDevices/00_D4_00/PCIeFunctions/DevType3__DevIndex4A"
        }
    ],
    "Members@odata.count": 1,
    "Name": "PCIeFunction Collection"
}
#>

                    foreach($pcifun_x_object in $converted_pcifun_x_object.Members)
                    {
                        $pcifun_x_url_string = "https://$ip" + $pcifun_x_object."@odata.id"
                        $pcifun_x_url_string = $pcifun_x_url_string -replace ' ', '%20' #patch asus bugs
                        #$pcifun_x_url_string
                        # Get system resource
                        try{

                        $response = Invoke-WebRequest -Uri $pcifun_x_url_string -Headers $JsonHeader -Method Get -UseBasicParsing
                        }
                        catch
                        {
                           continue
                        }
                        $pcifun_converted_object = $response.Content | ConvertFrom-Json
<#
{
    "@odata.context": "/redfish/v1/$metadata#PCIeFunction.PCIeFunction",
    "@odata.etag": "\"1770669948\"",
    "@odata.id": "/redfish/v1/Chassis/Self/PCIeDevices/00_D4_00/PCIeFunctions/DevType3__DevIndex4A",
    "@odata.type": "#PCIeFunction.v1_2_3.PCIeFunction",
    "ClassCode": "0x060400",
    "DeviceClass": "Bridge",
    "DeviceId": "0x1150",
    "FunctionId": 0,
    "FunctionType": "Physical",
    "Id": "DevType3__DevIndex4A",
    "Links": {
        "PCIeDevice": {
            "@odata.id": "/redfish/v1/Chassis/Self/PCIeDevices/00_D4_00"
        }
    },
    "Name": "DevType3__DevIndex4A",
    "RevisionId": "0x06",
    "Status": {
        "Health": "OK",
        "State": "Enabled"
    },
    "SubsystemId": "0x0000",
    "SubsystemVendorId": "0x0000",
    "VendorId": "0x1A03"
} 
#>
                        $hash_table = @{}
                        $pcifun_converted_object.psobject.properties | Foreach { $hash_table[$_.Name] = $_.Value }
                   
                        #$properties = @('Name', 'Description', 'Status')
                        foreach ($key in $hash_table.Keys) 
                        {
                
                            if('Description','@odata.context','@odata.id','@odata.type','@odata.etag', 'Links' -notcontains $key)
                            {
                
                                $ht_pcifunction[$key] = $hash_table.$key
                            }
                        }
                        #$ht_pcifunction
                        ConvertOutputHashTableToObject $ht_pcifunction
                    }
                }
                $pci_devices_url=$hash_table2.'Members@odata.nextLink' 
            }while($pci_devices_url)

        }  
        #$pci_details | ConvertTo-Json -Depth 10
        #Write-Host " "
    }
    catch
    {
        # Handle exception response
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
                $sr = new-object System.IO.StreamReader $_.Exception.Response.GetResponseStream()
                $resobject = $sr.ReadToEnd() | ConvertFrom-Json
                $resobject.error.('@Message.ExtendedInfo')    
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
