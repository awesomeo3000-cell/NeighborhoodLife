require "ISUI/ISPanel"
require "NL/SimsButton"
require "NL/Client"
require "NL/HouseholdClient"
require "NL/UITheme"

NLHouseholdPanel = ISPanel:derive("NLHouseholdPanel")
NLHouseholdPanel.instances = {}

local C = NLUI.colors

function NLHouseholdPanel:new(index)
    local o = ISPanel.new(self, 330, 90, 700, 620)
    o.playerIndex = index
    NLUI.applyPanel(o)
    return o
end

function NLHouseholdPanel:button(x, y, w, text, action, value, kind)
    local button = NLSimsButton:new(x, y, w, 30, text, self, self.onButton)
    button.action, button.value = action, value
    button:setKind(kind or (action == "close" and "close" or "ghost"))
    button:initialise()
    self:addChild(button)
    return button
end

function NLHouseholdPanel:initialise()
    ISPanel.initialise(self)
    self:button(self.width - 44, 9, 30, "✕", "close", nil, "close")
    self:button(18, 58, 122, "Create home", "create")
    self:button(148, 58, 120, "Accept invite", "accept")
    self:button(276, 58, 120, "Invite guest", "invite")
    self:button(404, 58, 88, "Leave", "leave")
    self:button(500, 58, 104, "Refresh", "refresh")
    self.transferButton = self:button(18, 96, 160, "Transfer owner", "transfer")

    self.storageButtons = {
        store = self:button(18, 450, 196, "Store Ripped Sheets", "store", { item="Base.RippedSheets", amount=1 }),
        retrieve = self:button(222, 450, 196, "Take Ripped Sheets", "retrieve", { item="Base.RippedSheets", amount=1 }),
    }

    self.taskButtons = {}
    for i, task in ipairs(NLHouseholds.taskOrder) do
        local col = (i - 1) % 3
        local row = math.floor((i - 1) / 3)
        self.taskButtons[task] = self:button(18 + col * 218, 516 + row * 36, 206,
            NLHouseholds.tasks[task].label, "task", task)
    end
end

function NLHouseholdPanel:inviteTarget()
    local selfPlayer = getSpecificPlayer(self.playerIndex)
    local selfName = selfPlayer and selfPlayer:getUsername()
    local presence = NLClient.presence
    for _, row in ipairs((presence and presence.players) or {}) do
        if row.username and row.username ~= selfName then return row.username end
    end
end

function NLHouseholdPanel:transferTarget()
    local selfPlayer = getSpecificPlayer(self.playerIndex)
    local selfName = selfPlayer and selfPlayer:getUsername()
    local state = NLHouseholdClient.snapshots[self.playerIndex]
    local household = state and state.household
    if not household or household.owner ~= selfName then return nil end
    for _, row in ipairs(household.members or {}) do
        if row.username and row.username ~= selfName then return row.username end
    end
end

function NLHouseholdPanel:onButton(button)
    if button.action == "close" then self:setVisible(false); return end
    if button.action == "invite" then
        local target = self:inviteTarget()
        if target then NLHouseholdClient.request(self.playerIndex, "invite", { target=target }) end
        return
    end
    if button.action == "transfer" then
        local target = self:transferTarget()
        if target then NLHouseholdClient.request(self.playerIndex, "transfer", { target=target }) end
        return
    end

    local args = {}
    if button.action == "task" then args = { task=button.value }
    elseif button.action == "store" or button.action == "retrieve" then args = button.value end
    NLHouseholdClient.request(self.playerIndex, button.action, args)
end

