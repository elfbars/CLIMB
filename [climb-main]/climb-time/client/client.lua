Citizen.CreateThread(function()
if Config.Framework == 'climb' or Config.Framework == 'aceperms' or Config.Framework == 'identifiers' then
        Citizen.CreateThread(function()
            Wait(3000)
            while true do
                Wait(1000)
                if NetworkIsSessionStarted() then
                    TriggerServerEvent('climb-time:SyncMe', {time = true, weather = true})
                    break
                end
            end
        end)

    elseif Config.Framework == 'other' then
        --Add your framework code here.

    end
end)


--███╗   ███╗ █████╗ ██╗███╗   ██╗
--████╗ ████║██╔══██╗██║████╗  ██║
--██╔████╔██║███████║██║██╔██╗ ██║
--██║╚██╔╝██║██╔══██║██║██║╚██╗██║
--██║ ╚═╝ ██║██║  ██║██║██║ ╚████║
--╚═╝     ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝


local self = {}
self.seconds = 0
self.tsunami = false
local NUI_status = false
local PauseSync = {}
PauseSync.state = false
local SyncHours = nil
local SyncMins = nil

RegisterNetEvent('climb-time:PauseSync')
AddEventHandler('climb-time:PauseSync', function(boolean, time)
    if boolean then
        PauseSync.state = true
        PauseSync.time = time or 20
        ChangeWeather('EXTRASUNNY', true)
        ChangeBlackout(self.blackout)
    else
        PauseSync.state = false
        TriggerServerEvent('climb-time:SyncMe')
    end
end)

RegisterNetEvent('climb-time:ForceUpdate')
AddEventHandler('climb-time:ForceUpdate', function(data)
    if not PauseSync.state then
        self.freeze = data.freeze
        if data.weather ~= nil then
            CheckSnowSync(data.weather)
            self.weather = data.weather
            self.blackout = data.blackout
            ChangeWeather(self.weather, data.instantweather)
            ChangeBlackout(self.blackout)
        end
        if data.hours ~= nil then
            local newhours = GetClockHours()
            NetworkOverrideClockTime(newhours, data.mins, self.seconds)
            if not data.instanttime then
                for cd_1 = 1, 24 do
                    newhours = newhours+1
                    if newhours == 24 then newhours = 0 end
                    if newhours < 24 then
                        self.hours = newhours
                        self.mins = data.mins
                        for cd_2 = 1, 60 do
                            Wait(10)
                            NetworkOverrideClockTime(newhours, cd_2, self.seconds)
                        end
                    end
                    if newhours == data.hours then break end
                end
            elseif data.instanttime or self.freeze then
                self.hours = data.hours
                self.mins = data.mins
                NetworkOverrideClockTime(self.hours, self.mins, self.seconds)
            end
        end
        if data.blackout ~= nil then
            self.blackout = data.blackout
            ChangeBlackout(self.blackout)
        end
    end
    if data.tsunami ~= nil and Config.TsunamiWarning and self.tsunami ~= data.tsunami then
        self.tsunami = data.tsunami
        TriggerEvent('climb-time:StartTsunamiCountdown', data.tsunami)
    end
end)

RegisterNetEvent('climb-time:SyncWeather')
AddEventHandler('climb-time:SyncWeather', function(data)
    if not PauseSync.state then
        CheckSnowSync(data.weather)
        self.weather = data.weather
        ChangeWeather(self.weather, data.instantweather)
    end
end)

RegisterNetEvent('climb-time:SyncTime')
AddEventHandler('climb-time:SyncTime', function(data)
    if not PauseSync.state then
        SyncHours = data.hours
        SyncMins = data.mins
    end
end)

Citizen.CreateThread(function()
    NetworkOverrideClockMillisecondsPerGameMinute(Config.TimeCycleSpeed*1000)
    while true do
        if self.hours ~= nil and self.mins ~= nil then
            if not PauseSync.state then
                if not self.freeze then
                    NetworkOverrideClockTime(self.hours, self.mins, self.seconds)
                    self.seconds = self.seconds+30
                    if SyncHours ~= nil and SyncMins ~= nil then
                        self.hours = SyncHours
                        self.mins = SyncMins
                        SyncHours = nil
                        SyncMins = nil
                    end
                    if self.seconds >= 60 then self.seconds = 0 self.mins = self.mins+1 end
                    if self.mins >= 60 then self.mins = 0 self.hours = self.hours+1 end
                    if self.hours >= 24 then self.hours = 0 end
                else
                    NetworkOverrideClockTime(self.hours, self.mins, self.seconds)
                end
            else
                NetworkOverrideClockTime(PauseSync.time, 00, 00)
            end
        end
        Wait(Config.TimeCycleSpeed*1000/2)
    end
end)

