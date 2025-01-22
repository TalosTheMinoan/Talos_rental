-- server.lua

ESX = nil

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

-- Bike options with prices
local bikeOptions = {
    { model = 'bmx', price = 100 },
    { model = 'scorcher', price = 150 }, -- Mountain bike
    { model = 'faggio', price = 200 }    -- Scooter
}

-- Store rental data
local playerRentals = {}

-- Current version
local currentVersion = "1.0"

-- Check for updates
function checkForUpdates()
    PerformHttpRequest("http://aboutkyriakos.wuaze.com/rentalscriptversion.txt", function(err, text, headers)
        if text and text ~= currentVersion then
            print("A new version of the rental script is available: " .. text)
        else
            print("You are using the latest version of the rental script.")
        end
    end)
end

-- Check for updates on server start
checkForUpdates()

RegisterCommand('rentalscriptscheckforupdates', function(source, args, rawCommand)
    checkForUpdates()
end, true)

RegisterServerEvent('bikeRental:rentBike')
AddEventHandler('bikeRental:rentBike', function(bikeIndex)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    local bike = bikeOptions[bikeIndex]

    -- Initialize player rental count if not present
    if not playerRentals[_source] then
        playerRentals[_source] = 0
    end

    -- Check if the player has enough money
    if xPlayer.getMoney() >= bike.price then
        xPlayer.removeMoney(bike.price)
        playerRentals[_source] = playerRentals[_source] + 1
        TriggerClientEvent('bikeRental:spawnBike', _source, bike.model)
        TriggerClientEvent('bikeRental:notify', _source, "success", "You rented a " .. bike.model .. " for $" .. bike.price)
    else
        TriggerClientEvent('bikeRental:notify', _source, "error", "Not enough money to rent a bike")
    end
end)

-- Function to get player rental count
ESX.RegisterServerCallback('bikeRental:getRentalCount', function(source, cb)
    cb(playerRentals[source] or 0)
end)