###
#
# Lenovo Redfish examples - Get the System information
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

function get_system_inventory
{
    <#
   .Synopsis
    Cmdlet used to get system inventory
   .DESCRIPTION
    Cmdlet used to get system inventory from BMC using Redfish API. system info will be printed to the screen. Connection information can be specified via command parameter or configuration file.
    - ip: Pass in BMC IP address
    - username: Pass in BMC username
    - password: Pass in BMC username password
    - system_id:Pass in ComputerSystem instance id(None: first instance, all: all instances)
    - config_file: Pass in configuration file path, default configuration file is config.ini.
   .EXAMPLE
    get_system_inventory -ip 10.10.10.10 -username USERID -password PASSW0RD
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
        
        # Get the system url collection
        $system_url_collection = @()
        $system_url_collection = get_system_urls -bmcip $ip -session $session -system_id $system_id

        # Loop all System resource instance in $system_url_collection
        foreach($system_url_string in $system_url_collection)
        {
            # Hash table for system info
            $system = @{}

            # Get system resource
            $url_address_system = "https://$ip" + $system_url_string
            $response = Invoke-WebRequest -Uri $url_address_system -Headers $JsonHeader -Method Get -UseBasicParsing
            $converted_object = $response.Content | ConvertFrom-JsonWithDuplicates #ConvertFrom-Json : fixed ASUS Bug: Unable to convert the JSON string because the dictionary created from this string contains duplicate keys 'AMI' and 'Ami'.
            $hash_table = @{}
            $converted_object.psobject.properties | Foreach { $hash_table[$_.Name] = $_.Value }
            $system_properties = @('Status', 'HostName', 'Model', 'Manufacturer', 'SystemType',
                      'PartNumber', 'SerialNumber', 'AssetTag', 'ServiceTag', 'UUID', 'SKU',
                      'BiosVersion', 'ProcessorSummary', 'MemorySummary', 'TrustedModules','Description','IndicatorLED','Name','PowerRestorePolicy', 'PowerState',,'PCIeDevices@odata.count','PCIeFunctions@odata.count')
            foreach ($system_property in $system_properties)
            {
                if($hash_table.Keys -contains $system_property)
                {
                    $system[$system_property] = $hash_table.$system_property
                }
            }
            
            if ($hash_table.Keys -contains 'Oem')
            {
                $hash_table_oem = @{}
                $hash_table.Oem.psobject.properties | Foreach { $hash_table_oem[$_.Name] = $_.Value }
                if ($hash_table_oem.Keys -contains 'Lenovo') 
                {
                    $hash_table_lenovo = @{}
                    $hash_table_oem.Lenovo.psobject.properties | Foreach { $hash_table_lenovo[$_.Name] = $_.Value }
                    $lenovo_oem_properties = @('FrontPanelUSB', 'SystemStatus', 'NumberOfReboots', 'TotalPowerOnHours')
                    $system['Oem'] = @{'Lenovo' = @{}}
                    foreach ($oem_property in $lenovo_oem_properties)
                    {
                        if($hash_table_lenovo.Keys -contains $oem_property)
                        {
                            $system['Oem']['Lenovo'][$oem_property] = $hash_table_lenovo.$oem_property
                        }
                    }
                }
                <#
                    "Oem": {
                        "Gbt": {
                            "@odata.type": "#GBTSystemsOemProperty.v1_0_0.GBTSystemsOemProperty"
                        },
                        "VirtualMedia": {
                            "@odata.type": "#GBTSystemVirtualMedia.v1_0_0.GBTSystemVirtualMedia",
                            "CDInstances": 4,
                            "RMediaStatus": "Disabled",
                            "RemovableStickInstances": 4
                        }
                    },
                #>
                if ($hash_table_oem.Keys -contains 'Gbt') 
                {
                    $hash_table_gbt = @{}
                    $hash_table_oem.Gbt.psobject.properties | Foreach { $hash_table_gbt[$_.Name] = $_.Value }
                    $gbt_oem_properties = @() #TODO
                    $system['Oem'] = @{'Gbt' = @{}}
                    foreach ($oem_property in $gbt_oem_properties)
                    {
                        if($hash_table_gbt.Keys -contains $oem_property)
                        {
                            $system['Oem']['Gbt'][$oem_property] = $hash_table_gbt.$oem_property
                        }
                    }
                }
            }


            # Get System EtherNetInterfaces resources
            $nics_url = "https://$ip" + $converted_object.EthernetInterfaces."@odata.id"
            $nics_response = Invoke-WebRequest -Uri $nics_url -Headers $JsonHeader -Method Get -UseBasicParsing
            $converted_nics = $nics_response.Content | ConvertFrom-Json
            $nics_count = $converted_nics."Members@odata.count"
            $system['EtherNetInterfaces'] = @()
            #$list_ethernetinterface = @()
            # Loop nic resource in EtherNetInterfaces resource
            for($num = 0;$num -lt $nics_count;$num ++)
            {
                $ht_ethernetinterface = @{}

                # Get nic_x info
                $nic_x_url = "https://$ip" + $converted_nics.Members[$num]."@odata.id"
                $nic_x_response = Invoke-WebRequest -Uri $nic_x_url -Headers $JsonHeader -Method Get -UseBasicParsing
                $convert_nic_x = $nic_x_response.Content | ConvertFrom-Json

                # Psobject
                $ht_ethernetinterface["Id"] = $convert_nic_x.Id
                $ht_ethernetinterface["Name"] = $convert_nic_x.Name
                $ht_ethernetinterface["UefiDevicePath"] = $convert_nic_x.UefiDevicePath
                $ht_ethernetinterface["PermanentMACAddress"] = $convert_nic_x.PermanentMACAddress
                $ht_ethernetinterface["EthernetInterfaceType"] = $convert_nic_x.EthernetInterfaceType
                #$object = [pscustomobject]$ht_ethernetinterface
                #$list_ethernetinterface += $object.PSObject.ToString()
                $system['EtherNetInterfaces'] += ConvertOutputHashTableToObject $ht_ethernetinterface                
            }
            # Get processors resource
            $processors_url = "https://$ip" + $converted_object.Processors."@odata.id"      
            $processors_response =   Invoke-WebRequest -Uri $processors_url -Headers $JsonHeader -Method Get -UseBasicParsing
            $processors_converted_object = $processors_response.Content | ConvertFrom-Json


            # Get cpu count
            $cpu_count = $processors_converted_object."Members@odata.count"
            $system['Processors']=@()
            # Loop all cpu resource instance in processor resource
            for($i = 0;$i -lt $cpu_count ;$i++)
            {
                # Get cpu resource
                $cpu_url = "https://$ip" + $processors_converted_object.Members[$i]."@odata.id"
                #$cpu_url
                $cpu_response =   Invoke-WebRequest -Uri $cpu_url -Headers $JsonHeader -Method Get -UseBasicParsing
                $cpu_converted_object = $cpu_response.Content | ConvertFrom-Json
                $ht_cpu_info = @{}

                $ht_tmp = @{}
                $cpu_converted_object.psobject. properties | Foreach{ $ht_tmp[$_.Name] = $_.Value }
                foreach($key in $ht_tmp.Keys)
                {
                    if($key -in 'Id', 'Name', 'TotalThreads', 'InstructionSet', 'Status', 'ProcessorType', 'ProcessorId', 'ProcessorMemory', 
                    'ProcessorArchitecture', 'TotalCores', 'TotalEnabledCores', 'Manufacturer', 'MaxSpeedMHz', 'Model', 'Socket', 'TDPWatts', 'OperatingSpeedMHz')
                    {
                        $ht_cpu_info[$key] = $ht_tmp[$key]
                    }
                }
                
                # Output result
                #ConvertOutputHashTableToObject $ht_cpu_info 
                 $system['Processors'] +=  ConvertOutputHashTableToObject $ht_cpu_info 
            }
            #Get memory resource
            $url_memory = "https://$ip" + $converted_object.Memory."@odata.id"
            $response = Invoke-WebRequest -Uri $url_memory -Headers $JsonHeader -Method Get -UseBasicParsing
            $converted_object = $response.Content | ConvertFrom-Json
            
            #Get memory info
            $system['Memory']=@()
            $list_memory = $converted_object.Members
            foreach($memory_info in $list_memory)
            {
                $ht_memory_info = @{}
                $url_sub_memory = "https://$ip" + $memory_info."@odata.id"
                $response = Invoke-WebRequest -Uri $url_sub_memory -Headers $JsonHeader -Method Get -UseBasicParsing
                $converted_object = $response.Content | ConvertFrom-Json
                
                $hash_table = @{}
                $converted_object.psobject.properties | Foreach { $hash_table[$_.Name] = $_.Value }
                foreach($key in $hash_table.Keys)
                {
                    if($key -eq "Links" -or  $key -eq "Oem" -or $key -like "@*")
                    {
                        continue
                    }
                    $ht_memory_info[$key] = $hash_table[$key]
                }
                
                # Output result
                $system['Memory'] +=ConvertOutputHashTableToObject $ht_memory_info
            }
            
            # Output result
            #$system['EtherNetInterfaces'] = $list_ethernetinterface
            #$system  | ConvertTo-Json -Depth 10
            ConvertOutputHashTableToObject $system
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
