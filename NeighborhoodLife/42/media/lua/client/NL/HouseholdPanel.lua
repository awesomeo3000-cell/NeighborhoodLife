require "ISUI/ISPanel"
require "ISUI/ISButton"
require "NL/Client"
require "NL/HouseholdClient"

NLHouseholdPanel = ISPanel:derive("NLHouseholdPanel")
NLHouseholdPanel.instances = {}

function NLHouseholdPanel:new(index)
    local o = ISPanel.new(self, 330, 130, 590, 490)
    o.playerIndex = index
    o.backgroundColor = { r = 0.96, g = 0.98, b = 1, a = 0.98 }
    o.borderColor = { r = 0.62, g = 0.76, b = 0.88, a = 1 }
    o.moveWithMouse = true
    return o
end

function NLHouseholdPanel:button(x, y, w, text, action, value)
    local button = ISButton:new(x, y, w, 28, text, self, self.onButton)
    button.action, button.value = action, value
    button.backgroundColor = { r = 0.86, g = 0.92, b = 0.97, a = 1 }
    button.backgroundColorMouseOver = { r = 0.69, g = 0.87, b = 0.98, a = 1 }
    button.borderColor = { r = 0.53, g = 0.69, b = 0.82, a = 1 }
    button.textColor = { r = 0.12, g = 0.30, b = 0.47, a = 1 }
    button:initialise(); self:addChild(button)
    return button
end

function NLHouseholdPanel:initialise()
    ISPanel.initialise(self)
    self:button(self.width - 75, 10, 60, "Close", "close")
    self:button(16, 48, 135, "Create home", "create")
    self:button(160, 48, 105, "Accept invite", "accept")
    self:button(274, 48, 105, "Invite guest", "invite")
    self:button(388, 48, 105, "Leave", "leave")
    self:button(500, 48, 74, "Refresh", "refresh")
    self.transferButton = self:button(16, 82, 135, "Transfer owner", "transfer")
    self.storageButtons = {
        store = self:button(16, 350, 175, "Store 1 RippedSheet", "store",
            { item = "Base.RippedSheets", amount = 1 }),
        retrieve = self:button(200, 350, 175, "Take 1 RippedSheet", "retrieve",
            { item = "Base.RippedSheets", amount = 1 }),
    }
    self.taskButtons = {}
    for i, task in ipairs(NLHouseholds.taskOrder) do
        self.taskButtons[task] = self:button(16 + (i - 1) * 185, 386, 170,
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
        if target then NLHouseholdClient.request(self.playerIndex, "invite", { target = target }) end
        return
    end
    if button.action == "transfer" then
        local target = self:transferTarget()
        if target then NLHouseholdClient.request(self.playerIndex, "transfer", { target = target }) end
        return
    end
    local args = {}
    if button.action == "task" then args = { task = button.value }
    elseif button.action == "store" or button.action == "retrieve" then args = button.value end
    NLHouseholdClient.request(self.playerIndex, button.action, args)
end

function NLHouseholdPanel:prerender()
    ISPanel.prerender(self)
    self:drawText("NEIGHBORHOOD / HOUSEHOLD", 16, 14, 0.12, 0.38, 0.63, 1, UIFont.Small)
    self:drawText("Shared home, responsibilities and co-op routines", 16, 80,
        0.18, 0.24, 0.32, 1, UIFont.Small)
    local state = NLHouseholdClient.snapshots[self.playerIndex]
    if not state then
        self:drawText("Waiting for household data. Refresh to check.", 16, 112,
            0.18, 0.24, 0.32, 1, UIFont.Small)
        return
    end
    local p = NLClient.profiles[self.playerIndex]
    local invite = state.invite
    if invite then
        self:drawText("INVITE: " .. tostring(invite.name or invite.householdId)
            .. " from " .. tostring(invite.from), 16, 112, 0.12, 0.38, 0.63, 1, UIFont.Small)
    elseif state.household then
        local h = state.household
        self:drawText(h.name .. " / owner: " .. tostring(h.owner), 16, 112,
            0.12, 0.38, 0.63, 1, UIFont.Small)
        self:drawText("Home tile " .. tostring(h.home.x) .. ", " .. tostring(h.home.y)
            .. ", " .. tostring(h.home.z), 16, 136, 0.30, 0.38, 0.47, 1, UIFont.Small)
        local y = 164
        for _, member in ipairs(h.members or {}) do
            self:drawText((member.online and "● " or "○ ") .. member.username
                .. " / " .. member.role .. " / " .. tostring(member.contribution) .. " routines",
                16, y, 0.18, 0.24, 0.32, 1, UIFont.Small)
            y = y + 24
        end
        self:drawText("Activities today: tidy " .. tostring(h.tasks.tidy or 0)
            .. " | meal " .. tostring(h.tasks.meal or 0)
            .. " | social " .. tostring(h.tasks.social or 0), 16, 304,
            0.30, 0.38, 0.47, 1, UIFont.Small)
        local stored = {}
        for itemType, amount in pairs(h.storage or {}) do
            stored[#stored + 1] = itemType .. " x" .. tostring(amount)
        end
        table.sort(stored)
        self:drawText("Shared storage: " .. (#stored > 0 and table.concat(stored, ", ") or "empty"),
            16, 328, 0.30, 0.38, 0.47, 1, UIFont.Small)
    else
        self:drawText("No household yet. Create a home or accept an invitation.", 16, 112,
            0.18, 0.24, 0.32, 1, UIFont.Small)
    end
    for task, button in pairs(self.taskButtons) do
        button:setEnable(state.household ~= nil and p ~= nil)
    end
    for _, button in pairs(self.storageButtons or {}) do
        button:setEnable(state.household ~= nil and p ~= nil)
    end
    if self.transferButton then
        self.transferButton:setEnable(self:transferTarget() ~= nil)
    end
    self:drawText(state.message or "", 16, 464, 0.12, 0.38, 0.63, 1, UIFont.Small)
end

function NLHouseholdPanel.open(index)
    local panel = NLHouseholdPanel.instances[index]
    if not panel then
        panel = NLHouseholdPanel:new(index); panel:initialise()
        NLHouseholdPanel.instances[index] = panel
    end
    panel:setX(getPlayerScreenLeft(index) + math.max(0,
        (getPlayerScreenWidth(index) - panel.width) / 2))
    panel:setY(getPlayerScreenTop(index) + math.max(0,
        (getPlayerScreenHeight(index) - panel.height) / 2))
    panel:removeFromUIManager(); panel:addToUIManager(); panel:setVisible(true); panel:bringToTop()
    NLHouseholdClient.request(index, "refresh")
end

Events.OnMainMenuEnter.Add(function()
    for _, panel in pairs(NLHouseholdPanel.instances) do panel:removeFromUIManager() end
    NLHouseholdPanel.instances = {}
end)
return NLHouseholdPanel
