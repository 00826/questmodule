--!strict

--[[
_template = {
	Name = ""; Desc = "";
	Priority = 0; Repeatable = false;

	Steps = {
		{
			Desc = "";
			Goal = 1; Signals = {  }; Rewards = {  };
		};
	};
};]]

--- catch luaulsp annotation
local _

--- type describing a questprofile, ideally saved to player save data
export type QuestProfile = {
	--- array of already-completed quests, in cases
	Completed: { string };
	--- { [QuestId]: {step, value} }
	Current: { [string]: {number} };
	--- `keyof<QuestProfile.Current>?`, describing the currently-tracked quest
	Tracked: string?;
}

--- type describing a quest step
export type Step = {
	--- target numeric value of quest step \
	--- when `QuestProfile.Current[QuestId][2] >= Goal` \
	--- `QuestProfile.Current[QuestId][1] += 1` (onto next step) \
	--- `QuestProfile.Current[QuestId][2] = 0` (reset step value)
	Goal: number;
	--- array of step signals that will advance this step forward
	Signals: { string };
	--- empty table, populated with rewards to be applied upon step completion
	Rewards: {  }?;

	-- optional fields for quest interfaces etc:
	--- step description
	Desc: string?;
}

--- type describing a quest, where each element of `Quest.Steps` is interpreted as a step
export type Quest = {
	Steps: { Step };

	-- optional fields for quest interfaces etc:
	--- name of quest
	Name: string?;
	--- description of quest
	Desc: string?;
	--- sort priority of quest, where lower priorities appear first in something like a list
	Priority: number?;
	--- is this quest repeatable? (with respect to `QuestProfile.Completed`)
	Repeatable: boolean?;
	--- rbxasset:// associated with this quest
	Sprite: string?;
}

--- type describing the return value of `QuestModule.addprogress()`
export type Manifest = {
	--- array of completed quests (`SavedQuest[1] > #Quest.Steps`)
	Completed: { string };
	--- array of quests where a step was advanced (`SavedQuest[1] += 1`)
	Advancements: { string };
	--- array of quests where a step had progress added (`SavedQuest[2] += n`)
	Progress: { string };
	--- array of reward tables from completed steps
	Rewards: {  };
	--- array of non-existent, erroneous quests (lacking quest info) \
	--- this is for cases where a player may be holding onto a quest that has since been deleted
	Errors: { string };
}

--- ### QuestModule.luau
---
--- cleanly handles linear, multi-step-style quests
local QuestModule = { Quests = { } :: { [string]: Quest } }

--- returns an empty QuestProfile
function QuestModule.createprofile(): QuestProfile
	return {
		Completed = {};
		Current = {};
		Tracked = nil;
	}
end

--- returns `true` if quest can be added to QuestProfile \
--- otherwise (`false`) return value includes a string describing why the quest cannot not be added
function QuestModule.canadd(id: string, qp: QuestProfile): (boolean, string?)
	local info = QuestModule.Quests[id]
	if not info then
		return false, `quest "{id}" does not exist in QuestModule.Quests`
	end

	if info.Repeatable == true then
		return true
	else
		if qp.Current[id] then
			return false, `quest "{id}" is already in qp.Current`
		else
			return table.find(qp.Completed, id) == nil, `non-repeatable quest "{id}" has already been completed`
		end
	end
end

--- adds quest to QuestProfile \
--- recommended to verify with QuestModule.canadd(id, qp) as this can overwrite pre-existing progress \
--- returns `QuestProfile.Current[id]` for convenience
function QuestModule.add(id: string, qp: QuestProfile)
	qp.Current[id] = {1, 0} --- step 1, progress 0

	return qp.Current[id]
end

