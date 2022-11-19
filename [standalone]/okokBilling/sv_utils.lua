QBCore = exports["qb-core"]:GetCoreObject()

Webhook = ''

QBCore.Functions.CreateCallback(Config.EventPrefix..":getPlayerGroup", function(source, cb)
    local isAdmin = false
	for k,v in ipairs(Config.AdminGroups) do
		if QBCore.Functions.HasPermission(source, v) then
			isAdmin = true
			break
		end
	end
	cb(isAdmin)
end)

function xPlayerSource(source)
	return QBCore.Functions.GetPlayer(source)
end

function xPlayerCitizenID(citizenid)
	return QBCore.Functions.GetPlayerByCitizenId(citizenid)
end

function getMoneyAmount(xPlayer, account)
	local moneyCount = 0
	if account == "cash" then
		moneyCount = xPlayer.PlayerData.money.cash
	else
		moneyCount = xPlayer.PlayerData.money.bank
	end
	
	return moneyCount
end

function removeMoney(xPlayer, account, value)
	xPlayer.Functions.RemoveMoney(account, tonumber(value))
end

function addMoney(xPlayer, account, value)
	xPlayer.Functions.AddMoney(account, tonumber(value))
end

function playerAccountsQuery()
	return 'SELECT money FROM players WHERE citizenid'
end

function playerAccountSetQuery()
	return 'UPDATE players SET money'
end

function getPlayerAccount(user)
	return json.decode(user[1].money)
end

function getPlayerBankMoney(playerAccount)
	return playerAccount.bank
end

function setMinusAccount(playerAccount, value)
	playerAccount.bank = playerAccount.bank - value
	return playerAccount
end

function setPlusAccount(playerAccount, value)
	playerAccount.bank = playerAccount.bank + value
	return playerAccount
end

function getCoords(xPlayer)
	local source = xPlayer.PlayerData.source
	local ped = GetPlayerPed(source)
	return GetEntityCoords(ped)
end

function MySQLexecute(query, values, func)
	return MySQL.Async.execute(query, values, func)
end

function MySQLfetchAll(query, values, func)
	return MySQL.Async.fetchAll(query, values, func)
end

function MySQLinsert(query, values, func)
	return MySQL.Async.insert(query, values, func)
end

function getName(identifier)
	local name = nil
	local xPlayer = QBCore.Functions.GetPlayerByCitizenId(identifier)
	name = xPlayer.PlayerData.charinfo.firstname.." "..xPlayer.PlayerData.charinfo.lastname
	return name
end

