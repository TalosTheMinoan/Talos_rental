-- client.lua

ESX = nil

Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(0)
    end
end)

-- Coordinates for the bike rental locations
local rentalLocations = {
    vector4(-239.2149, -989.0035, 29.28831, 254.0296),
    vector4(239.6978, -862.4493, 29.74767, 163.2569)
}

-- Coordinates for the bike return stations
local returnStations = {
    vector4(-237.935, -985.5645, 29.28832, 245.8022),
    vector4(236.4369, -862.2419, 29.82195, 138.4417)
}

-- Blip settings
local blipSettings = {
    rentalSprite = 226, -- Rental location icon
    returnSprite = 357, -- Return station icon
    rentalColor = 3,    -- Rental location color
    returnColor = 2,    -- Return station color
    scale = 0.8,        -- Blip size
    text = "Bike Rental"
}

-- Bike options with prices
local bikeOptions = {
    { model = 'bmx', price = 100 },
    { model = 'scorcher', price = 150 }, -- Mountain bike
    { model = 'faggio', price = 200 }    -- Scooter
}

-- Countdown time in seconds
local rentalTime = 600

-- Track if a bike is currently rented
local bikeRented = false
local rentedBike = nil
local bikeBlip = nil

Citizen.CreateThread(function()
    -- Create blips on the map
    for _, location in pairs(rentalLocations) do
        local blip = AddBlipForCoord(location.x, location.y, location.z)
        SetBlipSprite(blip, blipSettings.rentalSprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, blipSettings.scale)
        SetBlipColour(blip, blipSettings.rentalColor)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Bike Rental Location")
        EndTextCommandSetBlipName(blip)
    end

    -- Create blips for the return stations
    for _, station in pairs(returnStations) do
        local returnBlip = AddBlipForCoord(station.x, station.y, station.z)
        SetBlipSprite(returnBlip, blipSettings.returnSprite)
        SetBlipDisplay(returnBlip, 4)
        SetBlipScale(returnBlip, blipSettings.scale)
        SetBlipColour(returnBlip, blipSettings.returnColor)
        SetBlipAsShortRange(returnBlip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Bike Return Station")
        EndTextCommandSetBlipName(returnBlip)
    end

    -- Main loop to check for player interaction
    while true do
        Citizen.Wait(0)
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)

        for _, location in pairs(rentalLocations) do
            -- Draw a marker
            DrawMarker(1, location.x, location.y, location.z - 1.0, 0, 0, 0, 0, 0, 0, 1.5, 1.5, 0.5, 0, 255, 0, 100, false, true, 2, nil, nil, false)

            -- Check if player is near the rental location
            if GetDistanceBetweenCoords(playerCoords, location.x, location.y, location.z, true) < 50.0 then
                -- Display help text
                if not bikeRented then
                    DisplayHelpText("Press ~INPUT_CONTEXT~ to rent a bike")
                    if IsControlJustReleased(1, 51) then -- 51 is the default key for 'E'
                        OpenBikeMenu()
                    end
                else
                    DisplayHelpText("You already have a rented bike.")
                end
            end
        end

        -- Check if player is near any return station
        for _, station in pairs(returnStations) do
            if bikeRented and GetDistanceBetweenCoords(playerCoords, station.x, station.y, station.z, true) < 50.0 then
                DisplayHelpText("Press ~INPUT_CONTEXT~ to return the bike")
                if IsControlJustReleased(1, 51) then
                    ReturnBike()
                end
            end
        end
    end
end)

function OpenBikeMenu()
    local elements = {}
    for i, bike in ipairs(bikeOptions) do
        table.insert(elements, { label = bike.model .. " - $" .. bike.price, value = i })
    end

    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'bike_rental', {
        title    = 'Bike Rental',
        align    = 'top-left',
        elements = elements
    }, function(data, menu)
        local bikeIndex = data.current.value
        TriggerServerEvent('bikeRental:rentBike', bikeIndex)
        menu.close()
    end, function(data, menu)
        menu.close()
    end)
end

function DisplayHelpText(text)
    SetTextComponentFormat("STRING")
    AddTextComponentString(text)
    DisplayHelpTextFromStringLabel(0, 0, 1, -1)
end

RegisterNetEvent('bikeRental:spawnBike')
AddEventHandler('bikeRental:spawnBike', function(bikeModel)
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)

    -- Spawn the selected bike
    local model = GetHashKey(bikeModel)

    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(1)
    end

    rentedBike = CreateVehicle(model, coords.x, coords.y, coords.z, GetEntityHeading(playerPed), true, false)
    TaskWarpPedIntoVehicle(playerPed, rentedBike, -1)

    -- Mark bike as rented
    bikeRented = true

    -- Create a blip for the rented bike
    bikeBlip = AddBlipForEntity(rentedBike)
    SetBlipSprite(bikeBlip, 226)
    SetBlipColour(bikeBlip, 3)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Rented Bike")
    EndTextCommandSetBlipName(bikeBlip)

    -- Start the countdown
    StartRentalCountdown()
end)

function StartRentalCountdown()
    local endTime = GetGameTimer() + rentalTime * 1000

    Citizen.CreateThread(function()
        while GetGameTimer() < endTime and bikeRented do
            Citizen.Wait(0)
            local remainingTime = math.floor((endTime - GetGameTimer()) / 1000)
            DrawTextOnScreen("Time left: " .. remainingTime .. " seconds", 0.5, 0.05)
        end

        -- Remove the bike when the time is up
        if DoesEntityExist(rentedBike) then
            DeleteVehicle(rentedBike)
            RemoveBlip(bikeBlip)
            TriggerEvent('bikeRental:notify', "warning", "Your bike rental time is up!")
        end

        -- Allow renting another bike
        bikeRented = false
        rentedBike = nil
        bikeBlip = nil
    end)
end

function ReturnBike()
    if DoesEntityExist(rentedBike) then
        DeleteVehicle(rentedBike)
        RemoveBlip(bikeBlip)
        TriggerEvent('bikeRental:notify', "success", "Bike returned successfully!")
    end

    -- Allow renting another bike
    bikeRented = false
    rentedBike = nil
    bikeBlip = nil
end

function DrawTextOnScreen(text, x, y)
    SetTextFont(0)
    SetTextProportional(1)
    SetTextScale(0.5, 0.5)
    SetTextColour(255, 255, 255, 255)
    SetTextDropShadow(0, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextDropShadow()
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText("STRING")
    AddTextComponentString(text)
    EndTextCommandDisplayText(x, y)
end

RegisterNetEvent('bikeRental:notify')
AddEventHandler('bikeRental:notify', function(type, message)
    SetNotificationTextEntry("STRING")
    AddTextComponentString(message)
    DrawNotification(false, true)
end)