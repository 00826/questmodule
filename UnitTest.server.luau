--!strict

--- ### UnitTest.server.luau
---
--- QuestModule.luau test script

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local QuestModule = require(ReplicatedStorage:WaitForChild("QuestModule"))

local qp = QuestModule.createprofile()

--- add example quest to questmodule \
--- ideally `QuestModule.Quests` would point to an external module \
--- but this just exists for the sake of the unit test
QuestModule.Quests["examplequest"] = {
	Name = "example quest"; Desc = "pass the unit test";
	Priority = 0; Repeatable = false;

	Steps = {
		[1] = {
			Desc = "respond to step signals A or B.";
			Goal = 1; Signals = { "A", "B" }; Rewards = { XP = 50 };
		};
		[2] = {
			Desc = "respond to step signal C.";
			Goal = 100; Signals = { "C" }; Rewards = { Mango = 1 };
		};
		[3] = {
			Desc = "respond to step signal A";
			Goal = 1; Signals = { "A" }; Rewards = { XP = 1000; Mango = 100; };
		};
	};
}

local questid_that_errors = "quest_that_does_not_exist"
local questid = "examplequest"

--- [0]
--- try to add a quest that does not exist
do
	local s, e = QuestModule.canadd(questid_that_errors, qp)
	if s then
		--- case will never arrive here
	else
		warn(e)
	end
end

--- [1]
--- try to add a quest that does exist
do
	local s, e = QuestModule.canadd(questid, qp)
	if s then
		--- [2]
		--- add this quest to questprofile
		local progress = QuestModule.add(questid, qp)
		print("[2]", `new quest: "{questid}"`, qp, progress)
	else
		warn(e)
	end
end

--- [3]
--- progress questprofile with step signal `"D"`, should add no progress
do
	local manifest = QuestModule.progress(qp, { D = 100 })
	print("[3]", qp, manifest)
end

--- [4]
--- progress questprofile with step signal `"C"`, should add no progress as quest step is 0
do
	local manifest = QuestModule.progress(qp, { C = 1 })
	print("[4]", qp, manifest)
end

--- [5]
--- progress questprofile with step signal `"B"`, should advance quest step to 2 and reset value to 0
do
	local manifest = QuestModule.progress(qp, { B = 1 })
	print("[5]", qp, manifest, manifest.Rewards)
end

--- [6]
--- progress questprofile with step signal `"C"`, should make progress 50/100 or 50%
do
	local manifest = QuestModule.progress(qp, { C = 50 })
	local formatasquantity = QuestModule.format(questid, qp.Current[questid], "#")
	local formataspercentage, roadmap = QuestModule.format(questid, qp.Current[questid], "%")
	print("[6]", qp, manifest, formatasquantity, formataspercentage, roadmap)
end

--- [7]
--- negatively progress questprofile with step signal `"C"`, should make progress 25/100 or 25%
--- useful for quests that lose progress on death etc
do
	local manifest = QuestModule.progress(qp, { C = -25 })
	local formatasquantity = QuestModule.format(questid, qp.Current[questid], "#")
	local formataspercentage = QuestModule.format(questid, qp.Current[questid], "%")
	print("[7]", qp, manifest, formatasquantity, formataspercentage)
end

--- [8]
--- progress questprofile with step signal `"C"`, should advance quest to step 3
do
	local manifest = QuestModule.progress(qp, { C = 75 })
	print("[8]", qp, manifest)
	for _, id in manifest.Advancements do
		print(`new quest step! "{id}"`)
	end
end

--- [9]
--- progress questprofile with step signal `"A"`, should apply quest completion
do
	local manifest = QuestModule.progress(qp, { A = 1 })
	print("[9]", qp, manifest)
	for _, id in manifest.Completed do
		print(`quest complete! "{id}"`)
	end
end

--- [10]
--- attempt to add non-repeatable quest
do
	local s, e = QuestModule.canadd(questid, qp)
	if s then
		--- should not arrive at this case
	else
		warn("[10]", e)
	end
end

--- [11]
--- artificially insert a nonexistent quest, then progress questprofile with arbitrary step signal
do
	qp.Current[questid_that_errors] = table.create(2, 0)
	local manifest = QuestModule.progress(qp, { E = 10 })
	print("[11]", qp, manifest, manifest.Errors)

	--- [12]
	--- sample case to clear erroneous quests
	for _, id in manifest.Errors do
		QuestModule.wipe(id, qp, true)
	end
	print("[12]", qp, manifest)
end

print("unit test done :D!")