function playerPayInvoice(invoice, cb)

	local receiver_identifier = invoice.receiver_identifier
	local author_identifier = invoice.author_identifier
	local ref_id = invoice.ref_id

	xReceiver = QBCore.Functions.GetPlayerByCitizenId(receiver_identifier)
	xAuthor = QBCore.Functions.GetPlayerByCitizenId(author_identifier)

	if(xReceiver == nil) then
		MySQLfetchAll(playerAccountsQuery()..' = @id', {
			['@id'] = receiver_identifier
		}, function(account)
			if account ~= nil and json.encode(account) ~= '[]' then
				local playerAccount = getPlayerAccount(account)
				if tonumber(playerAccount.bank) >= (invoice.invoice_value) then
					playerAccount = json.encode(setMinusAccount(playerAccount, invoice.invoice_value))
			
					MySQLexecute(playerAccountSetQuery()..' = @playerAccount WHERE citizenid = @target', {
						['@playerAccount'] = playerAccount,
						['@target'] = receiver_identifier
					}, function(changed)
						if xAuthor == nil then
							MySQLfetchAll(playerAccountsQuery()..' = @id', {
								['@id'] = author_identifier
							}, function(account)
								if account ~= nil and json.encode(account) ~= '[]' then
									local playerAccount = getPlayerAccount(account)
									playerAccount = json.encode(setPlusAccount(playerAccount, invoice.invoice_value))
							
									MySQLexecute(playerAccountSetQuery()..' = @playerAccount WHERE citizenid = @target', {
										['@playerAccount'] = playerAccount,
										['@target'] = author_identifier
									}, function(changed)	
										MySQLexecute('UPDATE '..Config.DatabaseTable..' SET status = "paid", paid_date = CURRENT_TIMESTAMP() WHERE ref_id = @ref_id', {
											['@ref_id'] = ref_id
										}, function(changed)
											if(cb ~= nil) then
												if Webhook ~= "" then
													data = {
														playerid = receiver_identifier,
														type = "paid-invoice",
														ref_id = ref_id,
														amount = invoice.invoice_value,
													}

													discordWebhook(data)
												end
												cb("paid with success")
											end
										end)
									end)
								else
									MySQLexecute('UPDATE '..Config.DatabaseTable..' SET status = "paid", paid_date = CURRENT_TIMESTAMP() WHERE ref_id = @ref_id', {
										['@ref_id'] = ref_id
									}, function(changed)
										if(cb ~= nil) then
											if Webhook ~= "" then
												data = {
													playerid = receiver_identifier,
													type = "paid-invoice",
													ref_id = ref_id,
													amount = invoice.invoice_value,
												}

												discordWebhook(data)
											end
											cb("paid with success")
										end
									end)
								end
							end)
						else
							addMoney(xAuthor, "bank", invoice.invoice_value)
							MySQLexecute('UPDATE '..Config.DatabaseTable..' SET status = "paid", paid_date = CURRENT_TIMESTAMP() WHERE ref_id = @ref_id', {
								['@ref_id'] = ref_id
							}, function(changed)
								if(cb ~= nil) then
									if Webhook ~= "" then
										data = {
											playerid = xReceiver.PlayerData.source,
											type = "paid-invoice",
											ref_id = ref_id,
											amount = invoice.invoice_value,
										}

										discordWebhook(data)
									end
									cb("paid with success")
								end
							end)
						end						
					end)
				end
			else
				if xAuthor == nil then
					MySQLfetchAll(playerAccountsQuery()..' = @id', {
						['@id'] = author_identifier
					}, function(account)
						if account ~= nil and json.encode(account) ~= '[]' then
							local playerAccount = getPlayerAccount(account)
							playerAccount = json.encode(setPlusAccount(playerAccount, invoice.invoice_value))
					
							MySQLexecute(playerAccountSetQuery()..' = @playerAccount WHERE citizenid = @target', {
								['@playerAccount'] = playerAccount,
								['@target'] = author_identifier
							}, function(changed)	
								MySQLexecute('UPDATE '..Config.DatabaseTable..' SET status = "paid", paid_date = CURRENT_TIMESTAMP() WHERE ref_id = @ref_id', {
									['@ref_id'] = ref_id
								}, function(changed)
									if(cb ~= nil) then
										if Webhook ~= "" then
											data = {
												playerid = receiver_identifier,
												type = "paid-invoice",
												ref_id = ref_id,
												amount = invoice.invoice_value,
											}

											discordWebhook(data)
										end
										cb("paid with success")
									end
								end)
							end)
						else
							MySQLexecute('UPDATE '..Config.DatabaseTable..' SET status = "paid", paid_date = CURRENT_TIMESTAMP() WHERE ref_id = @ref_id', {
								['@ref_id'] = ref_id
							}, function(changed)
								if(cb ~= nil) then
									if Webhook ~= "" then
										data = {
											playerid = receiver_identifier,
											type = "paid-invoice",
											ref_id = ref_id,
											amount = invoice.invoice_value,
										}

										discordWebhook(data)
									end
									cb("paid with success")
								end
							end)
						end
					end)
				else
					addMoney(xAuthor, "bank", invoice.invoice_value)
					MySQLexecute('UPDATE '..Config.DatabaseTable..' SET status = "paid", paid_date = CURRENT_TIMESTAMP() WHERE ref_id = @ref_id', {
						['@ref_id'] = ref_id
					}, function(changed)
						if(cb ~= nil) then
							if Webhook ~= "" then
								data = {
									playerid = xReceiver.PlayerData.source,
									type = "paid-invoice",
									ref_id = ref_id,
									amount = invoice.invoice_value,
								}

								discordWebhook(data)
							end
							cb("paid with success")
						end
					end)
				end	
			end
		end)
	else
		if tonumber(getMoneyAmount(xReceiver, "bank")) >= (invoice.invoice_value) then
			removeMoney(xReceiver, "bank", invoice.invoice_value)
			if xAuthor == nil then
				if invoice.author_identifier == 'custom' then
					MySQLexecute('UPDATE '..Config.DatabaseTable..' SET status = "paid", paid_date = CURRENT_TIMESTAMP() WHERE ref_id = @ref_id', {
						['@ref_id'] = ref_id
					}, function(changed)
						if(cb ~= nil) then
							if Webhook ~= "" then
								data = {
									playerid = xReceiver.PlayerData.source,
									type = "paid-invoice",
									ref_id = ref_id,
									amount = invoice.invoice_value,
								}

								discordWebhook(data)
							end
							cb("paid with success")
						end
					end)
				else
					MySQLfetchAll(playerAccountsQuery()..' = @id', {
						['@id'] = author_identifier
					}, function(account)
						if account ~= nil and json.encode(account) ~= '[]' then
							local playerAccount = getPlayerAccount(account)
							playerAccount = json.encode(setPlusAccount(playerAccount, invoice.invoice_value))
					
							MySQLexecute(playerAccountSetQuery()..' = @playerAccount WHERE citizenid = @target', {
								['@playerAccount'] = playerAccount,
								['@target'] = author_identifier
							}, function(changed)	
								MySQLexecute('UPDATE '..Config.DatabaseTable..' SET status = "paid", paid_date = CURRENT_TIMESTAMP() WHERE ref_id = @ref_id', {
									['@ref_id'] = ref_id
								}, function(changed)
									if(cb ~= nil) then
										if Webhook ~= "" then
											data = {
												playerid = xReceiver.PlayerData.source,
												type = "paid-invoice",
												ref_id = ref_id,
												amount = invoice.invoice_value,
											}

											discordWebhook(data)
										end
										cb("paid with success")
									end
								end)
							end)
						else
							MySQLexecute('UPDATE '..Config.DatabaseTable..' SET status = "paid", paid_date = CURRENT_TIMESTAMP() WHERE ref_id = @ref_id', {
								['@ref_id'] = ref_id
							}, function(changed)
								if(cb ~= nil) then
									if Webhook ~= "" then
										data = {
											playerid = xReceiver.PlayerData.source,
											type = "paid-invoice",
											ref_id = ref_id,
											amount = invoice.invoice_value,
										}

										discordWebhook(data)
									end
									cb("paid with success")
								end
							end)
						end
					end)
				end
			else
				addMoney(xAuthor, "bank", invoice.invoice_value)
				MySQLexecute('UPDATE '..Config.DatabaseTable..' SET status = "paid", paid_date = CURRENT_TIMESTAMP() WHERE ref_id = @ref_id', {
					['@ref_id'] = ref_id
				}, function(changed)
					if(cb ~= nil) then
						if Webhook ~= "" then
							data = {
								playerid = xReceiver.PlayerData.source,
								type = "paid-invoice",
								ref_id = ref_id,
								amount = invoice.invoice_value,
							}

							discordWebhook(data)
						end
						cb("paid with success")
					end
				end)
			end	
		else
			TriggerClientEvent(Config.EventPrefix..':notification', xReceiver.PlayerData.source, _L('paid_error').title, _L('paid_error').text, _L('paid_error').time, _L('paid_error').type)
		end
	end