function NLHouseholdPanel:prerender()
    ISPanel.prerender(self)
    NLUI.window(self, "Household", "Shared home, storage and routines")

    local state = NLHouseholdClient.snapshots[self.playerIndex]
    if not state then
        NLUI.well(self, 18, 132, 664, 240, "HOUSEHOLD")
        self:drawText("Waiting for household data. Use Refresh if this persists.", 34, 178,
            C.textDark.r, C.textDark.g, C.textDark.b, 1, UIFont.Small)
        return
    end

    local profile = NLClient.profiles[self.playerIndex]
    local invite = state.invite

    NLUI.well(self, 18, 132, 664, 246, "HOUSEHOLD")
    if invite then
        self:drawText("Invitation", 34, 170, C.textDark.r, C.textDark.g, C.textDark.b, 1, UIFont.Small)
        self:drawText(tostring(invite.name or invite.householdId) .. " from " .. tostring(invite.from),
            34, 194, C.muted.r, C.muted.g, C.muted.b, 1, UIFont.Small)
        NLUI.pill(self, 34, 224, 150, "INVITE WAITING", "good")
    elseif state.household then
        local household = state.household
        NLUI.drawPlumbob(self, 42, 172, 22, 0.95)
        self:drawText(household.name, 62, 166, C.textDark.r, C.textDark.g, C.textDark.b, 1, UIFont.Small)
        self:drawText("Owner: " .. tostring(household.owner), 62, 188,
            C.muted.r, C.muted.g, C.muted.b, 1, UIFont.Small)
        self:drawText("Home tile " .. tostring(household.home.x) .. ", "
            .. tostring(household.home.y) .. ", " .. tostring(household.home.z), 62, 210,
            C.muted.r, C.muted.g, C.muted.b, 1, UIFont.Small)

        local x = 34
        local y = 246
        for i, member in ipairs(household.members or {}) do
            local cardX = x + ((i - 1) % 3) * 208
            local cardY = y + math.floor((i - 1) / 3) * 70
            NLUI.card(self, cardX, cardY, 194, 56, true)
            NLUI.monogram(self, cardX + 8, cardY + 8, 40, member.username)
            self:drawText(member.username, cardX + 56, cardY + 8,
                C.textDark.r, C.textDark.g, C.textDark.b, 1, UIFont.Small)
            self:drawText(member.role .. " | " .. tostring(member.contribution) .. " routines",
                cardX + 56, cardY + 28, C.muted.r, C.muted.g, C.muted.b, 1, UIFont.Small)
            if member.online then NLUI.pill(self, cardX + 112, cardY + 35, 72, "ONLINE", "good") end
            if i >= 6 then break end
        end
    else
        NLUI.drawPlumbob(self, 44, 175, 24, 0.95)
        self:drawText("Found a Household & Establish Safehouse", 68, 166, C.textDark.r, C.textDark.g, C.textDark.b, 1, UIFont.Small)
        self:drawText("• Claim your current safehouse tile as the communal neighborhood home.", 38, 196, C.muted.r, C.muted.g, C.muted.b, 1, UIFont.Small)
        self:drawText("• Pool food, building materials, and medicine in Shared Storage.", 38, 218, C.muted.r, C.muted.g, C.muted.b, 1, UIFont.Small)
        self:drawText("• Complete morning and evening routines for communal morale boosts.", 38, 240, C.muted.r, C.muted.g, C.muted.b, 1, UIFont.Small)
        NLUI.pill(self, 38, 276, 260, "CLICK 'CREATE HOME' ABOVE TO ESTABLISH", "accent")
    end

    NLUI.well(self, 18, 390, 664, 98, "SHARED STORAGE", true)
    local household = state.household
    local stored = {}
    if household then
        for itemType, amount in pairs(household.storage or {}) do
            stored[#stored + 1] = NLUI.itemLabel(itemType) .. " x" .. tostring(amount)
        end
        table.sort(stored)
    end
    self:drawText(#stored > 0 and table.concat(stored, ", ") or "Shared storage is empty.", 34, 426,
        C.textDark.r, C.textDark.g, C.textDark.b, 1, UIFont.Small)

    NLUI.well(self, 18, 500, 664, 92, "HOME ROUTINES")
    if household and state.homeAspirationLabel then
        self:drawText("Home aspiration: " .. tostring(state.homeAspirationLabel), 34, 536,
            C.textDark.r, C.textDark.g, C.textDark.b, 1, UIFont.Small)
    end

    for _, button in pairs(self.taskButtons) do button:setEnable(household ~= nil and profile ~= nil) end
    for _, button in pairs(self.storageButtons) do button:setEnable(household ~= nil and profile ~= nil) end
    if self.transferButton then self.transferButton:setEnable(self:transferTarget() ~= nil) end

    self:drawText(string.sub(state.message or "", 1, 90), 18, 598,
        C.frameMid.r, C.frameMid.g, C.frameMid.b, 1, UIFont.Small)
end

function NLHouseholdPanel.open(index)
    local panel = NLHouseholdPanel.instances[index]
    if not panel then
        panel = NLHouseholdPanel:new(index)
        panel:initialise()
        NLHouseholdPanel.instances[index] = panel
    end
    panel:setX(getPlayerScreenLeft(index) + math.max(0, (getPlayerScreenWidth(index) - panel.width) / 2))
    panel:setY(getPlayerScreenTop(index) + math.max(0, (getPlayerScreenHeight(index) - panel.height) / 2))
    panel:removeFromUIManager()
    panel:addToUIManager()
    panel:setVisible(true)
    panel:bringToTop()
    NLHouseholdClient.request(index, "refresh")
end

Events.OnMainMenuEnter.Add(function()
    for _, panel in pairs(NLHouseholdPanel.instances) do panel:removeFromUIManager() end
    NLHouseholdPanel.instances = {}
end)

return NLHouseholdPanel