--- adds quest progress to quests in `QuestProfile.Current` \
--- `progress: { [quest signal id]: value }`
function QuestModule.progress(qp: QuestProfile, progress: { [string]: number }): Manifest
	local manifest: Manifest = {
		Completed = {};
		Advancements = {};
		Progress = {};

		Rewards = {};
		Errors = {};
	}

	--- iterate through `QuestProfile.Current`
	for id, questprogress in qp.Current do
		local info = QuestModule.Quests[id]
		if info then
			local questlength = #info.Steps

			if questlength < 1 then
				warn(`quest "{id}" has no steps (unable to progress)`)
				continue
			end

			--- avoid quest softlock
			do
				local currentstep = questprogress[1]
				if currentstep < 1 then
					questprogress[1] = 1
				elseif currentstep > questlength then
					questprogress[1] = questlength
				end
			end

			local stepinfo = info.Steps[questprogress[1]]
			local stepsignals = stepinfo.Signals
			local stepgoal = stepinfo.Goal

			--- look for receptive step signals
			for signalid, value in progress do
				if table.find(stepsignals, signalid) then
					questprogress[2] += value

					--- progress was made
					if not table.find(manifest.Progress, id) then
						table.insert(manifest.Progress, id)
					end
				end

				if questprogress[2] >= stepgoal then
					questprogress[1] += 1
					questprogress[2] = 0

					--- advancement was made, also apply relevant rewards
					table.insert(manifest.Advancements, id)
					table.insert(manifest.Rewards, stepinfo.Rewards)

					if questprogress[1] > questlength then
						--- step was completed
						table.insert(manifest.Completed, id)

						--- add to profile completions
						if not table.find(qp.Completed, id) then
							table.insert(qp.Completed, id)
						end

						--- wipe from quest profile to keep clean
						qp.Current[id] = nil
					end
					break
				end
			end
		else
			warn(`quest "{id}" does not exist, inserting into Manifest.Errors to be handled externally`)
			table.insert(manifest.Errors, id)
			continue
		end
	end

	return manifest
end

--- wipes all relevant quest info stored in QuestProfile \
--- `removefromcompleted (?=false)` if exists, wipe entry from `QuestProfile.Completed`, for cases where a non-repeatable quest may have to be repeated
function QuestModule.wipe(id: string, qp: QuestProfile, removefromcompleted: boolean?)
	qp.Current[id] = nil
	
	if qp.Tracked == id then
		qp.Tracked = nil
	end

	if removefromcompleted then
		table.remove(qp.Completed, table.find(qp.Completed, id) or 0)
	end
end

--- returns quest+step as a unique string \
--- for use-cases where the context of quest progression matters (such as dialogs)
function QuestModule.tostring(qp: QuestProfile, id: string): string?
	local quest = qp.Current[id]
	if quest then
		return string.format("%s_%d", id, quest[1] or 1)
	else
		return nil
	end
end

--- formats quest progress for interfaces: \
--- `type == "#"`: displays progress as a quantity, for example `"do /e wave | 0/1"` \
--- `type == "%"`: displays progress as a percentage, for example `"score headshot kills | 23%"` \
--- `2nd arg`: string describing the current step in relation to overall quest length
function QuestModule.format(id: string, questprogress: {number}, type: "#"|"%")
	local info = QuestModule.info(id)

	local step = questprogress[1]
	local stepvalue = questprogress[2]

	local stepinfo = info.Steps[step]
	local stepgoal = stepinfo.Goal

	if type == "#" then
		return string.format("%d/%d", stepvalue, stepgoal), string.format("Step %d of %d", step, #info.Steps)
	elseif type == "%" then
		return string.format("%d%%", (stepvalue / stepgoal) * 100), string.format("Step %d of %d", step, #info.Steps)
	else
		error(`expected "#" or "%" to format progress, got "{type}"`)
	end
end

--- returns `QuestModule.Quests[id]`
function QuestModule.info(id: string): Quest
	assert(QuestModule.Quests[id], `quest "{id}" does not exist in QuestModule.Quests`)
	return QuestModule.Quests[id]
end

return QuestModule