end

function authorInvoiceReceive(invoice)
	if Config.AuthorReceivesAPercentage then
		local xAuthor = QBCore.Functions.GetPlayerByCitizenId(tostring(invoice.author_identifier))
		local receive = tonumber(invoice.invoice_value)
		authorReceive = receive * (Config.AuthorPercentage / 100)
		receive = receive - authorReceive


		if xAuthor == nil then
			MySQLfetchAll(playerAccountsQuery()..' = @id', {
				['@id'] = invoice.author_identifier
			}, function(account)
				if account ~= nil and json.encode(account) ~= '[]' then
					local playerAccount = getPlayerAccount(account)
					playerAccount = json.encode(setPlusAccount(playerAccount, receive))
			
					MySQLexecute(playerAccountSetQuery()..' = @playerAccount WHERE citizenid = @target', {
						['@playerAccount'] = playerAccount,
						['@target'] = invoice.author_identifier
					}, function(changed)	
						MySQLexecute('UPDATE '..Config.DatabaseTable..' SET status = "paid", paid_date = CURRENT_TIMESTAMP() WHERE ref_id = @ref_id', {
							['@ref_id'] = invoice.ref_id
						}, function(changed)
							if(cb ~= nil) then
								cb("paid with success")
							end
						end)
					end)
				else
					MySQLexecute('UPDATE '..Config.DatabaseTable..' SET status = "paid", paid_date = CURRENT_TIMESTAMP() WHERE ref_id = @ref_id', {
						['@ref_id'] = invoice.ref_id
					}, function(changed)
						if(cb ~= nil) then
							cb("paid with success")
						end
					end)
				end
			end)
		else
			addMoney(xAuthor, "bank", authorReceive)
			MySQLexecute('UPDATE '..Config.DatabaseTable..' SET status = "paid", paid_date = CURRENT_TIMESTAMP() WHERE ref_id = @ref_id', {
				['@ref_id'] = invoice.ref_id
			}, function(changed)
				if(cb ~= nil) then
					cb("paid with success")
				end
			end)
		end	
	end
