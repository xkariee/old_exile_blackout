local injuredTime = 0

local isBlackedOut = false
local isInjured = false
local dzwonCalled = false

local beltOn = false
local beltStatus = true
local beltCalled = false
local pokazPasy = true

AddEventHandler('exile_blackout:pasy', function(status)
	beltOn = status
end)

AddEventHandler('exile_dzwon:display', function(status)
	beltStatus = status
end)

RegisterNetEvent("exile:pasy")
AddEventHandler("exile:pasy", function(a)
	pokazPasy = a
end)

function pasyState()
	return beltOn
end

local playerPed = PlayerPedId()
local vehicle = GetVehiclePedIsIn(playerPed, false)
local inVehicle = IsPedInAnyVehicle(playerPed, false)

CreateThread(function ()
	while true do
		Wait(500)
		playerPed = PlayerPedId()
		vehicle = GetVehiclePedIsIn(playerPed, false)
		inVehicle = IsPedInAnyVehicle(playerPed, false)
	end
end)


RegisterNetEvent('exile_blackout:dzwon')
AddEventHandler('exile_blackout:dzwon', function(damage)
	isBlackedOut = true
	dzwonCalled = false
	CreateThread(function()
		SendNUIMessage({
			transaction = 'play'
		})

		StartScreenEffect('DeathFailOut', 0, true)

		SetCurrentPedWeapon(playerPed, GetHashKey('WEAPON_UNARMED'), true)
		ShakeGameplayCam("SMALL_EXPLOSION_SHAKE", 1.0)
		Wait(1000)

		ShakeGameplayCam("SMALL_EXPLOSION_SHAKE", 1.0)
		Wait(1000)

		ShakeGameplayCam("SMALL_EXPLOSION_SHAKE", 1.0)
		Wait(1000)
		StopScreenEffect('DeathFailOut')

		isInjured = false
		injuredTime = math.min(20, damage)
		isBlackedOut = false
	end)
end)

RegisterNetEvent("exile_blackoutC:dzwonCb")
AddEventHandler("exile_blackoutC:dzwonCb", function(dmg) 
	TriggerServerEvent("exile_blackout:dzwonCb", true, dmg)
end)

RegisterNetEvent('exile_blackout:impact')
AddEventHandler('exile_blackout:impact', function(speedBuffer, velocityBuffer)
	CreateThread(function()
		if inVehicle then
			local pass = GetEntityHealth(playerPed)
			
			if pass and not beltOn then
				local hr = GetEntityHeading(vehicle) + 90.0
				if hr < 0.0 then
					hr = 360.0 + hr
				end

				hr = hr * 0.0174533
				local forward = { x = math.cos(hr) * 2.0, y = math.sin(hr) * 2.0 }
				local coords = GetEntityCoords(playerPed)

				SetEntityCoords(playerPed, coords.x + forward.x, coords.y + forward.y, coords.z - 0.47, true, true, true)
				SetEntityVelocity(playerPed, velocityBuffer[2].x, velocityBuffer[2].y, velocityBuffer[2].z)
				Wait(1)

				SetPedToRagdoll(playerPed, 1000, 1000, 0, 0, 0, 0)
				if not beltOn then
					local speed = math.floor(speedBuffer[2] * 3.6 + 0.5)
					if speed > 120 then
						Wait(500)
						Citizen.InvokeNative(0x6B76DC1F3AE6E6A3, playerPed, math.floor(math.max(99, (pass - (speed - 100))) + 0.5))
					end
				else
					Wait(500)
				end
			end
		end
		beltCalled = false
	end)
end)

AddEventHandler('exile_blackout:belt', function(status)
	if inVehicle then
		beltOn = status

		local tmp = {}
		for _, player in ipairs(GetActivePlayers()) do
			tmp[Citizen.InvokeNative(0x43A66C31C68491C0, player)] = GetPlayerServerId(player)
		end
		for i = -1, GetVehicleNumberOfPassengers(vehicle) do
			local ped = GetPedInVehicleSeat(vehicle, i)
			if ped and ped ~= 0 then
				TriggerServerEvent('InteractSound_SV:PlayOnOne', tmp[ped], (beltOn and 'belton' or 'beltoff'), 0.35)
			end
		end
	end
end)