RegisterNUICallback('close', function()
    NUI_status = false
end)

RegisterNUICallback('instanttime', function(data)
    TriggerServerEvent('climb-time:ToggleInstantChange:Time', data.instanttime)
end)

RegisterNUICallback('instantweather', function(data)
    TriggerServerEvent('climb-time:ToggleInstantChange:Weather', data.instantweather)
end)

RegisterNUICallback('change', function(data)
    NUI_status = false
    TriggerServerEvent('climb-time:ForceUpdate', data.values)
    if data.savesettings then
        print('Saving Settings - please wait 2 seconds ...')
        Wait(2000)
        TriggerServerEvent('climb-time:SaveSettings')
        print('Settings Saved.')
    end
end)

function CheckSnowSync(NewWeather)
    if self.weather == 'XMAS' then
        SetForceVehicleTrails(false)
        SetForcePedFootstepsTracks(false)
    elseif NewWeather == 'XMAS' then
        SetForceVehicleTrails(true)
        SetForcePedFootstepsTracks(true)
    end
end

function ChangeWeather(weather, instant, changespeed)
    if instant then
        ClearOverrideWeather()
        ClearWeatherTypePersist()
        SetWeatherTypePersist(weather)
        SetWeatherTypeNow(weather)
        SetWeatherTypeNowPersist(weather)
    else
        ClearOverrideWeather()
        SetWeatherTypeOvertimePersist(weather, changespeed or 180.0)
    end
end

function ChangeBlackout(blackout)
    if GetGameBuildNumber() >= 2372 then
        SetArtificialLightsState(blackout)
        SetArtificialLightsStateAffectsVehicles(Config.VehicleBlackoutEffect)
    else
        SetBlackout(blackout)
    end
end

RegisterNetEvent('climb-time:OpenUI')
AddEventHandler('climb-time:OpenUI', function(values)
    TriggerEvent('climb-time:ToggleNUIFocus')
    SendNUIMessage({action = 'open', values = values})
end)

RegisterNetEvent('climb-time:ToggleNUIFocus')
AddEventHandler('climb-time:ToggleNUIFocus', function()
    NUI_status = true
    while NUI_status do
        Wait(0)
        SetNuiFocus(NUI_status, NUI_status)
        SetNuiFocusKeepInput(NUI_status)
        DisableControlAction(0, 1,   true)
        DisableControlAction(0, 2,   true)
        DisableControlAction(0, 106, true)
        DisableControlAction(0, 142, true)
        DisableControlAction(0, 21,  true)
        DisableControlAction(0, 24,  true)
        DisableControlAction(0, 25,  true)
        DisableControlAction(0, 47,  true)
        DisableControlAction(0, 58,  true)
        DisableControlAction(0, 263, true)
        DisableControlAction(0, 264, true)
        DisableControlAction(0, 257, true)
        DisableControlAction(0, 140, true)
        DisableControlAction(0, 141, true)
        DisableControlAction(0, 143, true)
        DisableControlAction(0, 75,  true)
        DisableControlAction(27, 75, true)
        SetPlayerCanDoDriveBy(PlayerId(), false)
    end
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SetPlayerCanDoDriveBy(PlayerId(), true)
    local count, keys = 0, {177, 200, 202, 322}
    while count < 100 do 
        Wait(0)
        count=count+1
        for c, d in pairs(keys) do
            DisableControlAction(0, d, true)
        end
    end
end)

local TsunamiCanceled = false
RegisterNetEvent('climb-time:StartTsunamiCountdown')
AddEventHandler('climb-time:StartTsunamiCountdown', function(boolean)
    if not Config.TsunamiWarning then return end
    if boolean then
        PauseSync.state = true
        PauseSync.time = self.hours
        TsunamiCanceled = false
        ChangeWeather('HALLOWEEN', false, Config.TsunamiWarning_time*60*1000/4/1000+0.0)
        Wait(Config.TsunamiWarning_time*60*1000/4*2)
        if TsunamiCanceled then return end
        ChangeBlackout(true)
        SendNUIMessage({action = 'playsound'})
    else
        PauseSync.state = false
        TsunamiCanceled = true
        TriggerServerEvent('climb-time:SyncMe')
    end
end)

function GetWeather()
    return self
end