end

function societyPayInvoice(invoice, cb)
	local ref_id = invoice.ref_id

	local sqlFetchSociety = ""
	local sqlUpdateSociety = ""

	if(Config.QBManagement) then
		sqlFetchSociety = "SELECT * FROM management_funds WHERE job_name"
		sqlUpdateSociety = "UPDATE management_funds SET amount = @value WHERE job_name = @target"
	else
		sqlFetchSociety = "SELECT * FROM okokbanking_societies WHERE society"
		sqlUpdateSociety = "UPDATE okokbanking_societies SET value = @value WHERE society = @target"
	end
	
	MySQLfetchAll(sqlFetchSociety..' = @identifier', {
		['@identifier'] = Config.SocietyHasSocietyPrefix and 'society_'..string.gsub(invoice.society, "society_", "") or string.gsub(invoice.society, "society_", ""),
	}, function(society_bank)
		local society_bank = society_bank[1]
		local xReceiver = QBCore.Functions.GetPlayerByCitizenId(invoice.receiver_identifier)
		local invoice_value = Config.AuthorReceivesAPercentage and tonumber(invoice.invoice_value) - (tonumber(invoice.invoice_value) * (Config.AuthorPercentage / 100)) or tonumber(invoice.invoice_value)

		if xReceiver == nil then
			MySQLfetchAll(playerAccountsQuery()..' = @id', {
				['@id'] = invoice.receiver_identifier
			}, function(account)
				if account ~= nil and json.encode(account) ~= '[]' then
					local receiverAccount = getPlayerAccount(account)
					local bank = nil

					if Config.SocietyReceivesLessWithVAT == true then
						local value = invoice_value
						value = value - (value * (Config.VATPercentage/100))
						bank = getPlayerBankMoney(receiverAccount)
						receiverAccount = json.encode(setPlusAccount(receiverAccount, value))
					else
						bank = getPlayerBankMoney(receiverAccount)
						receiverAccount = json.encode(setPlusAccount(receiverAccount, invoice_value))
					end

					

					if(bank >= 0) then
						local societyMoney = Config.QBManagement and society_bank.amount or society_bank.value
						exports['qb-management']:AddMoney(Config.SocietyHasSocietyPrefix and 'society_'..string.gsub(invoice.society, "society_", "") or string.gsub(invoice.society, "society_", ""), invoice_value)
						
						MySQLexecute(playerAccountSetQuery()..' = @playerAccount WHERE citizenid = @target', {
							['@playerAccount'] = receiverAccount,
							['@target'] = invoice.receiver_identifier
						}, function(changed)
							MySQLexecute('UPDATE '..Config.DatabaseTable..' SET status = "paid", paid_date = CURRENT_TIMESTAMP() WHERE ref_id = @ref_id', {
								['@ref_id'] = ref_id
							}, function(changed)
								if(cb ~= nil) then
									authorInvoiceReceive(invoice)
									if Webhook ~= "" then
										data = {
											playerid = xReceiver.PlayerData.source,
											type = "paid-invoice",
											ref_id = ref_id,
											amount = invoice_value,
										}

										discordWebhook(data)
									end
									cb("paid with success")
								end
							end)
						end)	
					end
				end
			end)
		else
			if getMoneyAmount(xReceiver, "bank") >= invoice_value then
				removeMoney(xReceiver, "bank", invoice_value)
				local value = 0
				local societyMoney
				if(Config.QBManagement) then
					societyMoney = society_bank.amount
				else
					societyMoney = society_bank.value
				end

				if Config.SocietyReceivesLessWithVAT == false then
					if Config.QBManagement then
						value = invoice_value
					else
						value = societyMoney + invoice_value
					end
					
				else
					value = invoice_value
					value = value - (value * (Config.VATPercentage/100))
					if not Config.QBManagement then
						value = value + societyMoney
					end
					
				end
				exports['qb-management']:AddMoney(Config.SocietyHasSocietyPrefix and 'society_'..string.gsub(invoice.society, "society_", "") or string.gsub(invoice.society, "society_", ""), value)

				MySQLexecute('UPDATE '..Config.DatabaseTable..' SET status = "paid", paid_date = CURRENT_TIMESTAMP() WHERE ref_id = @ref_id', {
					['@ref_id'] = ref_id
				}, function(changed)
					if(cb ~= nil) then
						authorInvoiceReceive(invoice)
						if Webhook ~= "" then
							data = {
								playerid = xReceiver.PlayerData.source,
								type = "paid-invoice",
								ref_id = ref_id,
								amount = invoice_value,
							}

							discordWebhook(data)
						end
						cb("paid with success")
					end
				end)
			else
				TriggerClientEvent(Config.EventPrefix..':notification', xReceiver.PlayerData.source, _L('paid_error').title, _L('paid_error').text, _L('paid_error').time, _L('paid_error').type)
			end
		end
	end)
