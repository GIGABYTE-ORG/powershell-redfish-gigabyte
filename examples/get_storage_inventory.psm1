###
#
# Lenovo Redfish examples - Get storage inventory
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

function get_storage_inventory
{
    <#
   .Synopsis
    Cmdlet used to Get storage inventory
   .DESCRIPTION
    Cmdlet used to Get storage inventory from BMC using Redfish API. Information will be printed to the screen. Connection information can be specified via command parameter or configuration file.
    - ip: Pass in BMC IP address
    - username: Pass in BMC username
    - password: Pass in BMC username password
    - system_id: Pass in ComputerSystem instance id(None: first instance, all: all instances)
    - config_file: Pass in configuration file path, default configuration file is config.ini
   .EXAMPLE
    get_storage_inventory -ip 10.10.10.10 -username USERID -password PASSW0RD
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
            # Hash table of boot mode information 
            $reset_types = @{}

            # Get system resource
            $url_address_system = "https://$ip"+$system_url_string
            $response = Invoke-WebRequest -Uri $url_address_system -Headers $JsonHeader -Method Get -UseBasicParsing
            $converted_object = $response.Content | ConvertFrom-Json
            $hash_table = @{}
            $converted_object.psobject.properties | Foreach { $hash_table[$_.Name] = $_.Value }

            # Get the storage url from the computer system resource
            if($hash_table.keys -contains "Storage")
            {
                $uri_storage = "https://$ip" + $converted_object.Storage.'@odata.id'
            }
            else
            {
                $uri_storage = "https://$ip" + $converted_object.SimpleStorage.'@odata.id'
            }

            # Get the storage information form the storage resource
            $response = Invoke-WebRequest -Uri $uri_storage -Headers $JsonHeader -Method Get -UseBasicParsing
            $storage_converted_object = $response.Content | ConvertFrom-Json
 
            $storage_list = @()
            foreach($storage_url in $storage_converted_object.Members)
            {
                $storage_x_url = "https://$ip" + $storage_url.'@odata.id'
                #$storage_x_url
                $response = Invoke-WebRequest -Uri $storage_x_url -Headers $JsonHeader -Method Get -UseBasicParsing
                $storage_x_converted_object = $response.Content | ConvertFrom-Json
                $hash_table = @{}
                $storage_x_converted_object.psobject.properties | Foreach { $hash_table[$_.Name] = $_.Value }
            
                # Build a empty hashtable store storage information
                $storage_info = @{}
                $storage_info["Storage_id"] = $hash_table.Id
                $storage_info["Name"] = $hash_table.Name
                $storagecontroller_list = @()

                # Get the storage controllers instances resources from each of the storage resources
                if($hash_table.keys -contains "Drives")
                {
                    foreach($controller in $hash_table.StorageControllers)
                    {
                        $hash_table1 = @{}
                        $controller.psobject.properties | Foreach { $hash_table1[$_.Name] = $_.Value }
                        $storage_controller = @{}
                        foreach($key in $hash_table1.Keys)
                            {
                                if(('@odata.id', 'Links') -notcontains $key)
                                {
                                    $storage_controller[$key] = $controller.$key
                                } 
                            }
                        $storagecontroller_list += ConvertOutputHashTableToObject $storage_controller 
                    }
                    $storage_info["StorageControllers"] = $storagecontroller_list
                }


                # Get the disk inventory from each of the disk resources
                $drive_list = @()
                if($hash_table.keys -contains "Drives")
                {
                    foreach($disk in $hash_table.Drives)
                    {
                        $disk_inventory = @{}
                        $disk_url = "https://$ip" + $disk.'@odata.id'
                        $response = Invoke-WebRequest -Uri $disk_url -Headers $JsonHeader -Method Get -UseBasicParsing
                        $disk_x_converted_object = $response.Content | ConvertFrom-Json
                        $hash_table2 = @{}
                        $disk_x_converted_object.psobject.properties | Foreach { $hash_table2[$_.Name] = $_.Value }
                        foreach($key in $hash_table2.Keys)
                        {
                            if('Description','@odata.context','@odata.id','@odata.type','@odata.etag', 'Links' -notcontains $key)
                            {
                                $disk_inventory[$key] = $hash_table2.$key
                            }
                        }
                        $drive_list += ConvertOutputHashTableToObject $disk_inventory
                    }
                    $storage_info["Drives"] = $drive_list
                }


                # Get the volume inventory from each of the disk resources
                $volume_list = @()
                if($hash_table.keys -contains "Volumes")
                {
                    foreach($volume in $hash_table.Volumes)
                    {
                        #$volume
                        $volumes_url = "https://$ip" + $volume.'@odata.id'
                        $response = Invoke-WebRequest -Uri $volumes_url -Headers $JsonHeader -Method Get -UseBasicParsing
                        $volumes_converted_object = $response.Content | ConvertFrom-Json
                        $hash_table3 = @{}
                        $volumes_converted_object.psobject.properties | Foreach { $hash_table3[$_.Name] = $_.Value }
                        #$volumes_converted_object
                        foreach($volume_x_url in $volumes_converted_object.Members)
                        {
                            $volume_x_url = "https://$ip" + $volume_x_url.'@odata.id'
                            $response = Invoke-WebRequest -Uri $volume_x_url -Headers $JsonHeader -Method Get -UseBasicParsing
                            $volume_x_converted_object = $response.Content | ConvertFrom-Json
                            #$volume_x_converted_object
                            $hash_table4 = @{}
                            $volume_x_converted_object.psobject.properties | Foreach { $hash_table4[$_.Name] = $_.Value }
                            $volume_inventory = @{}
                            foreach($key in $hash_table4.Keys)
                            {
                                if('Description','@odata.context','@odata.id','@odata.type','@odata.etag', 'Links' -notcontains $key)
                                {
                                    $volume_inventory[$key] = $hash_table4.$key
                                }
                                
                                if($key -contains "Links"){
                                    $drivesIds = @()
                                    foreach($drive in $converted_object.Links.Drives){
                                        $drivename = $drive."@odata.id" -split '/'
                                        $drivesIds += $drivename[8]
                                    }  
                                    $volume_inventory["LinkedDriveIds"] = $drivesIds
                                }
                                
                            }
                           
                            $volume_list += ConvertOutputHashTableToObject $volume_inventory
                        }
                    }
                    $storage_info["Volumes"] = $volume_list
                }
                # Output result
                $storage_list += $storage_info 
                ConvertOutputHashTableToObject $storage_info

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