RegisterKeyMapping('-pasy', 'Zapnij/odepnij pasy', 'keyboard', 'B')
RegisterCommand('-pasy', function(source, args, rawCommand)
	if inVehicle then
		if vehicle ~= 0 and IsCar(vehicle, true) then
			TriggerEvent('exile_blackout:belt', not beltOn)
		end
	end
end, false)

CreateThread(function()
	RequestStreamedTextureDict('mpinventory')
	while not HasStreamedTextureDictLoaded('mpinventory') do
			Wait(0)
	end

	local speedBuffer = {}
	local velocityBuffer = {}

	local timer = GetGameTimer()
	while true do
		Wait(0)
		local sleep = true
		if inVehicle then
			if vehicle ~= 0 and IsCar(vehicle, true) then
				if GetPedInVehicleSeat(vehicle, -1) == playerPed then
					sleep = false
					speedBuffer[2] = speedBuffer[1]
					speedBuffer[1] = GetEntitySpeed(vehicle)
					if speedBuffer[2] ~= nil and not beltCalled and speedBuffer[2] > 40.77 and (speedBuffer[2] - speedBuffer[1]) > (speedBuffer[1] * 0.25) and not GetPlayerInvincible(PlayerId()) and GetEntitySpeedVector(vehicle, true).y > 1.0 then
						local tmp = {}
						for _, player in ipairs(GetActivePlayers()) do
							tmp[Citizen.InvokeNative(0x43A66C31C68491C0, player)] = GetPlayerServerId(player)
						end

						local list = {}
						for i = 0, GetVehicleNumberOfPassengers(vehicle) do
							local ped = GetPedInVehicleSeat(vehicle, i)
							if ped and ped ~= 0 then
								table.insert(list, tmp[ped])
							end
						end

						local str = "Wypadek lub kolizja"
						local coords = GetEntityCoords(playerPed, false)

						local s1, s2 = Citizen.InvokeNative(0x2EB41072B4C1E4C0, coords.x, coords.y, coords.z, Citizen.PointerValueInt(), Citizen.PointerValueInt())
						if s1 ~= 0 and s2 ~= 0 then
							str = str .. " przy " .. GetStreetNameFromHashKey(s1) .. " na skrzyżowaniu z " .. GetStreetNameFromHashKey(s2)
						elseif s1 ~= 0 then
							str = str .. " przy " .. GetStreetNameFromHashKey(s1)
						end

						TriggerServerEvent('notifyAccident', {x = coords.x, y = coords.y, z = coords.y}, str)
						
						dzwonCalled = true
						beltCalled = true

						TriggerServerEvent('exile_blackout:impact', list, speedBuffer, velocityBuffer)

					end

					velocityBuffer[2] = velocityBuffer[1]
					velocityBuffer[1] = GetEntityVelocity(vehicle)
				else
					speedBuffer[1], speedBuffer[2], velocityBuffer[1], velocityBuffer[2] = 0.0, nil, 0.0, nil
				end
			else
				Wait(250)
				speedBuffer[1], speedBuffer[2], velocityBuffer[1], velocityBuffer[2] = 0.0, nil, 0.0, nil
			end
		else
			Wait(250)
			beltOn = false
			speedBuffer[1], speedBuffer[2], velocityBuffer[1], velocityBuffer[2] = 0.0, nil, 0.0, nil
		end
		if sleep then
			Wait(500)
		end
	end
end)

function IsCar(v, ignoreBikes)
	if ignoreBikes and IsThisModelABike(GetEntityModel(v)) then
		return false
	end

	local vc = GetVehicleClass(v)
	return (vc >= 0 and vc <= 12) or vc == 15 or vc == 17 or vc == 18 or vc == 20
end

function IsAffected()
	return isBlackedOut or isInjured
end

-- [[ KLASY POJAZDÓW ]] --
--[[  
0: Compacts  
1: Sedans  
2: SUVs  
3: Coupes  
4: Muscle  
5: Sports Classics  
6: Sports  
7: Super  
8: Motorcycles  
9: Off-road  
10: Industrial  
11: Utility  
12: Vans  
13: Cycles  
14: Boats  
15: Helicopters  
16: Planes  
17: Service  
18: Emergency  
19: Military  
20: Commercial  
21: Trains 
]]