end

QBCore.Functions.CreateCallback(Config.EventPrefix..":PayReference", function(source, cb, ref_id)
	MySQLfetchAll('SELECT * FROM '..Config.DatabaseTable..' WHERE ref_id = @identifier', {
		['@identifier'] = ref_id,
	}, function(invoice)
		local xPlayer = QBCore.Functions.GetPlayer(source)
		local invoice = invoice[1]

		
		if(invoice["society"] == "") then
			local author_identifier = invoice.author_identifier
			xAuthor = QBCore.Functions.GetPlayerByCitizenId(author_identifier)
			if tonumber(getMoneyAmount(xPlayer, "bank")) >= (invoice.invoice_value) then
				removeMoney(xPlayer, "bank", invoice.invoice_value)
				if xAuthor == nil then
					if invoice.author_identifier == 'custom' then
						MySQLexecute('UPDATE '..Config.DatabaseTable..' SET status = "paid", paid_date = CURRENT_TIMESTAMP() WHERE ref_id = @ref_id', {
							['@ref_id'] = ref_id
						}, function(changed)
							if(cb ~= nil) then
								cb("paid with success")
							end
						end)
					else
						MySQLfetchAll(playerAccountsQuery()..' = @id', {
							['@id'] = author_identifier
						}, function(account)
							if account ~= nil and json.encode(account) ~= '[]' then
								local playerAccount = getPlayerAccount(account)
								playerAccount = json.encode(setPlusAccount(playerAccount, invoice.invoice_value))
						
								MySQLexecute(playerAccountSetQuery()..' = @playerAccount WHERE citizenid = @target', {
									['@playerAccount'] = playerAccount,
									['@target'] = author_identifier
								}, function(changed)	
									MySQLexecute('UPDATE '..Config.DatabaseTable..' SET status = "paid", paid_date = CURRENT_TIMESTAMP() WHERE ref_id = @ref_id', {
										['@ref_id'] = ref_id
									}, function(changed)
										cb("paid with success")
									end)
								end)
							else
								MySQLexecute('UPDATE '..Config.DatabaseTable..' SET status = "paid", paid_date = CURRENT_TIMESTAMP() WHERE ref_id = @ref_id', {
									['@ref_id'] = ref_id
								}, function(changed)
									cb("paid with success")
								end)
							end
						end)
					end
				else
					addMoney(xAuthor, "bank", invoice.invoice_value)
					MySQLexecute('UPDATE '..Config.DatabaseTable..' SET status = "paid", paid_date = CURRENT_TIMESTAMP() WHERE ref_id = @ref_id', {
						['@ref_id'] = ref_id
					}, function(changed)
						cb("paid with success")
					end)
				end	
			else
				TriggerClientEvent(Config.EventPrefix..':notification', xPlayer.PlayerData.source, _L('paid_error').title, _L('paid_error').text, _L('paid_error').time, _L('paid_error').type)
			end	
		else
			local sqlFetchSociety = ""
			local sqlUpdateSociety = ""

			if(Config.QBManagement) then
				sqlFetchSociety = "SELECT * FROM management_funds WHERE job_name"
				sqlUpdateSociety = "UPDATE management_funds SET amount = @value WHERE job_name = @target"
			else
				sqlFetchSociety = "SELECT * FROM okokbanking_societies WHERE society"
				sqlUpdateSociety = "UPDATE okokbanking_societies SET value = @value WHERE society = @target"
			end

			MySQLfetchAll(sqlFetchSociety..' = @identifier', {
				['@identifier'] = Config.SocietyHasSocietyPrefix and 'society_'..string.gsub(invoice.society, "society_", "") or string.gsub(invoice.society, "society_", ""),
			}, function(society_bank)
				local society_bank = society_bank[1]
		
				if getMoneyAmount(xPlayer, "bank") >= (invoice.invoice_value) then
					removeMoney(xPlayer, "bank", invoice.invoice_value)
					local value = 0
					local societyMoney = Config.QBManagement and society_bank.amount or society_bank.value

					if Config.SocietyReceivesLessWithVAT == false then
						value = societyMoney + (invoice.invoice_value)
					else
						value = (invoice.invoice_value)
						value = value - (value * (Config.VATPercentage/100))
						value = value + societyMoney
					end
					MySQLexecute(sqlUpdateSociety, {
						['@value'] = value,
						['@target'] = Config.SocietyHasSocietyPrefix and 'society_'..string.gsub(invoice.society, "society_", "") or string.gsub(invoice.society, "society_", "")
					}, function(changed)
						MySQLexecute('UPDATE '..Config.DatabaseTable..' SET status = "paid", paid_date = CURRENT_TIMESTAMP() WHERE ref_id = @ref_id', {
							['@ref_id'] = ref_id
						}, function(changed)
							cb("paid with success")
						end)
					end)
				else
					TriggerClientEvent(Config.EventPrefix..':notification', xPlayer.PlayerData.source, _L('paid_error').title, _L('paid_error').text, _L('paid_error').time, _L('paid_error').type)
				end
			end)
		end	
	end)
end)

RegisterServerEvent(Config.EventPrefix..":PayInvoice")
AddEventHandler(Config.EventPrefix..":PayInvoice", function(invoiceID)
    MySQLfetchAll('SELECT * FROM '..Config.DatabaseTable..' WHERE id = @id', {
        ['@id'] = invoiceID,
    }, function(invoice)
        local xReceiver = xPlayerCitizenID(invoice[1]["receiver_identifier"])
        if(invoice[1]["society"] == "" or invoice[1]["society"] == nil or string.gsub(invoice[1]["society"], "%s+", "") == "") then
            playerPayInvoice(invoice[1], cb)
        else
            societyPayInvoice(invoice[1], cb)
        end    
    end)
end)

-------------------------- IDENTIFIERS

function ExtractIdentifiers(id)
	local identifiers = {
		steam = "",
		ip = "",
		discord = "",
		license = "",
		xbl = "",
		live = ""
	}

	for i = 0, GetNumPlayerIdentifiers(id) - 1 do
		local playerID = GetPlayerIdentifier(id, i)

		if string.find(playerID, "steam") then
			identifiers.steam = playerID
		elseif string.find(playerID, "ip") then
			identifiers.ip = playerID
		elseif string.find(playerID, "discord") then
			identifiers.discord = playerID
		elseif string.find(playerID, "license") then
			identifiers.license = playerID
		elseif string.find(playerID, "xbl") then
			identifiers.xbl = playerID
		elseif string.find(playerID, "live") then
			identifiers.live = playerID
		end
	end

	return identifiers
end

-------------------------- WEBHOOK

function discordWebhook(data)
	local color = '65352'
	local category = 'default'
	local identifierlist = ExtractIdentifiers(data.playerid)
	local identifier = identifierlist.license:gsub("license2:", "")
	local discord = "<@"..identifierlist.discord:gsub("discord:", "")..">"
	local description = ''

	if data.type == 'paid-invoice' then
		color = Config.PayInvoiceWebhookColor
		category = 'paid an invoice'
		local ref_id = data.ref_id
		local amount = data.amount
		description = '**Action:** '..category..'\n\n**Reference:** '..ref_id..'\n**Value:** '..amount
	
	elseif data.type == 'create-invoice-job' then
		color = Config.CreateJobInvoiceWebhookColor
		category = 'Sent an invoice as '..data.job
		local author_id = data.author_id
		local author_name = data.author_name
		local receiver_id = data.receiver_id
		local receiver_name = data.receiver_name
		local job = data.job
		local item = data.item
		local amount = data.amount
		description = '**Action:** '..category..'\n\n**Job:** '..job..'\n**Item:** '..item..'\n**Value:** '..amount..'\n\n**Author:** '..author_name..'\n**Author Identifier:** '..author_id..'\n**Receiver:** '..receiver_name..'\n**Receiver Identifier:** '..receiver_id
	
	elseif data.type == 'create-invoice-player' then
		color = Config.CreatePersonalInvoiceWebhookColor
		category = 'Sent a personal invoice'
		local author_id = data.author_id
		local author_name = data.author_name
		local receiver_id = data.receiver_id
		local receiver_name = data.receiver_name
		local item = data.item
		local amount = data.amount
		description = '**Action:** '..category..'\n\n**Item:** '..item..'\n**Value:** '..amount..'\n\n**Author:** '..author_name..'\n**Author Identifier:** '..author_id..'\n**Receiver:** '..receiver_name..'\n**Receiver Identifier:** '..receiver_id

	elseif data.type == 'cancel-invoice' then
		color = Config.CancelInvoiceWebhookColor
		category = 'Invoice was canceled'
		local ref_id = data.ref_id
		local player_id = data.player_id
		local player_name = data.player_name
		description = '**Action:** '..category..'\n\n**Reference:** '..ref_id..'\n\n**Canceled by:** '..player_name..'\n**Identifier:** '..player_id
		
	elseif data.type == 'create-invoice-custom' then
		color = Config.CreateJobInvoiceWebhookColor
		category = 'Sent a custom invoice'
		local author_id = data.author_id
		local author_name = data.author_name
		local receiver_id = data.receiver_id
		local receiver_name = data.receiver_name
		local item = data.item
		local amount = data.amount
		description = '**Action:** '..category..'\n\n**Item:** '..item..'\n**Value:** '..amount..'\n\n**Author:** '..author_name..'\n**Author Identifier:** '..author_id..'\n**Receiver:** '..receiver_name..'\n**Receiver Identifier:** '..receiver_id

	end

	local information = {
		{
			["color"] = color,
			["author"] = {
				["icon_url"] = Config.IconURL,
				["name"] = Config.ServerName..' - Logs',
			},
			["title"] = 'BILLING',
			["description"] = description..'\n\n**ID:** '..data.playerid..'\n**Identifier:** '..identifier..'\n**Discord:** '..discord,
			["footer"] = {
				["text"] = os.date(Config.DateFormat),
			}
		}
	}

	PerformHttpRequest(Webhook, function(err, text, headers) end, 'POST', json.encode({username = Config.BotName, embeds = information}), {['Content-Type'] = 'application/json'})
end